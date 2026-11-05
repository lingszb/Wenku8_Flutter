import 'package:flutter_test/flutter_test.dart';
import 'package:wenku8_flutter/updates/app_updates.dart';

void main() {
  const name = 'wenku8-0.5.7-arm64-v8a.apk';
  Map<String, dynamic> release({
    String repository = 'lingszb/Wenku8_Flutter',
  }) => {
    'tag_name': 'v0.5.7+2278',
    'assets': [
      {
        'name': name,
        'size': 100000,
        'browser_download_url':
            'https://github.com/$repository/releases/download/v0.5.7+2278/$name',
      },
    ],
  };

  test('fork release naming is recognized for ARM64 updates', () {
    final parsed = AppRelease.fromGithub(release(), updateRepository)!;
    expect(parsed.assetFor(['arm64-v8a'])?.name, name);
    expect(parsed.assetFor(['x86_64']), isNull);
    expect(
      parsed.isNewerThan(
        const InstalledApp(version: '0.5.6', build: 2277, abis: ['arm64-v8a']),
      ),
      isTrue,
    );
  });

  test('fork updates reject assets pointing at the upstream repository', () {
    final parsed = AppRelease.fromGithub(
      release(repository: 'mikufoxxx/Wenku8_Flutter'),
      updateRepository,
    )!;
    expect(parsed.assets, isEmpty);
  });

  test('draft releases are never offered as application updates', () {
    expect(
      AppRelease.fromGithub({...release(), 'draft': true}, updateRepository),
      isNull,
    );
  });
}
