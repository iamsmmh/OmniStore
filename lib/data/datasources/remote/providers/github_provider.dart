import 'package:logging/logging.dart';

import 'package:omnistore/domain/models/repository_entity.dart';
import 'package:omnistore/domain/models/app_entity.dart';
import 'package:omnistore/domain/services/repository_provider.dart';
import 'package:omnistore/data/datasources/remote/api_client.dart';

/// GitHub repository provider
/// Handles GitHub Releases-based repositories
class GitHubProvider implements RepositoryProvider {
  final ApiClient _apiClient;
  final _logger = Logger('GitHubProvider');

  GitHubProvider(this._apiClient);

  @override
  RepositoryType get type => RepositoryType.github;

  @override
  bool canHandle(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return uri.host == 'github.com' || uri.host.endsWith('.github.com');
  }

  @override
  Future<RepositoryValidationData> validate(String url) async {
    try {
      final parsed = _parseGitHubUrl(url);
      if (parsed == null) {
        return RepositoryValidationData(isValid: false, name: '', appCount: 0);
      }

      // Fetch repo info
      final repoInfo = await _apiClient.getGitHubRepo(
        parsed['owner']!,
        parsed['repo']!,
      );

      return RepositoryValidationData(
        isValid: true,
        name: repoInfo['full_name'] ?? '${parsed['owner']}/${parsed['repo']}',
        description: repoInfo['description'] as String?,
        iconUrl: repoInfo['owner']?['avatar_url'] as String?,
        maintainer: repoInfo['owner']?['login'] as String?,
        appCount: 1,
        metadata: repoInfo,
      );
    } catch (e) {
      _logger.severe('Failed to validate GitHub repo: $url', e);
      return RepositoryValidationData(isValid: false, name: '', appCount: 0);
    }
  }

  @override
  Future<List<AppEntity>> fetchApps(String url) async {
    try {
      final parsed = _parseGitHubUrl(url);
      if (parsed == null) return [];

      final releases = await _apiClient.getGitHubReleases(
        parsed['owner']!,
        parsed['repo']!,
      );

      return releases.map((release) => _mapReleaseToApp(release, url)).toList();
    } catch (e) {
      _logger.severe('Failed to fetch GitHub releases: $url', e);
      return [];
    }
  }

  @override
  Future<List<AppEntity>> fetchUpdates(String url, DateTime since) async {
    final apps = await fetchApps(url);
    return apps.where((app) => app.releaseDate.isAfter(since)).toList();
  }

  Map<String, String>? _parseGitHubUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length < 2) return null;

    return {'owner': segments[0], 'repo': segments[1]};
  }

  AppEntity _mapReleaseToApp(Map<String, dynamic> release, String sourceUrl) {
    final assets = (release['assets'] as List? ?? [])
        .map((a) => a['browser_download_url'] as String? ?? '')
        .where((url) => url.isNotEmpty)
        .toList();

    return AppEntity(
      id: '${release['id']}',
      name: release['name'] as String? ?? 'Unknown',
      bundleId: '',
      developer: '',
      description: release['body'] as String? ?? '',
      version: (release['tag_name'] as String? ?? '0.0.0')
          .replaceFirst(RegExp(r'^v'), ''),
      buildNumber: '1',
      releaseDate: DateTime.parse(
        release['published_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      iconUrl: '',
      screenshots: [],
      categories: [],
      tags: [],
      downloadSize: 0,
      minOsVersion: '',
      sourceUrl: sourceUrl,
      repositoryId: '',
      changelog: release['body'] as String?,
      downloadUrl: assets.isNotEmpty ? assets.first : null,
    );
  }
}
