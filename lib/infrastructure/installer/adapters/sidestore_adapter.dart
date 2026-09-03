import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/logger/app_logger.dart';
import '../../../domain/services/installer_adapter.dart';

/// SideStore installer adapter.
/// Alternative to AltStore that does not require a PC for refreshing.
class SideStoreAdapter implements InstallerAdapter {
  final _logger = AppLogger.getLogger('SideStoreAdapter');

  @override
  String get id => 'sidestore';
  @override
  String get name => 'SideStore';
  @override
  String get version => '1.0.0';
  @override
  String get supportedPlatform => 'ios';

  @override
  bool get isSupportedOnCurrentPlatform {
    try {
      return Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isAvailable() async {
    if (!isSupportedOnCurrentPlatform) return false;
    try {
      return await canLaunchUrl(Uri.parse('sidestore://'));
    } catch (e) {
      _logger.warning('Failed to check SideStore availability', e);
      return false;
    }
  }

  @override
  Future<InstallResult> install({required String filePath, required String bundleId, Map<String, dynamic>? metadata}) async {
    try {
      if (!File(filePath).existsSync()) {
        return InstallResult.failure('Package not found', code: InstallErrorCode.fileNotFound);
      }
      _logger.info('Installing via SideStore: $bundleId');
      final uri = Uri.parse('sidestore://install?url=${Uri.encodeComponent(filePath)}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return InstallResult.success(bundleId: bundleId, version: metadata?['version'] as String? ?? '1.0.0');
      }
      return InstallResult.failure('SideStore not available', code: InstallErrorCode.installerNotFound);
    } catch (e) {
      _logger.severe('SideStore install failed', e);
      return InstallResult.failure(e.toString(), code: InstallErrorCode.unknown);
    }
  }

  @override
  Future<InstallResult> update({required String filePath, required String bundleId, required String currentVersion, Map<String, dynamic>? metadata}) async {
    return install(filePath: filePath, bundleId: bundleId, metadata: metadata);
  }

  @override
  Future<InstallResult> reinstall({required String filePath, required String bundleId, Map<String, dynamic>? metadata}) async {
    return install(filePath: filePath, bundleId: bundleId, metadata: metadata);
  }

  @override
  Future<bool> uninstall(String bundleId) async => false;

  @override
  Future<bool> isInstalled(String bundleId) async => false;

  @override
  Future<String?> getInstalledVersion(String bundleId) async => null;

  @override
  Future<List<InstalledAppInfo>> getInstalledApps() async => [];

  @override
  Future<bool> openApp(String bundleId) async {
    try {
      final uri = Uri.parse('sidestore://');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  bool supportsFileType(String extension) => extension.toLowerCase() == 'ipa';
}
