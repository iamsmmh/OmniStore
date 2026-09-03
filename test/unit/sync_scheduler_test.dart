import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnistore/infrastructure/sync/sync_scheduler.dart';

void main() {
  final now = DateTime(2026, 9, 3, 12);
  final scheduler = SyncScheduler(random: Random(1));

  RepositorySyncState state(
    String id, {
    bool enabled = true,
    int installed = 0,
    bool pinned = false,
    Duration? sinceAttempt,
    Duration? sinceSuccess,
    Duration? sinceChange,
    int failures = 0,
  }) {
    return RepositorySyncState(
      repositoryId: id,
      isEnabled: enabled,
      installedAppCount: installed,
      isPinned: pinned,
      lastAttemptAt: sinceAttempt == null ? null : now.subtract(sinceAttempt),
      lastSuccessAt: sinceSuccess == null ? null : now.subtract(sinceSuccess),
      lastChangeAt: sinceChange == null ? null : now.subtract(sinceChange),
      consecutiveFailures: failures,
    );
  }

  group('priority', () {
    test('a disabled repository has zero priority', () {
      expect(scheduler.priorityFor(state('a', enabled: false), now), 0);
    });

    test('a never-synced repository outranks a synced one', () {
      final fresh = scheduler.priorityFor(state('new'), now);
      final synced = scheduler.priorityFor(
          state('old', sinceAttempt: const Duration(hours: 1), sinceSuccess: const Duration(hours: 1)),
          now);
      expect(fresh, greaterThan(synced));
    });

    test('installed apps raise priority', () {
      final withInstalls = scheduler.priorityFor(
          state('a', installed: 10, sinceAttempt: const Duration(hours: 7)),
          now);
      final without = scheduler.priorityFor(
          state('b', sinceAttempt: const Duration(hours: 7)), now);
      expect(withInstalls, greaterThan(without));
    });

    test('pinning raises priority', () {
      expect(
        scheduler.priorityFor(
            state('a', pinned: true, sinceAttempt: const Duration(hours: 7)), now),
        greaterThan(scheduler.priorityFor(
            state('b', sinceAttempt: const Duration(hours: 7)), now)),
      );
    });

    test('repeated failures lower priority', () {
      expect(
        scheduler.priorityFor(
            state('a', failures: 5, sinceAttempt: const Duration(hours: 7)), now),
        lessThan(scheduler.priorityFor(
            state('b', sinceAttempt: const Duration(hours: 7)), now)),
      );
    });

    test('priority is clamped to 0..10', () {
      final value = scheduler.priorityFor(
        state('a', pinned: true, installed: 100, sinceAttempt: const Duration(days: 30)),
        now,
      );
      expect(value, inInclusiveRange(0, 10));
    });
  });

  group('adaptive interval', () {
    test('a quiet repository backs off', () {
      final quiet = scheduler.intervalFor(
          state('a', sinceChange: const Duration(days: 400)), now);
      final normal = scheduler.intervalFor(
          state('b', sinceChange: const Duration(days: 10)), now);
      expect(quiet, greaterThan(normal));
    });

    test('a very active repository refreshes sooner than baseline', () {
      final active = scheduler.intervalFor(
          state('a', sinceChange: const Duration(days: 1)), now);
      expect(active, lessThan(const SyncPolicy().baseInterval));
    });

    test('installed apps tighten the interval', () {
      expect(
        scheduler.intervalFor(state('a', installed: 3), now),
        lessThan(scheduler.intervalFor(state('b'), now)),
      );
    });

    test('interval never violates the configured bounds', () {
      const policy = SyncPolicy();
      final tight = scheduler.intervalFor(
          state('a', pinned: true, installed: 50, sinceChange: const Duration(days: 1)),
          now);
      final loose = scheduler.intervalFor(
          state('b', sinceChange: const Duration(days: 1000)), now);
      expect(tight, greaterThanOrEqualTo(policy.minimumInterval));
      expect(loose, lessThanOrEqualTo(policy.maximumInterval));
    });
  });

  group('backoff', () {
    test('is zero with no failures', () {
      expect(scheduler.backoffFor(0), Duration.zero);
    });

    test('grows with consecutive failures', () {
      expect(scheduler.backoffFor(4).inSeconds,
          greaterThan(scheduler.backoffFor(1).inSeconds));
    });

    test('is capped', () {
      const policy = SyncPolicy();
      expect(
        scheduler.backoffFor(50).inMilliseconds,
        lessThanOrEqualTo(
            (policy.backoffCap.inMilliseconds * (1 + policy.jitterRatio)).round()),
      );
    });
  });

  group('isDue', () {
    test('a never-attempted repository is due', () {
      expect(scheduler.isDue(state('a'), now), isTrue);
    });

    test('a just-synced repository is not due', () {
      expect(
          scheduler.isDue(
              state('a', sinceAttempt: const Duration(minutes: 1)), now),
          isFalse);
    });

    test('an overdue repository is due', () {
      expect(
          scheduler.isDue(state('a', sinceAttempt: const Duration(days: 2)), now),
          isTrue);
    });

    test('a failing repository waits for its backoff window', () {
      final tooSoon = state('a',
          sinceAttempt: const Duration(minutes: 1), failures: 3);
      final elapsed = state('b',
          sinceAttempt: const Duration(hours: 3), failures: 3);
      expect(scheduler.isDue(tooSoon, now), isFalse);
      expect(scheduler.isDue(elapsed, now), isTrue);
    });

    test('a disabled repository is never due', () {
      expect(scheduler.isDue(state('a', enabled: false), now), isFalse);
    });
  });

  group('plan', () {
    test('orders tasks by descending priority', () {
      final tasks = scheduler.plan([
        state('low', sinceAttempt: const Duration(days: 1), sinceSuccess: const Duration(days: 1)),
        state('high', pinned: true, installed: 20, sinceAttempt: const Duration(days: 1), sinceSuccess: const Duration(days: 1)),
      ], now: now);
      expect(tasks.first.repositoryId, 'high');
    });

    test('bounds the number of tasks per round', () {
      final states = List.generate(200, (i) => state('r$i'));
      final tasks = scheduler.plan(states, now: now);
      expect(tasks.length, const SyncPolicy().maxTasksPerRound);
    });

    test('forced repositories are always included at top priority', () {
      final tasks = scheduler.plan(
        [state('a', sinceAttempt: const Duration(minutes: 1))],
        now: now,
        forced: {'a'},
      );
      expect(tasks.single.repositoryId, 'a');
      expect(tasks.single.trigger, SyncTrigger.manual);
    });

    test('skips disabled repositories', () {
      final tasks = scheduler.plan([state('a', enabled: false)], now: now);
      expect(tasks, isEmpty);
    });

    test('labels first syncs and retries', () {
      final tasks = scheduler.plan([
        state('first'),
        state('retry',
            sinceAttempt: const Duration(days: 1),
            sinceSuccess: const Duration(days: 5),
            failures: 2),
      ], now: now);
      final byId = {for (final t in tasks) t.repositoryId: t};
      expect(byId['first']!.trigger, SyncTrigger.firstSync);
      expect(byId['retry']!.trigger, SyncTrigger.backoffRetry);
    });

    test('carries conditional-request validators', () {
      final tasks = scheduler.plan([
        RepositorySyncState(
          repositoryId: 'a',
          etag: 'W/"abc"',
          lastModified: 'Wed, 02 Sep 2026 00:00:00 GMT',
        ),
      ], now: now);
      expect(tasks.single.etag, 'W/"abc"');
      expect(tasks.single.lastModified, isNotNull);
    });

    test('ordering is deterministic for equal priorities', () {
      final states = [state('b'), state('a')];
      final first = scheduler.plan(states, now: now).map((t) => t.repositoryId);
      final second = scheduler.plan(states, now: now).map((t) => t.repositoryId);
      expect(first, second);
    });
  });

  group('applySyncOutcome', () {
    test('a successful update records a change and clears failures', () {
      final next = applySyncOutcome(
        state('a', failures: 3),
        SyncOutcome.updated,
        now: now,
        etag: 'e1',
        contentHash: 'h1',
      );
      expect(next.consecutiveFailures, 0);
      expect(next.lastChangeAt, now);
      expect(next.etag, 'e1');
      expect(next.contentHash, 'h1');
    });

    test('not-modified counts as success but not as a change', () {
      final previous = state('a', sinceChange: const Duration(days: 5));
      final next =
          applySyncOutcome(previous, SyncOutcome.notModified, now: now);
      expect(next.lastSuccessAt, now);
      expect(next.lastChangeAt, previous.lastChangeAt);
      expect(next.consecutiveFailures, 0);
    });

    test('a failure increments the failure counter', () {
      final next =
          applySyncOutcome(state('a', failures: 2), SyncOutcome.failed, now: now);
      expect(next.consecutiveFailures, 3);
      expect(next.lastSuccessAt, isNull);
    });
  });
}
