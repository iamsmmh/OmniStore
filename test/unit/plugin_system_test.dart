import 'package:flutter_test/flutter_test.dart';
import 'package:omnistore/core/plugin/plugin_system.dart';

class TestPlugin extends OmniStorePlugin {
  bool initialized = false;
  bool disposed = false;

  @override
  String get id => 'test-plugin';

  @override
  String get name => 'Test Plugin';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'A test plugin';

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  group('PluginRegistry', () {
    late PluginRegistry registry;

    setUp(() {
      registry = PluginRegistry();
    });

    test('should register a plugin', () async {
      final plugin = TestPlugin();
      final manifest = PluginManifest(
        id: 'test-plugin',
        name: 'Test Plugin',
        version: '1.0.0',
        description: 'A test plugin',
        author: 'Test Author',
        type: PluginType.repositoryProvider,
      );

      await registry.register(manifest, plugin);

      expect(registry.isRegistered('test-plugin'), isTrue);
      expect(plugin.initialized, isTrue);
      expect(registry.allPlugins.length, 1);
    });

    test('should not register duplicate plugins', () async {
      final plugin1 = TestPlugin();
      final plugin2 = TestPlugin();
      final manifest = PluginManifest(
        id: 'test-plugin',
        name: 'Test Plugin',
        version: '1.0.0',
        description: 'A test plugin',
        author: 'Test Author',
        type: PluginType.repositoryProvider,
      );

      await registry.register(manifest, plugin1);
      await registry.register(manifest, plugin2);

      expect(registry.allPlugins.length, 1);
    });

    test('should unregister a plugin', () async {
      final plugin = TestPlugin();
      final manifest = PluginManifest(
        id: 'test-plugin',
        name: 'Test Plugin',
        version: '1.0.0',
        description: 'A test plugin',
        author: 'Test Author',
        type: PluginType.repositoryProvider,
      );

      await registry.register(manifest, plugin);
      await registry.unregister('test-plugin');

      expect(registry.isRegistered('test-plugin'), isFalse);
      expect(plugin.disposed, isTrue);
    });

    test('should get plugin by ID', () async {
      final plugin = TestPlugin();
      final manifest = PluginManifest(
        id: 'test-plugin',
        name: 'Test Plugin',
        version: '1.0.0',
        description: 'A test plugin',
        author: 'Test Author',
        type: PluginType.repositoryProvider,
      );

      await registry.register(manifest, plugin);

      final retrieved = registry.getPlugin<TestPlugin>('test-plugin');
      expect(retrieved, isNotNull);
      expect(retrieved?.name, 'Test Plugin');
    });

    test('should dispose all plugins', () async {
      final plugin = TestPlugin();
      final manifest = PluginManifest(
        id: 'test-plugin',
        name: 'Test Plugin',
        version: '1.0.0',
        description: 'A test plugin',
        author: 'Test Author',
        type: PluginType.repositoryProvider,
      );

      await registry.register(manifest, plugin);
      await registry.disposeAll();

      expect(registry.allPlugins.length, 0);
      expect(plugin.disposed, isTrue);
    });
  });

  group('PluginManifest', () {
    test('should create manifest with all fields', () {
      final manifest = PluginManifest(
        id: 'test',
        name: 'Test',
        version: '1.0.0',
        description: 'Test plugin',
        author: 'Author',
        website: 'https://example.com',
        type: PluginType.repositoryProvider,
        config: {'key': 'value'},
      );

      expect(manifest.id, 'test');
      expect(manifest.name, 'Test');
      expect(manifest.version, '1.0.0');
      expect(manifest.type, PluginType.repositoryProvider);
      expect(manifest.config['key'], 'value');
    });
  });
}
