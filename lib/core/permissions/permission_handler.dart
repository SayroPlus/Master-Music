import 'dart:io';

import 'package:permission_handler/permission_handler.dart' as ph;

/// Handles runtime permission requests for storage and audio access.
///
/// The permission strategy varies by Android SDK level:
/// - **SDK 36 (Android 16)**: READ_MEDIA_AUDIO
/// - **SDK 35 (Android 15)**: READ_MEDIA_AUDIO
/// - **SDK 33–34 (Android 13–14)**: READ_MEDIA_AUDIO
/// - **SDK 29–32 (Android 10–12)**: READ_EXTERNAL_STORAGE + WRITE_EXTERNAL_STORAGE
///
/// Additionally, MANAGE_EXTERNAL_STORAGE is requested separately because
/// it requires navigating to a system settings screen on Android 11+.
class AppPermissionHandler {
  AppPermissionHandler._();

  // ═══════════════════════════════════════════════════════════════════════════
  // Public API
  // ═══════════════════════════════════════════════════════════════════════════

  /// Requests the appropriate media/storage permissions based on SDK version.
  ///
  /// Returns `true` if the base permissions are granted. This does NOT
  /// include MANAGE_EXTERNAL_STORAGE — call [requestManageStorage] for that.
  static Future<bool> checkAndRequestPermissions() async {
    if (!Platform.isAndroid) return false;

    final sdkInt = await _getAndroidSdkVersion();

    if (sdkInt >= 33) {
      // ── Android 13+ (SDK 33–36): granular media permissions ──────────
      final status = await ph.Permission.audio.request();
      if (status.isGranted) return true;
      if (status.isPermanentlyDenied) return false;
      // Try once more if only denied (not permanently)
      final retry = await ph.Permission.audio.request();
      return retry.isGranted;
    } else if (sdkInt >= 29) {
      // ── Android 10–12 (SDK 29–32): legacy storage permissions ────────
      final readStatus = await ph.Permission.storage.request();
      return readStatus.isGranted;
    }

    return false;
  }

  /// Requests MANAGE_EXTERNAL_STORAGE permission.
  ///
  /// On Android 11+ (SDK 30+), this opens the system settings intent
  /// because this permission cannot be granted via a runtime dialog.
  /// On Android 10 (SDK 29), it falls back to legacy storage permission.
  ///
  /// Returns `true` if the permission is granted after the request.
  static Future<bool> requestManageStorage() async {
    if (!Platform.isAndroid) return false;

    final sdkInt = await _getAndroidSdkVersion();

    if (sdkInt >= 30) {
      // Check if already granted
      if (await ph.Permission.manageExternalStorage.isGranted) return true;

      // Request — this opens the system Settings screen
      final status = await ph.Permission.manageExternalStorage.request();
      return status.isGranted;
    } else {
      // SDK 29: MANAGE_EXTERNAL_STORAGE is not available, use legacy
      final status = await ph.Permission.storage.request();
      return status.isGranted;
    }
  }

  /// Returns `true` if MANAGE_EXTERNAL_STORAGE is currently granted.
  static Future<bool> isManageStorageGranted() async {
    if (!Platform.isAndroid) return false;

    final sdkInt = await _getAndroidSdkVersion();

    if (sdkInt >= 30) {
      return await ph.Permission.manageExternalStorage.isGranted;
    } else {
      // On SDK 29, check legacy storage permission
      return await ph.Permission.storage.isGranted;
    }
  }

  /// Returns `true` if the base audio/storage permission is granted.
  static Future<bool> hasAudioPermission() async {
    if (!Platform.isAndroid) return false;

    final sdkInt = await _getAndroidSdkVersion();

    if (sdkInt >= 33) {
      return await ph.Permission.audio.isGranted;
    } else {
      return await ph.Permission.storage.isGranted;
    }
  }

  /// Returns `true` if the permission is permanently denied (user checked
  /// "Don't ask again"). In this case, the user must be directed to settings.
  static Future<bool> isPermissionPermanentlyDenied() async {
    if (!Platform.isAndroid) return false;

    final sdkInt = await _getAndroidSdkVersion();

    if (sdkInt >= 33) {
      return await ph.Permission.audio.isPermanentlyDenied;
    } else {
      return await ph.Permission.storage.isPermanentlyDenied;
    }
  }

  /// Opens the app's system settings page so the user can manually
  /// grant/revoke permissions.
  static Future<bool> openAppSettings() async {
    return await ph.openAppSettings();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Private helpers
  // ═══════════════════════════════════════════════════════════════════════════

  /// Returns the Android SDK version (API level) as an integer.
  ///
  /// Falls back to 29 if detection fails.
  static Future<int> _getAndroidSdkVersion() async {
    try {
      // permission_handler exposes the SDK version internally,
      // but we can also rely on device_info or a simple approach.
      // Using a safe parse of Platform.operatingSystemVersion:
      final versionStr = Platform.operatingSystemVersion;
      final match = RegExp(r'API\s*(\d+)').firstMatch(versionStr);
      if (match != null) {
        return int.parse(match.group(1)!);
      }
      // Fallback: assume modern Android
      return 33;
    } catch (_) {
      return 29;
    }
  }
}
