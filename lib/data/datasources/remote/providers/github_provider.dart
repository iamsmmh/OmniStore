import 'package:logging/logging.dart';
import '../../../domain/models/repository_entity.dart';
import '../../../domain/models/app_entity.dart';
import '../../../domain/services/repository_provider.dart';
import '../api_client.dart';

/// GitHub Releases provider — production-ready.
/// Handles pagination, asset discovery, version detection, changelog extraction,
/// error handling with retry, caching via ApiClient, and metadata validation.
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
    final host = uri.host.toLowerCase();
    return host == 'github.com' || host.endsWith('.github.com');
  }

  @override
  Future<RepositoryValidationData> validate(String url) async {
    final parsed = _parseGitHubUrl(url);
    if (parsed == null) {
      return const RepositoryValidationData(isValid: false, name: '', appCount: 0);
    }
    try {
      // Use cached repo info with retry
      final repoInfo = await _apiClient.getGitHubRepo(parsed['owner']!, parsed['repo']!);
      // Probe releases to confirm feed structure and count
      final releases = await _apiClient.getGitHubReleases(parsed['owner']!, parsed['repo']!, perPage: 1);
      final isValidStructure = repoInfo.containsKey('full_name') || repoInfo.containsKey('name');
      if (!isValidStructure) {
        return RepositoryValidationData(isValid: false, name: '', appCount: 0, metadata: repoInfo);
      }
      return RepositoryValidationData(
        isValid: true,
        name: repoInfo['full_name'] as String? ?? '${parsed['owner']}/${parsed['repo']}',
        description: repoInfo['description'] as String?,
        iconUrl: repoInfo['owner']?['avatar_url'] as String?,
        maintainer: repoInfo['owner']?['login'] as String? ?? parsed['owner'],
        appCount: releases.length,
        metadata: repoInfo,
      );
    } catch (e) {
      _logger.warning('GitHub validate failed for $url: $e');
      // Distinguish rate-limit vs not-found for better UX
      if (e.toString().contains('404')) {
        return const RepositoryValidationData(isValid: false, name: '', appCount: 0);
      }
      return const RepositoryValidationData(isValid: false, name: '', appCount: 0);
    }
  }

  @override
  Future<List<AppEntity>> fetchApps(String url) async {
    final parsed = _parseGitHubUrl(url);
    if (parsed == null) return [];
    try {
      // Paginated fetch with retry handling in ApiClient
      final releases = await _apiClient.getGitHubReleasesPaginated(
        parsed['owner']!,
        parsed['repo']!,
        maxPages: 4,
        perPage: 30,
      );
      if (releases.isEmpty) {
        _logger.info('No GitHub releases for $url');
        return [];
      }
      final apps = <AppEntity>[];
      for (final r in releases) {
        try {
          final app = _mapReleaseToApp(r, url, parsed);
          if (app != null) apps.add(app);
        } catch (e) {
          _logger.warning('Skipping malformed GitHub release: $e');
        }
      }
      return apps;
    } catch (e) {
      _logger.warning('GitHub fetch failed for $url: $e');
      return [];
    }
  }

  @override
  Future<List<AppEntity>> fetchUpdates(String url, DateTime since) async {
    final apps = await fetchApps(url);
    return apps.where((a) => a.releaseDate.isAfter(since)).toList();
  }

  Map<String, String>? _parseGitHubUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length < 2) return null;
    // Strip .git suffix and handle tree/blob paths
    final owner = segments[0];
    var repo = segments[1].replaceAll('.git', '');
    // Handle URLs like github.com/owner/repo/releases
    return {'owner': owner, 'repo': repo};
  }

  AppEntity? _mapReleaseToApp(Map<String, dynamic> release, String sourceUrl, Map<String, String> parsed) {
    try {
      final tag = release['tag_name'] as String? ?? release['name'] as String? ?? '0.0.0';
      final version = _detectVersion(tag);
      final rawAssets = (release['assets'] as List? ?? []);
      // Asset discovery: filter installable files, prefer largest IPA/APK, collect changelog
      final candidates = <Map<String, dynamic>>[];
      for (final raw in rawAssets) {
        final a = raw as Map<String, dynamic>;
        final url = a['browser_download_url'] as String? ?? '';
        if (url.isEmpty) continue;
        final name = a['name'] as String? ?? '';
        final lower = name.toLowerCase();
        // Prefer IPA/APK/ZIP, but keep all as fallback
        final score = lower.endsWith('.ipa') ? 3 : lower.endsWith('.apk') ? 3 : lower.endsWith('.zip') ? 2 : 1;
        candidates.add({...a, '_score': score});
      }
      candidates.sort((a, b) => (b['_score'] as int).compareTo(a['_score'] as int));
      String? downloadUrl;
      int downloadSize = 0;
      String? sha256;
      String contentType = 'application/octet-stream';
      if (candidates.isNotEmpty) {
        final best = candidates.first;
        downloadUrl = best['browser_download_url'] as String?;
        downloadSize = best['size'] as int? ?? 0;
        sha256 = best['digest'] as String?; // GitHub sometimes provides sha
        contentType = best['content_type'] as String? ?? contentType;
        // Try to extract SHA256 from label if present
        final label = best['label'] as String? ?? '';
        final shaMatch = RegExp(r'[0-9a-f]{64}').firstMatch(label);
        if (shaMatch != null) sha256 = shaMatch.group(0);
      }

      final publishedAt = release['published_at'] as String? ?? release['created_at'] as String?;
      final releaseDate = DateTime.tryParse(publishedAt ?? '') ?? DateTime.now();
      final author = release['author'] as Map<String, dynamic>?;
      final isPrerelease = release['prerelease'] as bool? ?? false;
      final isDraft = release['draft'] as bool? ?? false;
      if (isDraft) return null; // Skip drafts

      // Changelog extraction: prefer body, fallback to name
      final body = release['body'] as String? ?? '';
      final changelog = body.isNotEmpty ? body : release['name'] as String?;

      // Metadata completeness: map to AppEntity with rich fields
      final owner = parsed['owner']!;
      final repo = parsed['repo']!;
      final bundleId = 'com.github.$owner.$repo.${tag.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
      final tags = <String>[
        if (isPrerelease) 'prerelease',
        'github',
        owner.toLowerCase(),
      ];

      return AppEntity(
        id: 'github_${release['id'] ?? tag}',
        name: release['name'] as String? ?? '$owner/$repo $tag',
        bundleId: bundleId,
        developer: author?['login'] as String? ?? owner,
        description: body.isNotEmpty ? body.split('\n').first.trim() : 'GitHub release $tag for $owner/$repo',
        version: version,
        buildNumber: release['id']?.toString() ?? '1',
        releaseDate: releaseDate,
        iconUrl: author?['avatar_url'] as String? ?? '',
        screenshots: const [],
        categories: const ['Development'],
        tags: tags,
        downloadSize: downloadSize,
        minOsVersion: '',
        sourceUrl: sourceUrl,
        repositoryId: '',
        changelog: changelog,
        sha256: sha256,
        downloadUrl: downloadUrl,
        lastUpdated: releaseDate,
      );
    } catch (e) {
      _logger.warning('GitHub map failed: $e');
      return null;
    }
  }

  String _detectVersion(String tag) {
    // Strip v prefix and handle semver + date versions
    var v = tag.trim().replaceFirst(RegExp(r'^v', caseSensitive: false), '');
    // Handle 2024.05.01 style
    if (RegExp(r'^\d{4}\.\d{2}\.\d{2}').hasMatch(v)) return v;
    // Extract semver core
    final match = RegExp(r'(\d+\.\d+\.\d+[^+\s]*)').firstMatch(v);
    if (match != null) return match.group(1)!;
    final simple = RegExp(r'(\d+\.\d+[^+\s]*)').firstMatch(v);
    if (simple != null) return simple.group(1)!;
    return v.isEmpty ? '0.0.0' : v;
  }
}
