/// Repository trust and asset integrity analysis.
///
/// OmniStore installs software from sources the user chose but did not audit.
/// This module turns observable, non-invasive facts (transport, metadata
/// completeness, checksum availability, release consistency) into an
/// explainable trust score. It deliberately never claims an app is "safe" —
/// it reports what could and could not be verified.
library;

import '../../core/versioning/semantic_version.dart';

/// Severity of a trust finding.
enum TrustSeverity { info, low, medium, high }

/// A single observation about a repository or asset.
class TrustFinding {
  final String code;
  final String title;
  final String detail;
  final TrustSeverity severity;

  /// Concrete action the user or maintainer can take.
  final String? remediation;

  const TrustFinding({
    required this.code,
    required this.title,
    required this.detail,
    required this.severity,
    this.remediation,
  });

  @override
  String toString() => '$code(${severity.name})';
}

/// Trust tier shown as a badge.
enum TrustLevel { verified, trusted, caution, untrusted }

extension TrustLevelDisplay on TrustLevel {
  String get label => switch (this) {
        TrustLevel.verified => 'Verified',
        TrustLevel.trusted => 'Trusted',
        TrustLevel.caution => 'Use caution',
        TrustLevel.untrusted => 'Untrusted',
      };

  String get accessibleDescription => switch (this) {
        TrustLevel.verified =>
          'Verified source: secure transport, complete metadata and published checksums',
        TrustLevel.trusted =>
          'Trusted source: secure transport and mostly complete metadata',
        TrustLevel.caution =>
          'Use caution: this source is missing integrity or metadata information',
        TrustLevel.untrusted =>
          'Untrusted source: serious integrity or transport problems detected',
      };
}

/// Facts about a repository, gathered during sync.
class RepositoryTrustInput {
  final String repositoryId;
  final String url;

  /// Fraction of apps in the repo that publish a SHA-256 (`[0, 1]`).
  final double checksumCoverage;

  /// Fraction of apps with all core metadata fields populated (`[0, 1]`).
  final double metadataCompleteness;

  /// Fraction of download URLs that are HTTPS (`[0, 1]`).
  final double httpsAssetRatio;

  /// Fraction of releases whose version strings parse as semver (`[0, 1]`).
  final double versionConsistency;

  final int appCount;
  final DateTime? lastSuccessfulSync;
  final int consecutiveSyncFailures;

  /// Number of assets that returned 4xx/5xx on the last integrity probe.
  final int brokenAssetCount;

  /// Explicitly verified by the user or by an OmniSource verification record.
  final bool isPubliclyVerified;

  const RepositoryTrustInput({
    required this.repositoryId,
    required this.url,
    this.checksumCoverage = 0,
    this.metadataCompleteness = 0,
    this.httpsAssetRatio = 0,
    this.versionConsistency = 0,
    this.appCount = 0,
    this.lastSuccessfulSync,
    this.consecutiveSyncFailures = 0,
    this.brokenAssetCount = 0,
    this.isPubliclyVerified = false,
  });
}

/// Result of analysing a repository.
class TrustReport {
  final String repositoryId;
  final TrustLevel level;

  /// `[0, 100]`.
  final int score;
  final List<TrustFinding> findings;

  const TrustReport({
    required this.repositoryId,
    required this.level,
    required this.score,
    required this.findings,
  });

  bool get hasBlockingIssues =>
      findings.any((f) => f.severity == TrustSeverity.high);
}

/// Scores repositories and validates individual assets.
class TrustAnalyzer {
  const TrustAnalyzer();

  TrustReport analyzeRepository(RepositoryTrustInput input, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final findings = <TrustFinding>[];
    var score = 100;

    final uri = Uri.tryParse(input.url);
    if (uri == null || uri.host.isEmpty) {
      findings.add(const TrustFinding(
        code: 'invalid_url',
        title: 'Malformed repository URL',
        detail: 'The repository URL could not be parsed.',
        severity: TrustSeverity.high,
        remediation: 'Remove or correct this repository.',
      ));
      score -= 60;
    } else if (uri.scheme != 'https') {
      findings.add(TrustFinding(
        code: 'insecure_transport',
        title: 'Repository is not served over HTTPS',
        detail: 'Metadata is fetched over ${uri.scheme.toUpperCase()}, so it '
            'can be observed or modified in transit.',
        severity: TrustSeverity.high,
        remediation: 'Ask the maintainer to publish over HTTPS.',
      ));
      score -= 45;
    }

    if (input.httpsAssetRatio < 1.0 && input.appCount > 0) {
      final percent = ((1 - input.httpsAssetRatio) * 100).round();
      findings.add(TrustFinding(
        code: 'insecure_assets',
        title: 'Some downloads are not HTTPS',
        detail: '$percent% of download links in this repository use plain HTTP.',
        severity:
            input.httpsAssetRatio < 0.5 ? TrustSeverity.high : TrustSeverity.medium,
        remediation: 'Avoid installing apps whose download link is not HTTPS.',
      ));
      score -= (30 * (1 - input.httpsAssetRatio)).round();
    }

    if (input.checksumCoverage < 0.95) {
      final severity = input.checksumCoverage < 0.25
          ? TrustSeverity.high
          : input.checksumCoverage < 0.7
              ? TrustSeverity.medium
              : TrustSeverity.low;
      findings.add(TrustFinding(
        code: 'missing_checksums',
        title: 'Incomplete checksum coverage',
        detail:
            '${(input.checksumCoverage * 100).round()}% of apps publish a '
            'SHA-256 checksum. Downloads without one cannot be verified.',
        severity: severity,
        remediation: 'Prefer apps that publish checksums.',
      ));
      score -= (25 * (1 - input.checksumCoverage)).round();
    }

    if (input.metadataCompleteness < 0.8) {
      findings.add(TrustFinding(
        code: 'poor_metadata',
        title: 'Incomplete metadata',
        detail:
            'Only ${(input.metadataCompleteness * 100).round()}% of entries '
            'provide the core fields (name, version, developer, description, '
            'source URL).',
        severity: input.metadataCompleteness < 0.4
            ? TrustSeverity.medium
            : TrustSeverity.low,
        remediation: 'Metadata gaps make it harder to identify what you install.',
      ));
      score -= (15 * (1 - input.metadataCompleteness)).round();
    }

    if (input.versionConsistency < 0.6 && input.appCount > 2) {
      findings.add(TrustFinding(
        code: 'inconsistent_versions',
        title: 'Inconsistent version scheme',
        detail:
            'Only ${(input.versionConsistency * 100).round()}% of versions '
            'follow a recognisable scheme, so update detection may be unreliable.',
        severity: TrustSeverity.low,
      ));
      score -= 8;
    }

    if (input.brokenAssetCount > 0) {
      findings.add(TrustFinding(
        code: 'broken_downloads',
        title: 'Broken downloads detected',
        detail:
            '${input.brokenAssetCount} download link(s) did not respond '
            'successfully during the last check.',
        severity:
            input.brokenAssetCount > 3 ? TrustSeverity.high : TrustSeverity.medium,
        remediation: 'Report the broken links to the maintainer.',
      ));
      score -= (5 * input.brokenAssetCount).clamp(0, 30);
    }

    if (input.consecutiveSyncFailures >= 3) {
      findings.add(TrustFinding(
        code: 'sync_failing',
        title: 'Repository is failing to sync',
        detail:
            '${input.consecutiveSyncFailures} consecutive sync attempts failed. '
            'Catalog data may be stale.',
        severity: TrustSeverity.medium,
      ));
      score -= 10;
    }

    final lastSync = input.lastSuccessfulSync;
    if (lastSync != null) {
      final staleDays = reference.difference(lastSync).inDays;
      if (staleDays > 30) {
        findings.add(TrustFinding(
          code: 'stale_catalog',
          title: 'Catalog is stale',
          detail: 'Last successful sync was $staleDays days ago.',
          severity: TrustSeverity.low,
        ));
        score -= 5;
      }
    }

    if (input.appCount == 0) {
      findings.add(const TrustFinding(
        code: 'empty_repository',
        title: 'Repository is empty',
        detail: 'No applications were found in this repository.',
        severity: TrustSeverity.low,
      ));
    }

    if (input.isPubliclyVerified) {
      findings.add(const TrustFinding(
        code: 'verified_source',
        title: 'Verified source',
        detail: 'This repository has a verified ownership record.',
        severity: TrustSeverity.info,
      ));
      score += 5;
    }

    score = score.clamp(0, 100);
    return TrustReport(
      repositoryId: input.repositoryId,
      level: _level(score, findings, input.isPubliclyVerified),
      score: score,
      findings: List.unmodifiable(findings),
    );
  }

  TrustLevel _level(int score, List<TrustFinding> findings, bool verified) {
    if (findings.any((f) => f.severity == TrustSeverity.high)) {
      return score >= 55 ? TrustLevel.caution : TrustLevel.untrusted;
    }
    if (verified && score >= 85) return TrustLevel.verified;
    if (score >= 85) return TrustLevel.trusted;
    if (score >= 60) return TrustLevel.caution;
    return TrustLevel.untrusted;
  }

  /// Validates a single downloadable asset's declared metadata.
  ///
  /// This is pre-download validation; the actual byte-level checksum
  /// comparison happens in `SecurityService` after the file lands on disk.
  List<TrustFinding> validateAsset({
    required String? downloadUrl,
    required String? sha256,
    required int? sizeBytes,
    required String? version,
    String? contentType,
  }) {
    final findings = <TrustFinding>[];

    final uri = Uri.tryParse(downloadUrl ?? '');
    if (downloadUrl == null || downloadUrl.isEmpty || uri == null) {
      findings.add(const TrustFinding(
        code: 'asset_no_url',
        title: 'No download URL',
        detail: 'This release does not provide a downloadable asset.',
        severity: TrustSeverity.high,
      ));
    } else if (uri.scheme != 'https') {
      findings.add(const TrustFinding(
        code: 'asset_insecure',
        title: 'Insecure download link',
        detail: 'The download is not served over HTTPS and could be tampered '
            'with in transit.',
        severity: TrustSeverity.high,
        remediation: 'Do not install unless you trust the network path.',
      ));
    }

    if (sha256 == null || sha256.isEmpty) {
      findings.add(const TrustFinding(
        code: 'asset_no_checksum',
        title: 'No checksum published',
        detail: 'Download integrity cannot be verified after downloading.',
        severity: TrustSeverity.medium,
      ));
    } else if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(sha256)) {
      findings.add(const TrustFinding(
        code: 'asset_bad_checksum_format',
        title: 'Malformed checksum',
        detail: 'The published checksum is not a valid 64-character SHA-256 '
            'value, so it cannot be used for verification.',
        severity: TrustSeverity.high,
      ));
    }

    if (sizeBytes == null || sizeBytes <= 0) {
      findings.add(const TrustFinding(
        code: 'asset_no_size',
        title: 'Unknown download size',
        detail: 'The asset size is missing, so download progress and integrity '
            'checks are limited.',
        severity: TrustSeverity.low,
      ));
    }

    if (SemanticVersion.tryParse(version) == null) {
      findings.add(const TrustFinding(
        code: 'asset_unparseable_version',
        title: 'Unrecognised version format',
        detail: 'Update detection may be unreliable for this app.',
        severity: TrustSeverity.low,
      ));
    }

    if (contentType != null &&
        contentType.startsWith('text/html')) {
      findings.add(const TrustFinding(
        code: 'asset_html_response',
        title: 'Download link returns a web page',
        detail: 'The link appears to point at an HTML page rather than an '
            'installable package.',
        severity: TrustSeverity.high,
      ));
    }

    return findings;
  }
}
