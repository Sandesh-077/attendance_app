import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch);
  final int major;
  final int minor;
  final int patch;

  static AppVersion? parse(String value) {
    final match = RegExp(
      r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$',
    ).firstMatch(value);
    if (match == null) return null;
    return AppVersion(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
    );
  }

  @override
  int compareTo(AppVersion other) {
    for (final pair in [
      (major, other.major),
      (minor, other.minor),
      (patch, other.patch),
    ]) {
      final result = pair.$1.compareTo(pair.$2);
      if (result != 0) return result;
    }
    return 0;
  }
}

class ReleaseConfig {
  const ReleaseConfig({
    required this.latestVersion,
    required this.minimumVersion,
    required this.releaseNotes,
    required this.updateUrl,
    required this.forceUpdate,
    this.releasedAt,
  });
  final String latestVersion;
  final String minimumVersion;
  final String releaseNotes;
  final Uri? updateUrl;
  final bool forceUpdate;
  final DateTime? releasedAt;

  static ReleaseConfig? fromData(Map<String, dynamic>? data) {
    if (data == null) return null;
    final latest = data['latestVersion'];
    final minimum = data['minimumVersion'];
    if (latest is! String ||
        minimum is! String ||
        AppVersion.parse(latest) == null ||
        AppVersion.parse(minimum) == null) {
      return null;
    }
    final rawUrl = data['updateUrl'];
    final uri = rawUrl is String ? Uri.tryParse(rawUrl) : null;
    final safeUrl =
        uri != null &&
            uri.scheme == 'https' &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty
        ? uri
        : null;
    return ReleaseConfig(
      latestVersion: latest,
      minimumVersion: minimum,
      releaseNotes: data['releaseNotes'] is String
          ? data['releaseNotes'] as String
          : '',
      updateUrl: safeUrl,
      forceUpdate: data['forceUpdate'] == true,
      releasedAt: data['releasedAt'] is Timestamp
          ? (data['releasedAt'] as Timestamp).toDate()
          : null,
    );
  }

  bool requiresUpdate(String installedVersion) {
    final installed = AppVersion.parse(installedVersion);
    if (installed == null) return false;
    return installed.compareTo(AppVersion.parse(minimumVersion)!) < 0 ||
        (forceUpdate &&
            installed.compareTo(AppVersion.parse(latestVersion)!) < 0);
  }

  bool hasUpdate(String installedVersion) {
    final installed = AppVersion.parse(installedVersion);
    return installed != null &&
        installed.compareTo(AppVersion.parse(latestVersion)!) < 0;
  }
}

class AppUpdateService {
  Future<PackageInfo> installedInfo() => PackageInfo.fromPlatform();

  Future<ReleaseConfig?> fetchConfig() async {
    final snapshot = await FirebaseFirestore.instance
        .doc('appConfig/currentVersion')
        .get(const GetOptions(source: Source.server));
    return ReleaseConfig.fromData(snapshot.data());
  }

  Future<bool> releaseNotesShown(String version) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('releaseNotesShownForVersion') == version;
  }

  Future<void> markReleaseNotesShown(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('releaseNotesShownForVersion', version);
  }

  Future<bool> openUpdate(ReleaseConfig config) async {
    final url = config.updateUrl;
    if (url == null) return false;
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
