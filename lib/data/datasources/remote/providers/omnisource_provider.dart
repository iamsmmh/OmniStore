import 'package:logging/logging.dart';

import '../../../../domain/models/repository_entity.dart';
import '../../../../domain/models/app_entity.dart';
import '../../../../domain/services/repository_provider.dart';
import '../../remote/api_client.dart';

/// OmniSource feed provider
/// First-class support for OmniSource feeds
class OmniSourceProvider implements RepositoryProvider {
  final ApiClient _apiClient;
  final _logger = Logger('OmniSourceProvider');

  OmniSourceProvider(this._apiClient);

  @override
  RepositoryType get type => RepositoryType.omnsource;

  @override
  bool canHandle(String url) {
    return url.contains('omnisource') || url.contains('/feed');
  }

  @override
  Future<RepositoryValidationData> validate(String url) async {
    try {
      final feedData = await _apiClient.getOmniSourceFeed(url);

      if (feedData == null) {
        return RepositoryValidationData(isValid: false, name: '', appCount: 0);
      }

      final apps = feedData['apps'] as List? ?? [];
      final feedInfo = feedData['feedInfo'] as Map<String, dynamic>?;

      return RepositoryValidationData(
        isValid: true,
        name: feedInfo?['name'] as String? ?? 'OmniSource Feed',
        description: feedInfo?['description'] as String?,
        iconUrl: feedInfo?['iconUrl'] as String?,
        maintainer: feedInfo?['maintainer'] as String?,
        appCount: apps.length,
        metadata: feedData,
      );
    } catch (e) {
      _logger.severe('Failed to validate OmniSource feed: $url', e);
      return RepositoryValidationData(isValid: false, name: '', appCount: 0);
    }
  }

  @override
  Future<List<AppEntity>> fetchApps(String url) async {
    try {
      final feedData = await _apiClient.getOmniSourceFeed(url);
      if (feedData == null) return [];

      final apps = feedData['apps'] as List? ?? [];
      return apps
          .map((app) => _mapOmniSourceApp(app, url))
          .whereType<AppEntity>()
          .toList();
    } catch (e) {
      _logger.severe('Failed to fetch OmniSource apps: $url', e);
      return [];
    }
  }

  @override
  Future<List<AppEntity>> fetchUpdates(String url, DateTime since) async {
    try {
      final feedData = await _apiClient.getOmniSourceUpdates(url, since);
      if (feedData == null) return [];

      final apps = feedData['apps'] as List? ?? [];
      return apps
          .map((app) => _mapOmniSourceApp(app, url))
          .whereType<AppEntity>()
          .toList();
    } catch (e) {
      _logger.severe('Failed to fetch OmniSource updates: $url', e);
      return [];
    }
  }

  AppEntity? _mapOmniSourceApp(Map<String, dynamic> app, String sourceUrl) {
    try {
      return AppEntity(
        id: app['id'] as String? ?? '',
        name: app['name'] as String? ?? 'Unknown',
        bundleId: app['bundleId'] as String? ?? '',
        developer: app['developer'] as String? ?? '',
        description: app['description'] as String? ?? '',
        version: app['version'] as String? ?? '0.0.0',
        buildNumber: app['buildNumber'] as String? ?? '1',
        releaseDate: DateTime.parse(
          app['releaseDate'] as String? ?? DateTime.now().toIso8601String(),
        ),
        iconUrl: app['iconUrl'] as String? ?? '',
        screenshots: (app['screenshots'] as List? ?? [])
            .map((s) => s as String)
            .toList(),
        categories: (app['categories'] as List? ?? [])
            .map((c) => c as String)
            .toList(),
        tags: (app['tags'] as List? ?? [])
            .map((t) => t as String)
            .toList(),
        downloadSize: app['downloadSize'] as int? ?? 0,
        minOsVersion: app['minOsVersion'] as String? ?? '',
        sourceUrl: sourceUrl,
        repositoryId: '',
        changelog: app['changelog'] as String?,
        sha256: app['sha256'] as String?,
        downloadUrl: app['downloadUrl'] as String?,
      );
    } catch (e) {
      _logger.warning('Failed to map OmniSource app: $e');
      return null;
    }
  }
}
