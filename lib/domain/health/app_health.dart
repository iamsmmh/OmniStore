/// Application health scoring.
///
/// Answers the question users actually have before installing software from
/// an independent repository: "is this project still alive?". Derived purely
/// from release cadence data OmniStore already stores, so it works offline and
/// costs no extra API calls.
library;

import 'dart:math' as math;

/// Coarse health classification surfaced as a badge in the UI.
enum HealthStatus {
  /// Frequent, recent releases.
  healthy,

  /// Regular but less frequent releases.
  active,

  /// Only occasional releases; likely bug fixes only.
  maintenance,

  /// No releases for a long time; may be abandoned.
  potentiallyAbandoned,

  /// Not enough data to judge (e.g. brand new project).
  unknown,
}

extension HealthStatusDisplay on HealthStatus {
  String get label => switch (this) {
        HealthStatus.healthy => 'Healthy',
        HealthStatus.active => 'Active',
        HealthStatus.maintenance => 'Maintenance mode',
        HealthStatus.potentiallyAbandoned => 'Potentially abandoned',
        HealthStatus.unknown => 'Unknown',
      };

  /// Wording for screen readers and tooltips — avoids relying on colour alone.
  String get accessibleDescription => switch (this) {
        HealthStatus.healthy =>
          'Actively maintained with frequent recent releases',
        HealthStatus.active => 'Maintained with regular releases',
        HealthStatus.maintenance =>
          'In maintenance mode; occasional releases only',
        HealthStatus.potentiallyAbandoned =>
          'No releases for a long time; may no longer be maintained',
        HealthStatus.unknown => 'Not enough release history to assess',
      };
}

/// Detailed health assessment for one application.
class HealthReport {
  final String appId;
  final HealthStatus status;

  /// Composite score in `[0, 100]`, useful for ranking and sorting.
  final int score;

  final DateTime? lastReleaseAt;
  final int releasesLast90Days;
  final int releasesLast365Days;

  /// Median days between the analysed releases; `null` with <2 releases.
  final double? medianDaysBetweenReleases;

  /// Human-readable justifications for the classification.
  final List<String> reasons;

  const HealthReport({
    required this.appId,
    required this.status,
    required this.score,
    required this.lastReleaseAt,
    required this.releasesLast90Days,
    required this.releasesLast365Days,
    required this.medianDaysBetweenReleases,
    required this.reasons,
  });

  int? daysSinceLastRelease(DateTime now) =>
      lastReleaseAt == null ? null : now.difference(lastReleaseAt!).inDays;
}

/// Computes [HealthReport]s from release timestamps.
class AppHealthAnalyzer {
  const AppHealthAnalyzer();

  /// [releaseDates] may be unsorted and may contain duplicates.
  /// [now] is injectable for deterministic tests.
  HealthReport analyze({
    required String appId,
    required List<DateTime> releaseDates,
    DateTime? now,
    bool repositoryArchived = false,
  }) {
    final reference = now ?? DateTime.now();
    final dates = releaseDates.toSet().toList()..sort();

    if (dates.isEmpty) {
      return HealthReport(
        appId: appId,
        status: HealthStatus.unknown,
        score: 0,
        lastReleaseAt: null,
        releasesLast90Days: 0,
        releasesLast365Days: 0,
        medianDaysBetweenReleases: null,
        reasons: const ['No release history available.'],
      );
    }

    final last = dates.last;
    final daysSince = reference.difference(last).inDays;
    final in90 = dates
        .where((d) => reference.difference(d).inDays <= 90 && !d.isAfter(reference))
        .length;
    final in365 = dates
        .where((d) => reference.difference(d).inDays <= 365 && !d.isAfter(reference))
        .length;
    final median = _medianGapDays(dates);

    final reasons = <String>[];

    // Recency is the dominant factor: an old project with a release last week
    // is healthier than a once-busy project silent for two years.
    final recencyScore = switch (daysSince) {
      <= 30 => 45,
      <= 90 => 38,
      <= 180 => 28,
      <= 365 => 16,
      <= 730 => 6,
      _ => 0,
    };
    reasons.add(daysSince <= 1
        ? 'Released today.'
        : 'Last release $daysSince days ago.');

    final cadenceScore = switch (in365) {
      0 => 0,
      1 => 8,
      <= 3 => 18,
      <= 6 => 26,
      <= 12 => 32,
      _ => 35,
    };
    reasons.add('$in365 release(s) in the last year, $in90 in the last 90 days.');

    var consistencyScore = 0;
    if (median != null) {
      // Predictable cadence is a trust signal independent of raw frequency.
      consistencyScore = median <= 45
          ? 20
          : median <= 120
              ? 14
              : median <= 270
                  ? 8
                  : 3;
      reasons.add('Typically ships every ${median.round()} days.');
    } else {
      reasons.add('Only one release recorded.');
    }

    var score = recencyScore + cadenceScore + consistencyScore;

    if (repositoryArchived) {
      score = math.min(score, 15);
      reasons.add('Upstream repository is archived.');
    }
    score = score.clamp(0, 100);

    final status = _classify(
      daysSince: daysSince,
      releasesLast365Days: in365,
      releasesLast90Days: in90,
      archived: repositoryArchived,
      totalReleases: dates.length,
    );

    return HealthReport(
      appId: appId,
      status: status,
      score: score,
      lastReleaseAt: last,
      releasesLast90Days: in90,
      releasesLast365Days: in365,
      medianDaysBetweenReleases: median,
      reasons: List.unmodifiable(reasons),
    );
  }

  HealthStatus _classify({
    required int daysSince,
    required int releasesLast365Days,
    required int releasesLast90Days,
    required bool archived,
    required int totalReleases,
  }) {
    if (archived) return HealthStatus.potentiallyAbandoned;
    if (daysSince > 540) return HealthStatus.potentiallyAbandoned;
    if (totalReleases == 1 && daysSince <= 90) return HealthStatus.unknown;

    if (daysSince <= 90 && releasesLast365Days >= 4) return HealthStatus.healthy;
    if (daysSince <= 45 && releasesLast90Days >= 1) return HealthStatus.healthy;
    if (daysSince <= 210 && releasesLast365Days >= 2) return HealthStatus.active;
    if (daysSince <= 540) return HealthStatus.maintenance;
    return HealthStatus.potentiallyAbandoned;
  }

  static double? _medianGapDays(List<DateTime> sortedDates) {
    if (sortedDates.length < 2) return null;
    final gaps = <int>[];
    for (var i = 1; i < sortedDates.length; i++) {
      gaps.add(sortedDates[i].difference(sortedDates[i - 1]).inDays);
    }
    gaps.sort();
    final middle = gaps.length ~/ 2;
    if (gaps.length.isOdd) return gaps[middle].toDouble();
    return (gaps[middle - 1] + gaps[middle]) / 2;
  }
}
