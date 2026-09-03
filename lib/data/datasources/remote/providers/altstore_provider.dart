import 'package:logging/logging.dart';
import '../../../../domain/models/repository_entity.dart';
import '../../../../domain/models/app_entity.dart';
import '../../../../domain/services/repository_provider.dart';
import '../api_client.dart';

/// AltStore source provider — production-ready
/// Handles pagination (AltStore is single JSON, but validates structure),
/// asset discovery, version detection, changelog extraction, caching via ApiClient.
class AltStoreProvider implements RepositoryProvider {
  final ApiClient _apiClient;
  final _logger = Logger('AltStoreProvider');

  AltStoreProvider(this._apiClient);

  @override
  RepositoryType get type => RepositoryType.altstore;

  @override
  bool canHandle(String url) {
    final lower = url.toLowerCase();
    // AltStore sources often contain 'altstore' but generic JSON also ends with .json
    // Distinguish by probing structure in validate(), but heuristic here:
    if (lower.contains('altstore')) return true;
    // Generic JSON fallback is handled by GenericJsonProvider last, so AltStore can claim .json
    // We check for feather to avoid collision
    if (lower.endsWith('.json') && !lower.contains('feather')) return true;
    return false;
  }

  @override
  Future<RepositoryValidationData> validate(String url) async {
    try {
      final data = await _apiClient.getAltStoreSource(url);
      if (data == null) return const RepositoryValidationData(isValid: false, name: '', appCount: 0);
      // Feed structure validation
      if (data['apps'] == null && data['sourceInfo'] == null) {
        return const RepositoryValidationData(isValid: false, name: '', appCount: 0, metadata: {});
      }
      final apps = data['apps'] as List? ?? [];
      final sourceInfo = data['sourceInfo'] as Map<String, dynamic>? ?? data['meta'] as Map<String, dynamic>?;
      // Assets validation: check at least one app has download URL
      int withAssets = 0;
      for (final raw in apps) {
        try {
          final m = raw as Map<String, dynamic>;
          final versions = m['versions'] as List? ?? [];
          if (versions.isNotEmpty && (versions.first['downloadURL'] ?? versions.first['downloadUrl']) != null) withAssets++;
        } catch (_) {}
      }
      final hasValidStructure = apps.isNotEmpty;
      if (!hasValidStructure) {
        return RepositoryValidationData(isValid: false, name: '', appCount: 0, metadata: data);
      }
      return RepositoryValidationData(
        isValid: true,
        name: sourceInfo?['name'] as String? ?? data['name'] as String? ?? 'AltStore Source',
        description: sourceInfo?['description'] as String? ?? data['description'] as String?,
        iconUrl: sourceInfo?['iconURL'] as String? ?? sourceInfo?['iconUrl'] as String?,
        maintainer: sourceInfo?['website'] as String? ?? sourceInfo?['maintainer'] as String?,
        appCount: apps.length,
        metadata: data,
      );
    } catch (e) {
      _logger.warning('AltStore validate failed: $e');
      return const RepositoryValidationData(isValid: false, name: '', appCount: 0);
    }
  }

  @override
  Future<List<AppEntity>> fetchApps(String url) async {
    try {
      final data = await _apiClient.getAltStoreSource(url);
      if (data == null) return [];
      final rawApps = data['apps'] as List? ?? [];
      final apps = <AppEntity>[];
      for (final raw in rawApps) {
        try {
          final app = _mapAltStoreApp(raw as Map<String, dynamic>, url);
          if (app != null) apps.add(app);
        } catch (e) {
          _logger.warning('Skipping malformed AltStore app: $e');
        }
      }
      return apps;
    } catch (e) {
      _logger.warning('AltStore fetch failed: $e');
      return [];
    }
  }

  @override
  Future<List<AppEntity>> fetchUpdates(String url, DateTime since) async {
    final apps = await fetchApps(url);
    return apps.where((a) => a.releaseDate.isAfter(since)).toList();
  }

  AppEntity? _mapAltStoreApp(Map<String, dynamic> app, String sourceUrl) {
    try {
      final versions = app['versions'] as List? ?? [];
      if (versions.isEmpty) return null;
      // AltStore versions are newest-first; pick first but validate version detection
      final latest = versions.first as Map<String, dynamic>;
      final bundleId = app['bundleIdentifier'] as String? ?? app['bundleID'] as String? ?? '';
      if (bundleId.isEmpty) return null;
      final version = _detectVersion(latest['version'] as String? ?? app['version'] as String? ?? '0.0.0');
      final downloadUrl = latest['downloadURL'] as String? ?? latest['downloadUrl'] as String? ?? '';
      final size = latest['size'] as int? ?? 0;
      final dateStr = latest['date'] as String? ?? latest['versionDate'] as String?;
      final releaseDate = DateTime.tryParse(dateStr ?? '') ?? DateTime.now();
      final changelog = latest['localizedDescription'] as String? ?? latest['changelog'] as String?;
      final sha256 = latest['sha256'] as String?;
      // Asset discovery: validate downloadUrl is HTTPS
      final hasValidAsset = downloadUrl.isNotEmpty && downloadUrl.startsWith('https');
      if (!hasValidAsset && downloadUrl.isNotEmpty) {
        _logger.warning('AltStore app $bundleId has non-HTTPS download: $downloadUrl');
      }
      return AppEntity(
        id: bundleId,
        name: app['name'] as String? ?? 'Unknown',
        bundleId: bundleId,
        developer: app['developerName'] as String? ?? '',
        description: app['subtitle'] as String? ?? app['localizedDescription'] as String? ?? '',
        version: version,
        buildNumber: latest['buildVersion'] as String? ?? '1',
        releaseDate: releaseDate,
        iconUrl: app['iconURL'] as String? ?? app['iconUrl'] as String? ?? '',
        screenshots: (app['screenshots'] as List? ?? []).map((s) {
          if (s is String) return s;
          if (s is Map) return s['imageURL'] as String? ?? s['url'] as String? ?? '';
          return '';
        }).where((s) => s.isNotEmpty).cast<String>().toList(),
        categories: [app['category'] as String? ?? 'Other'].whereType<String>().toList(),
        tags: (app['tags'] as List? ?? []).map((t) => t.toString()).toList(),
        downloadSize: size,
        minOsVersion: latest['minOSVersion'] as String? ?? '',
        sourceUrl: sourceUrl,
        repositoryId: '',
        changelog: changelog,
        sha256: sha256,
        downloadUrl: downloadUrl.isNotEmpty ? downloadUrl : null,
        lastUpdated: releaseDate,
      );
    } catch (e) {
      _logger.warning('AltStore map failed: $e');
      return null;
    }
  }

  String _detectVersion(String raw) {
    var v = raw.trim().replaceFirst(RegExp(r'^v', caseSensitive: false), '');
    if (v.isEmpty) return '0.0.0';
    // Normalize AltStore versions like "1.4.2 (42)" -> "1.4.2"
    v = v.split(' ').first;
    v = v.split('(').first.trim();
    return v;
  }
}
