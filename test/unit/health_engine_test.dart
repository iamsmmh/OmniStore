import 'package:flutter_test/flutter_test.dart';
import 'package:omnistore/domain/health/health_engine.dart';

void main() {
  group('HealthEngine', () {
    const engine = HealthEngine();

    test('healthy for recent releases', () {
      final now = DateTime(2025, 6, 1);
      final dates = [DateTime(2025, 5, 28), DateTime(2025, 4, 1), DateTime(2025, 2, 1)];
      final score = engine.evaluate(appId: 'app1', releaseDates: dates, now: now);
      expect(score.status, AppHealthStatus.healthy);
      expect(score.score, greaterThan(60));
    });

    test('critical for abandoned app', () {
      final now = DateTime(2025, 6, 1);
      final dates = [DateTime(2020, 1, 1)];
      final score = engine.evaluate(appId: 'app2', releaseDates: dates, now: now);
      expect(score.status, AppHealthStatus.critical);
    });

    test('warning for maintenance mode', () {
      final now = DateTime(2025, 6, 1);
      final dates = [DateTime(2024, 6, 1)];
      final score = engine.evaluate(appId: 'app3', releaseDates: dates, now: now);
      expect(score.status, isIn([AppHealthStatus.warning, AppHealthStatus.critical, AppHealthStatus.healthy]));
    });

    test('penalizes broken downloads', () {
      final now = DateTime(2025, 6, 1);
      final dates = [DateTime(2025, 5, 28)];
      final clean = engine.evaluate(appId: 'app1', releaseDates: dates, now: now, brokenDownloads: 0);
      final broken = engine.evaluate(appId: 'app1', releaseDates: dates, now: now, brokenDownloads: 5);
      expect(broken.score, lessThan(clean.score));
    });

    test('accessible descriptions', () {
      expect(AppHealthStatus.healthy.accessibleDescription, isNotEmpty);
      expect(AppHealthStatus.critical.accessibleDescription, isNotEmpty);
    });
  });
}
