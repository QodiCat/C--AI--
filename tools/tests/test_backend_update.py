import importlib.util
import io
import json
from pathlib import Path
import shutil
import socket
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import patch

TOOLS = Path(__file__).resolve().parents[1]


def module(name):
    spec = importlib.util.spec_from_file_location(name, TOOLS / (name + '.py'))
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


client = module('update_backend')
remote = module('deploy_backend_remote')


class PackagingTests(unittest.TestCase):
    def test_only_sources_are_packaged_and_deleted_files_do_not_linger(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            server = root / 'server'
            (server / 'cmd/api').mkdir(parents=True)
            (server / 'internal').mkdir()
            for name in ('go.mod', 'go.sum', 'cmd/api/main.go', 'internal/current.go', '.env', 'cmd/.env'):
                (server / name).write_text('fixture')
            archive = root / 'source.tar.gz'
            client.package_source(archive, root)
            destination = root / 'release'
            remote.extract_source(archive, destination)
            self.assertTrue((destination / 'internal/current.go').exists())
            self.assertFalse((destination / '.env').exists())
            self.assertFalse((destination / 'cmd/.env').exists())
            self.assertFalse((destination / 'internal/deleted.go').exists())

    def test_unsafe_config_and_archive_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = {'ssh_target': 'qodi@example.com', 'ssh_port': 22, 'remote_directory': '../outside', 'api_port': 3000}
            path = root / 'config.json'
            path.write_text(json.dumps(config))
            with self.assertRaises(ValueError):
                client.read_config(path)
            archive = root / 'bad.tar.gz'
            with tarfile.open(archive, 'w:gz') as bundle:
                member = tarfile.TarInfo('../outside')
                member.size = 1
                bundle.addfile(member, io.BytesIO(b'x'))
            with self.assertRaises(ValueError):
                remote.extract_source(archive, root / 'release')
            self.assertFalse((root / 'outside').exists())


    def test_dry_run_does_not_connect_to_server(self):
        config = {'ssh_target': 'qodi@example.com', 'ssh_port': 22, 'remote_directory': 'ai-closet', 'api_port': 3000}
        with patch.object(client.subprocess, 'run') as commands:
            client.run(config, dry_run=True)
            commands.assert_not_called()


class UpdateTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.working = self.base / 'server'
        (self.working / 'bin').mkdir(parents=True)
        (self.working / '.env').write_text('PORT=3000\nDATABASE_PASSWORD=private-fixture\n')
        self.binary = self.working / 'bin/api'
        self.binary.write_bytes(b'old executable')
        self.token = 'a' * 32
        self.stage = self.base / 'releases' / self.token
        self.stage.mkdir(parents=True)
        with tarfile.open(self.stage / 'source.tar.gz', 'w:gz') as bundle:
            member = tarfile.TarInfo('go.mod')
            member.size = 1
            bundle.addfile(member, io.BytesIO(b'x'))

    def build(self, command, **kwargs):
        if command[1] == 'build':
            Path(command[command.index('-o') + 1]).write_bytes(b'new executable')

    def test_build_failure_leaves_existing_service_and_files(self):
        with patch.object(remote.subprocess, 'run', side_effect=subprocess.CalledProcessError(1, ['go'])), patch.object(remote, 'stop_process') as stop:
            with self.assertRaises(subprocess.CalledProcessError):
                remote.update(self.base, self.token, 3000)
            stop.assert_not_called()
        self.assertEqual(self.binary.read_bytes(), b'old executable')
        self.assertIn('private-fixture', (self.working / '.env').read_text())

    def test_unknown_listener_is_never_stopped(self):
        with patch.object(remote.subprocess, 'run', side_effect=self.build), patch.object(remote, 'matching_processes', return_value=[]), patch.object(remote, 'port_in_use', return_value=True), patch.object(remote, 'stop_process') as stop:
            with self.assertRaisesRegex(RuntimeError, 'unrecognized'):
                remote.update(self.base, self.token, 3000)
            stop.assert_not_called()
        self.assertEqual(self.binary.read_bytes(), b'old executable')

    def test_success_saves_backup_and_preserves_configuration(self):
        process = unittest.mock.Mock(pid=123)
        process.poll.return_value = None
        with patch.object(remote.subprocess, 'run', side_effect=self.build), patch.object(remote, 'matching_processes', side_effect=[[100], [123]]), patch.object(remote, 'port_in_use', return_value=False), patch.object(remote, 'stop_process') as stop, patch.object(remote, 'start', return_value=process), patch.object(remote, 'healthy', return_value=True):
            remote.update(self.base, self.token, 3000)
            stop.assert_called_once_with(100, self.binary, self.working)
        self.assertEqual(self.binary.read_bytes(), b'new executable')
        self.assertEqual((self.stage / 'previous-api').read_bytes(), b'old executable')
        self.assertEqual((self.working / 'api.pid').read_text(), '123\n')
        self.assertIn('private-fixture', (self.working / '.env').read_text())

    def test_unhealthy_release_restores_binary_without_automatic_database_rollback(self):
        process = unittest.mock.Mock(pid=123)
        process.poll.return_value = None
        with patch.object(remote.subprocess, 'run', side_effect=self.build), patch.object(remote, 'matching_processes', return_value=[]), patch.object(remote, 'port_in_use', return_value=False), patch.object(remote, 'start', return_value=process) as start, patch.object(remote, 'healthy', return_value=False), patch.object(remote, 'stop_process') as stop, patch.object(remote.time, 'sleep'):
            with self.assertRaisesRegex(RuntimeError, 'database migrations are not rolled back'):
                remote.update(self.base, self.token, 3000)
            stop.assert_called_once_with(123, self.binary, self.working)
            start.assert_called_once()
        self.assertEqual(self.binary.read_bytes(), b'old executable')

    def test_actual_detached_process_identity_and_shutdown(self):
        compiler = shutil.which('cc')
        if not compiler:
            self.skipTest('C compiler required for process identity integration check')
        source = self.base / 'fixture.c'
        source.write_text('#include <unistd.h>\nint main(void) { for (;;) pause(); }\n')
        subprocess.run([compiler, str(source), '-o', str(self.binary)], check=True)
        process = remote.start(self.binary, self.working, self.working / 'log')
        def cleanup():
            if process.poll() is None:
                process.kill()
            process.wait(timeout=5)
        self.addCleanup(cleanup)
        # Wait for exec before inspecting /proc identity.
        for _ in range(100):
            if process.pid in remote.matching_processes(self.binary, self.working):
                break
            remote.time.sleep(0.01)
        self.assertIn(process.pid, remote.matching_processes(self.binary, self.working))
        remote.stop_process(process.pid, self.binary, self.working)
        process.wait(timeout=5)


if __name__ == '__main__':
    unittest.main()
