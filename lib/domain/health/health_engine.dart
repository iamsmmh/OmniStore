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

  const AppHealthScore({
    required this.appId,
    required this.score,
    required this.status,
    required this.detailedReport,
  });
}

/// Facade that maps the detailed HealthReport to spec tri-state.
class HealthEngine {
  final AppHealthAnalyzer _analyzer;

  const HealthEngine({AppHealthAnalyzer? analyzer}) : _analyzer = analyzer ?? const AppHealthAnalyzer();

  AppHealthScore evaluate({
    required String appId,
    required List<DateTime> releaseDates,
    DateTime? now,
    bool repositoryArchived = false,
    int brokenDownloads = 0,
    bool hasBrokenMetadata = false,
  }) {
    final report = _analyzer.analyze(
      appId: appId,
      releaseDates: releaseDates,
      now: now,
      repositoryArchived: repositoryArchived,
    );

    // Adjust score for broken downloads/metadata
    var score = report.score;
    if (brokenDownloads > 0) score -= (brokenDownloads * 8).clamp(0, 30);
    if (hasBrokenMetadata) score -= 10;
    if (repositoryArchived) score = (score - 30).clamp(0, 100);

    final status = _mapStatus(report.status, score);
    return AppHealthScore(appId: appId, score: score.clamp(0, 100), status: status, detailedReport: report);
  }

  AppHealthStatus _mapStatus(HealthStatus detailed, int score) {
    // Critical: abandoned or very low score
    if (detailed == HealthStatus.potentiallyAbandoned || score < 35) return AppHealthStatus.critical;
    if (detailed == HealthStatus.maintenance || detailed == HealthStatus.unknown || score < 65) {
      return AppHealthStatus.warning;
    }
    return AppHealthStatus.healthy;
  }
}
