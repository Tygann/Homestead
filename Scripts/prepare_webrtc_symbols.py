#!/usr/bin/env python3
"""Add UUID-matched, pinned WebRTC device symbols before archive export/upload."""
import argparse
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile


def uuids(path):
    result = subprocess.run(['xcrun', 'dwarfdump', '--uuid', str(path)],
                            check=True, capture_output=True, text=True)
    values = set(re.findall(r'UUID: ([0-9A-Fa-f-]+) \(([^)]+)\)', result.stdout))
    if not values:
        raise ValueError(f'No debug UUIDs found: {path}')
    return {(value.upper(), arch) for value, arch in values}


def prepare(archive, cache):
    root = Path(__file__).resolve().parent.parent
    resolved = root / 'Homestead.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved'
    pins = json.loads(resolved.read_text())['pins']
    pin = next(p for p in pins if p['identity'] == 'webrtc')
    if pin['location'] != 'https://github.com/stasel/WebRTC.git':
        raise ValueError('Unsupported WebRTC supplier; review its symbol distribution first.')
    version = pin['state']['version']
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise ValueError(f'Unsupported WebRTC version: {version}')
    info = plistlib.loads((archive / 'Info.plist').read_bytes())
    app = archive / 'Products' / info['ApplicationProperties']['ApplicationPath']
    binary = app / 'Frameworks/WebRTC.framework/WebRTC'
    expected = uuids(binary)
    if {arch for _, arch in expected} != {'arm64'}:
        raise ValueError('Expected an iOS arm64 device archive.')
    destination = archive / 'dSYMs/WebRTC.framework.dSYM'
    if destination.exists():
        if uuids(destination) != expected:
            raise ValueError('Existing archive WebRTC dSYM is mismatched; archive left unchanged.')
        print('Archive already contains matching WebRTC symbols.')
        return

    cache.mkdir(parents=True, exist_ok=True)
    package = cache / f'WebRTC-M{version}-dSYM.zip'
    major = version.split('.')[0]
    url = f'https://github.com/stasel/WebRTC/releases/download/{version}/WebRTC-M{major}-dSYM.zip'
    if not package.exists():
        # Atomic download: interrupted transfers never become reusable cache entries.
        with tempfile.TemporaryDirectory(dir=cache) as temporary:
            download = Path(temporary) / 'download.zip'
            subprocess.run(['curl', '--fail', '--location', '--silent', '--show-error',
                            '--retry', '2', '--output', str(download), url], check=True)
            with zipfile.ZipFile(download) as bundle:
                if bundle.testzip() is not None:
                    raise ValueError('Downloaded symbol ZIP failed its integrity check.')
            os.replace(download, package)

    prefix = 'WebRTC-ios-arm64.dSYM/'
    with tempfile.TemporaryDirectory(dir=cache) as temporary:
        staging = Path(temporary)
        with zipfile.ZipFile(package) as bundle:
            for member in bundle.infolist():
                if not member.filename.startswith(prefix):
                    continue
                target = (staging / member.filename).resolve()
                if not target.is_relative_to(staging.resolve()):
                    raise ValueError('Unsafe symbol ZIP path.')
                if member.is_dir():
                    target.mkdir(parents=True, exist_ok=True)
                else:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    with bundle.open(member) as source, target.open('wb') as output:
                        shutil.copyfileobj(source, output)
        symbols = staging / prefix
        if uuids(symbols) != expected:
            raise ValueError('Downloaded dSYM UUID does not match this archive. No symbols copied.')
        destination.parent.mkdir(parents=True, exist_ok=True)
        # Stage on the archive volume so installation is atomic.
        with tempfile.TemporaryDirectory(dir=destination.parent) as temporary_archive:
            candidate = Path(temporary_archive) / destination.name
            shutil.copytree(symbols, candidate)
            os.rename(candidate, destination)
    print(f'Installed WebRTC {version} symbols: {destination}')
    for value, arch in sorted(expected):
        print(f'  {arch}: {value}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path, help='Existing iOS .xcarchive (modified in place)')
    parser.add_argument('--cache-dir', type=Path,
                        default=Path.home() / 'Library/Caches/Homestead/WebRTCSymbols')
    args = parser.parse_args()
    try:
        prepare(args.archive.resolve(), args.cache_dir.expanduser().resolve())
    except (OSError, ValueError, KeyError, StopIteration, zipfile.BadZipFile,
            subprocess.CalledProcessError) as error:
        print(f'WebRTC symbol preparation failed: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
