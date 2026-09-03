import 'trust_analyzer.dart';

/// Spec categories: Trusted, Verified, Community, Unknown, Risky
enum TrustCategory { verified, trusted, community, unknown, risky }

extension TrustCategoryDisplay on TrustCategory {
  String get label => switch (this) {
        TrustCategory.verified => 'Verified',
        TrustCategory.trusted => 'Trusted',
        TrustCategory.community => 'Community',
        TrustCategory.unknown => 'Unknown',
        TrustCategory.risky => 'Risky',
      };
  String get description => switch (this) {
        TrustCategory.verified => 'Verified ownership and strong integrity signals',
        TrustCategory.trusted => 'Strong security and metadata quality',
        TrustCategory.community => 'Community-contributed, use discretion',
        TrustCategory.unknown => 'Not enough signals to assess',
        TrustCategory.risky => 'Integrity or transport issues detected',
      };
}

class TrustScore {
  final String repositoryId;
  final int score; // 0-100
  final TrustCategory category;
  final TrustReport detailedReport;

  const TrustScore({
    required this.repositoryId,
    required this.score,
    required this.category,
    required this.detailedReport,
  });
}

/// Facade that maps detailed TrustReport to spec TrustCategory.
class TrustEngine {
  final TrustAnalyzer _analyzer;

  const TrustEngine({TrustAnalyzer? analyzer}) : _analyzer = analyzer ?? const TrustAnalyzer();

  TrustScore evaluate(RepositoryTrustInput input, {DateTime? now}) {
    final report = _analyzer.analyzeRepository(input, now: now);
    final category = _mapCategory(report.level, report.score, input);
    return TrustScore(repositoryId: input.repositoryId, score: report.score, category: category, detailedReport: report);
  }

  TrustCategory _mapCategory(TrustLevel level, int score, RepositoryTrustInput input) {
    // Verified via explicit verification and high score -> Verified
    if (input.isPubliclyVerified && score >= 85) return TrustCategory.verified;
    switch (level) {
      case TrustLevel.verified:
        return TrustCategory.verified;
      case TrustLevel.trusted:
        return score >= 85 ? TrustCategory.trusted : TrustCategory.community;
      case TrustLevel.caution:
        return score >= 45 ? TrustCategory.community : TrustCategory.unknown;
      case TrustLevel.untrusted:
        if (score == 0 && input.appCount == 0) return TrustCategory.unknown;
        return TrustCategory.risky;
    }
  }
}
