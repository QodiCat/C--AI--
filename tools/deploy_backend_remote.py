#!/usr/bin/env python3
"""Remote half of the source update. Requires only the deployment user's rights."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import signal
import socket
import subprocess
import tarfile
import time
import urllib.request


def extract_source(archive, destination):
    destination.mkdir(exist_ok=False)
    with tarfile.open(archive, 'r:gz') as bundle:
        members = bundle.getmembers()
        for member in members:
            path = Path(member.name)
            if path.is_absolute() or '..' in path.parts or not member.isfile():
                raise ValueError('unsafe source archive member')
            if not path.parts or path.parts[0] not in ('cmd', 'internal', 'go.mod', 'go.sum'):
                raise ValueError('unexpected source archive member')
        bundle.extractall(destination, members=members)


def matching_processes(binary, working_directory):
    result = []
    for process in Path('/proc').iterdir():
        if not process.name.isdecimal():
            continue
        try:
            executable = os.readlink(process / 'exe')
            if executable.endswith(' (deleted)'):
                executable = executable[:-10]
            if process.stat().st_uid == os.getuid() and executable == str(binary) and (process / 'cwd').resolve() == working_directory:
                result.append(int(process.name))
        except (OSError, RuntimeError):
            continue
    return result


def stop_process(pid, binary, working_directory):
    if pid not in matching_processes(binary, working_directory):
        raise RuntimeError('process identity changed; refusing to stop it')
    os.kill(pid, signal.SIGTERM)
    for _ in range(150):
        if pid not in matching_processes(binary, working_directory):
            return
        time.sleep(0.1)
    raise RuntimeError('old process did not exit; new binary was not installed')


def port_in_use(port):
    with socket.socket() as connection:
        connection.settimeout(1)
        return connection.connect_ex(('127.0.0.1', port)) == 0


def healthy(port):
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    try:
        with opener.open(f'http://127.0.0.1:{port}/health', timeout=2) as response:
            value = json.load(response)
            return response.status == 200 and value.get('success') is True and value.get('data', {}).get('status') == 'ok'
    except (OSError, ValueError, AttributeError):
        return False


def start(binary, working_directory, log):
    with log.open('ab') as output:
        return subprocess.Popen([str(binary)], cwd=working_directory, stdin=subprocess.DEVNULL, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)


def update(base, release, port):
    working = (base / 'server').resolve()
    if base not in working.parents:
        raise RuntimeError('server directory must stay inside the deployment directory')
    configuration = working / '.env'
    if not configuration.is_file():
        raise RuntimeError('server/.env must already be configured; no credentials will be uploaded')
    # Inspect only PORT, never echo or source the secret-bearing configuration.
    configured_port = os.environ.get('PORT', '3000')
    if 'PORT' not in os.environ:
        for line in configuration.read_text().splitlines():
            key, separator, value = line.strip().partition('=')
            if separator and key.strip() == 'PORT':
                configured_port = value.strip().strip('\"\'')
    if int(configured_port) != port:
        raise RuntimeError('api_port differs from the configured backend PORT')
    binary = working / 'bin/api'
    (working / 'bin').mkdir(exist_ok=True)
    logs = working / 'logs'
    logs.mkdir(mode=0o700, exist_ok=True)
    stage = base / 'releases' / release
    source = stage / 'source'
    extract_source(stage / 'source.tar.gz', source)
    environment = os.environ.copy()
    environment['GOTOOLCHAIN'] = 'auto'
    print('Downloading modules and compiling clean source; existing service stays running.', flush=True)
    subprocess.run(['go', 'mod', 'download'], cwd=source, env=environment, check=True)
    subprocess.run(['go', 'build', '-o', str(stage / 'api'), './cmd/api'], cwd=source, env=environment, check=True)
    processes = matching_processes(binary, working)
    if len(processes) > 1 or (port_in_use(port) and not processes):
        raise RuntimeError('port belongs to an unrecognized service; refusing to stop it')
    backup = stage / 'previous-api'
    if binary.exists():
        shutil.copy2(binary, backup)
    replacement = working / 'bin/api.new'
    shutil.copy2(stage / 'api', replacement)
    if processes:
        stop_process(processes[0], binary, working)
    if port_in_use(port):
        raise RuntimeError('port is still occupied; previous binary remains installed')
    os.replace(replacement, binary)
    process = start(binary, working, logs / 'api.log')
    for _ in range(30):
        if process.poll() is not None:
            break
        if healthy(port) and process.pid in matching_processes(binary, working):
            (working / 'api.pid').write_text(str(process.pid) + '\n')
            print(f'Update successful. PID {process.pid}. Backup/source: {stage}', flush=True)
            return
        time.sleep(1)
    if process.poll() is None:
        stop_process(process.pid, binary, working)
    if backup.exists():
        shutil.copy2(backup, replacement)
        os.replace(replacement, binary)
    raise RuntimeError(f'health check failed; new service stopped. Old binary restored if available, but not restarted: database migrations are not rolled back. Review {logs / "api.log"} before starting the previous version.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', required=True)
    parser.add_argument('--release', required=True)
    parser.add_argument('--port', required=True, type=int)
    args = parser.parse_args()
    relative = Path(args.base)
    if relative.is_absolute() or '..' in relative.parts or not re.fullmatch(r'[0-9a-f]{32}', args.release) or not 1 <= args.port <= 65535:
        raise SystemExit('invalid deployment arguments')
    base = (Path.home() / relative).resolve()
    if Path.home().resolve() not in base.parents:
        raise SystemExit('deployment directory must be under user home')
    with (base / '.update.lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            update(base, args.release, args.port)
        except BlockingIOError:
            raise SystemExit('Another update is running; this update did not restart the service')
        except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
            raise SystemExit(f'Update failed: {error}')


if __name__ == '__main__':
    main()
