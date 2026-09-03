import 'package:logging/logging.dart';

import '../../../../domain/models/repository_entity.dart';
import '../../../../domain/models/app_entity.dart';
import '../../../../domain/services/repository_provider.dart';
import '../api_client.dart';

/// Forgejo repository provider
/// Handles Forgejo Releases-based repositories
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
    // Check for common Forgejo indicators
    return uri.host.contains('forgejo') ||
        uri.host.contains('gitea') ||
        url.contains('/releases');
  }

  @override
  Future<RepositoryValidationData> validate(String url) async {
    try {
      final parsed = _parseForgejoUrl(url);
      if (parsed == null) {
        return RepositoryValidationData(isValid: false, name: '', appCount: 0);
      }

      final repoInfo = await _apiClient.getForgejoRepo(
        url,
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
      _logger.severe('Failed to validate Forgejo repo: $url', e);
      return RepositoryValidationData(isValid: false, name: '', appCount: 0);
    }
  }

  @override
  Future<List<AppEntity>> fetchApps(String url) async {
    try {
      final parsed = _parseForgejoUrl(url);
      if (parsed == null) return [];

      final releases = await _apiClient.getForgejoReleases(
        url,
        parsed['owner']!,
        parsed['repo']!,
      );

      return releases.map((release) => _mapReleaseToApp(release, url)).toList();
    } catch (e) {
      _logger.severe('Failed to fetch Forgejo releases: $url', e);
      return [];
    }
  }

  @override
  Future<List<AppEntity>> fetchUpdates(String url, DateTime since) async {
    final apps = await fetchApps(url);
    return apps.where((app) => app.releaseDate.isAfter(since)).toList();
  }

  Map<String, String>? _parseForgejoUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    // Handle various URL formats
    // https://forgejo.example.com/owner/repo
    // https://forgejo.example.com/owner/repo/releases
    final segments = uri.pathSegments
        .where((s) => s.isNotEmpty)
        .where((s) => !['releases', 'tags', 'compare'].contains(s))
        .toList();

    if (segments.length < 2) return null;

    return {'owner': segments[0], 'repo': segments[1]};
  }

  AppEntity _mapReleaseToApp(Map<String, dynamic> release, String sourceUrl) {
    final assets = (release['assets'] as List? ?? [])
        .map((a) => a['browser_download_url'] as String? ?? a['url'] as String? ?? '')
        .where((url) => url.isNotEmpty)
        .toList();

    return AppEntity(
      id: '${release['id']}',
      name: release['name'] as String? ?? release['tag_name'] as String? ?? 'Unknown',
      bundleId: '',
      developer: '',
      description: release['body'] as String? ?? release['description'] as String? ?? '',
      version: (release['tag_name'] as String? ?? '0.0.0').replaceFirst(RegExp(r'^v'), ''),
      buildNumber: '1',
      releaseDate: DateTime.tryParse(release['published_at'] as String? ?? release['created_at'] as String? ?? '') ?? DateTime.now(),
      iconUrl: '',
      screenshots: [],
      categories: [],
      tags: [],
      downloadSize: 0,
      minOsVersion: '',
      sourceUrl: sourceUrl,
      repositoryId: '',
      changelog: release['body'] as String? ?? release['description'] as String?,
      downloadUrl: assets.isNotEmpty ? assets.first : null,
    );
  }
}
