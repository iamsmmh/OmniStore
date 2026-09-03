import 'package:logging/logging.dart';
import '../../../../domain/models/repository_entity.dart';
import '../../../../domain/models/app_entity.dart';
import '../../../../domain/services/repository_provider.dart';
import '../api_client.dart';

/// Codeberg (Forgejo) Releases provider.
class CodebergProvider implements RepositoryProvider {
  final ApiClient _apiClient;
  final _logger = Logger('CodebergProvider');
  static const _baseUrl = 'https://codeberg.org';

  CodebergProvider(this._apiClient);

  @override
  RepositoryType get type => RepositoryType.codeberg;

  @override
  bool canHandle(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return uri.host.toLowerCase() == 'codeberg.org' || uri.host.toLowerCase().endsWith('.codeberg.org');
  }

  @override
  Future<RepositoryValidationData> validate(String url) async {
    try {
      final parsed = _parseUrl(url);
      if (parsed == null) return const RepositoryValidationData(isValid: false, name: '', appCount: 0);
      final repo = await _apiClient.getGiteaRepo(parsed['owner']!, parsed['repo']!, baseUrl: _baseUrl);
      if (repo == null) return const RepositoryValidationData(isValid: false, name: '', appCount: 0);
      final releases = await _apiClient.getGiteaReleases(parsed['owner']!, parsed['repo']!, baseUrl: _baseUrl, perPage: 1);
      return RepositoryValidationData(
        isValid: true,
        name: repo['full_name'] as String? ?? '${parsed['owner']}/${parsed['repo']}',
        description: repo['description'] as String?,
        iconUrl: repo['avatar_url'] as String? ?? repo['owner']?['avatar_url'] as String?,
        maintainer: repo['owner']?['login'] as String? ?? repo['owner']?['username'] as String?,
        appCount: releases.length,
        metadata: repo,
      );
    } catch (e) {
      _logger.warning('Failed to validate Codeberg repo: $url - $e');
      return const RepositoryValidationData(isValid: false, name: '', appCount: 0);
    }
  }

  @override
  Future<List<AppEntity>> fetchApps(String url) async {
    try {
      final parsed = _parseUrl(url);
      if (parsed == null) return [];
      final releases = await _apiClient.getGiteaReleasesPaginated(parsed['owner']!, parsed['repo']!, baseUrl: _baseUrl, maxPages: 3);
      return releases.map((r) => _mapRelease(r, url)).whereType<AppEntity>().toList();
    } catch (e, stack) {
      _logger.severe('Failed to fetch Codeberg releases: $url', e, stack);
      return [];
    }
  }

  @override
  Future<List<AppEntity>> fetchUpdates(String url, DateTime since) async {
    final apps = await fetchApps(url);
    return apps.where((a) => a.releaseDate.isAfter(since)).toList();
  }

  Map<String, String>? _parseUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length < 2) return null;
    return {'owner': segments[0], 'repo': segments[1].replaceAll('.git', '')};
  }

  AppEntity? _mapRelease(Map<String, dynamic> release, String sourceUrl) {
    try {
      final assets = (release['assets'] as List? ?? []);
      String? downloadUrl;
      int size = 0;
      String? sha256;
      if (assets.isNotEmpty) {
        final first = assets.first as Map<String, dynamic>;
        downloadUrl = first['browser_download_url'] as String? ?? first['download_url'] as String?;
        size = first['size'] as int? ?? 0;
        sha256 = first['sha256'] as String? ?? first['hash'] as String?;
      }
      final tag = release['tag_name'] as String? ?? '0.0.0';
      final created = release['created_at'] as String? ?? release['published_at'] as String?;
      return AppEntity(
        id: '${release['id']}',
        name: release['name'] as String? ?? tag,
        bundleId: '',
        developer: release['author'] is Map ? (release['author'] as Map)['login'] as String? ?? '' : '',
        description: release['body'] as String? ?? '',
        version: tag.replaceFirst(RegExp(r'^v'), ''),
        buildNumber: '1',
        releaseDate: DateTime.tryParse(created ?? '') ?? DateTime.now(),
        iconUrl: '',
        screenshots: const [],
        categories: const [],
        tags: const [],
        downloadSize: size,
        minOsVersion: '',
        sourceUrl: sourceUrl,
        repositoryId: '',
        changelog: release['body'] as String?,
        sha256: sha256,
        downloadUrl: downloadUrl,
      );
    } catch (e) {
      _logger.warning('Failed to map Codeberg release: $e');
      return null;
    }
  }
}
