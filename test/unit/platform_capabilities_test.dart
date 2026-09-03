import 'package:flutter_test/flutter_test.dart';
import 'package:omnistore/core/platform/platform_capabilities.dart';

void main() {
  group('capability profiles', () {
    test('web is browse-only', () {
      expect(PlatformCapabilities.web.canInstallPackages, isFalse);
      expect(PlatformCapabilities.web.supportsFullLifecycle, isFalse);
      expect(PlatformCapabilities.web.requiresCorsProxy, isTrue);
    });

    test('mobile supports the full lifecycle', () {
      expect(PlatformCapabilities.android.supportsFullLifecycle, isTrue);
      expect(PlatformCapabilities.ios.supportsFullLifecycle, isTrue);
    });

    test('iOS cannot enumerate installed apps', () {
      expect(PlatformCapabilities.ios.canEnumerateInstalledApps, isFalse);
      expect(PlatformCapabilities.android.canEnumerateInstalledApps, isTrue);
    });

    test('desktop has the largest cache budget', () {
      expect(PlatformCapabilities.desktop.catalogCacheBudget,
          greaterThan(PlatformCapabilities.android.catalogCacheBudget));
      expect(PlatformCapabilities.android.catalogCacheBudget,
          greaterThan(PlatformCapabilities.web.catalogCacheBudget));
    });

    test('withTarget preserves capabilities', () {
      final windows =
          PlatformCapabilities.desktop.withTarget(TargetPlatform2.windows);
      expect(windows.target, TargetPlatform2.windows);
      expect(windows.canInstallPackages,
          PlatformCapabilities.desktop.canInstallPackages);
      expect(windows.catalogCacheBudget,
          PlatformCapabilities.desktop.catalogCacheBudget);
    });
  });

  group('install affordance', () {
    test('installs when everything is available', () {
      expect(
        resolveInstallAffordance(
          capabilities: PlatformCapabilities.android,
          hasInstallerAdapter: true,
          hasDownloadUrl: true,
          hasSourceUrl: true,
        ),
        InstallAffordance.install,
      );
    });

    test('falls back to download without an installer adapter', () {
      expect(
        resolveInstallAffordance(
          capabilities: PlatformCapabilities.desktop,
          hasInstallerAdapter: false,
          hasDownloadUrl: true,
          hasSourceUrl: true,
        ),
        InstallAffordance.download,
      );
    });

    test('web sends the user to the source page', () {
      expect(
        resolveInstallAffordance(
          capabilities: PlatformCapabilities.web,
          hasInstallerAdapter: false,
          hasDownloadUrl: true,
          hasSourceUrl: true,
        ),
        InstallAffordance.openSourcePage,
      );
    });

    test('reports unavailable when there is nothing to offer', () {
      expect(
        resolveInstallAffordance(
          capabilities: PlatformCapabilities.web,
          hasInstallerAdapter: false,
          hasDownloadUrl: false,
          hasSourceUrl: false,
        ),
        InstallAffordance.unavailable,
      );
    });

    test('mobile without a download URL still offers the source page', () {
      expect(
        resolveInstallAffordance(
          capabilities: PlatformCapabilities.android,
          hasInstallerAdapter: true,
          hasDownloadUrl: false,
          hasSourceUrl: true,
        ),
        InstallAffordance.openSourcePage,
      );
    });
  });
}
