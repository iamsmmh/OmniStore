import 'package:flutter_test/flutter_test.dart';
import 'package:omnistore/domain/services/installer_adapter.dart';

void main() {
  group('InstallResult Tests', () {
    test('should create successful install result', () {
      final result = InstallResult.success(
        bundleId: 'com.test.app',
        version: '1.0.0',
      );

      expect(result.success, isTrue);
      expect(result.bundleId, equals('com.test.app'));
      expect(result.version, equals('1.0.0'));
      expect(result.error, isNull);
    });

    test('should create failed install result', () {
      const result = InstallResult.failure('Installation failed');

      expect(result.success, isFalse);
      expect(result.error, equals('Installation failed'));
      expect(result.bundleId, isNull);
      expect(result.version, isNull);
    });
  });

  group('InstalledAppInfo Tests', () {
    test('should create valid installed app info', () {
      final info = InstalledAppInfo(
        bundleId: 'com.example.app',
        name: 'Example App',
        version: '2.5.0',
        installerId: 'altstore',
        installedDate: DateTime(2024, 1, 15),
      );

      expect(info.bundleId, equals('com.example.app'));
      expect(info.name, equals('Example App'));
      expect(info.version, equals('2.5.0'));
      expect(info.installerId, equals('altstore'));
      expect(info.installedDate, equals(DateTime(2024, 1, 15)));
    });

    test('should allow null installer id', () {
      final info = InstalledAppInfo(
        bundleId: 'com.minimal.app',
        name: 'Minimal App',
        version: '1.0.0',
      );

      expect(info.installerId, isNull);
      expect(info.installedDate, isNull);
    });
  });

  group('InstallerAdapterRegistry Tests', () {
    late InstallerAdapterRegistry registry;

    setUp(() {
      registry = InstallerAdapterRegistry();
    });

    test('should start empty', () {
      expect(registry.allAdapters, isEmpty);
    });

    test('should register adapter', () {
      final adapter = _MockInstallerAdapter();
      registry.register(adapter);

      expect(registry.allAdapters.length, equals(1));
      expect(registry.allAdapters.first.id, equals('mock'));
    });

    test('should unregister adapter', () {
      final adapter = _MockInstallerAdapter();
      registry.register(adapter);
      registry.unregister('mock');

      expect(registry.allAdapters, isEmpty);
    });

    test('should get adapter by id', () {
      final adapter = _MockInstallerAdapter();
      registry.register(adapter);

      final found = registry.getAdapter('mock');
      expect(found, isNotNull);
      expect(found?.id, equals('mock'));
    });

    test('should return null for unknown adapter id', () {
      final found = registry.getAdapter('unknown');
      expect(found, isNull);
    });
  });
}

/// Mock installer adapter for testing
class _MockInstallerAdapter implements InstallerAdapter {
  @override
  String get id => 'mock';

  @override
  String get name => 'Mock Installer';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<InstallResult> install({
    required String filePath,
    required String bundleId,
    Map<String, dynamic>? metadata,
  }) async {
    return InstallResult.success(bundleId: bundleId, version: '1.0.0');
  }

  @override
  Future<bool> uninstall(String bundleId) async => true;

  @override
  Future<bool> isInstalled(String bundleId) async => false;

  @override
  Future<String?> getInstalledVersion(String bundleId) async => null;

  @override
  Future<List<InstalledAppInfo>> getInstalledApps() async => [];

  @override
  bool supportsFileType(String extension) => extension == 'ipa';
}
