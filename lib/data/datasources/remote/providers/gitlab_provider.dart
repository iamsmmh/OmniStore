import 'package:logging/logging.dart';
import '../../../../domain/models/repository_entity.dart';
import '../../../../domain/models/app_entity.dart';
import '../../../../domain/services/repository_provider.dart';
import '../api_client.dart';

/// GitLab Releases provider.
/// Supports gitlab.com and self-hosted GitLab instances via base URL detection.
class GitLabProvider implements RepositoryProvider {
  final ApiClient _apiClient;
  final _logger = Logger('GitLabProvider');

  GitLabProvider(this._apiClient);

  @override
  RepositoryType get type => RepositoryType.gitlab;

  @override
  bool canHandle(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    // Detect GitLab by host or path structure
    if (host == 'gitlab.com' || host.endsWith('.gitlab.com')) return true;
    if (host.contains('gitlab')) return true;
    // GitLab project URLs often contain /-/ or /projects
    if (url.contains('gitlab')) return true;
    return false;
  }

  @override
  Future<RepositoryValidationData> validate(String url) async {
    try {
      final parsed = _parseGitLabUrl(url);
      if (parsed == null) {
        return const RepositoryValidationData(isValid: false, name: '', appCount: 0);
      }
      final baseUrl = parsed['baseUrl']!;
      final projectId = parsed['projectId']!;
      final project = await _apiClient.getGitLabProject(projectId, baseUrl: baseUrl);
      if (project.isEmpty) {
        return const RepositoryValidationData(isValid: false, name: '', appCount: 0);
      }
      final releases = await _apiClient.getGitLabReleases(projectId, baseUrl: baseUrl, perPage: 1);
      return RepositoryValidationData(
        isValid: true,
        name: project['name'] as String? ?? project['path_with_namespace'] as String? ?? projectId,
        description: project['description'] as String?,
        iconUrl: project['avatar_url'] as String?,
        maintainer: (project['owner'] is Map ? (project['owner'] as Map)['name'] as String? : null) ??
            project['namespace']?['name'] as String?,
        appCount: releases.length,
        metadata: project,
      );
    } catch (e) {
      _logger.warning('Failed to validate GitLab repo: $url - $e');
      return const RepositoryValidationData(isValid: false, name: '', appCount: 0);
    }
  }

  @override
  Future<List<AppEntity>> fetchApps(String url) async {
    try {
      final parsed = _parseGitLabUrl(url);
      if (parsed == null) return [];
      final baseUrl = parsed['baseUrl']!;
      final projectId = parsed['projectId']!;
      // Use pagination to fetch multiple pages
      final releases = await _apiClient.getGitLabReleasesPaginated(projectId, baseUrl: baseUrl, maxPages: 3);
      final apps = <AppEntity>[];
      for (final release in releases) {
        final app = _mapReleaseToApp(release, url, projectId);
        if (app != null) apps.add(app);
      }
      return apps;
    } catch (e, stack) {
      _logger.severe('Failed to fetch GitLab releases: $url', e, stack);
      return [];
    }
  }

  @override
  Future<List<AppEntity>> fetchUpdates(String url, DateTime since) async {
    final apps = await fetchApps(url);
    return apps.where((a) => a.releaseDate.isAfter(since)).toList();
  }

  Map<String, String>? _parseGitLabUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final baseUrl = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    // Expect url like https://gitlab.com/owner/repo or https://gitlab.com/api/v4/projects/123
    // Extract path segments excluding api parts
    final segments = uri.pathSegments.where((s) => s.isNotEmpty && s != 'api' && s != 'v4' && s != 'projects').toList();
    if (segments.isEmpty) return null;
    // If URL already encoded project ID (contains %2F or numeric), use it directly
    if (uri.path.contains('/projects/')) {
      final idx = uri.pathSegments.indexOf('projects');
      if (idx >= 0 && idx + 1 < uri.pathSegments.length) {
        final raw = uri.pathSegments[idx + 1];
        return {'baseUrl': baseUrl, 'projectId': Uri.decodeComponent(raw)};
      }
    }
    // Otherwise construct projectId as namespace/path
    // GitLab project ID for API is URL-encoded path: owner%2Frepo
    String projectId;
    if (segments.length >= 2) {
      // Handle subgroups: take all segments as path
      final path = segments.take(segments.length >= 3 ? segments.length : 2).join('/');
      projectId = Uri.encodeComponent(path);
      // If more than 2 segments, try to detect release-specific URL and trim
      if (segments.contains('releases') || segments.contains('-')) {
        final clean = segments.where((s) => s != '-' && s != 'releases').take(2).join('/');
        projectId = Uri.encodeComponent(clean);
      }
    } else {
      return null;
    }
    return {'baseUrl': baseUrl, 'projectId': projectId};
  }

  AppEntity? _mapReleaseToApp(Map<String, dynamic> release, String sourceUrl, String projectId) {
    try {
      final tag = release['tag_name'] as String? ?? release['name'] as String? ?? '0.0.0';
      final assetsMap = release['assets'] as Map<String, dynamic>?;
      final links = assetsMap?['links'] as List? ?? [];
      final sources = assetsMap?['sources'] as List? ?? [];
      String? downloadUrl;
      int downloadSize = 0;
      if (links.isNotEmpty) {
        final first = links.first as Map<String, dynamic>;
        downloadUrl = first['url'] as String? ?? first['direct_asset_url'] as String?;
      }
      // Fallback to sources
      if ((downloadUrl == null || downloadUrl.isEmpty) && sources.isNotEmpty) {
        final src = sources.first as Map<String, dynamic>;
        downloadUrl = src['url'] as String?;
      }
      final version = tag.replaceFirst(RegExp(r'^v'), '');
      return AppEntity(
        id: '${projectId}_${release['tag_name'] ?? release['name']}',
        name: release['name'] as String? ?? tag,
        bundleId: release['tag_name'] as String? ?? '',
        developer: release['author'] is Map ? (release['author'] as Map)['name'] as String? ?? '' : '',
        description: release['description'] as String? ?? '',
        version: version,
        buildNumber: '1',
        releaseDate: DateTime.tryParse(release['released_at'] as String? ?? release['created_at'] as String? ?? '') ?? DateTime.now(),
        iconUrl: '',
        screenshots: const [],
        categories: const [],
        tags: const [],
        downloadSize: downloadSize,
        minOsVersion: '',
        sourceUrl: sourceUrl,
        repositoryId: '',
        changelog: release['description'] as String?,
        downloadUrl: downloadUrl,
      );
    } catch (e) {
      _logger.warning('Failed to map GitLab release: $e');
      return null;
    }
  }
}
