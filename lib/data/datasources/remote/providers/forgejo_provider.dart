import 'package:logging/logging.dart';
import '../../../../domain/models/repository_entity.dart';
import '../../../../domain/models/app_entity.dart';
import '../../../../domain/services/repository_provider.dart';
import '../api_client.dart';

/// Forgejo self-hosted Releases provider (generic Gitea API compatible).
/// Detects Forgejo/Gitea instances via URL patterns.
class ForgejoProvider implements RepositoryProvider {
  final ApiClient _apiClient;
  final _logger = Logger('ForgejoProvider');

  ForgejoProvider(this._apiClient);

  @override
  RepositoryType get type => RepositoryType.forgejo;

  @override
  bool canHandle(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    // Heuristic: not github/gitlab/codeberg but looks like a git forge
    if (host == 'github.com' || host.contains('github')) return false;
    if (host == 'gitlab.com' || host.contains('gitlab')) return false;
    if (host == 'codeberg.org') return false;
    if (host.contains('altstore') || host.contains('omnisource') || host.contains('feather')) return false;
    // If URL contains .json feed it is generic JSON, not forgejo
    if (url.endsWith('.json')) return false;
    // Must look like https://host/owner/repo
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length < 2) return false;
    // Only handle if it appears to be a forge instance — require at least owner/repo structure
    // and that baseUrl is not a generic website. We treat any 2-segment git URL not already handled as Forgejo.
    // To avoid false positives for generic websites, we require the host to look like a forge or be explicitly typed as forgejo
    if (url.contains('forgejo') || url.contains('gitea')) return true;
    // Self-hosted detection: if repository type is forgejo explicitly set, canHandle may still be called
    // We conservatively handle only when URL is likely a git repo: host not containing generic feed keywords
    // and path has exactly 2 segments (owner/repo)
    if (segments.length == 2 && !host.contains('apple') && !host.contains('google')) {
      // Check if we can probe the api quickly — but for canHandle we just return true for any unclaimed 2-segment URL
      // that was explicitly added as forgejo type. However to avoid stealing generic URLs, we return false unless host contains forge/gitea/git
      if (host.contains('git') || host.contains('forge')) return true;
    }
    return false;
  }

  bool canHandleForced(String url, RepositoryType type) {
    return type == RepositoryType.forgejo;
  }

  @override
  Future<RepositoryValidationData> validate(String url) async {
    try {
      final parsed = _parseUrl(url);
      if (parsed == null) return const RepositoryValidationData(isValid: false, name: '', appCount: 0);
      final baseUrl = parsed['baseUrl']!;
      final repo = await _apiClient.getGiteaRepo(parsed['owner']!, parsed['repo']!, baseUrl: baseUrl);
      if (repo == null) return const RepositoryValidationData(isValid: false, name: '', appCount: 0);
      final releases = await _apiClient.getGiteaReleases(parsed['owner']!, parsed['repo']!, baseUrl: baseUrl, perPage: 1);
      return RepositoryValidationData(
        isValid: true,
        name: repo['full_name'] as String? ?? '${parsed['owner']}/${parsed['repo']}',
        description: repo['description'] as String?,
        iconUrl: repo['avatar_url'] as String?,
        maintainer: repo['owner']?['login'] as String?,
        appCount: releases.length,
        metadata: repo,
      );
    } catch (e) {
      _logger.warning('Failed to validate Forgejo repo: $url - $e');
      return const RepositoryValidationData(isValid: false, name: '', appCount: 0);
    }
  }

  @override
  Future<List<AppEntity>> fetchApps(String url) async {
    try {
      final parsed = _parseUrl(url);
      if (parsed == null) return [];
      final releases = await _apiClient.getGiteaReleasesPaginated(parsed['owner']!, parsed['repo']!, baseUrl: parsed['baseUrl']!, maxPages: 3);
      return releases.map((r) => _mapRelease(r, url)).whereType<AppEntity>().toList();
    } catch (e, stack) {
      _logger.severe('Failed to fetch Forgejo releases: $url', e, stack);
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
    final baseUrl = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length < 2) return null;
    return {'baseUrl': baseUrl, 'owner': segments[0], 'repo': segments[1].replaceAll('.git', '')};
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
        sha256 = first['sha256'] as String?;
      }
      final tag = release['tag_name'] as String? ?? '0.0.0';
      return AppEntity(
        id: '${release['id']}',
        name: release['name'] as String? ?? tag,
        bundleId: '',
        developer: '',
        description: release['body'] as String? ?? '',
        version: tag.replaceFirst(RegExp(r'^v'), ''),
        buildNumber: '1',
        releaseDate: DateTime.tryParse(release['created_at'] as String? ?? release['published_at'] as String? ?? '') ?? DateTime.now(),
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
      _logger.warning('Failed to map Forgejo release: $e');
      return null;
    }
  }
}
