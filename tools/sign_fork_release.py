"""Sign the fork's unsigned ARM64 APK without exposing signing credentials."""
from __future__ import annotations

import argparse
import base64
import hashlib
import os
from pathlib import Path
import re
import subprocess
import tempfile


def command(args: list[str], phase: str) -> str:
    result = subprocess.run(args, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(f'{phase} failed; credentials and tool output withheld')
    return result.stdout


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    version = os.environ['RELEASE_VERSION']
    build = os.environ['RELEASE_BUILD']
    certificate = os.environ['ANDROID_SIGNING_CERT_SHA256'].lower()
    if not re.fullmatch(r'\d+\.\d+\.\d+', version) or not re.fullmatch(r'[1-9]\d*', build):
        raise ValueError('Invalid release version')
    if not re.fullmatch(r'[0-9a-f]{64}', certificate):
        raise ValueError('Missing or invalid pinned signing certificate')
    tools = Path(os.environ['ANDROID_HOME']) / 'build-tools' / '36.0.0'
    badging = command([str(tools / 'aapt'), 'dump', 'badging', str(args.input)], 'Inspect APK')
    identity = f"name='io.github.lingszb.wenku8.localreader' versionCode='{build}' versionName='{version}'"
    if identity not in badging or 'application-debuggable' in badging or "native-code: 'arm64-v8a'" not in badging:
        raise ValueError('APK package, version, architecture or Release mode mismatch')
    args.output.mkdir(parents=True, exist_ok=True)
    apk = args.output / f'wenku8-{version}-arm64-v8a.apk'
    with tempfile.TemporaryDirectory(prefix='fork-signing-') as temporary:
        key = Path(temporary) / 'release.jks'
        key.write_bytes(base64.b64decode(os.environ['ANDROID_KEYSTORE_BASE64'], validate=True))
        key.chmod(0o600)
        command([
            str(tools / 'apksigner'), 'sign', '--v4-signing-enabled', 'false', '--ks', str(key),
            '--ks-key-alias', os.environ['ANDROID_KEY_ALIAS'],
            '--ks-pass', 'env:ANDROID_STORE_PASSWORD', '--key-pass', 'env:ANDROID_KEY_PASSWORD',
            '--out', str(apk), str(args.input),
        ], 'Sign APK')
    verification = command([str(tools / 'apksigner'), 'verify', '--verbose', '--print-certs', str(apk)], 'Verify APK')
    found = re.findall(r'certificate SHA-256 digest: ([0-9a-fA-F]{64})', verification)
    if len(found) != 1 or found[0].lower() != certificate:
        apk.unlink()
        raise ValueError('Unexpected APK signing certificate')
    with apk.open('rb') as stream:
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    (args.output / 'SHA256SUMS.txt').write_text(f'{digest}  {apk.name}\n')
    (args.output / 'signing-certificate-sha256.txt').write_text(certificate + '\n')
    print(f'Verified signed Release: {apk.name}; SHA256={digest}')


if __name__ == '__main__':
    main()
