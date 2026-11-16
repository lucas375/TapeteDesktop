#!/usr/bin/env python3
"""Inspect the exact source allowlist, staged Git content, app, and optional ZIPs.

Only finding names/counts are printed. Matched values are never logged.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import sys
import zipfile

SOURCE_ENTRIES = ('.gitignore', 'Package.swift', 'README.md', 'PRIVACY.md', 'SECURITY.md',
                  'Sources', 'Resources', 'Scripts', 'Tests', 'Tools', 'docs')
FORBIDDEN_PARTS = {'.git', '.build', '.swiftpm', 'build', 'dist', '.codex', '.agents',
                   'xcuserdata', '__MACOSX'}
PRIVATE_PATH = rb'/' + b'Users' + rb'/[^\s\x00"<>]+|/' + b'home' + rb'/[^\s\x00"<>]+|/' + b'private/var/folders' + rb'/[^\s\x00"<>]+'
RULES = {
    'private-machine-path': re.compile(PRIVATE_PATH),
    'private-project-id': re.compile(rb'\bg-p-[a-f0-9]{24,}\b'),
    'private-key': re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----'),
    'github-token': re.compile(rb'\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})\b'),
    'api-key': re.compile(rb'\bsk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{24,}\b'),
    'cloud-key': re.compile(rb'\b(?:AKIA|ASIA)[A-Z0-9]{16}\b'),
    'credential-in-url': re.compile(rb'https?://[^\s/]+:[^\s/@]+@'),
    'credential-literal': re.compile(rb'''(?i)(?:api_key|access_token|client_secret|password)["']?\s*[:=]\s*["'][A-Za-z0-9_+/=-]{20,}["']'''),
}
EMAIL = re.compile(rb'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}')
FORBIDDEN_SUFFIXES = {'.p12', '.p8', '.pem', '.key', '.mobileprovision', '.provisionprofile',
                      '.xcuserstate', '.sqlite', '.sqlite3', '.db', '.log'}


def source_files(root: Path) -> list[Path]:
    files = []
    for entry in SOURCE_ENTRIES:
        path = root / entry
        if not path.exists():
            continue
        candidates = sorted(path.rglob('*')) if path.is_dir() else [path]
        for candidate in candidates:
            relative = candidate.relative_to(root)
            if '__pycache__' in relative.parts or candidate.name == '.DS_Store':
                continue
            if candidate.is_symlink():
                raise ValueError(f'Symlink is not allowed: {relative.as_posix()}')
            if candidate.is_file():
                files.append(candidate)
    return sorted(files)


def inspect_bytes(name: str, data: bytes) -> list[dict]:
    findings = []
    path = PurePosixPath(name)
    if any(part in FORBIDDEN_PARTS for part in path.parts):
        findings.append({'file': name, 'rule': 'excluded-directory', 'count': 1})
    if path.name.startswith('.env') or path.suffix.lower() in FORBIDDEN_SUFFIXES:
        findings.append({'file': name, 'rule': 'sensitive-file-type', 'count': 1})
    for rule, pattern in RULES.items():
        count = len(pattern.findall(data))
        if count:
            findings.append({'file': name, 'rule': rule, 'count': count})
    # A generated image's public signing-certificate contact is not a user email.
    allowed_domains = {b'users.noreply.github.com'}
    if path.suffix.lower() == '.png':
        allowed_domains.add(b'trufo.ai')
    count = sum(1 for email in EMAIL.findall(data) if email.split(b'@')[-1].lower() not in allowed_domains)
    if count:
        findings.append({'file': name, 'rule': 'email-address', 'count': count})
    return findings


def audit(root: Path, archives: list[Path] | None = None) -> dict:
    findings = []
    files = source_files(root)
    manifest = []
    for path in files:
        name = path.relative_to(root).as_posix()
        data = path.read_bytes()
        findings.extend(inspect_bytes(name, data))
        manifest.append({'path': name, 'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data)})
    if (root / '.git').exists():
        result = subprocess.run(['git', 'ls-files', '-z'], cwd=root, capture_output=True, check=True)
        tracked = [name for name in result.stdout.decode().split('\0') if name]
        expected = {entry['path'] for entry in manifest}
        for name in tracked:
            if name not in expected:
                findings.append({'file': name, 'rule': 'unexpected-git-file', 'count': 1})
            staged = subprocess.run(['git', 'show', ':' + name], cwd=root, capture_output=True, check=True).stdout
            findings.extend(inspect_bytes(name, staged))
    app = root / 'build/TapeteDesktop.app'
    app_manifest = []
    if app.exists():
        for path in sorted(app.rglob('*')):
            if path.is_symlink():
                findings.append({'file': path.relative_to(root).as_posix(), 'rule': 'app-symlink', 'count': 1})
            if path.is_file():
                name = path.relative_to(root / 'build').as_posix()
                data = path.read_bytes()
                findings.extend(inspect_bytes(name, data))
                app_manifest.append({'path': name, 'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data)})
    zip_reports = []
    for archive in archives or []:
        with zipfile.ZipFile(archive) as bundle:
            if bundle.testzip() is not None:
                findings.append({'file': archive.name, 'rule': 'corrupt-zip', 'count': 1})
            if bundle.comment:
                findings.append({'file': archive.name, 'rule': 'zip-comment', 'count': 1})
            for entry in bundle.infolist():
                path = PurePosixPath(entry.filename)
                if path.is_absolute() or '..' in path.parts:
                    findings.append({'file': archive.name, 'rule': 'unsafe-zip-path', 'count': 1})
                if entry.extra or entry.comment:
                    findings.append({'file': entry.filename, 'rule': 'zip-local-metadata', 'count': 1})
                if stat.S_ISLNK(entry.external_attr >> 16):
                    findings.append({'file': entry.filename, 'rule': 'zip-symlink', 'count': 1})
                if not entry.is_dir():
                    findings.extend(inspect_bytes(entry.filename, bundle.read(entry)))
            zip_reports.append({'file': archive.name, 'bytes': archive.stat().st_size,
                                'entries': len(bundle.infolist()), 'sha256': hashlib.sha256(archive.read_bytes()).hexdigest()})
    return {
        'result': 'pass' if not findings else 'fail',
        'scope': 'explicit source allowlist, staged Git content when present, app bundle, and supplied ZIPs',
        'checks': list(RULES) + ['email-address', 'sensitive-file-type', 'unexpected-git-file', 'zip-local-metadata', 'unsafe-zip-path'],
        'limitations': 'Pattern-based review is not an independent security assessment or a guarantee of no vulnerabilities.',
        'source_files': manifest, 'application_files': app_manifest, 'archives': zip_reports,
        'findings': findings,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--zip', action='append', type=Path, default=[])
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    report = audit(args.root.resolve(), args.zip)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n')
    print(json.dumps({'result': report['result'], 'source_files': len(report['source_files']),
                      'application_files': len(report['application_files']), 'archives': len(report['archives']),
                      'findings': report['findings']}, ensure_ascii=False))
    return 0 if report['result'] == 'pass' else 1


if __name__ == '__main__':
    sys.exit(main())
