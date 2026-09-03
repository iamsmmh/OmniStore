import 'package:logging/logging.dart';

import '../../../../domain/models/repository_entity.dart';
import '../../../../domain/models/app_entity.dart';
import '../../../../domain/services/repository_provider.dart';
import '../api_client.dart';

/// GitLab repository provider
/// Handles GitLab Releases-based repositories
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
    return uri.host == 'gitlab.com' ||
        uri.host.endsWith('.gitlab.com') ||
        uri.host.contains('gitlab');
  }

  @override
  Future<RepositoryValidationData> validate(String url) async {
    try {
      final parsed = _parseGitLabUrl(url);
      if (parsed == null) {
        return RepositoryValidationData(isValid: false, name: '', appCount: 0);
      }

      // Fetch project info
      final projectInfo = await _apiClient.getGitLabProject(parsed['projectId']!);

      return RepositoryValidationData(
        isValid: true,
        name: projectInfo['name'] as String? ?? 'Unknown Project',
        description: projectInfo['description'] as String?,
        iconUrl: projectInfo['avatar_url'] as String?,
        maintainer: projectInfo['namespace']?['name'] as String?,
        appCount: 1,
        metadata: projectInfo,
      );
    } catch (e) {
      _logger.severe('Failed to validate GitLab project: $url', e);
      return RepositoryValidationData(isValid: false, name: '', appCount: 0);
    }
  }

  @override
  Future<List<AppEntity>> fetchApps(String url) async {
    try {
      final parsed = _parseGitLabUrl(url);
      if (parsed == null) return [];

      final releases = await _apiClient.getGitLabReleases(parsed['projectId']!);

      return releases.map((release) => _mapReleaseToApp(release, url)).toList();
    } catch (e) {
      _logger.severe('Failed to fetch GitLab releases: $url', e);
      return [];
    }
  }

  @override
  Future<List<AppEntity>> fetchUpdates(String url, DateTime since) async {
    final apps = await fetchApps(url);
    return apps.where((app) => app.releaseDate.isAfter(since)).toList();
  }

  Map<String, String>? _parseGitLabUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    // Handle various GitLab URL formats
    // https://gitlab.com/username/project
    // https://gitlab.com/username/project/-/releases
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    
    // Filter out common GitLab path segments
    final filteredSegments = segments
        .where((s) => !['-', 'releases', 'issues', 'wiki', 'milestones'].contains(s))
        .toList();
    
    if (filteredSegments.length < 2) return null;

    // Construct project ID (URL-encoded path)
    final projectId = filteredSegments.join('/');

    return {'projectId': projectId, 'path': uri.path};
  }

  AppEntity _mapReleaseToApp(Map<String, dynamic> release, String sourceUrl) {
    final assets = (release['assets']?['links'] as List? ?? [])
        .map((a) => a['url'] as String? ?? '')
        .where((url) => url.isNotEmpty)
        .toList();

    final name = release['name'] as String? ?? release['tag_name'] as String? ?? 'Unknown';
    final tagName = release['tag_name'] as String? ?? '0.0.0';
    
    return AppEntity(
      id: '${release['tag_name']}_${release['project_id'] ?? ''}',
      name: name.replaceFirst(RegExp(r'^v'), ''),
      bundleId: '',
      developer: '',
      description: release['description'] as String? ?? '',
      version: tagName.replaceFirst(RegExp(r'^v'), ''),
      buildNumber: '1',
      releaseDate: DateTime.tryParse(release['released_at'] as String? ?? '') ?? DateTime.now(),
      iconUrl: '',
      screenshots: [],
      categories: [],
      tags: [],
      downloadSize: 0,
      minOsVersion: '',
      sourceUrl: sourceUrl,
      repositoryId: '',
      changelog: release['description'] as String?,
      downloadUrl: assets.isNotEmpty ? assets.first : null,
    );
  }
}
