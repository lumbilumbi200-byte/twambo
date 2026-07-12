import 'package:package_info_plus/package_info_plus.dart';
import '../api/api_client.dart';
import '../api/endpoints.dart';

class VersionResult {
  final String currentVersion;
  final String latestVersion;
  final String minRequiredVersion;
  final String downloadUrl;
  final String releaseNotes;

  const VersionResult({
    required this.currentVersion,
    required this.latestVersion,
    required this.minRequiredVersion,
    required this.downloadUrl,
    required this.releaseNotes,
  });

  // Returns <0 if a < b, 0 if equal, >0 if a > b
  static int _cmp(String a, String b) {
    final ap = a.trim().split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final bp = b.trim().split('.').map((s) => int.tryParse(s) ?? 0).toList();
    for (int i = 0; i < 3; i++) {
      final ai = i < ap.length ? ap[i] : 0;
      final bi = i < bp.length ? bp[i] : 0;
      if (ai != bi) return ai.compareTo(bi);
    }
    return 0;
  }

  // Current is below minimum — must update before proceeding
  bool get isForceUpdate => _cmp(currentVersion, minRequiredVersion) < 0;

  // Current works but newer version exists — optional prompt
  bool get isSoftUpdate => !isForceUpdate && _cmp(currentVersion, latestVersion) < 0;

  bool get isUpToDate => !isForceUpdate && !isSoftUpdate;
}

class VersionCheckService {
  static Future<VersionResult?> check() async {
    try {
      final results = await Future.wait([
        PackageInfo.fromPlatform(),
        ApiClient.dio.get(Endpoints.appVersion),
      ]);
      final info = results[0] as PackageInfo;
      final data = (results[1] as dynamic).data as Map<String, dynamic>;
      return VersionResult(
        currentVersion: info.version,
        latestVersion: data['latest_version'] as String,
        minRequiredVersion: data['min_required_version'] as String,
        downloadUrl: data['download_url'] as String,
        releaseNotes: data['release_notes'] as String? ?? '',
      );
    } catch (_) {
      return null; // network failure → let the app open normally
    }
  }
}
