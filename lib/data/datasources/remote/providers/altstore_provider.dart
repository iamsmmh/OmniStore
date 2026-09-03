import 'package:logging/logging.dart';

import '../../../../domain/models/repository_entity.dart';
import '../../../../domain/models/app_entity.dart';
import '../../../../domain/services/repository_provider.dart';
import '../../remote/api_client.dart';

/// AltStore source provider
/// Handles AltStore source JSON format
class AltStoreProvider implements RepositoryProvider {
  final ApiClient _apiClient;
  final _logger = Logger('AltStoreProvider');

  AltStoreProvider(this._apiClient);

  @override
  RepositoryType get type => RepositoryType.altstore;

  @override
  bool canHandle(String url) {
    return url.contains('altstore') ||
        url.endsWith('.json') && !url.contains('feather');
  }

  @override
  Future<RepositoryValidationData> validate(String url) async {
    try {
      final sourceData = await _apiClient.getAltStoreSource(url);

      if (sourceData == null || sourceData['apps'] == null) {
        return const RepositoryValidationData(isValid: false, name: '', appCount: 0);
      }

      final apps = sourceData['apps'] as List;
      final sourceInfo = sourceData['sourceInfo'] as Map<String, dynamic>?;

      return RepositoryValidationData(
        isValid: true,
        name: sourceInfo?['name'] as String? ?? 'AltStore Source',
        description: sourceInfo?['description'] as String?,
        iconUrl: sourceInfo?['iconURL'] as String?,
        maintainer: sourceInfo?['website'] as String?,
        appCount: apps.length,
        metadata: sourceData,
      );
    } catch (e) {
      _logger.severe('Failed to validate AltStore source: $url', e);
      return const RepositoryValidationData(isValid: false, name: '', appCount: 0);
    }
  }

  @override
  Future<List<AppEntity>> fetchApps(String url) async {
    try {
      final sourceData = await _apiClient.getAltStoreSource(url);
      if (sourceData == null || sourceData['apps'] == null) return [];

      final apps = sourceData['apps'] as List;
      return apps
          .map((app) => _mapAltStoreApp(app, url))
          .whereType<AppEntity>()
          .toList();
    } catch (e) {
      _logger.severe('Failed to fetch AltStore apps: $url', e);
      return [];
    }
  }

  @override
  Future<List<AppEntity>> fetchUpdates(String url, DateTime since) async {
    final apps = await fetchApps(url);
    return apps.where((app) => app.releaseDate.isAfter(since)).toList();
  }

  AppEntity? _mapAltStoreApp(Map<String, dynamic> app, String sourceUrl) {
    try {
      final versions =
        (app['versions'] as List? ?? []).cast<Map<String, dynamic>>();
      final latestVersion = versions.isNotEmpty ? versions.first : null;

      if (latestVersion == null) return null;

      final downloadUrl = latestVersion['downloadURL'] as String? ?? '';
      final size = latestVersion['size'] as int? ?? 0;

      return AppEntity(
        id: app['bundleIdentifier'] as String? ?? '',
        name: app['name'] as String? ?? 'Unknown',
        bundleId: app['bundleIdentifier'] as String? ?? '',
        developer: app['developerName'] as String? ?? '',
        description: app['subtitle'] as String? ?? '',
        version: latestVersion['version'] as String? ?? '0.0.0',
        buildNumber: latestVersion['buildVersion'] as String? ?? '1',
        releaseDate: DateTime.parse(
          latestVersion['date'] as String? ?? DateTime.now().toIso8601String(),
        ),
        iconUrl: app['iconURL'] as String? ?? '',
        screenshots: (app['screenshots'] as List? ?? [])
            .map((s) => s as String)
            .toList(),
        categories: [app['category'] as String? ?? 'Other']
            .whereType<String>()
            .toList(),
        tags: [],
        downloadSize: size,
        minOsVersion: latestVersion['minOSVersion'] as String? ?? '',
        sourceUrl: sourceUrl,
        repositoryId: '',
        changelog: latestVersion['changelog'] as String?,
        sha256: latestVersion['sha256'] as String?,
        downloadUrl: downloadUrl.isNotEmpty ? downloadUrl : null,
      );
    } catch (e) {
      _logger.warning('Failed to map AltStore app: $e');
      return null;
    }
  }
}
