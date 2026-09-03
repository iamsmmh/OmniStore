import 'package:logging/logging.dart';
import '../../../../domain/models/repository_entity.dart';
import '../../../../domain/models/app_entity.dart';
import '../../../../domain/services/repository_provider.dart';
import '../api_client.dart';

/// Feather source provider.
/// Feather JSON format is based on AltStore but includes different fields.
class FeatherProvider implements RepositoryProvider {
  final ApiClient _apiClient;
  final _logger = Logger('FeatherProvider');

  FeatherProvider(this._apiClient);

  @override
  RepositoryType get type => RepositoryType.feather;

  @override
  bool canHandle(String url) {
    return url.toLowerCase().contains('feather');
  }

  @override
  Future<RepositoryValidationData> validate(String url) async {
    try {
      final data = await _apiClient.getFeatherSource(url);
      if (data == null) {
        return const RepositoryValidationData(isValid: false, name: '', appCount: 0);
      }
      // Feather sources may have "apps" or "repositories" top level
      final apps = _extractApps(data);
      final meta = _extractMeta(data);
      return RepositoryValidationData(
        isValid: true,
        name: meta['name'] as String? ?? 'Feather Source',
        description: meta['description'] as String?,
        iconUrl: meta['iconURL'] as String? ?? meta['iconUrl'] as String?,
        maintainer: meta['website'] as String? ?? meta['maintainer'] as String?,
        appCount: apps.length,
        metadata: data,
      );
    } catch (e) {
      _logger.warning('Failed to validate Feather source: $url - $e');
      return const RepositoryValidationData(isValid: false, name: '', appCount: 0);
    }
  }

  @override
  Future<List<AppEntity>> fetchApps(String url) async {
    try {
      final data = await _apiClient.getFeatherSource(url);
      if (data == null) return [];
      final apps = _extractApps(data);
      return apps.map((a) => _mapFeatherApp(a, url)).whereType<AppEntity>().toList();
    } catch (e, stack) {
      _logger.severe('Failed to fetch Feather apps: $url', e, stack);
      return [];
    }
  }

  @override
  Future<List<AppEntity>> fetchUpdates(String url, DateTime since) async {
    final apps = await fetchApps(url);
    return apps.where((a) => a.releaseDate.isAfter(since)).toList();
  }

  List<dynamic> _extractApps(Map<String, dynamic> data) {
    if (data['apps'] is List) return data['apps'] as List;
    if (data['applications'] is List) return data['applications'] as List;
    if (data['repos'] is List) return data['repos'] as List;
    // Some Feather feeds wrap in sourceInfo
    if (data['sourceInfo'] is Map && (data['sourceInfo'] as Map)['apps'] is List) {
      return (data['sourceInfo'] as Map)['apps'] as List;
    }
    return [];
  }

  Map<String, dynamic> _extractMeta(Map<String, dynamic> data) {
    if (data['sourceInfo'] is Map) return Map<String, dynamic>.from(data['sourceInfo'] as Map);
    if (data['meta'] is Map) return Map<String, dynamic>.from(data['meta'] as Map);
    if (data['info'] is Map) return Map<String, dynamic>.from(data['info'] as Map);
    return data;
  }

  AppEntity? _mapFeatherApp(dynamic raw, String sourceUrl) {
    try {
      final app = raw as Map<String, dynamic>;
      final versions = app['versions'] as List? ?? [];
      final latest = versions.isNotEmpty ? versions.first as Map<String, dynamic> : null;
      final bundleId = app['bundleIdentifier'] as String? ?? app['bundleID'] as String? ?? app['id'] as String? ?? '';
      if (bundleId.isEmpty) return null;
      final version = latest?['version'] as String? ?? app['version'] as String? ?? '0.0.0';
      final downloadUrl = latest?['downloadURL'] as String? ?? latest?['downloadUrl'] as String? ?? app['downloadURL'] as String? ?? app['downloadUrl'] as String? ?? '';
      final size = latest?['size'] as int? ?? app['size'] as int? ?? 0;
      final dateStr = latest?['date'] as String? ?? app['versionDate'] as String? ?? app['date'] as String?;
      return AppEntity(
        id: bundleId,
        name: app['name'] as String? ?? 'Unknown',
        bundleId: bundleId,
        developer: app['developerName'] as String? ?? app['developer'] as String? ?? '',
        description: app['subtitle'] as String? ?? app['description'] as String? ?? '',
        version: version,
        buildNumber: latest?['buildVersion'] as String? ?? '1',
        releaseDate: DateTime.tryParse(dateStr ?? '') ?? DateTime.now(),
        iconUrl: app['iconURL'] as String? ?? app['iconUrl'] as String? ?? '',
        screenshots: (app['screenshots'] as List? ?? []).map((s) => s is String ? s : (s as Map)['imageURL'] as String? ?? '').where((s) => s.isNotEmpty).cast<String>().toList(),
        categories: [app['category'] as String? ?? 'Other'].whereType<String>().toList(),
        tags: (app['tags'] as List? ?? []).map((t) => t.toString()).toList(),
        downloadSize: size,
        minOsVersion: latest?['minOSVersion'] as String? ?? '',
        sourceUrl: sourceUrl,
        repositoryId: '',
        changelog: latest?['localizedDescription'] as String? ?? latest?['changelog'] as String? ?? app['changelog'] as String?,
        sha256: latest?['sha256'] as String?,
        downloadUrl: downloadUrl.isNotEmpty ? downloadUrl : null,
      );
    } catch (e) {
      _logger.warning('Failed to map Feather app: $e');
      return null;
    }
  }
}
