import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

import '../../../core/network/http_client.dart';
import '../../../core/security/security_service.dart';

/// Centralized API client for all remote data sources
class ApiClient {
  final HttpClient _httpClient;
  final SecurityService _securityService;
  final _logger = Logger('ApiClient');

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
    final response = await _httpClient.get(
      'https://api.github.com/repos/$owner/$repo',
      options: Options(headers: {'Accept': 'application/vnd.github.v3+json'}),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getGitHubReleases(
    String owner,
    String repo, {
    int perPage = 30,
    int page = 1,
  }) async {
    final response = await _httpClient.get(
      'https://api.github.com/repos/$owner/$repo/releases',
      queryParameters: {'per_page': perPage, 'page': page},
      options: Options(headers: {'Accept': 'application/vnd.github.v3+json'}),
    );
    return (response.data as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  // ─── GitLab API ──────────────────────────────────────────────

  Future<Map<String, dynamic>> getGitLabProject(String projectId) async {
    final response = await _httpClient.get(
      'https://gitlab.com/api/v4/projects/$projectId',
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getGitLabReleases(
    String projectId, {
    int perPage = 30,
    int page = 1,
  }) async {
    final response = await _httpClient.get(
      'https://gitlab.com/api/v4/projects/$projectId/releases',
      queryParameters: {'per_page': perPage, 'page': page},
    );
    return (response.data as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  // ─── AltStore Source ─────────────────────────────────────────

  Future<Map<String, dynamic>?> getAltStoreSource(String url) async {
    try {
      final response = await _httpClient.get(url);
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      _logger.severe('Failed to fetch AltStore source', e);
      return null;
    }
  }

  // ─── OmniSource Feed ─────────────────────────────────────────

  Future<Map<String, dynamic>?> getOmniSourceFeed(String url) async {
    try {
      final response = await _httpClient.get(url);
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      _logger.severe('Failed to fetch OmniSource feed', e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> getOmniSourceUpdates(
    String url,
    DateTime since,
  ) async {
    try {
      final response = await _httpClient.get(
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
    try {
      final response = await _httpClient.get(url);
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      _logger.severe('Failed to fetch Feather source', e);
      return null;
    }
  }

  // ─── Forgejo API ─────────────────────────────────────────────

  Future<Map<String, dynamic>> getForgejoRepo(
    String baseUrl,
    String owner,
    String repo,
  ) async {
    final apiUrl = _buildForgejoApiUrl(baseUrl, owner, repo);
    final response = await _httpClient.get(apiUrl);
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getForgejoReleases(
    String baseUrl,
    String owner,
    String repo, {
    int perPage = 30,
    int page = 1,
  }) async {
    final apiUrl = _buildForgejoReleasesUrl(baseUrl, owner, repo, perPage, page);
    try {
      final response = await _httpClient.get(apiUrl);
      final data = response.data;
      if (data is List) {
        return data.map((e) => e as Map<String, dynamic>).toList();
      }
      return [];
    } catch (e) {
      _logger.severe('Failed to fetch Forgejo releases', e);
      return [];
    }
  }

  String _buildForgejoApiUrl(String baseUrl, String owner, String repo) {
    final uri = Uri.parse(baseUrl);
    return '${uri.scheme}://${uri.host}/api/v1/repos/$owner/$repo';
  }

  String _buildForgejoReleasesUrl(
    String baseUrl,
    String owner,
    String repo,
    int perPage,
    int page,
  ) {
    return '${_buildForgejoApiUrl(baseUrl, owner, repo)}/releases?per_page=$perPage&page=$page';
  }

  // ─── Codeberg API ─────────────────────────────────────────────

  Future<Map<String, dynamic>> getCodebergRepo(String owner, String repo) async {
    final response = await _httpClient.get(
      'https://codeberg.org/api/v1/repos/$owner/$repo',
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getCodebergReleases(
    String owner,
    String repo, {
    int perPage = 30,
    int page = 1,
  }) async {
    final response = await _httpClient.get(
      'https://codeberg.org/api/v1/repos/$owner/$repo/releases',
      queryParameters: {'per_page': perPage, 'page': page},
    );
    return (response.data as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  // ─── Generic Feed ────────────────────────────────────────────

  Future<Map<String, dynamic>?> getGenericFeed(String url) async {
    try {
      final response = await _httpClient.get(url);
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      _logger.severe('Failed to fetch generic feed', e);
      return null;
    }
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
