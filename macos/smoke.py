"""Exercise the packaged dashboard over HTTP without radio hardware."""
import configparser
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
import urllib.request

exe = str(Path(sys.argv[1]).resolve())
with tempfile.TemporaryDirectory(prefix='meshcore-smoke-') as folder:
    cfg = configparser.ConfigParser()
    cfg.read('config.ini.example')
    cfg['Bot']['db_path'] = str(Path(folder) / 'bot.db')
    cfg['Logging']['log_file'] = ''
    cfg['Web_Viewer']['enabled'] = 'true'
    cfg['Web_Viewer']['host'] = '127.0.0.1'
    cfg['Web_Viewer']['web_viewer_password'] = ''
    config = Path(folder) / 'config.ini'
    with config.open('w') as out:
        cfg.write(out)
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        port = sock.getsockname()[1]
    with (Path(folder) / 'viewer.log').open('w+') as log:
        process = subprocess.Popen([exe, '--desktop-viewer', '--config', str(config), '--host', '127.0.0.1', '--port', str(port)], cwd=folder, stdout=log, stderr=log, env={**os.environ, 'PYTHONUNBUFFERED': '1'})
        try:
            for attempt in range(60):
                if process.poll() is not None:
                    raise RuntimeError(f'Dashboard exited with {process.returncode}')
                try:
                    with urllib.request.urlopen(f'http://127.0.0.1:{port}/', timeout=2) as response:
                        assert response.status == 200
                        assert b'<html' in response.read().lower()
                    print('Packaged dashboard HTTP/template smoke test passed')
                    break
                except OSError:
                    time.sleep(0.5)
            else:
                raise RuntimeError('Dashboard did not respond within 30 seconds')
        except Exception:
            log.flush()
            log.seek(0)
            print(log.read())
            raise
        finally:
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
