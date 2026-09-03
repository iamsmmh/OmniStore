/// Cross-platform capability model.
///
/// OmniStore's current code assumes a mobile device that can install packages.
/// Web and desktop cannot (or must do so very differently), and today those
/// assumptions are scattered through UI and installer code. Centralising them
/// here means the Discover/Search/Details experience — the majority of the
/// app — compiles and behaves correctly on every target, and only the
/// install action varies.
library;

/// Supported delivery targets.
enum TargetPlatform2 { android, ios, windows, macos, linux, web }

/// What OmniStore can do on the current target.
class PlatformCapabilities {
  final TargetPlatform2 target;

  /// Can hand a downloaded artifact to a system installer.
  final bool canInstallPackages;

  /// Can write large downloads to a persistent filesystem.
  final bool hasFilesystemDownloads;

  /// Can run work while the app is not foregrounded.
  final bool supportsBackgroundSync;

  /// Can raise OS-level notifications.
  final bool supportsNotifications;

  /// Can read the list of installed applications.
  final bool canEnumerateInstalledApps;

  /// Subject to browser CORS rules — repository fetches may need a proxy.
  final bool requiresCorsProxy;

  /// Has a persistent local database (web falls back to IndexedDB-backed or
  /// in-memory storage with a smaller budget).
  final bool hasPersistentDatabase;

  /// Suggested maximum cached catalog entries for this target.
  final int catalogCacheBudget;

  const PlatformCapabilities({
    required this.target,
    required this.canInstallPackages,
    required this.hasFilesystemDownloads,
    required this.supportsBackgroundSync,
    required this.supportsNotifications,
    required this.canEnumerateInstalledApps,
    required this.requiresCorsProxy,
    required this.hasPersistentDatabase,
    required this.catalogCacheBudget,
  });

  /// Discovery, search and details work everywhere; this is the property the
  /// UI should gate browse-only affordances on.
  bool get supportsFullLifecycle => canInstallPackages;

  static const PlatformCapabilities android = PlatformCapabilities(
    target: TargetPlatform2.android,
    canInstallPackages: true,
    hasFilesystemDownloads: true,
    supportsBackgroundSync: true,
    supportsNotifications: true,
    canEnumerateInstalledApps: true,
    requiresCorsProxy: false,
    hasPersistentDatabase: true,
    catalogCacheBudget: 250000,
  );

  static const PlatformCapabilities ios = PlatformCapabilities(
    target: TargetPlatform2.ios,
    // iOS installs are delegated to AltStore/SideStore adapters.
    canInstallPackages: true,
    hasFilesystemDownloads: true,
    supportsBackgroundSync: true,
    supportsNotifications: true,
    // iOS does not permit enumerating installed third-party apps.
    canEnumerateInstalledApps: false,
    requiresCorsProxy: false,
    hasPersistentDatabase: true,
    catalogCacheBudget: 150000,
  );

  static const PlatformCapabilities desktop = PlatformCapabilities(
    target: TargetPlatform2.linux,
    canInstallPackages: true,
    hasFilesystemDownloads: true,
    supportsBackgroundSync: true,
    supportsNotifications: true,
    canEnumerateInstalledApps: false,
    requiresCorsProxy: false,
    hasPersistentDatabase: true,
    catalogCacheBudget: 1000000,
  );

  static const PlatformCapabilities web = PlatformCapabilities(
    target: TargetPlatform2.web,
    canInstallPackages: false,
    hasFilesystemDownloads: false,
    supportsBackgroundSync: false,
    supportsNotifications: false,
    canEnumerateInstalledApps: false,
    requiresCorsProxy: true,
    hasPersistentDatabase: false,
    catalogCacheBudget: 20000,
  );

  PlatformCapabilities withTarget(TargetPlatform2 target) =>
      PlatformCapabilities(
        target: target,
        canInstallPackages: canInstallPackages,
        hasFilesystemDownloads: hasFilesystemDownloads,
        supportsBackgroundSync: supportsBackgroundSync,
        supportsNotifications: supportsNotifications,
        canEnumerateInstalledApps: canEnumerateInstalledApps,
        requiresCorsProxy: requiresCorsProxy,
        hasPersistentDatabase: hasPersistentDatabase,
        catalogCacheBudget: catalogCacheBudget,
      );
}

/// What the install button should offer on the current target.
enum InstallAffordance {
  /// Full install pipeline available.
  install,

  /// Download the artifact only (desktop without an installer adapter).
  download,

  /// Send the user to the upstream release page (web).
  openSourcePage,

  /// Nothing actionable — show why.
  unavailable,
}

InstallAffordance resolveInstallAffordance({
  required PlatformCapabilities capabilities,
  required bool hasInstallerAdapter,
  required bool hasDownloadUrl,
  required bool hasSourceUrl,
}) {
  if (capabilities.canInstallPackages && hasInstallerAdapter && hasDownloadUrl) {
    return InstallAffordance.install;
  }
  if (capabilities.hasFilesystemDownloads && hasDownloadUrl) {
    return InstallAffordance.download;
  }
  if (hasSourceUrl || hasDownloadUrl) return InstallAffordance.openSourcePage;
  return InstallAffordance.unavailable;
}
