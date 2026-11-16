#!/usr/bin/env python3
"""Build reviewed source/app ZIPs without extended attributes or owner metadata."""
from __future__ import annotations
import hashlib
import importlib.util
import json
from pathlib import Path
import plistlib
import stat
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('release_audit', ROOT / 'Scripts/audit-release.py')
audit_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit_module)


def archive_files(destination: Path, files: list[tuple[Path, str]]) -> None:
    with zipfile.ZipFile(destination, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path, name in files:
            if path.is_symlink():
                raise ValueError('Symlinks are not included in releases')
            info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            executable = bool(path.stat().st_mode & 0o111)
            info.external_attr = (stat.S_IFREG | (0o755 if executable else 0o644)) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, path.read_bytes())


def main() -> int:
    app = ROOT / 'build/TapeteDesktop.app'
    with (app / 'Contents/Info.plist').open('rb') as stream:
        version = plistlib.load(stream)['CFBundleShortVersionString']
    subprocess.run(['/usr/bin/codesign', '--verify', '--strict', str(app)], check=True)
    before = audit_module.audit(ROOT)
    if before['result'] != 'pass':
        print(json.dumps({'result': 'fail', 'findings': before['findings']})); return 1
    architecture = subprocess.check_output(['/usr/bin/lipo', '-archs', str(app / 'Contents/MacOS/TapeteDesktop')], text=True).strip()
    if architecture != 'arm64':
        raise ValueError('The downloadable artifact name is reserved for the verified arm64 build')
    dist = ROOT / 'dist'
    dist.mkdir(exist_ok=True)
    app_zip = dist / f'TapeteDesktop-v{version}-macOS-arm64.zip'
    source_zip = dist / f'TapeteDesktop-v{version}-codigo-fonte.zip'
    archive_files(app_zip, [(p, p.relative_to(ROOT / 'build').as_posix()) for p in sorted(app.rglob('*')) if p.is_file()])
    archive_files(source_zip, [(p, 'TapeteDesktop/' + p.relative_to(ROOT).as_posix()) for p in audit_module.source_files(ROOT)])
    after = audit_module.audit(ROOT, [app_zip, source_zip])
    (dist / 'AUDIT.json').write_text(json.dumps(after, indent=2, ensure_ascii=False) + '\n')
    if after['result'] != 'pass':
        print(json.dumps({'result': 'fail', 'findings': after['findings']})); return 1
    assets = [app_zip, source_zip, dist / 'AUDIT.json']
    (dist / 'SHA256SUMS.txt').write_text(''.join(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}\n' for p in assets))
    print(json.dumps({'result': 'pass', 'version': version, 'architecture': architecture,
                      'files': [p.name for p in assets] + ['SHA256SUMS.txt']}, ensure_ascii=False))
    return 0


if __name__ == '__main__':
    sys.exit(main())
