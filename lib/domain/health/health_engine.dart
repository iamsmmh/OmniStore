import 'app_health.dart';

/// Spec-compliant health engine that produces 0-100 score and
/// Healthy / Warning / Critical tri-state for UI.
enum AppHealthStatus { healthy, warning, critical }

extension AppHealthStatusDisplay on AppHealthStatus {
  String get label => switch (this) {
        AppHealthStatus.healthy => 'Healthy',
        AppHealthStatus.warning => 'Warning',
        AppHealthStatus.critical => 'Critical',
      };
  String get accessibleDescription => switch (this) {
        AppHealthStatus.healthy => 'App is actively maintained',
        AppHealthStatus.warning => 'App shows reduced maintenance activity',
        AppHealthStatus.critical => 'App may be abandoned or broken',
      };
}

class AppHealthScore {
  final String appId;
  final int score; // 0-100
  final AppHealthStatus status;
  final HealthReport detailedReport;
  final List<String> healthSignals;

  const AppHealthScore({
    required this.appId,
    required this.score,
    required this.status,
    required this.detailedReport,
    this.healthSignals = const [],
  });
}

/// Facade that maps the detailed HealthReport to spec tri-state
/// and incorporates real-world signals: broken assets/downloads, maintainer
/// activity, metadata quality, repository responsiveness.
class HealthEngine {
  final AppHealthAnalyzer _analyzer;

  const HealthEngine({AppHealthAnalyzer? analyzer}) : _analyzer = analyzer ?? const AppHealthAnalyzer();

  AppHealthScore evaluate({
    required String appId,
    required List<DateTime> releaseDates,
    DateTime? now,
    bool repositoryArchived = false,
    int brokenAssets = 0,
    int brokenDownloads = 0,
    bool hasBrokenMetadata = false,
    double maintainerActivityScore = 1.0, // 0-1, 1 = active
    double metadataQualityScore = 1.0, // 0-1
    int? repositoryResponseTimeMs, // null = unknown, >2000 = slow
    int? consecutiveSyncFailures,
  }) {
    final report = _analyzer.analyze(
      appId: appId,
      releaseDates: releaseDates,
      now: now,
      repositoryArchived: repositoryArchived,
    );

    var score = report.score;
    final signals = <String>[];

    // Broken assets: missing or 404 icons/downloads
    if (brokenAssets > 0) {
      final penalty = (brokenAssets * 12).clamp(0, 35);
      score -= penalty;
      signals.add('$brokenAssets broken asset(s) detected');
    }
    if (brokenDownloads > 0) {
      final penalty = (brokenDownloads * 10).clamp(0, 30);
      score -= penalty;
      signals.add('$brokenDownloads broken download(s)');
    }
    if (hasBrokenMetadata) {
      score -= 12;
      signals.add('Incomplete metadata');
    }

    // Maintainer activity: low activity penalizes
    if (maintainerActivityScore < 0.3) {
      score -= 10;
      signals.add('Low maintainer activity');
    } else if (maintainerActivityScore > 0.7) {
      score += 3;
      signals.add('Active maintainer');
    }

    // Metadata quality
    if (metadataQualityScore < 0.5) {
      score -= 8;
      signals.add('Poor metadata quality');
    } else if (metadataQualityScore > 0.9) {
      score += 2;
    }

    // Repository responsiveness: slow or failing syncs
    if (repositoryResponseTimeMs != null) {
      if (repositoryResponseTimeMs > 5000) {
        score -= 8;
        signals.add('Repository slow to respond (${repositoryResponseTimeMs}ms)');
      } else if (repositoryResponseTimeMs > 2000) {
        score -= 4;
        signals.add('Repository response slow');
      }
    }
    if (consecutiveSyncFailures != null && consecutiveSyncFailures > 0) {
      final penalty = (consecutiveSyncFailures * 5).clamp(0, 20);
      score -= penalty;
      signals.add('$consecutiveSyncFailures consecutive sync failures');
    }

    if (repositoryArchived) {
      score = (score - 30).clamp(0, 100);
      signals.add('Repository archived');
    }

    score = score.clamp(0, 100);
    final status = _mapStatus(report.status, score);

    return AppHealthScore(
      appId: appId,
      score: score,
      status: status,
      detailedReport: report,
      healthSignals: signals,
    );
  }

  AppHealthStatus _mapStatus(HealthStatus detailed, int score) {
    if (detailed == HealthStatus.potentiallyAbandoned || score < 35) return AppHealthStatus.critical;
    if (detailed == HealthStatus.maintenance || detailed == HealthStatus.unknown || score < 65) {
      return AppHealthStatus.warning;
    }
    return AppHealthStatus.healthy;
  }
}
