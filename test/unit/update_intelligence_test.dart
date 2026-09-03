import 'package:flutter_test/flutter_test.dart';
import 'package:omnistore/core/versioning/semantic_version.dart';
import 'package:omnistore/domain/updates/update_intelligence.dart';

/// A syntactically valid 64-character SHA-256 placeholder.
const String validSha =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

ReleaseCandidate candidate({
  String appId = 'app',
  String from = '1.0.0',
  String to = '1.0.1',
  String? changelog = 'Minor fixes.',
  String? sha256 = validSha,
  int? size,
  int? previousSize,
  bool prerelease = false,
  String? minOs,
  String? installedMinOs,
}) {
  return ReleaseCandidate(
    appId: appId,
    installedVersion: from,
    latestVersion: to,
    changelog: changelog,
    sha256: sha256,
    downloadSize: size,
    previousDownloadSize: previousSize,
    isPrerelease: prerelease,
    minOsVersion: minOs,
    installedMinOsVersion: installedMinOs,
  );
}

void main() {
  const intelligence = UpdateIntelligence();

  group('urgency', () {
    test('a security changelog is critical', () {
      final verdict = intelligence.analyze(candidate(
          changelog: 'Fixes a security vulnerability (CVE-2026-1234).'));
      expect(verdict.urgency, UpdateUrgency.critical);
      expect(verdict.isSecurityUpdate, isTrue);
      expect(verdict.summary, contains('Security'));
    });

    test('a data-loss fix is critical', () {
      final verdict = intelligence
          .analyze(candidate(changelog: 'Hotfix for crash on launch.'));
      expect(verdict.urgency, UpdateUrgency.critical);
    });

    test('a major release is important', () {
      final verdict =
          intelligence.analyze(candidate(from: '1.4.0', to: '2.0.0'));
      expect(verdict.urgency, UpdateUrgency.important);
      expect(verdict.bumpType, VersionBumpType.major);
      expect(verdict.hasBreakingChanges, isTrue);
    });

    test('a plain patch is routine', () {
      final verdict = intelligence.analyze(candidate());
      expect(verdict.urgency, UpdateUrgency.routine);
      expect(verdict.summary, 'Bug fixes');
    });

    test('a pre-release is optional', () {
      final verdict = intelligence.analyze(
          candidate(from: '1.0.0', to: '1.0.1-beta.1', prerelease: true));
      expect(verdict.urgency, UpdateUrgency.optional);
      expect(verdict.isPreRelease, isTrue);
    });

    test('a breaking pre-release stays important', () {
      final verdict = intelligence.analyze(candidate(
        from: '1.0.0',
        to: '1.1.0-beta.1',
        prerelease: true,
        changelog: 'Breaking change: config format replaced.',
      ));
      expect(verdict.urgency, UpdateUrgency.important);
      expect(verdict.hasBreakingChanges, isTrue);
    });
  });

  group('signals', () {
    test('flags a pre-1.0 minor bump as potentially breaking', () {
      final verdict =
          intelligence.analyze(candidate(from: '0.4.0', to: '0.5.0'));
      expect(verdict.signals.map((s) => s.code), contains('unstable_minor'));
      expect(verdict.hasBreakingChanges, isTrue);
    });

    test('flags a missing checksum', () {
      final verdict = intelligence.analyze(candidate(sha256: null));
      expect(verdict.signals.map((s) => s.code), contains('missing_checksum'));
    });

    test('accepts a valid 64-char checksum silently', () {
      final verdict = intelligence.analyze(candidate());
      expect(
          verdict.signals.map((s) => s.code), isNot(contains('missing_checksum')));
    });

    test('flags a missing changelog', () {
      final verdict = intelligence.analyze(candidate(changelog: '   '));
      expect(verdict.signals.map((s) => s.code), contains('no_changelog'));
    });

    test('flags a raised OS requirement', () {
      final verdict = intelligence
          .analyze(candidate(minOs: '17.0', installedMinOs: '15.0'));
      expect(verdict.signals.map((s) => s.code),
          contains('os_requirement_raised'));
      expect(verdict.urgency, UpdateUrgency.important);
    });

    test('ignores an unchanged OS requirement', () {
      final verdict = intelligence
          .analyze(candidate(minOs: '15.0', installedMinOs: '15.0'));
      expect(verdict.signals.map((s) => s.code),
          isNot(contains('os_requirement_raised')));
    });

    test('flags a suspiciously small download', () {
      final verdict =
          intelligence.analyze(candidate(size: 100, previousSize: 1000));
      expect(verdict.signals.map((s) => s.code), contains('size_drop'));
    });

    test('notes a much larger download', () {
      final verdict =
          intelligence.analyze(candidate(size: 5000, previousSize: 1000));
      expect(verdict.signals.map((s) => s.code), contains('size_increase'));
    });

    test('ignores a normal size change', () {
      final verdict =
          intelligence.analyze(candidate(size: 1100, previousSize: 1000));
      final codes = verdict.signals.map((s) => s.code);
      expect(codes, isNot(contains('size_drop')));
      expect(codes, isNot(contains('size_increase')));
    });
  });

  group('analyzeAll', () {
    test('orders critical updates before routine ones', () {
      final verdicts = intelligence.analyzeAll([
        candidate(appId: 'routine'),
        candidate(appId: 'security', changelog: 'Security fix for XSS.'),
        candidate(appId: 'major', from: '1.0.0', to: '2.0.0'),
      ]);
      expect(verdicts.map((v) => v.appId).toList(),
          ['security', 'major', 'routine']);
    });
  });

  group('ChangelogDiff', () {
    test('reports added and removed lines', () {
      final diff = ChangelogDiff.between(
        '- Fixed A\n- Fixed B',
        '- Fixed B\n- Added C',
      );
      expect(diff.addedLines, ['Added C']);
      expect(diff.removedLines, ['Fixed A']);
    });

    test('ignores bullet-style and whitespace reformatting', () {
      final diff = ChangelogDiff.between('* Fixed A', '  - Fixed A  ');
      expect(diff.isEmpty, isTrue);
    });

    test('handles null inputs', () {
      final diff = ChangelogDiff.between(null, '- New');
      expect(diff.addedLines, ['New']);
      expect(diff.removedLines, isEmpty);
    });
  });
}
