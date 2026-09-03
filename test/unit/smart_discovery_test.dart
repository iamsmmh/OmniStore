import 'package:flutter_test/flutter_test.dart';
import 'package:omnistore/domain/discovery/smart_discovery_engine.dart';
import 'package:omnistore/domain/health/app_health.dart';

void main() {
  group('SmartDiscoveryEngine', () {
    const engine = SmartDiscoveryEngine();

    test('suggests related repositories', () {
      final anchor = RepositoryProfile(id: 'a', name: 'Music Hub', url: 'https://a.com', categories: ['music', 'audio'], addedAt: DateTime.now().subtract(const Duration(days: 10)), appCount: 20);
      final catalog = [
        RepositoryProfile(id: 'b', name: 'Audio Tools', url: 'https://b.com', categories: ['music', 'audio'], addedAt: DateTime.now().subtract(const Duration(days: 5)), appCount: 15),
        RepositoryProfile(id: 'c', name: 'Games', url: 'https://c.com', categories: ['games'], addedAt: DateTime.now(), appCount: 30),
      ];
      final suggestions = engine.suggestRepositories(anchor: anchor, catalog: catalog, healthByRepo: {});
      expect(suggestions.isNotEmpty, isTrue);
      expect(suggestions.first.repositoryId, 'b');
    });

    test('boosts verified and popular', () {
      final anchor = RepositoryProfile(id: 'a', name: 'Test', url: 'https://a.com', categories: ['utilities'], addedAt: DateTime.now(), appCount: 5);
      final catalog = [
        RepositoryProfile(id: 'b', name: 'Verified Big', url: 'https://b.com', categories: ['utilities'], isVerified: true, popularity: 0.9, appCount: 100, addedAt: DateTime.now().subtract(const Duration(days: 100))),
        RepositoryProfile(id: 'c', name: 'Small', url: 'https://c.com', categories: ['utilities'], appCount: 2, addedAt: DateTime.now().subtract(const Duration(days: 100))),
      ];
      final suggestions = engine.suggestRepositories(anchor: anchor, catalog: catalog, healthByRepo: {});
      expect(suggestions.first.repositoryId, 'b');
    });

    test('respects health penalties', () {
      final anchor = RepositoryProfile(id: 'a', name: 'A', url: 'https://a.com', categories: ['music'], addedAt: DateTime.now(), appCount: 10);
      final catalog = [
        RepositoryProfile(id: 'b', name: 'Healthy', url: 'https://b.com', categories: ['music'], addedAt: DateTime.now(), appCount: 10),
        RepositoryProfile(id: 'c', name: 'Abandoned', url: 'https://c.com', categories: ['music'], addedAt: DateTime.now(), appCount: 10),
      ];
      final health = {
        'b': HealthReport(appId: 'b', status: HealthStatus.healthy, score: 95, lastReleaseAt: DateTime.now(), releasesLast90Days: 5, releasesLast365Days: 12, medianDaysBetweenReleases: 30, reasons: []),
        'c': HealthReport(appId: 'c', status: HealthStatus.potentiallyAbandoned, score: 10, lastReleaseAt: DateTime(2020, 1, 1), releasesLast90Days: 0, releasesLast365Days: 0, medianDaysBetweenReleases: null, reasons: []),
      };
      final suggestions = engine.suggestRepositories(anchor: anchor, catalog: catalog, healthByRepo: health);
      expect(suggestions.first.repositoryId, 'b');
    });
  });
}
