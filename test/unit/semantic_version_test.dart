import 'package:flutter_test/flutter_test.dart';
import 'package:omnistore/core/versioning/semantic_version.dart';

void main() {
  group('SemanticVersion.tryParse', () {
    test('parses plain semver', () {
      final v = SemanticVersion.tryParse('1.2.3')!;
      expect(v.major, 1);
      expect(v.minor, 2);
      expect(v.patch, 3);
      expect(v.isPreRelease, isFalse);
    });

    test('tolerates a leading v and whitespace', () {
      final v = SemanticVersion.tryParse('  v10.0.1 ')!;
      expect(v.major, 10);
      expect(v.patch, 1);
    });

    test('fills missing minor and patch', () {
      expect(SemanticVersion.tryParse('2')!.toString(), '2.0.0');
      expect(SemanticVersion.tryParse('2.5')!.toString(), '2.5.0');
    });

    test('parses pre-release identifiers', () {
      final v = SemanticVersion.tryParse('1.0.0-beta.2')!;
      expect(v.preRelease, ['beta', '2']);
      expect(v.isPreRelease, isTrue);
    });

    test('parses build metadata', () {
      final v = SemanticVersion.tryParse('1.0.0+42')!;
      expect(v.build, '42');
    });

    test('folds a fourth numeric component into build metadata', () {
      final v = SemanticVersion.tryParse('1.2.3.4')!;
      expect(v.major, 1);
      expect(v.patch, 3);
      expect(v.build, '4');
    });

    test('returns null for non-version text', () {
      expect(SemanticVersion.tryParse('nightly'), isNull);
      expect(SemanticVersion.tryParse(''), isNull);
      expect(SemanticVersion.tryParse(null), isNull);
    });

    test('parseOrZero never throws and keeps raw text', () {
      final v = SemanticVersion.parseOrZero('nightly');
      expect(v.major, 0);
      expect(v.raw, 'nightly');
    });
  });

  group('ordering', () {
    test('orders by major, minor, patch', () {
      expect(SemanticVersion.tryParse('2.0.0')! >
          SemanticVersion.tryParse('1.9.9')!, isTrue);
      expect(SemanticVersion.tryParse('1.2.0')! >
          SemanticVersion.tryParse('1.1.9')!, isTrue);
      expect(SemanticVersion.tryParse('1.1.2')! >
          SemanticVersion.tryParse('1.1.1')!, isTrue);
    });

    test('a release outranks its own pre-release', () {
      expect(SemanticVersion.tryParse('1.0.0')! >
          SemanticVersion.tryParse('1.0.0-rc.1')!, isTrue);
    });

    test('orders pre-release identifiers numerically then lexically', () {
      expect(SemanticVersion.tryParse('1.0.0-beta.10')! >
          SemanticVersion.tryParse('1.0.0-beta.2')!, isTrue);
      expect(SemanticVersion.tryParse('1.0.0-beta')! >
          SemanticVersion.tryParse('1.0.0-alpha')!, isTrue);
    });

    test('numeric identifiers rank below alphanumeric ones', () {
      expect(SemanticVersion.tryParse('1.0.0-1')! <
          SemanticVersion.tryParse('1.0.0-alpha')!, isTrue);
    });

    test('build metadata does not affect precedence', () {
      expect(SemanticVersion.tryParse('1.0.0+1'),
          SemanticVersion.tryParse('1.0.0+2'));
    });

    test('sorts a mixed list correctly', () {
      final versions = ['1.0.0', '1.0.0-rc.1', '0.9.9', '2.0.0', '1.10.0']
          .map((v) => SemanticVersion.tryParse(v)!)
          .toList()
        ..sort();
      expect(versions.map((v) => v.toString()).toList(),
          ['0.9.9', '1.0.0-rc.1', '1.0.0', '1.10.0', '2.0.0']);
    });
  });

  group('classify', () {
    test('detects each bump type', () {
      expect(SemanticVersion.classify('1.0.0', '2.0.0'), VersionBumpType.major);
      expect(SemanticVersion.classify('1.0.0', '1.1.0'), VersionBumpType.minor);
      expect(SemanticVersion.classify('1.0.0', '1.0.1'), VersionBumpType.patch);
      expect(SemanticVersion.classify('1.0.0-a', '1.0.0-b'),
          VersionBumpType.prerelease);
      expect(SemanticVersion.classify('1.0.0+1', '1.0.0+2'),
          VersionBumpType.build);
      expect(SemanticVersion.classify('1.0.0', '1.0.0'), VersionBumpType.none);
    });

    test('reports unknown for unparseable inputs', () {
      expect(SemanticVersion.classify('nightly', '1.0.0'),
          VersionBumpType.unknown);
    });

    test('treats identical unparseable strings as no change', () {
      expect(SemanticVersion.classify('nightly', 'nightly'),
          VersionBumpType.none);
    });
  });

  group('isNewer', () {
    test('handles the pre-release regression correctly', () {
      // The old dotted-integer comparison considered these equal.
      expect(SemanticVersion.isNewer('1.0.0', '1.0.0-beta'), isTrue);
      expect(SemanticVersion.isNewer('1.0.0-beta', '1.0.0'), isFalse);
    });

    test('falls back to string inequality for date-style tags', () {
      expect(SemanticVersion.isNewer('nightly-b', 'nightly-a'), isTrue);
      expect(SemanticVersion.isNewer('nightly', 'nightly'), isFalse);
    });
  });

  test('isUnstable flags pre-1.0 projects', () {
    expect(SemanticVersion.tryParse('0.4.2')!.isUnstable, isTrue);
    expect(SemanticVersion.tryParse('1.0.0')!.isUnstable, isFalse);
  });
}
