import 'package:flutter_test/flutter_test.dart';
import 'package:omnistore/infrastructure/cache/offline_cache_policy.dart';

void main() {
  final now = DateTime(2026, 9, 3);

  group('freshness evaluation', () {
    test('within TTL is fresh', () {
      expect(
        CachePolicy.standard.evaluate(
          kind: CacheKind.catalog,
          storedAt: now.subtract(const Duration(hours: 1)),
          now: now,
        ),
        Freshness.fresh,
      );
    });

    test('past TTL but within hard expiry is stale', () {
      expect(
        CachePolicy.standard.evaluate(
          kind: CacheKind.catalog,
          storedAt: now.subtract(const Duration(days: 2)),
          now: now,
        ),
        Freshness.stale,
      );
    });

    test('past hard expiry is expired', () {
      expect(
        CachePolicy.standard.evaluate(
          kind: CacheKind.catalog,
          storedAt: now.subtract(const Duration(days: 100)),
          now: now,
        ),
        Freshness.expired,
      );
    });

    test('no timestamp is missing', () {
      expect(
        CachePolicy.standard
            .evaluate(kind: CacheKind.catalog, storedAt: null, now: now),
        Freshness.missing,
      );
    });

    test('clock skew is treated as fresh rather than as an error', () {
      expect(
        CachePolicy.standard.evaluate(
          kind: CacheKind.catalog,
          storedAt: now.add(const Duration(days: 1)),
          now: now,
        ),
        Freshness.fresh,
      );
    });

    test('data saver tolerates more staleness than the standard policy', () {
      final storedAt = now.subtract(const Duration(days: 1));
      expect(
        CachePolicy.standard
            .evaluate(kind: CacheKind.catalog, storedAt: storedAt, now: now),
        Freshness.stale,
      );
      expect(
        CachePolicy.dataSaver
            .evaluate(kind: CacheKind.catalog, storedAt: storedAt, now: now),
        Freshness.fresh,
      );
    });
  });

  group('cache decisions', () {
    test('fresh data is used without revalidation', () {
      final decision = decideCacheUsage(
        kind: CacheKind.catalog,
        storedAt: now.subtract(const Duration(hours: 1)),
        isOnline: true,
        now: now,
      );
      expect(decision.useCache, isTrue);
      expect(decision.revalidateInBackground, isFalse);
      expect(decision.staleNotice, isNull);
    });

    test('stale data online is shown immediately and revalidated', () {
      final decision = decideCacheUsage(
        kind: CacheKind.catalog,
        storedAt: now.subtract(const Duration(days: 2)),
        isOnline: true,
        now: now,
      );
      expect(decision.useCache, isTrue);
      expect(decision.revalidateInBackground, isTrue);
      expect(decision.blockOnNetwork, isFalse);
    });

    test('stale data offline is shown with a notice', () {
      final decision = decideCacheUsage(
        kind: CacheKind.catalog,
        storedAt: now.subtract(const Duration(days: 2)),
        isOnline: false,
        now: now,
      );
      expect(decision.useCache, isTrue);
      expect(decision.revalidateInBackground, isFalse);
      expect(decision.staleNotice, contains('2 days ago'));
    });

    test('expired data offline is still shown rather than an empty screen', () {
      final decision = decideCacheUsage(
        kind: CacheKind.catalog,
        storedAt: now.subtract(const Duration(days: 100)),
        isOnline: false,
        now: now,
      );
      expect(decision.useCache, isTrue);
      expect(decision.staleNotice, isNotNull);
    });

    test('expired data online blocks on a refresh', () {
      final decision = decideCacheUsage(
        kind: CacheKind.catalog,
        storedAt: now.subtract(const Duration(days: 100)),
        isOnline: true,
        now: now,
      );
      expect(decision.useCache, isFalse);
      expect(decision.blockOnNetwork, isTrue);
    });

    test('missing data offline explains what to do', () {
      final decision = decideCacheUsage(
        kind: CacheKind.catalog,
        storedAt: null,
        isOnline: false,
        now: now,
      );
      expect(decision.useCache, isFalse);
      expect(decision.staleNotice, contains('Connect to the internet'));
    });

    test('notices read naturally for today and yesterday', () {
      expect(
        decideCacheUsage(
          kind: CacheKind.feed,
          storedAt: now.subtract(const Duration(hours: 2)),
          isOnline: false,
          now: now,
        ).staleNotice,
        contains('today'),
      );
      expect(
        decideCacheUsage(
          kind: CacheKind.feed,
          storedAt: now.subtract(const Duration(days: 1)),
          isOnline: false,
          now: now,
        ).staleNotice,
        contains('yesterday'),
      );
    });
  });
}
