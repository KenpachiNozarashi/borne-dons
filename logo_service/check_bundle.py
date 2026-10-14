"""Smoke-test the actual packaged service on Windows/Linux CI runners."""
import os
from pathlib import Path
import subprocess
import sys
import time
import urllib.request

executable = Path('dist/logo-service') / ('logo-service.exe' if os.name == 'nt' else 'logo-service')
process = subprocess.Popen([str(executable.resolve())], cwd=str(executable.parent))
try:
    for attempt in range(120):
        if process.poll() is not None:
            raise RuntimeError(f'Packaged service exited with code {process.returncode}')
        try:
            with urllib.request.urlopen('http://127.0.0.1:3002/health', timeout=1) as response:
                if response.status == 200:
                    break
        except Exception:
            time.sleep(1)
    else:
        raise RuntimeError('Packaged service did not become ready')
    subprocess.run([sys.executable, 'logo_service/smoke_test.py'], check=True)
finally:
    process.terminate()
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        process.kill()
    log = Path(os.environ.get('LOCALAPPDATA', str(Path.home()))) / 'borne-dons/logo-service.log'
    if log.exists():
        print(log.read_text(encoding='utf-8', errors='replace')[-12000:])
