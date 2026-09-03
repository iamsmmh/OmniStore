import 'dart:io';
import 'package:logging/logging.dart';

import '../../core/logger/app_logger.dart';
import '../../domain/services/installer_adapter.dart';
import 'adapters/altstore_adapter.dart';
import 'adapters/sidestore_adapter.dart';
import 'adapters/android_adapter.dart';

/// Manager for all installer adapters
class InstallerManager {
  final InstallerAdapterRegistry _registry = InstallerAdapterRegistry();
  final _logger = AppLogger.getLogger('InstallerManager');

  InstallerManager() {
    _registerDefaultAdapters();
  }

  void _registerDefaultAdapters() {
    _registry.register(AndroidInstallerAdapter());
    _registry.register(AltStoreAdapter());
    _registry.register(SideStoreAdapter());
    _logger.info('Default installer adapters registered: '
        'Android, AltStore, SideStore');
  }

  /// Register a custom installer adapter
  void registerAdapter(InstallerAdapter adapter) {
    _registry.register(adapter);
    _logger.info('Custom adapter registered: ${adapter.name}');
  }

  /// Get all available adapters
  Future<List<InstallerAdapter>> getAvailableAdapters() {
    return _registry.getAvailableAdapters();
  }

  /// Get a specific adapter by ID
  InstallerAdapter? getAdapter(String id) {
    return _registry.getAdapter(id);
  }

  /// Install an app using the best available adapter
  Future<InstallResult> installApp({
    required String filePath,
    required String bundleId,
    String? preferredAdapter,
    Map<String, dynamic>? metadata,
  }) async {
    // Get file extension
    final file = File(filePath);
    final extension = file.path.split('.').last.toLowerCase();

    // If a specific adapter is preferred, try it first
    if (preferredAdapter != null) {
      final adapter = getAdapter(preferredAdapter);
      if (adapter != null) {
        if (await adapter.isAvailable()) {
          if (adapter.supportsFileType(extension)) {
            _logger.info(
              'Installing using preferred adapter: ${adapter.name}',
            );
            return adapter.install(
              filePath: filePath,
              bundleId: bundleId,
              metadata: metadata,
            );
          }
        }
      }
    }

    // Try all available adapters
    final available = await getAvailableAdapters();
    for (final adapter in available) {
      if (adapter.supportsFileType(extension)) {
        _logger.info('Installing using adapter: ${adapter.name}');
        return adapter.install(
          filePath: filePath,
          bundleId: bundleId,
          metadata: metadata,
        );
      }
    }

    _logger.severe('No suitable installer found for file: $filePath');
    return InstallResult.failure('No suitable installer found');
  }

  /// Check if an app is installed (via any adapter)
  Future<bool> isAppInstalled(String bundleId) async {
    final available = await getAvailableAdapters();
    for (final adapter in available) {
      if (await adapter.isInstalled(bundleId)) {
        return true;
      }
    }
    return false;
  }

  /// Get installed version from any adapter
  Future<String?> getInstalledVersion(String bundleId) async {
    final available = await getAvailableAdapters();
    for (final adapter in available) {
      final version = await adapter.getInstalledVersion(bundleId);
      if (version != null) {
        return version;
      }
    }
    return null;
  }

  /// Get all installed apps from all adapters
  Future<List<InstalledAppInfo>> getAllInstalledApps() async {
    final allApps = <InstalledAppInfo>[];
    final available = await getAvailableAdapters();

    for (final adapter in available) {
      final apps = await adapter.getInstalledApps();
      allApps.addAll(apps);
    }

    return allApps;
  }
}
