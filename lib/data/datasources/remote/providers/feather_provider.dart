import 'package:logging/logging.dart';

import '../../../../domain/models/repository_entity.dart';
import '../../../../domain/models/app_entity.dart';
import '../../../../domain/services/repository_provider.dart';
import '../api_client.dart';

/// Feather repository provider
/// Handles Feather repositories
class FeatherProvider implements RepositoryProvider {
  final ApiClient _apiClient;
  final _logger = Logger('FeatherProvider');

  FeatherProvider(this._apiClient);

  @override
  RepositoryType get type => RepositoryType.feather;

  @override
  bool canHandle(String url) {
    return url.contains('feather') || url.endsWith('/apps.json');
  }

  @override
  Future<RepositoryValidationData> validate(String url) async {
    try {
      final sourceData = await _apiClient.getFeatherSource(url);

      if (sourceData == null) {
        return RepositoryValidationData(isValid: false, name: '', appCount: 0);
      }

      final apps = sourceData['apps'] as List? ?? [];
      final sourceInfo = sourceData['source'] as Map<String, dynamic>? ?? sourceData['sourceInfo'] as Map<String, dynamic>?;

      return RepositoryValidationData(
        isValid: true,
        name: sourceInfo?['name'] as String? ?? 'Feather Source',
        description: sourceInfo?['description'] as String?,
        iconUrl: sourceInfo?['iconURL'] as String? ?? sourceInfo?['iconUrl'] as String?,
        maintainer: sourceInfo?['maintainer'] as String?,
        appCount: apps.length,
        metadata: sourceData,
      );
    } catch (e) {
      _logger.severe('Failed to validate Feather source: $url', e);
      return RepositoryValidationData(isValid: false, name: '', appCount: 0);
    }
  }

  @override
  Future<List<AppEntity>> fetchApps(String url) async {
    try {
      final sourceData = await _apiClient.getFeatherSource(url);

      if (sourceData == null) return [];

      final apps = sourceData['apps'] as List? ?? [];
      return apps
          .map((app) => _mapFeatherApp(app, url))
          .whereType<AppEntity>()
          .toList();
    } catch (e) {
      _logger.severe('Failed to fetch Feather apps: $url', e);
      return [];
    }
  }

  @override
  Future<List<AppEntity>> fetchUpdates(String url, DateTime since) async {
    final apps = await fetchApps(url);
    return apps.where((app) => app.releaseDate.isAfter(since)).toList();
  }

  AppEntity? _mapFeatherApp(Map<String, dynamic> app, String sourceUrl) {
    try {
      // Feather uses a JSON format similar to AltStore
      final versions = app['versions'] as List? ?? app['releases'] as List? ?? [];
      final latestVersion = versions.isNotEmpty ? versions.first : null;

      if (latestVersion == null) return null;

      final downloadUrl = latestVersion['downloadURL'] as String? ??
          latestVersion['downloadUrl'] as String? ??
          latestVersion['url'] as String? ?? '';

      final size = latestVersion['size'] as int? ?? 0;

      return AppEntity(
        id: app['bundleIdentifier'] as String? ?? app['id'] as String? ?? '',
        name: app['name'] as String? ?? 'Unknown',
        bundleId: app['bundleIdentifier'] as String? ?? '',
        developer: app['developerName'] as String? ?? app['developer'] as String? ?? '',
        description: app['subtitle'] as String? ?? app['description'] as String? ?? '',
        version: latestVersion['version'] as String? ?? '0.0.0',
        buildNumber: latestVersion['buildVersion'] as String? ?? latestVersion['build'] as String? ?? '1',
        releaseDate: DateTime.tryParse(latestVersion['date'] as String? ?? '') ?? DateTime.now(),
        iconUrl: app['iconURL'] as String? ?? app['iconUrl'] as String? ?? '',
        screenshots: (app['screenshots'] as List? ?? [])
            .map((s) => s as String)
            .toList(),
        categories: [app['category'] as String? ?? 'Other']
            .whereType<String>()
            .toList(),
        tags: (app['tags'] as List? ?? [])
            .map((t) => t as String)
            .toList(),
        downloadSize: size,
        minOsVersion: latestVersion['minOSVersion'] as String? ?? latestVersion['minOsVersion'] as String? ?? '',
        sourceUrl: sourceUrl,
        repositoryId: '',
        changelog: latestVersion['changelog'] as String? ?? latestVersion['description'] as String?,
        sha256: latestVersion['sha256'] as String?,
        downloadUrl: downloadUrl.isNotEmpty ? downloadUrl : null,
      );
    } catch (e) {
      _logger.warning('Failed to map Feather app: $e');
      return null;
    }
  }
}
