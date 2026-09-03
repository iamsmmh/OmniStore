import 'dart:io';
import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/logger/app_logger.dart';
import '../../domain/services/installer_adapter.dart';
import 'adapters/altstore_adapter.dart';
import 'adapters/sidestore_adapter.dart';
import 'adapters/feather_adapter.dart';
import 'adapters/esign_adapter.dart';
import 'adapters/livecontainer_adapter.dart';

/// Manager for all installer adapters with install/update/reinstall/open and platform filtering.
class InstallerManager {
  final InstallerAdapterRegistry _registry = InstallerAdapterRegistry();
  final _logger = AppLogger.getLogger('InstallerManager');

  InstallerManager() {
    _registerDefaultAdapters();
  }

  void _registerDefaultAdapters() {
    _registry.register(AltStoreAdapter());
    _registry.register(SideStoreAdapter());
    _registry.register(FeatherAdapter());
    _registry.register(ESignAdapter());
    _registry.register(LiveContainerAdapter());
    _logger.info('All installer adapters registered: altstore, sidestore, feather, esign, livecontainer');
  }

  void registerAdapter(InstallerAdapter adapter) {
    _registry.register(adapter);
    _logger.info('Custom adapter registered: ${adapter.name}');
  }

  Future<List<InstallerAdapter>> getAvailableAdapters() {
    return _registry.getAvailableAdapters();
  }

  /// Only adapters that are supported on current platform (for UI filtering).
  List<InstallerAdapter> getSupportedAdapters() {
    return _registry.getSupportedAdapters();
  }

  List<InstallerAdapter> get allAdapters => _registry.allAdapters;

  InstallerAdapter? getAdapter(String id) {
    return _registry.getAdapter(id);
  }

  /// Resolve best adapter for a given file extension.
  Future<InstallerAdapter?> resolveAdapterForFile(String extension) async {
    final available = await getAvailableAdapters();
    for (final a in available) {
      if (a.supportsFileType(extension)) return a;
    }
    return null;
  }

  Future<InstallResult> installApp({
    required String filePath,
    required String bundleId,
    String? preferredAdapter,
    Map<String, dynamic>? metadata,
  }) async {
    final extension = filePath.split('.').last.toLowerCase();
    if (preferredAdapter != null) {
      final adapter = getAdapter(preferredAdapter);
      if (adapter != null && adapter.isSupportedOnCurrentPlatform) {
        if (await adapter.isAvailable() && adapter.supportsFileType(extension)) {
          _logger.info('Installing via preferred adapter: ${adapter.name}');
          return adapter.install(filePath: filePath, bundleId: bundleId, metadata: metadata);
        }
      }
    }
    final available = await getAvailableAdapters();
    for (final adapter in available) {
      if (adapter.supportsFileType(extension)) {
        _logger.info('Installing via adapter: ${adapter.name}');
        return adapter.install(filePath: filePath, bundleId: bundleId, metadata: metadata);
      }
    }
    _logger.warning('No suitable installer for file: $filePath');
    return InstallResult.failure('No suitable installer found for this file type', code: InstallErrorCode.installerNotFound);
  }

  Future<InstallResult> updateApp({
    required String filePath,
    required String bundleId,
    required String currentVersion,
    String? preferredAdapter,
    Map<String, dynamic>? metadata,
  }) async {
    final extension = filePath.split('.').last.toLowerCase();
    if (preferredAdapter != null) {
      final adapter = getAdapter(preferredAdapter);
      if (adapter != null && await adapter.isAvailable() && adapter.supportsFileType(extension)) {
        return adapter.update(filePath: filePath, bundleId: bundleId, currentVersion: currentVersion, metadata: metadata);
      }
    }
    final available = await getAvailableAdapters();
    for (final adapter in available) {
      if (adapter.supportsFileType(extension)) {
        return adapter.update(filePath: filePath, bundleId: bundleId, currentVersion: currentVersion, metadata: metadata);
      }
    }
    return InstallResult.failure('No suitable installer for update', code: InstallErrorCode.installerNotFound);
  }

  Future<InstallResult> reinstallApp({
    required String filePath,
    required String bundleId,
    String? preferredAdapter,
    Map<String, dynamic>? metadata,
  }) async {
    final extension = filePath.split('.').last.toLowerCase();
    if (preferredAdapter != null) {
      final adapter = getAdapter(preferredAdapter);
      if (adapter != null && await adapter.isAvailable() && adapter.supportsFileType(extension)) {
        return adapter.reinstall(filePath: filePath, bundleId: bundleId, metadata: metadata);
      }
    }
    final available = await getAvailableAdapters();
    for (final adapter in available) {
      if (adapter.supportsFileType(extension)) {
        return adapter.reinstall(filePath: filePath, bundleId: bundleId, metadata: metadata);
      }
    }
    return InstallResult.failure('No suitable installer for reinstall', code: InstallErrorCode.installerNotFound);
  }

  Future<bool> openApp(String bundleId, {String? preferredAdapter}) async {
    if (preferredAdapter != null) {
      final adapter = getAdapter(preferredAdapter);
      if (adapter != null && await adapter.isAvailable()) {
        if (await adapter.openApp(bundleId)) return true;
      }
    }
    final available = await getAvailableAdapters();
    for (final adapter in available) {
      try {
        if (await adapter.openApp(bundleId)) return true;
      } catch (_) {}
    }
    // Fallback: try to launch bundle scheme directly
    try {
      final uri = Uri.parse('$bundleId://');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (_) {}
    _logger.warning('Failed to open app: $bundleId');
    return false;
  }

  Future<bool> isAppInstalled(String bundleId) async {
    final available = await getAvailableAdapters();
    for (final adapter in available) {
      try {
        if (await adapter.isInstalled(bundleId)) return true;
      } catch (_) {}
    }
    return false;
  }

  Future<String?> getInstalledVersion(String bundleId) async {
    final available = await getAvailableAdapters();
    for (final adapter in available) {
      try {
        final version = await adapter.getInstalledVersion(bundleId);
        if (version != null) return version;
      } catch (_) {}
    }
    return null;
  }

  Future<List<InstalledAppInfo>> getAllInstalledApps() async {
    final all = <InstalledAppInfo>[];
    final available = await getAvailableAdapters();
    for (final adapter in available) {
      try {
        all.addAll(await adapter.getInstalledApps());
      } catch (e) {
        _logger.warning('Failed to get installed apps from ${adapter.name}: $e');
      }
    }
    return all;
  }
}
