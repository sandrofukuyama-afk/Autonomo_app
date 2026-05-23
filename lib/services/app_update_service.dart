import 'dart:io' show Platform;

import 'package:package_info_plus/package_info_plus.dart';

import '../data/supabase_service.dart';

class AppUpdateInfo {
  final bool hasUpdate;
  final bool forceUpdate;
  final String currentVersion;
  final String targetVersion;
  final String? storeUrl;
  final String? message;

  const AppUpdateInfo({
    required this.hasUpdate,
    required this.forceUpdate,
    required this.currentVersion,
    required this.targetVersion,
    this.storeUrl,
    this.message,
  });
}

class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  Future<AppUpdateInfo?> checkForUpdates() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version.trim();
    final settings = await SupabaseService.instance.getAppSettings();

    final latestVersion = (settings['latest_app_version'] ?? '').toString().trim();
    if (latestVersion.isEmpty) return null;

    final minRequiredVersion =
        (settings['min_supported_app_version'] ?? '').toString().trim();
    final androidUrl = (settings['android_store_url'] ?? '').toString().trim();
    final iosUrl = (settings['ios_store_url'] ?? '').toString().trim();
    final message = (settings['update_message'] ?? '').toString().trim();

    final hasUpdate = _compareSemver(currentVersion, latestVersion) < 0;
    if (!hasUpdate) return null;

    final forceUpdate = minRequiredVersion.isNotEmpty &&
        _compareSemver(currentVersion, minRequiredVersion) < 0;

    String? storeUrl;
    if (Platform.isAndroid && androidUrl.isNotEmpty) {
      storeUrl = androidUrl;
    } else if (Platform.isIOS && iosUrl.isNotEmpty) {
      storeUrl = iosUrl;
    }

    return AppUpdateInfo(
      hasUpdate: true,
      forceUpdate: forceUpdate,
      currentVersion: currentVersion,
      targetVersion: latestVersion,
      storeUrl: storeUrl,
      message: message.isEmpty ? null : message,
    );
  }

  int _compareSemver(String a, String b) {
    final aParts = _normalizeSemver(a);
    final bParts = _normalizeSemver(b);
    for (var i = 0; i < 3; i++) {
      if (aParts[i] > bParts[i]) return 1;
      if (aParts[i] < bParts[i]) return -1;
    }
    return 0;
  }

  List<int> _normalizeSemver(String input) {
    final cleaned = input.split('+').first.trim();
    final parts = cleaned.split('.');
    final normalized = <int>[0, 0, 0];
    for (var i = 0; i < normalized.length && i < parts.length; i++) {
      normalized[i] = int.tryParse(parts[i]) ?? 0;
    }
    return normalized;
  }
}

