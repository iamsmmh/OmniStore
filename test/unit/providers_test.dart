import 'package:flutter_test/flutter_test.dart';
import 'package:omnistore/data/datasources/remote/api_client.dart';
import 'package:omnistore/core/network/http_client.dart';
import 'package:omnistore/core/security/security_service.dart';
import 'package:omnistore/data/datasources/remote/providers/github_provider.dart';
import 'package:omnistore/data/datasources/remote/providers/gitlab_provider.dart';
import 'package:omnistore/data/datasources/remote/providers/codeberg_provider.dart';
import 'package:omnistore/data/datasources/remote/providers/altstore_provider.dart';
import 'package:omnistore/data/datasources/remote/providers/feather_provider.dart';
import 'package:omnistore/data/datasources/remote/providers/generic_json_provider.dart';

void main() {
  late ApiClient apiClient;

  setUp(() {
    apiClient = ApiClient(httpClient: HttpClient(), securityService: SecurityService());
  });

  group('Repository Providers', () {
    test('GitHub canHandle', () {
      final p = GitHubProvider(apiClient);
      expect(p.canHandle('https://github.com/owner/repo'), isTrue);
      expect(p.canHandle('https://gitlab.com/owner/repo'), isFalse);
    });

    test('GitLab canHandle', () {
      final p = GitLabProvider(apiClient);
      expect(p.canHandle('https://gitlab.com/owner/repo'), isTrue);
      expect(p.canHandle('https://github.com/owner/repo'), isFalse);
    });

    test('Codeberg canHandle', () {
      final p = CodebergProvider(apiClient);
      expect(p.canHandle('https://codeberg.org/owner/repo'), isTrue);
      expect(p.canHandle('https://github.com/owner/repo'), isFalse);
    });

    test('Feather canHandle', () {
      final p = FeatherProvider(apiClient);
      expect(p.canHandle('https://example.com/feather.json'), isTrue);
      expect(p.canHandle('https://github.com/owner/repo'), isFalse);
    });

    test('AltStore canHandle', () {
      final p = AltStoreProvider(apiClient);
      expect(p.canHandle('https://example.com/apps.json'), isTrue);
    });

    test('Generic canHandle fallback', () {
      final p = GenericJsonProvider(apiClient);
      expect(p.canHandle('https://example.com/feed.json'), isTrue);
      expect(p.canHandle('https://example.com/api'), isTrue);
    });

    test('Provider registry detects correctly', () {
      expect(GitHubProvider(ApiClient(httpClient: HttpClient(), securityService: SecurityService())).type.name, 'github');
    });
  });
}
