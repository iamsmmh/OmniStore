import 'package:omnistore/core/logger/app_logger.dart';

/// Plugin system architecture for future extensibility
/// Supports repository providers, installer providers, and metadata providers

/// Base plugin interface
abstract class OmniStorePlugin {
  /// Unique identifier
  String get id;

  /// Display name
  String get name;

  /// Plugin version
  String get version;

  /// Plugin description
  String get description;

  /// Initialize the plugin
  Future<void> initialize();

  /// Dispose resources
  Future<void> dispose();
}

/// Plugin type categories
enum PluginType {
  repositoryProvider,
  installerAdapter,
  metadataProvider,
  contentFilter,
  notificationHandler,
  themeExtension,
}

/// Plugin manifest for registration
class PluginManifest {
  final String id;
  final String name;
  final String version;
  final String description;
  final String author;
  final String? website;
  final PluginType type;
  final Map<String, dynamic> config;

  const PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    required this.author,
    this.website,
    required this.type,
    this.config = const {},
  });
}

/// Plugin registry for managing plugins
class PluginRegistry {
  final Map<String, OmniStorePlugin> _plugins = {};
  final Map<String, PluginManifest> _manifests = {};
  final _logger = AppLogger.getLogger('PluginRegistry');

  /// Register a plugin
  Future<void> register(
    PluginManifest manifest,
    OmniStorePlugin plugin,
  ) async {
    if (_plugins.containsKey(manifest.id)) {
      _logger.warning('Plugin already registered: ${manifest.id}');
      return;
    }

    try {
      await plugin.initialize();
      _plugins[manifest.id] = plugin;
      _manifests[manifest.id] = manifest;
      _logger.info('Plugin registered: ${manifest.name} v${manifest.version}');
    } catch (e, stack) {
      _logger.severe('Failed to register plugin: ${manifest.name}', e, stack);
      rethrow;
    }
  }

  /// Unregister a plugin
  Future<void> unregister(String id) async {
    final plugin = _plugins[id];
    if (plugin != null) {
      try {
        await plugin.dispose();
        _plugins.remove(id);
        _manifests.remove(id);
        _logger.info('Plugin unregistered: $id');
      } catch (e, stack) {
        _logger.severe('Failed to unregister plugin: $id', e, stack);
      }
    }
  }

  /// Get a plugin by ID
  T? getPlugin<T extends OmniStorePlugin>(String id) {
    final plugin = _plugins[id];
    return plugin is T ? plugin : null;
  }

  /// Get plugins by type
  List<T> getPluginsByType<T extends OmniStorePlugin>(PluginType type) {
    return _manifests.entries
        .where((e) => e.value.type == type)
        .map((e) => _plugins[e.key])
        .whereType<T>()
        .toList();
  }

  /// Get all registered plugins
  List<OmniStorePlugin> get allPlugins => List.unmodifiable(_plugins.values);

  /// Get all manifests
  List<PluginManifest> get allManifests =>
      List.unmodifiable(_manifests.values);

  /// Check if a plugin is registered
  bool isRegistered(String id) => _plugins.containsKey(id);

  /// Dispose all plugins
  Future<void> disposeAll() async {
    for (final entry in _plugins.entries) {
      try {
        await entry.value.dispose();
      } catch (e) {
        _logger.severe('Failed to dispose plugin: ${entry.key}', e);
      }
    }
    _plugins.clear();
    _manifests.clear();
  }
}
