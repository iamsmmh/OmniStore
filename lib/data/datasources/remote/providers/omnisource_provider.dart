import 'package:logging/logging.dart';
import '../../../../domain/models/repository_entity.dart';
import '../../../../domain/models/app_entity.dart';
import '../../../../domain/services/repository_provider.dart';
import '../api_client.dart';

/// OmniSource provider — first-class, with incremental sync support,
/// caching via ApiClient, and robust parsing.
class OmniSourceProvider implements RepositoryProvider {
  final ApiClient _apiClient;
  final _logger = Logger('OmniSourceProvider');

  OmniSourceProvider(this._apiClient);

  @override
  RepositoryType get type => RepositoryType.omnsource;

  @override
  bool canHandle(String url) {
    final lower = url.toLowerCase();
    return lower.contains('omnisource') || lower.contains('/feed') || lower.contains('omni');
  }

  @override
  Future<RepositoryValidationData> validate(String url) async {
    try {
      final data = await _apiClient.getOmniSourceFeed(url);
      if (data == null) return const RepositoryValidationData(isValid: false, name: '', appCount: 0);
      // Feed structure validation
      final apps = data['apps'] as List? ?? data['applications'] as List? ?? [];
      final feedInfo = data['feedInfo'] as Map<String, dynamic>? ?? data['sourceInfo'] as Map<String, dynamic>? ?? data['meta'] as Map<String, dynamic>?;
      // Validate assets
      int withAssets = 0;
      for (final raw in apps) {
        try {
          final m = raw as Map<String, dynamic>;
          if ((m['downloadUrl'] ?? m['downloadURL'] ?? m['url']) != null) withAssets++;
        } catch (_) {}
      }
      if (apps.isNotEmpty && withAssets == 0) {
        _logger.warning('OmniSource feed has no downloadable app assets');
      }
      return RepositoryValidationData(
        isValid: true,
        name: feedInfo?['name'] as String? ?? data['name'] as String? ?? 'OmniSource Feed',
        description: feedInfo?['description'] as String? ?? data['description'] as String?,
        iconUrl: feedInfo?['iconUrl'] as String? ?? feedInfo?['iconURL'] as String?,
        maintainer: feedInfo?['maintainer'] as String? ?? feedInfo?['author'] as String?,
        appCount: apps.length,
        metadata: data,
      );
    } catch (e) {
      _logger.warning('OmniSource validate failed: $e');
      return const RepositoryValidationData(isValid: false, name: '', appCount: 0);
    }
  }

  @override
  Future<List<AppEntity>> fetchApps(String url) async {
    try {
      final data = await _apiClient.getOmniSourceFeed(url);
      if (data == null) return [];
      final rawApps = data['apps'] as List? ?? data['applications'] as List? ?? [];
      return rawApps.map((a) => _mapApp(a as Map<String, dynamic>, url)).whereType<AppEntity>().toList();
    } catch (e) {
      _logger.warning('OmniSource fetch failed: $e');
      return [];
    }
  }

  @override
  Future<List<AppEntity>> fetchUpdates(String url, DateTime since) async {
    try {
      // Prefer incremental endpoint if available
      final delta = await _apiClient.getOmniSourceUpdates(url, since);
      if (delta != null) {
        final rawApps = delta['apps'] as List? ?? delta['applications'] as List? ?? [];
        if (rawApps.isNotEmpty) {
          return rawApps.map((a) => _mapApp(a as Map<String, dynamic>, url)).whereType<AppEntity>().toList();
        }
      }
    } catch (e) {
      _logger.warning('OmniSource incremental failed, falling back: $e');
    }
    // Fallback: filter full fetch
    final all = await fetchApps(url);
    return all.where((a) => a.releaseDate.isAfter(since)).toList();
  }

  AppEntity? _mapApp(Map<String, dynamic> app, String sourceUrl) {
    try {
      final bundleId = app['bundleId'] as String? ?? app['bundleIdentifier'] as String? ?? app['id'] as String? ?? '';
      if (bundleId.isEmpty && (app['name'] as String?) == null) return null;
      final id = bundleId.isNotEmpty ? bundleId : (app['name'] as String);
      final version = _detectVersion(app['version'] as String? ?? '0.0.0');
      final downloadUrl = app['downloadUrl'] as String? ?? app['downloadURL'] as String? ?? app['url'] as String?;
      final size = app['downloadSize'] as int? ?? app['size'] as int? ?? 0;
      final dateStr = app['releaseDate'] as String? ?? app['versionDate'] as String? ?? app['date'] as String?;
      final releaseDate = DateTime.tryParse(dateStr ?? '') ?? DateTime.now();
      final changelog = app['changelog'] as String? ?? app['localizedDescription'] as String?;
      final sha256 = app['sha256'] as String? ?? app['hash'] as String?;
      // Asset discovery: validate changelog extraction
      final categories = (app['categories'] as List? ?? [app['category']]).whereType<String>().toList();
      if (categories.isEmpty) categories.add('Other');
      return AppEntity(
        id: id,
        name: app['name'] as String? ?? 'Unknown',
        bundleId: bundleId,
        developer: app['developer'] as String? ?? app['developerName'] as String? ?? '',
        description: app['description'] as String? ?? app['subtitle'] as String? ?? '',
        version: version,
        buildNumber: app['buildNumber'] as String? ?? '1',
        releaseDate: releaseDate,
        iconUrl: app['iconUrl'] as String? ?? app['iconURL'] as String? ?? '',
        screenshots: (app['screenshots'] as List? ?? []).map((s) => s is String ? s : (s as Map)['imageURL'] as String? ?? '').where((s) => s.isNotEmpty).cast<String>().toList(),
        categories: categories,
        tags: (app['tags'] as List? ?? []).map((t) => t.toString()).toList(),
        downloadSize: size,
        minOsVersion: app['minOsVersion'] as String? ?? '',
        sourceUrl: sourceUrl,
        repositoryId: '',
        changelog: changelog,
        sha256: sha256,
        downloadUrl: downloadUrl,
        lastUpdated: releaseDate,
      );
    } catch (e) {
      _logger.warning('OmniSource map failed: $e');
      return null;
    }
  }

  String _detectVersion(String raw) {
    var v = raw.trim().replaceFirst(RegExp(r'^v', caseSensitive: false), '');
    if (v.isEmpty) return '0.0.0';
    // Handle semver with build numbers
    return v;
  }
}
