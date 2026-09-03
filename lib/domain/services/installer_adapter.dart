/// Base interface for installer adapters
/// Supports AltStore, SideStore, Feather, and future installers
abstract class InstallerAdapter {
  /// Unique identifier for this installer
  String get id;

  /// Display name
  String get name;

  /// Check if this installer is available on the device
  Future<bool> isAvailable();

  /// Install an app from a file path
  Future<InstallResult> install({
    required String filePath,
    required String bundleId,
    Map<String, dynamic>? metadata,
  });

  /// Uninstall an app
  Future<bool> uninstall(String bundleId);

  /// Check if an app is installed
  Future<bool> isInstalled(String bundleId);

  /// Get installed version of an app
  Future<String?> getInstalledVersion(String bundleId);

  /// Get all installed apps managed by this installer
  Future<List<InstalledAppInfo>> getInstalledApps();

  /// Check if this adapter supports the given file type
  bool supportsFileType(String extension);
}

/// Result of an install operation
class InstallResult {
  final bool success;
  final String? bundleId;
  final String? version;
  final String? error;

  const InstallResult({
    required this.success,
    this.bundleId,
    this.version,
    this.error,
  });

  factory InstallResult.success({
    required String bundleId,
    required String version,
  }) =>
      InstallResult(
        success: true,
        bundleId: bundleId,
        version: version,
      );

  factory InstallResult.failure(String error) => InstallResult(
        success: false,
        error: error,
      );
}

/// Info about an installed app
class InstalledAppInfo {
  final String bundleId;
  final String name;
  final String version;
  final String? installerId;
  final DateTime? installedDate;

  const InstalledAppInfo({
    required this.bundleId,
    required this.name,
    required this.version,
    this.installerId,
    this.installedDate,
  });
}

/// Registry for installer adapters
class InstallerAdapterRegistry {
  final List<InstallerAdapter> _adapters = [];

  void register(InstallerAdapter adapter) {
    _adapters.add(adapter);
  }

  void unregister(String id) {
    _adapters.removeWhere((a) => a.id == id);
  }

  Future<List<InstallerAdapter>> getAvailableAdapters() async {
    final available = <InstallerAdapter>[];
    for (final adapter in _adapters) {
      if (await adapter.isAvailable()) {
        available.add(adapter);
      }
    }
    return available;
  }

  InstallerAdapter? getAdapter(String id) {
    try {
      return _adapters.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  List<InstallerAdapter> get allAdapters => List.unmodifiable(_adapters);
}
