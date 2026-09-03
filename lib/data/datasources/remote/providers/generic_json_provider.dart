import 'package:logging/logging.dart';
import '../../../../domain/models/repository_entity.dart';
import '../../../../domain/models/app_entity.dart';
import '../../../../domain/services/repository_provider.dart';
import '../api_client.dart';

/// Generic JSON source provider.
/// Handles unknown JSON feeds by inferring structure.
class GenericJsonProvider implements RepositoryProvider {
  final ApiClient _apiClient;
  final _logger = Logger('GenericJsonProvider');

  GenericJsonProvider(this._apiClient);

  @override
  RepositoryType get type => RepositoryType.genericFeed;

  @override
  bool canHandle(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    // Generic fallback: any HTTPS JSON URL not already handled
    if (uri.scheme != 'https') return false;
    if (url.endsWith('.json')) return true;
    if (url.contains('/feed') || url.contains('/apps') || url.contains('/repository')) return true;
    return true; // fallback for any repository URL
  }

  @override
  Future<RepositoryValidationData> validate(String url) async {
    try {
      final data = await _apiClient.getGenericFeed(url);
      if (data == null) return const RepositoryValidationData(isValid: false, name: '', appCount: 0);
      if (!_hasValidStructure(data)) {
        return const RepositoryValidationData(isValid: false, name: '', appCount: 0);
      }
      final apps = _extractApps(data);
      final meta = _extractMeta(data);
      return RepositoryValidationData(
        isValid: true,
        name: meta['name'] as String? ?? meta['title'] as String? ?? Uri.parse(url).host,
        description: meta['description'] as String?,
        iconUrl: meta['iconURL'] as String? ?? meta['iconUrl'] as String?,
        maintainer: meta['maintainer'] as String? ?? meta['developer'] as String?,
        appCount: apps.length,
        metadata: data,
      );
    } catch (e) {
      _logger.warning('Failed to validate generic feed: $url - $e');
      return const RepositoryValidationData(isValid: false, name: '', appCount: 0);
    }
  }

  @override
  Future<List<AppEntity>> fetchApps(String url) async {
    try {
      final data = await _apiClient.getGenericFeed(url);
      if (data == null) return [];
      final apps = _extractApps(data);
      return apps.map((a) => _mapApp(a, url)).whereType<AppEntity>().toList();
    } catch (e, stack) {
      _logger.severe('Failed to fetch generic apps: $url', e, stack);
      return [];
    }
  }

  @override
  Future<List<AppEntity>> fetchUpdates(String url, DateTime since) async {
    final apps = await fetchApps(url);
    return apps.where((a) => a.releaseDate.isAfter(since)).toList();
  }

  bool _hasValidStructure(Map<String, dynamic> data) {
    // At least one of these keys suggests a valid feed
    const keys = ['apps', 'applications', 'packages', 'items', 'data', 'releases', 'feed', 'repositories'];
    for (final k in keys) {
      if (data.containsKey(k) && data[k] is List) return true;
    }
    // If data itself looks like an app entry
    if (data.containsKey('name') && data.containsKey('version')) return true;
    // AltStore/Feather style
    if (data.containsKey('sourceInfo') || data.containsKey('feedInfo')) return true;
    return false;
  }

  List<dynamic> _extractApps(Map<String, dynamic> data) {
    if (data['apps'] is List) return data['apps'] as List;
    if (data['applications'] is List) return data['applications'] as List;
    if (data['packages'] is List) return data['packages'] as List;
    if (data['items'] is List) return data['items'] as List;
    if (data['data'] is List) return data['data'] as List;
    if (data['releases'] is List) return data['releases'] as List;
    if (data['repositories'] is List) return data['repositories'] as List;
    if (data['feed'] is Map && (data['feed'] as Map)['apps'] is List) return (data['feed'] as Map)['apps'] as List;
    if (data['feedInfo'] is Map && data.containsKey('apps')) return []; // handled above
    // Single app object
    if (data.containsKey('name') && data.containsKey('version')) return [data];
    return [];
  }

  Map<String, dynamic> _extractMeta(Map<String, dynamic> data) {
    if (data['sourceInfo'] is Map) return Map<String, dynamic>.from(data['sourceInfo'] as Map);
    if (data['feedInfo'] is Map) return Map<String, dynamic>.from(data['feedInfo'] as Map);
    if (data['meta'] is Map) return Map<String, dynamic>.from(data['meta'] as Map);
    if (data['info'] is Map) return Map<String, dynamic>.from(data['info'] as Map);
    return data;
  }

  AppEntity? _mapApp(dynamic raw, String sourceUrl) {
    try {
      final map = raw as Map<String, dynamic>;
      // Try multiple key variants
      final bundleId = map['bundleIdentifier'] as String? ??
          map['bundleId'] as String? ??
          map['id'] as String? ??
          map['identifier'] as String? ??
          map['package'] as String? ??
          '';
      if (bundleId.isEmpty && (map['name'] as String?) == null) return null;
      final id = bundleId.isNotEmpty ? bundleId : (map['name'] as String? ?? 'unknown');

      // Version handling with fallback
      final versions = map['versions'] as List?;
      Map<String, dynamic>? latest;
      if (versions != null && versions.isNotEmpty) latest = versions.first as Map<String, dynamic>;

      final version = latest?['version'] as String? ??
          map['version'] as String? ??
          map['latestVersion'] as String? ??
          '0.0.0';
      final downloadUrl = latest?['downloadURL'] as String? ??
          latest?['downloadUrl'] as String? ??
          map['downloadURL'] as String? ??
          map['downloadUrl'] as String? ??
          map['url'] as String? ??
          map['download_url'] as String?;
      final rawSize = latest?['size'] ?? map['size'] ?? map['downloadSize'];
      final size = rawSize is int
          ? rawSize
          : int.tryParse(rawSize?.toString() ?? '') ?? 0;
      final dateStr = latest?['date'] as String? ?? map['releaseDate'] as String? ?? map['date'] as String? ?? map['updatedAt'] as String?;
      final icon = map['iconURL'] as String? ?? map['iconUrl'] as String? ?? map['icon'] as String? ?? '';

      // Categories from various fields
      List<String> categories = [];
      if (map['categories'] is List) {
        categories = (map['categories'] as List).map((e) => e.toString()).toList();
      } else if (map['category'] is String) {
        categories = [map['category'] as String];
      } else {
        categories = ['Other'];
      }

      return AppEntity(
        id: id,
        name: map['name'] as String? ?? map['title'] as String? ?? 'Unknown',
        bundleId: bundleId,
        developer: map['developerName'] as String? ?? map['developer'] as String? ?? map['author'] as String? ?? '',
        description: map['subtitle'] as String? ?? map['description'] as String? ?? map['summary'] as String? ?? '',
        version: version,
        buildNumber: latest?['buildVersion'] as String? ?? map['buildNumber'] as String? ?? '1',
        releaseDate: DateTime.tryParse(dateStr ?? '') ?? DateTime.now(),
        iconUrl: icon,
        screenshots: (map['screenshots'] as List? ?? []).map((s) => s is String ? s : (s as Map)['url']?.toString() ?? '').where((s) => s.isNotEmpty).cast<String>().toList(),
        categories: categories,
        tags: (map['tags'] as List? ?? []).map((t) => t.toString()).toList(),
        downloadSize: size is int ? size : int.tryParse(size.toString()) ?? 0,
        minOsVersion: latest?['minOSVersion'] as String? ?? map['minOsVersion'] as String? ?? '',
        sourceUrl: sourceUrl,
        repositoryId: '',
        changelog: latest?['changelog'] as String? ?? map['changelog'] as String?,
        sha256: latest?['sha256'] as String? ?? map['sha256'] as String? ?? map['hash'] as String?,
        downloadUrl: downloadUrl,
      );
    } catch (e) {
      _logger.warning('Failed to map generic app: $e');
      return null;
    }
  }
}
