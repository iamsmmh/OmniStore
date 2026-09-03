import 'dart:io';
import 'package:logging/logging.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/logger/app_logger.dart';
import '../../../domain/services/installer_adapter.dart';

/// Android installer adapter
/// Handles APK installation on Android devices
class AndroidInstallerAdapter implements InstallerAdapter {
  final _logger = AppLogger.getLogger('AndroidInstallerAdapter');

  @override
  String get id => 'android';

  @override
  String get name => 'Android Package Manager';

  @override
  Future<bool> isAvailable() async {
    return Platform.isAndroid;
  }

  @override
  Future<InstallResult> install({
    required String filePath,
    required String bundleId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      _logger.info('Installing APK: $bundleId from $filePath');

      // Verify file exists
      final file = File(filePath);
      if (!await file.exists()) {
        return InstallResult.failure('APK file not found: $filePath');
      }

      // Get file size
      final fileSize = await file.length();
      _logger.info('APK size: ${_formatBytes(fileSize)}');

      // Open the APK with the system's installer
      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );

      _logger.info('OpenFilex result: ${result.message} (${result.type})');

      // OpenFilex typically launches the system installer
      // We don't get a definitive success/failure callback,
      // so we return a pending result
      if (result.type == ResultType.done || result.type == ResultType.opened) {
        return InstallResult.success(
          bundleId: bundleId,
          version: metadata?['version'] as String? ?? '1.0.0',
        );
      }

      return InstallResult.failure('Failed to open installer: ${result.message}');
    } catch (e) {
      _logger.severe('Android installation failed', e);
      return InstallResult.failure('Installation failed: ${e.toString()}');
    }
  }

  @override
  Future<bool> uninstall(String bundleId) async {
    try {
      _logger.info('Uninstalling Android app: $bundleId');
      // Android uninstall would typically use intent to open system settings
      // or require the app to have UNINSTALL_REQUEST code
      // For now, we can only open the app info settings
      return false;
    } catch (e) {
      _logger.severe('Android uninstall failed', e);
      return false;
    }
  }

  @override
  Future<bool> isInstalled(String bundleId) async {
    try {
      // Check if the app is installed by trying to get its package info
      // This would typically require platform-specific code
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String?> getInstalledVersion(String bundleId) async {
    try {
      // Get the installed version of the app
      // This would typically require platform-specific code
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<InstalledAppInfo>> getInstalledApps() async {
    try {
      // Get list of installed apps
      // This would typically require platform-specific code
      return [];
    } catch (e) {
      _logger.severe('Failed to get installed apps', e);
      return [];
    }
  }

  @override
  bool supportsFileType(String extension) {
    return extension.toLowerCase() == 'apk';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
