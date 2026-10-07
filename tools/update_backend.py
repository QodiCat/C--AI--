#!/usr/bin/env python3
"""Upload a clean source release and update a user's backend over SSH."""
import argparse
import json
from pathlib import Path
import re
import shlex
import subprocess
import tarfile
import tempfile
import uuid

ROOT = Path(__file__).resolve().parent.parent


def read_config(path):
    config = json.loads(path.read_text())
    target = config['ssh_target']
    directory = config['remote_directory']
    if not re.fullmatch(r'[A-Za-z0-9_][A-Za-z0-9_.-]*@[A-Za-z0-9][A-Za-z0-9_.-]*', target):
        raise ValueError('ssh_target must be user@host')
    if not re.fullmatch(r'[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*', directory):
        raise ValueError('remote_directory must be a relative path under the SSH user home')
    if any(part in ('.', '..') for part in directory.split('/')):
        raise ValueError('relative traversal is not allowed')
    for key in ('ssh_port', 'api_port'):
        if type(config[key]) is not int or not 1 <= config[key] <= 65535:
            raise ValueError(f'{key} must be a valid port')
    return config


def package_source(destination, root=ROOT):
    source = root / 'server'
    with tarfile.open(destination, 'w:gz') as archive:
        for name in ('go.mod', 'go.sum', 'cmd', 'internal'):
            path = source / name
            if not path.exists():
                raise ValueError(f'missing server source: {name}')
            paths = [path] if path.is_file() else sorted(path.rglob('*'))
            for entry in paths:
                if entry.is_symlink():
                    raise ValueError('source symlinks are not supported')
                if entry.is_file():
                    relative = entry.relative_to(source)
                    if any(part.startswith('.env') or part in ('logs', 'data', 'bin', '.cache') for part in relative.parts):
                        continue
                    archive.add(entry, arcname=str(relative), recursive=False)


def run(config, dry_run=False):
    token = uuid.uuid4().hex
    remote = f"{config['remote_directory']}/releases/{token}"
    with tempfile.TemporaryDirectory(prefix='ai-closet-update-') as temporary:
        archive = Path(temporary) / 'source.tar.gz'
        package_source(archive)
        print(f"Destination: {config['ssh_target']}:{config['remote_directory']}", flush=True)
        print('Source packaged; server .env, runtime data and logs are excluded.', flush=True)
        if dry_run:
            print('Dry run complete: no SSH connection or server mutation.')
            return
        options = ['-o', 'ControlMaster=auto', '-o', 'ControlPersist=60', '-o', 'ControlPath=' + str(Path(temporary) / 'ssh')]
        ssh = ['ssh', *options, '-p', str(config['ssh_port']), config['ssh_target']]
        scp = ['scp', *options, '-P', str(config['ssh_port'])]
        subprocess.run(ssh + ['mkdir -p -- ' + shlex.quote(remote)], check=True)
        for local, name in ((archive, 'source.tar.gz'), (ROOT / 'tools/deploy_backend_remote.py', 'apply.py')):
            subprocess.run(scp + [str(local), f"{config['ssh_target']}:{remote}/{name}"], check=True)
        command = shlex.join(['python3', remote + '/apply.py', '--base', config['remote_directory'], '--release', token, '--port', str(config['api_port'])])
        subprocess.run(ssh + [command], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, default=ROOT / 'deploy/backend.json')
    parser.add_argument('--dry-run', action='store_true', help='validate configuration and package locally without contacting the server')
    args = parser.parse_args()
    try:
        run(read_config(args.config), args.dry_run)
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        raise SystemExit(f'Update failed: {error}')


if __name__ == '__main__':
    main()
