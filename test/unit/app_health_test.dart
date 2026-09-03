import 'package:flutter_test/flutter_test.dart';
import 'package:omnistore/domain/health/app_health.dart';

void main() {
  const analyzer = AppHealthAnalyzer();
  final now = DateTime(2026, 9, 3);

  List<DateTime> monthly(int count, {int startDaysAgo = 0}) {
    return List.generate(
      count,
      (i) => now.subtract(Duration(days: startDaysAgo + i * 30)),
    );
  }

  group('classification', () {
    test('frequent recent releases are healthy', () {
      final report = analyzer.analyze(
          appId: 'a', releaseDates: monthly(8), now: now);
      expect(report.status, HealthStatus.healthy);
      expect(report.score, greaterThan(70));
    });

    test('a couple of releases per year is active', () {
      final report = analyzer.analyze(
        appId: 'a',
        releaseDates: [
          now.subtract(const Duration(days: 150)),
          now.subtract(const Duration(days: 330)),
          now.subtract(const Duration(days: 500)),
        ],
        now: now,
      );
      expect(report.status, HealthStatus.active);
    });

    test('a long-quiet but not ancient project is in maintenance mode', () {
      final report = analyzer.analyze(
        appId: 'a',
        releaseDates: [
          now.subtract(const Duration(days: 400)),
          now.subtract(const Duration(days: 800)),
        ],
        now: now,
      );
      expect(report.status, HealthStatus.maintenance);
    });

    test('no release for well over a year is potentially abandoned', () {
      final report = analyzer.analyze(
        appId: 'a',
        releaseDates: [now.subtract(const Duration(days: 900))],
        now: now,
      );
      expect(report.status, HealthStatus.potentiallyAbandoned);
    });

    test('an archived repository is always potentially abandoned', () {
      final report = analyzer.analyze(
        appId: 'a',
        releaseDates: monthly(8),
        now: now,
        repositoryArchived: true,
      );
      expect(report.status, HealthStatus.potentiallyAbandoned);
      expect(report.score, lessThanOrEqualTo(15));
    });

    test('a single recent release is unknown, not healthy', () {
      final report = analyzer.analyze(
        appId: 'a',
        releaseDates: [now.subtract(const Duration(days: 10))],
        now: now,
      );
      expect(report.status, HealthStatus.unknown);
    });

    test('no history at all is unknown with zero score', () {
      final report =
          analyzer.analyze(appId: 'a', releaseDates: const [], now: now);
      expect(report.status, HealthStatus.unknown);
      expect(report.score, 0);
      expect(report.lastReleaseAt, isNull);
    });
  });

  group('metrics', () {
    test('counts releases in the 90 and 365 day windows', () {
      final report = analyzer.analyze(
        appId: 'a',
        releaseDates: [
          now.subtract(const Duration(days: 5)),
          now.subtract(const Duration(days: 60)),
          now.subtract(const Duration(days: 200)),
          now.subtract(const Duration(days: 800)),
        ],
        now: now,
      );
      expect(report.releasesLast90Days, 2);
      expect(report.releasesLast365Days, 3);
    });

    test('computes the median gap between releases', () {
      final report = analyzer.analyze(
        appId: 'a',
        releaseDates: monthly(5),
        now: now,
      );
      expect(report.medianDaysBetweenReleases, 30);
    });

    test('median is null with a single release', () {
      final report = analyzer.analyze(
        appId: 'a',
        releaseDates: [now.subtract(const Duration(days: 10))],
        now: now,
      );
      expect(report.medianDaysBetweenReleases, isNull);
    });

    test('deduplicates identical timestamps', () {
      final date = now.subtract(const Duration(days: 10));
      final report =
          analyzer.analyze(appId: 'a', releaseDates: [date, date], now: now);
      expect(report.medianDaysBetweenReleases, isNull);
    });

    test('unsorted input still yields the latest release', () {
      final report = analyzer.analyze(
        appId: 'a',
        releaseDates: [
          now.subtract(const Duration(days: 300)),
          now.subtract(const Duration(days: 5)),
          now.subtract(const Duration(days: 100)),
        ],
        now: now,
      );
      expect(report.daysSinceLastRelease(now), 5);
    });

    test('score is bounded to 0..100', () {
      final report =
          analyzer.analyze(appId: 'a', releaseDates: monthly(40), now: now);
      expect(report.score, inInclusiveRange(0, 100));
    });

    test('reasons are always populated', () {
      final report =
          analyzer.analyze(appId: 'a', releaseDates: monthly(3), now: now);
      expect(report.reasons, isNotEmpty);
    });
  });

  test('labels and accessible descriptions exist for every status', () {
    for (final status in HealthStatus.values) {
      expect(status.label, isNotEmpty);
      expect(status.accessibleDescription, isNotEmpty);
    }
  });
}
