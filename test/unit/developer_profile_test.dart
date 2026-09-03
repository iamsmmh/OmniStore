import 'package:flutter_test/flutter_test.dart';
import 'package:omnistore/domain/developer/developer_profile.dart';

void main() {
  const evaluator = BadgeEvaluator();
  final now = DateTime(2026, 9, 3);

  VerificationRecord record({
    VerificationStatus status = VerificationStatus.verified,
    Duration? expiresIn = const Duration(days: 30),
    VerificationMethod method = VerificationMethod.dnsTxtRecord,
  }) =>
      VerificationRecord(
        method: method,
        status: status,
        checkedAt: now.subtract(const Duration(days: 1)),
        subject: 'example.com',
        expiresAt: expiresIn == null ? null : now.add(expiresIn),
      );

  group('verification records', () {
    test('a current verified record is active', () {
      expect(record().isActiveAt(now), isTrue);
    });

    test('an expired record is not active', () {
      expect(
        record(expiresIn: const Duration(days: -1)).isActiveAt(now),
        isFalse,
      );
    });

    test('a failed record is not active', () {
      expect(record(status: VerificationStatus.failed).isActiveAt(now), isFalse);
    });

    test('a revoked record is not active', () {
      expect(
          record(status: VerificationStatus.revoked).isActiveAt(now), isFalse);
    });

    test('a record without an expiry stays active', () {
      expect(record(expiresIn: null).isActiveAt(now), isTrue);
    });
  });

  group('badge evaluation', () {
    test('grants a verified publisher badge with justification', () {
      final badges = evaluator.evaluate(
        verifications: [record()],
        metrics: const DeveloperMetrics(),
        now: now,
      );
      final badge =
          badges.firstWhere((b) => b.kind == BadgeKind.verifiedPublisher);
      expect(badge.justification, contains('example.com'));
      expect(badge.justification, contains('DNS TXT'));
    });

    test('grants no verification badge without an active record', () {
      final badges = evaluator.evaluate(
        verifications: [record(status: VerificationStatus.pending)],
        metrics: const DeveloperMetrics(),
        now: now,
      );
      expect(badges.map((b) => b.kind),
          isNot(contains(BadgeKind.verifiedPublisher)));
    });

    test('grants a checksum badge only with sufficient coverage and history',
        () {
      expect(
        evaluator
            .evaluate(
              verifications: const [],
              metrics: const DeveloperMetrics(
                  checksumCoverage: 1.0, releaseCount: 5),
              now: now,
            )
            .map((b) => b.kind),
        contains(BadgeKind.checksumPublisher),
      );
      expect(
        evaluator
            .evaluate(
              verifications: const [],
              metrics: const DeveloperMetrics(
                  checksumCoverage: 1.0, releaseCount: 1),
              now: now,
            )
            .map((b) => b.kind),
        isNot(contains(BadgeKind.checksumPublisher)),
      );
    });

    test('grants an open source badge', () {
      final badges = evaluator.evaluate(
        verifications: const [],
        metrics: const DeveloperMetrics(openSourceRatio: 1.0, appCount: 2),
        now: now,
      );
      expect(badges.map((b) => b.kind), contains(BadgeKind.openSource));
    });

    test('grants a consistent maintainer badge for recent, regular releases',
        () {
      final badges = evaluator.evaluate(
        verifications: const [],
        metrics: DeveloperMetrics(
          releaseCount: 10,
          lastReleaseAt: now.subtract(const Duration(days: 30)),
        ),
        now: now,
      );
      expect(
          badges.map((b) => b.kind), contains(BadgeKind.consistentMaintainer));
    });

    test('withholds the maintainer badge when releases went quiet', () {
      final badges = evaluator.evaluate(
        verifications: const [],
        metrics: DeveloperMetrics(
          releaseCount: 10,
          lastReleaseAt: now.subtract(const Duration(days: 400)),
        ),
        now: now,
      );
      expect(badges.map((b) => b.kind),
          isNot(contains(BadgeKind.consistentMaintainer)));
    });

    test('grants a long-standing badge after two years', () {
      final badges = evaluator.evaluate(
        verifications: const [],
        metrics: DeveloperMetrics(
            firstSeenAt: now.subtract(const Duration(days: 900))),
        now: now,
      );
      expect(badges.map((b) => b.kind), contains(BadgeKind.longStanding));
    });

    test('grants a signed releases badge', () {
      final badges = evaluator.evaluate(
        verifications: const [],
        metrics: const DeveloperMetrics(hasSignedReleases: true),
        now: now,
      );
      expect(badges.map((b) => b.kind), contains(BadgeKind.signedReleases));
    });

    test('grants nothing for an unknown developer', () {
      expect(
        evaluator.evaluate(
            verifications: const [],
            metrics: const DeveloperMetrics(),
            now: now),
        isEmpty,
      );
    });

    test('every badge carries a non-empty justification', () {
      final badges = evaluator.evaluate(
        verifications: [record()],
        metrics: DeveloperMetrics(
          appCount: 3,
          releaseCount: 12,
          checksumCoverage: 1.0,
          openSourceRatio: 1.0,
          hasSignedReleases: true,
          firstSeenAt: now.subtract(const Duration(days: 1000)),
          lastReleaseAt: now.subtract(const Duration(days: 5)),
        ),
        now: now,
      );
      expect(badges.length, 6);
      for (final badge in badges) {
        expect(badge.label, isNotEmpty);
        expect(badge.justification, isNotEmpty);
      }
    });
  });

  group('DeveloperProfile', () {
    test('reports verification state', () {
      final profile = DeveloperProfile(
        id: 'dev',
        displayName: 'Dev',
        verifications: [record()],
      );
      expect(profile.isVerifiedAt(now), isTrue);
    });

    test('returns the latest release from unsorted history', () {
      final profile = DeveloperProfile(
        id: 'dev',
        displayName: 'Dev',
        releaseHistory: [
          now.subtract(const Duration(days: 100)),
          now.subtract(const Duration(days: 2)),
          now.subtract(const Duration(days: 50)),
        ],
      );
      expect(profile.lastReleaseAt, now.subtract(const Duration(days: 2)));
    });

    test('handles an empty release history', () {
      const profile = DeveloperProfile(id: 'dev', displayName: 'Dev');
      expect(profile.lastReleaseAt, isNull);
      expect(profile.appIds, isEmpty);
    });
  });
}
