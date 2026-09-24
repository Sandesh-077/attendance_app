import 'package:ca_attendance/services/app_update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('semantic versions compare numeric components', () {
    expect(
      AppVersion.parse('1.10.0')!.compareTo(AppVersion.parse('1.9.9')!),
      greaterThan(0),
    );
    expect(AppVersion.parse('1.0.0')!.compareTo(AppVersion.parse('1.0.0')!), 0);
    expect(AppVersion.parse('1.0'), isNull);
  });

  test('required update follows minimum or forced latest release', () {
    const config = ReleaseConfig(
      latestVersion: '1.10.0',
      minimumVersion: '1.2.0',
      releaseNotes: '',
      updateUrl: null,
      forceUpdate: false,
    );
    expect(config.requiresUpdate('1.1.9'), isTrue);
    expect(config.requiresUpdate('1.9.0'), isFalse);
    expect(config.hasUpdate('1.9.0'), isTrue);
    const forced = ReleaseConfig(
      latestVersion: '1.10.0',
      minimumVersion: '1.2.0',
      releaseNotes: '',
      updateUrl: null,
      forceUpdate: true,
    );
    expect(forced.requiresUpdate('1.9.0'), isTrue);
  });

  test('rejects unsafe update URLs', () {
    final config = ReleaseConfig.fromData({
      'latestVersion': '1.0.1',
      'minimumVersion': '1.0.0',
      'updateUrl': 'http://example.com/app.apk',
    });
    expect(config?.updateUrl, isNull);
  });
}
