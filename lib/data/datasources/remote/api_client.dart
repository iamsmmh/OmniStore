import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/http_client.dart';
import '../../../core/security/security_service.dart';

/// Centralized API client with caching, pagination, ETag support and validation.
class ApiClient {
  final HttpClient _httpClient;
  final SecurityService _securityService;
  final _logger = Logger('ApiClient');

  // Simple in-memory response cache with TTL
  final Map<String, _CachedResponse> _cache = {};
  final Map<String, String> _etagCache = {};

  ApiClient({
    required HttpClient httpClient,
    required SecurityService securityService,
  })  : _httpClient = httpClient,
        _securityService = securityService;

  // ─── GitHub API ──────────────────────────────────────────────

  Future<Map<String, dynamic>> getGitHubRepo(
    String owner,
    String repo,
  ) async {
    final response = await _getWithCache(
      'https://api.github.com/repos/$owner/$repo',
      headers: {'Accept': 'application/vnd.github.v3+json'},
      ttl: AppConstants.feedCacheDuration,
    );
    return response as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getGitHubReleases(
    String owner,
    String repo, {
    int perPage = 30,
    int page = 1,
  }) async {
    final data = await _getWithCache(
      'https://api.github.com/repos/$owner/$repo/releases',
      queryParameters: {'per_page': perPage, 'page': page},
      headers: {'Accept': 'application/vnd.github.v3+json'},
      ttl: AppConstants.feedCacheDuration,
    );
    return (data as List).map((e) => e as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> getGitHubReleasesPaginated(
    String owner,
    String repo, {
    int maxPages = 3,
    int perPage = 30,
  }) async {
    final all = <Map<String, dynamic>>[];
    for (int page = 1; page <= maxPages; page++) {
      try {
        final releases = await getGitHubReleases(owner, repo, perPage: perPage, page: page);
        if (releases.isEmpty) break;
        all.addAll(releases);
        if (releases.length < perPage) break;
      } catch (e) {
        _logger.warning('GitHub pagination stopped at page $page: $e');
        break;
      }
    }
    return all;
  }

  // ─── GitLab API ──────────────────────────────────────────────

  Future<Map<String, dynamic>> getGitLabProject(
    String projectId, {
    String baseUrl = 'https://gitlab.com',
  }) async {
    final response = await _getWithCache(
      '$baseUrl/api/v4/projects/${Uri.encodeComponent(projectId)}',
      ttl: AppConstants.feedCacheDuration,
    );
    return response as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getGitLabReleases(
    String projectId, {
    String baseUrl = 'https://gitlab.com',
    int perPage = 30,
    int page = 1,
  }) async {
    final data = await _getWithCache(
      '$baseUrl/api/v4/projects/${Uri.encodeComponent(projectId)}/releases',
      queryParameters: {'per_page': perPage, 'page': page},
      ttl: AppConstants.feedCacheDuration,
    );
    return (data as List).map((e) => e as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> getGitLabReleasesPaginated(
    String projectId, {
    String baseUrl = 'https://gitlab.com',
    int maxPages = 3,
    int perPage = 30,
  }) async {
    final all = <Map<String, dynamic>>[];
    for (int page = 1; page <= maxPages; page++) {
      try {
        final releases = await getGitLabReleases(projectId, baseUrl: baseUrl, perPage: perPage, page: page);
        if (releases.isEmpty) break;
        all.addAll(releases);
        if (releases.length < perPage) break;
      } catch (e) {
        _logger.warning('GitLab pagination stopped at page $page: $e');
        break;
      }
    }
    return all;
  }

  // ─── Gitea / Forgejo / Codeberg API ──────────────────────────

  Future<Map<String, dynamic>?> getGiteaRepo(
    String owner,
    String repo, {
    required String baseUrl,
  }) async {
    try {
      final data = await _getWithCache(
        '$baseUrl/api/v1/repos/$owner/$repo',
        ttl: AppConstants.feedCacheDuration,
      );
      return data as Map<String, dynamic>;
    } catch (e) {
      _logger.warning('Failed to fetch Gitea repo $owner/$repo at $baseUrl: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getGiteaReleases(
    String owner,
    String repo, {
    required String baseUrl,
    int perPage = 30,
    int page = 1,
  }) async {
    try {
      final data = await _getWithCache(
        '$baseUrl/api/v1/repos/$owner/$repo/releases',
        queryParameters: {'limit': perPage, 'page': page},
        ttl: AppConstants.feedCacheDuration,
      );
      if (data is List) {
        return data.map((e) => e as Map<String, dynamic>).toList();
      }
      return [];
    } catch (e) {
      _logger.warning('Failed to fetch Gitea releases $owner/$repo: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getGiteaReleasesPaginated(
    String owner,
    String repo, {
    required String baseUrl,
    int maxPages = 3,
    int perPage = 30,
  }) async {
    final all = <Map<String, dynamic>>[];
    for (int page = 1; page <= maxPages; page++) {
      final releases = await getGiteaReleases(owner, repo, baseUrl: baseUrl, perPage: perPage, page: page);
      if (releases.isEmpty) break;
      all.addAll(releases);
      if (releases.length < perPage) break;
    }
    return all;
  }

  // ─── AltStore Source ─────────────────────────────────────────

  Future<Map<String, dynamic>?> getAltStoreSource(String url) async {
    return _getJsonFeed(url);
  }

  // ─── OmniSource Feed ─────────────────────────────────────────

  Future<Map<String, dynamic>?> getOmniSourceFeed(String url) async {
    return _getJsonFeed(url);
  }

  Future<Map<String, dynamic>?> getOmniSourceUpdates(
    String url,
    DateTime since,
  ) async {
    try {
      final response = await _httpClient.get<dynamic>(
        url,
        queryParameters: {'since': since.toIso8601String()},
      );
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      _logger.severe('Failed to fetch OmniSource updates', e);
      return null;
    }
  }

  // ─── Feather Source ──────────────────────────────────────────

  Future<Map<String, dynamic>?> getFeatherSource(String url) async {
    return _getJsonFeed(url);
  }

  // ─── Generic Feed ────────────────────────────────────────────

  Future<Map<String, dynamic>?> getGenericFeed(String url) async {
    return _getJsonFeed(url);
  }

  /// Fetch arbitrary JSON feed with validation, caching and conditional request.
  Future<Map<String, dynamic>?> getJsonFeed(String url, {Duration? ttl}) async {
    return _getJsonFeed(url, ttl: ttl);
  }

  Future<Map<String, dynamic>?> _getJsonFeed(String url, {Duration? ttl}) async {
    try {
      if (!_securityService.validateUrl(url)) {
        _logger.warning('Blocked insecure feed URL: $url');
        return null;
      }
      final data = await _getWithCache(url, ttl: ttl ?? AppConstants.feedCacheDuration);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return null;
    } catch (e) {
      _logger.severe('Failed to fetch feed: $url', e);
      return null;
    }
  }

  Future<dynamic> _getWithCache(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    Duration? ttl,
  }) async {
    final cacheKey = _buildCacheKey(url, queryParameters);
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.data;
    }

    final etag = _etagCache[cacheKey];
    final options = Options(
      headers: {
        if (headers != null) ...headers,
        if (etag != null) 'If-None-Match': etag,
      },
    );

    try {
      final response = await _httpClient.get<dynamic>(
        url,
        queryParameters: queryParameters,
        options: options,
      );

      // Handle 304 Not Modified
      if (response.statusCode == 304 && cached != null) {
        return cached.data;
      }

      // Store ETag
      final responseEtag = response.headers.map['etag']?.first;
      if (responseEtag != null) {
        _etagCache[cacheKey] = responseEtag;
      }

      final data = response.data;
      _cache[cacheKey] = _CachedResponse(
        data: data,
        timestamp: DateTime.now(),
        ttl: ttl ?? AppConstants.feedCacheDuration,
      );

      // Enforce cache size limit
      if (_cache.length > 100) {
        final oldest = _cache.keys.first;
        _cache.remove(oldest);
      }

      return data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 304 && cached != null) {
        return cached.data;
      }
      rethrow;
    }
  }

  String _buildCacheKey(String url, Map<String, dynamic>? queryParameters) {
    if (queryParameters == null || queryParameters.isEmpty) return url;
    final qs = queryParameters.entries.map((e) => '${e.key}=${e.value}').join('&');
    return '$url?$qs';
  }

  void clearCache() {
    _cache.clear();
    _etagCache.clear();
  }

  // ─── Download ────────────────────────────────────────────────

  Future<Response<dynamic>> downloadFile(
    String url,
    String savePath, {
    void Function(int, int)? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    if (!_securityService.validateUrl(url)) {
      throw Exception('Invalid or insecure download URL: $url');
    }
    return _httpClient.download(
      url,
      savePath,
      onReceiveProgress: onReceiveProgress,
      cancelToken: cancelToken,
    );
  }
}

class _CachedResponse {
  final dynamic data;
  final DateTime timestamp;
  final Duration ttl;

  _CachedResponse({required this.data, required this.timestamp, required this.ttl});

  bool get isExpired => DateTime.now().difference(timestamp) > ttl;
}
