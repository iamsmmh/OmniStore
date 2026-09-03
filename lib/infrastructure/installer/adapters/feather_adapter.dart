import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/logger/app_logger.dart';
import '../../../domain/services/installer_adapter.dart';

/// Feather installer adapter.
/// Feather is an on-device iOS signer that handles .ipa and .tipa files.
class FeatherAdapter implements InstallerAdapter {
  final _logger = AppLogger.getLogger('FeatherAdapter');

  @override
  String get id => 'feather';
  @override
  String get name => 'Feather';
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
      return await canLaunchUrl(Uri.parse('feather://'));
    } catch (e) {
      _logger.warning('Feather availability check failed', e);
      return false;
    }
  }

  @override
  Future<InstallResult> install({required String filePath, required String bundleId, Map<String, dynamic>? metadata}) async {
    try {
      if (!File(filePath).existsSync()) {
        return InstallResult.failure('Package file not found', code: InstallErrorCode.fileNotFound);
      }
      _logger.info('Installing via Feather: $bundleId');
      // Feather supports direct file import via share sheet or URL scheme
      final uri = Uri.parse('feather://import?url=${Uri.encodeComponent(File(filePath).uri.toString())}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return InstallResult.success(bundleId: bundleId, version: metadata?['version'] as String? ?? '1.0.0');
      }
      // Fallback: try share via system file opener approach
      return InstallResult.failure('Feather not available', code: InstallErrorCode.installerNotFound);
    } catch (e) {
      _logger.severe('Feather install failed', e);
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
      final uri = Uri.parse('feather://');
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
  bool supportsFileType(String extension) {
    final ext = extension.toLowerCase();
    return ext == 'ipa' || ext == 'tipa' || ext == 'zip';
  }
}
