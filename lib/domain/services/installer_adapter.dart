/// Base interface for installer adapters.
/// Supports AltStore, SideStore, Feather, ESign, LiveContainer.
abstract class InstallerAdapter {
  String get id;
  String get name;
  String get version;
  String get supportedPlatform; // ios, android, all

  Future<bool> isAvailable();

  Future<InstallResult> install({
    required String filePath,
    required String bundleId,
    Map<String, dynamic>? metadata,
  });

  Future<InstallResult> update({
    required String filePath,
    required String bundleId,
    required String currentVersion,
    Map<String, dynamic>? metadata,
  });

  Future<InstallResult> reinstall({
    required String filePath,
    required String bundleId,
    Map<String, dynamic>? metadata,
  });

  Future<bool> uninstall(String bundleId);

  Future<bool> isInstalled(String bundleId);

  Future<String?> getInstalledVersion(String bundleId);

  Future<List<InstalledAppInfo>> getInstalledApps();

  Future<bool> openApp(String bundleId);

  bool supportsFileType(String extension);

  /// Whether this adapter should appear in UI on current platform.
  bool get isSupportedOnCurrentPlatform;
}

/// Result of an install/update/reinstall operation.
class InstallResult {
  final bool success;
  final String? bundleId;
  final String? version;
  final String? error;
  final InstallErrorCode? errorCode;

  const InstallResult({
    required this.success,
    this.bundleId,
    this.version,
    this.error,
    this.errorCode,
  });

  factory InstallResult.success({
    required String bundleId,
    required String version,
  }) =>
      InstallResult(success: true, bundleId: bundleId, version: version);

  factory InstallResult.failure(String error, {InstallErrorCode? code}) =>
      InstallResult(success: false, error: error, errorCode: code);
}

enum InstallErrorCode {
  installerNotFound,
  fileNotFound,
  invalidPackage,
  incompatibleOs,
  insufficientStorage,
  networkError,
  cancelled,
  unknown,
}

/// Info about an installed app.
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

/// Registry for installer adapters.
class InstallerAdapterRegistry {
  final List<InstallerAdapter> _adapters = [];

  void register(InstallerAdapter adapter) {
    if (_adapters.any((a) => a.id == adapter.id)) return;
    _adapters.add(adapter);
  }

  void unregister(String id) {
    _adapters.removeWhere((a) => a.id == id);
  }

  Future<List<InstallerAdapter>> getAvailableAdapters() async {
    final available = <InstallerAdapter>[];
    for (final adapter in _adapters) {
      if (!adapter.isSupportedOnCurrentPlatform) continue;
      try {
        if (await adapter.isAvailable()) {
          available.add(adapter);
        }
      } catch (_) {}
    }
    return available;
  }

  /// Adapters that are supported on current platform regardless of installed state.
  List<InstallerAdapter> getSupportedAdapters() {
    return _adapters.where((a) => a.isSupportedOnCurrentPlatform).toList();
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
