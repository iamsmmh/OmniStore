import '../../models/repository_entity.dart';
import '../../models/app_entity.dart';

/// Base interface for all repository providers (GitHub, GitLab, etc.)
/// This enables the plugin architecture for new source types
abstract class RepositoryProvider {
  /// The type of repository this provider handles
  RepositoryType get type;

  /// Validate the repository and return metadata
  Future<RepositoryValidationData> validate(String url);

  /// Fetch all apps from the repository
  Future<List<AppEntity>> fetchApps(String url);

  /// Fetch updates since a given timestamp
  Future<List<AppEntity>> fetchUpdates(String url, DateTime since);

  /// Check if this provider can handle the given URL
  bool canHandle(String url);
}

/// Data returned from repository validation
class RepositoryValidationData {
  final bool isValid;
  final String name;
  final String? description;
  final String? iconUrl;
  final String? maintainer;
  final int appCount;
  final Map<String, dynamic> metadata;

  const RepositoryValidationData({
    required this.isValid,
    required this.name,
    this.description,
    this.iconUrl,
    this.maintainer,
    required this.appCount,
    this.metadata = const {},
  });
}

/// Registry for repository providers
class RepositoryProviderRegistry {
  final List<RepositoryProvider> _providers = [];

  void register(RepositoryProvider provider) {
    _providers.add(provider);
  }

  void unregister(RepositoryType type) {
    _providers.removeWhere((p) => p.type == type);
  }

  RepositoryProvider? getProvider(RepositoryType type) {
    try {
      return _providers.firstWhere((p) => p.type == type);
    } catch (_) {
      return null;
    }
  }

  RepositoryProvider? detectProvider(String url) {
    for (final provider in _providers) {
      if (provider.canHandle(url)) {
        return provider;
      }
    }
    return null;
  }

  List<RepositoryProvider> get allProviders => List.unmodifiable(_providers);
}
