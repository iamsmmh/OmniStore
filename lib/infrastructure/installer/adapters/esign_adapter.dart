import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/logger/app_logger.dart';
import '../../../domain/services/installer_adapter.dart';

/// ESign installer adapter.
/// ESign is an on-device app signer for iOS.
class ESignAdapter implements InstallerAdapter {
  final _logger = AppLogger.getLogger('ESignAdapter');

  @override
  String get id => 'esign';
  @override
  String get name => 'ESign';
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
      // ESign registers esign://
      return await canLaunchUrl(Uri.parse('esign://'));
    } catch (e) {
      _logger.warning('ESign availability check failed', e);
      return false;
    }
  }

  @override
  Future<InstallResult> install({required String filePath, required String bundleId, Map<String, dynamic>? metadata}) async {
    try {
      if (!File(filePath).existsSync()) {
        return InstallResult.failure('Package not found', code: InstallErrorCode.fileNotFound);
      }
      _logger.info('Installing via ESign: $bundleId');
      final uri = Uri.parse('esign://install?url=${Uri.encodeComponent(File(filePath).uri.toString())}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return InstallResult.success(bundleId: bundleId, version: metadata?['version'] as String? ?? '1.0.0');
      }
      return InstallResult.failure('ESign not available', code: InstallErrorCode.installerNotFound);
    } catch (e) {
      _logger.severe('ESign install failed', e);
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
      final uri = Uri.parse('esign://');
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
