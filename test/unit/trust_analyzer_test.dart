import 'package:flutter_test/flutter_test.dart';
import 'package:omnistore/domain/security/trust_analyzer.dart';

void main() {
  const analyzer = TrustAnalyzer();
  final now = DateTime(2026, 9, 3);

  RepositoryTrustInput input({
    String url = 'https://apps.example.com/index.json',
    double checksums = 1.0,
    double metadata = 1.0,
    double https = 1.0,
    double versions = 1.0,
    int apps = 10,
    int failures = 0,
    int broken = 0,
    bool verified = false,
    Duration? lastSync = const Duration(hours: 1),
  }) {
    return RepositoryTrustInput(
      repositoryId: 'repo',
      url: url,
      checksumCoverage: checksums,
      metadataCompleteness: metadata,
      httpsAssetRatio: https,
      versionConsistency: versions,
      appCount: apps,
      consecutiveSyncFailures: failures,
      brokenAssetCount: broken,
      isPubliclyVerified: verified,
      lastSuccessfulSync: lastSync == null ? null : now.subtract(lastSync),
    );
  }

  group('repository scoring', () {
    test('a clean HTTPS repository is trusted', () {
      final report = analyzer.analyzeRepository(input(), now: now);
      expect(report.level, TrustLevel.trusted);
      expect(report.score, greaterThanOrEqualTo(85));
      expect(report.hasBlockingIssues, isFalse);
    });

    test('a clean repository with verification is verified', () {
      final report =
          analyzer.analyzeRepository(input(verified: true), now: now);
      expect(report.level, TrustLevel.verified);
    });

    test('plain HTTP is a high-severity finding', () {
      final report = analyzer
          .analyzeRepository(input(url: 'http://apps.example.com'), now: now);
      expect(report.findings.map((f) => f.code),
          contains('insecure_transport'));
      expect(report.hasBlockingIssues, isTrue);
      expect(report.level,
          anyOf(TrustLevel.caution, TrustLevel.untrusted));
    });

    test('a malformed URL is untrusted', () {
      final report =
          analyzer.analyzeRepository(input(url: 'not a url'), now: now);
      expect(report.findings.map((f) => f.code), contains('invalid_url'));
      expect(report.level, TrustLevel.untrusted);
    });

    test('missing checksums lower the score', () {
      final report = analyzer.analyzeRepository(input(checksums: 0.1), now: now);
      expect(report.findings.map((f) => f.code), contains('missing_checksums'));
      expect(report.score, lessThan(85));
    });

    test('poor metadata is reported', () {
      final report = analyzer.analyzeRepository(input(metadata: 0.3), now: now);
      expect(report.findings.map((f) => f.code), contains('poor_metadata'));
    });

    test('inconsistent versioning is reported', () {
      final report = analyzer.analyzeRepository(input(versions: 0.2), now: now);
      expect(report.findings.map((f) => f.code),
          contains('inconsistent_versions'));
    });

    test('broken downloads are reported', () {
      final report = analyzer.analyzeRepository(input(broken: 5), now: now);
      expect(report.findings.map((f) => f.code), contains('broken_downloads'));
      expect(report.hasBlockingIssues, isTrue);
    });

    test('repeated sync failures are reported', () {
      final report = analyzer.analyzeRepository(input(failures: 4), now: now);
      expect(report.findings.map((f) => f.code), contains('sync_failing'));
    });

    test('a stale catalog is reported', () {
      final report = analyzer
          .analyzeRepository(input(lastSync: const Duration(days: 60)), now: now);
      expect(report.findings.map((f) => f.code), contains('stale_catalog'));
    });

    test('an empty repository is reported', () {
      final report = analyzer.analyzeRepository(input(apps: 0), now: now);
      expect(report.findings.map((f) => f.code), contains('empty_repository'));
    });

    test('score stays within 0..100', () {
      final worst = analyzer.analyzeRepository(
        input(
          url: 'http://bad.example.com',
          checksums: 0,
          metadata: 0,
          https: 0,
          versions: 0,
          broken: 20,
          failures: 10,
          lastSync: const Duration(days: 400),
        ),
        now: now,
      );
      expect(worst.score, inInclusiveRange(0, 100));
      expect(worst.level, TrustLevel.untrusted);
    });

    test('findings expose readable titles and details', () {
      final report = analyzer.analyzeRepository(input(checksums: 0.5), now: now);
      for (final finding in report.findings) {
        expect(finding.title, isNotEmpty);
        expect(finding.detail, isNotEmpty);
      }
    });
  });

  group('asset validation', () {
    test('a well-formed asset produces no findings', () {
      final findings = analyzer.validateAsset(
        downloadUrl: 'https://example.com/app.ipa',
        sha256: 'b' * 64,
        sizeBytes: 1024,
        version: '1.2.3',
      );
      expect(findings, isEmpty);
    });

    test('a missing URL is high severity', () {
      final findings = analyzer.validateAsset(
        downloadUrl: null,
        sha256: 'b' * 64,
        sizeBytes: 1,
        version: '1.0.0',
      );
      expect(findings.single.code, 'asset_no_url');
      expect(findings.single.severity, TrustSeverity.high);
    });

    test('an HTTP download is high severity', () {
      final findings = analyzer.validateAsset(
        downloadUrl: 'http://example.com/app.apk',
        sha256: 'b' * 64,
        sizeBytes: 1,
        version: '1.0.0',
      );
      expect(findings.map((f) => f.code), contains('asset_insecure'));
    });

    test('a missing checksum is medium severity', () {
      final findings = analyzer.validateAsset(
        downloadUrl: 'https://example.com/app.apk',
        sha256: null,
        sizeBytes: 1,
        version: '1.0.0',
      );
      expect(findings.single.code, 'asset_no_checksum');
      expect(findings.single.severity, TrustSeverity.medium);
    });

    test('a malformed checksum is high severity', () {
      final findings = analyzer.validateAsset(
        downloadUrl: 'https://example.com/app.apk',
        sha256: 'zzz',
        sizeBytes: 1,
        version: '1.0.0',
      );
      expect(findings.single.code, 'asset_bad_checksum_format');
    });

    test('a missing size is low severity', () {
      final findings = analyzer.validateAsset(
        downloadUrl: 'https://example.com/app.apk',
        sha256: 'b' * 64,
        sizeBytes: null,
        version: '1.0.0',
      );
      expect(findings.single.code, 'asset_no_size');
    });

    test('an unparseable version is reported', () {
      final findings = analyzer.validateAsset(
        downloadUrl: 'https://example.com/app.apk',
        sha256: 'b' * 64,
        sizeBytes: 1,
        version: 'nightly',
      );
      expect(findings.single.code, 'asset_unparseable_version');
    });

    test('an HTML response is flagged', () {
      final findings = analyzer.validateAsset(
        downloadUrl: 'https://example.com/download',
        sha256: 'b' * 64,
        sizeBytes: 1,
        version: '1.0.0',
        contentType: 'text/html; charset=utf-8',
      );
      expect(findings.map((f) => f.code), contains('asset_html_response'));
    });
  });

  test('every trust level has display text', () {
    for (final level in TrustLevel.values) {
      expect(level.label, isNotEmpty);
      expect(level.accessibleDescription, isNotEmpty);
    }
  });
}
