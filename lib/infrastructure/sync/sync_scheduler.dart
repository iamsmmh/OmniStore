/// Sync Engine v2 scheduling core.
///
/// The v1 engine synced every enabled repository sequentially on a fixed
/// timer, held a single global `_isSyncing` lock, and retried nothing. That
/// design costs O(all repositories) work every cycle and lets one slow or
/// broken source block the whole catalog.
///
/// v2 splits *policy* (this file — pure, deterministic, unit-testable) from
/// *execution* (the engine, which owns HTTP and persistence):
///
///  * priority scoring so repositories the user actually uses refresh first;
///  * adaptive intervals — sources that rarely change back off automatically;
///  * exponential backoff with jitter for failing sources;
///  * conditional-request state (ETag / Last-Modified) for delta sync;
///  * a bounded work plan so a 5,000-repository catalog never tries to sync
///    everything at once.
library;

import 'dart:math' as math;

/// Why a repository was scheduled — surfaced in diagnostics and the UI.
enum SyncTrigger { manual, userVisible, periodic, backoffRetry, firstSync }

/// Persistent per-repository sync state.
class RepositorySyncState {
  final String repositoryId;

  /// User-facing weight: enabled + frequently browsed sources rank higher.
  final bool isEnabled;

  /// Number of installed apps sourced from this repository.
  final int installedAppCount;

  /// Number of apps in this repository.
  final int appCount;

  /// Manual pin from the user ("always keep this fresh").
  final bool isPinned;

  final DateTime? lastAttemptAt;
  final DateTime? lastSuccessAt;

  /// Last time the payload actually differed from what we had stored.
  final DateTime? lastChangeAt;

  final int consecutiveFailures;

  /// HTTP validators enabling delta/incremental sync.
  final String? etag;
  final String? lastModified;

  /// Content hash of the last successfully parsed payload; lets the engine
  /// skip re-parsing and re-writing unchanged catalogs even when the server
  /// does not support conditional requests.
  final String? contentHash;

  const RepositorySyncState({
    required this.repositoryId,
    this.isEnabled = true,
    this.installedAppCount = 0,
    this.appCount = 0,
    this.isPinned = false,
    this.lastAttemptAt,
    this.lastSuccessAt,
    this.lastChangeAt,
    this.consecutiveFailures = 0,
    this.etag,
    this.lastModified,
    this.contentHash,
  });

  RepositorySyncState copyWith({
    bool? isEnabled,
    int? installedAppCount,
    int? appCount,
    bool? isPinned,
    DateTime? lastAttemptAt,
    DateTime? lastSuccessAt,
    DateTime? lastChangeAt,
    int? consecutiveFailures,
    String? etag,
    String? lastModified,
    String? contentHash,
  }) {
    return RepositorySyncState(
      repositoryId: repositoryId,
      isEnabled: isEnabled ?? this.isEnabled,
      installedAppCount: installedAppCount ?? this.installedAppCount,
      appCount: appCount ?? this.appCount,
      isPinned: isPinned ?? this.isPinned,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      lastChangeAt: lastChangeAt ?? this.lastChangeAt,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      etag: etag ?? this.etag,
      lastModified: lastModified ?? this.lastModified,
      contentHash: contentHash ?? this.contentHash,
    );
  }
}

/// One scheduled unit of work.
class SyncTask {
  final String repositoryId;
  final double priority;
  final SyncTrigger trigger;

  /// Validators to send as `If-None-Match` / `If-Modified-Since`.
  final String? etag;
  final String? lastModified;

  const SyncTask({
    required this.repositoryId,
    required this.priority,
    required this.trigger,
    this.etag,
    this.lastModified,
  });
}

/// Tunable scheduling policy.
class SyncPolicy {
  /// Baseline refresh interval for a source that changes at a normal rate.
  final Duration baseInterval;

  /// Never refresh a source more often than this, regardless of priority.
  final Duration minimumInterval;

  /// Upper bound for adaptive back-off of quiet sources.
  final Duration maximumInterval;

  /// Maximum repositories included in a single planning round.
  final int maxTasksPerRound;

  /// Maximum simultaneous repository fetches.
  final int maxConcurrency;

  /// Base delay for exponential backoff after a failure.
  final Duration backoffBase;

  final Duration backoffCap;

  /// Fractional jitter applied to backoff to avoid thundering herds when many
  /// repositories fail at once (e.g. after the device loses connectivity).
  final double jitterRatio;

  const SyncPolicy({
    this.baseInterval = const Duration(hours: 6),
    this.minimumInterval = const Duration(minutes: 15),
    this.maximumInterval = const Duration(days: 7),
    this.maxTasksPerRound = 25,
    this.maxConcurrency = 4,
    this.backoffBase = const Duration(minutes: 5),
    this.backoffCap = const Duration(hours: 12),
    this.jitterRatio = 0.2,
  });

  /// Conservative profile for metered connections or low battery.
  static const SyncPolicy conservative = SyncPolicy(
    baseInterval: Duration(hours: 24),
    maxTasksPerRound: 5,
    maxConcurrency: 2,
  );
}

/// Pure scheduling logic. Deterministic given an injected clock and RNG.
class SyncScheduler {
  final SyncPolicy policy;
  final math.Random _random;

  SyncScheduler({this.policy = const SyncPolicy(), math.Random? random})
      : _random = random ?? math.Random(0);

  /// Priority in roughly `[0, 10]`; higher runs first.
  ///
  /// Weighted so that (a) sources backing installed apps are refreshed first
  /// because they drive update notifications, and (b) overdue sources
  /// gradually outrank fresh ones instead of starving.
  double priorityFor(RepositorySyncState state, DateTime now) {
    if (!state.isEnabled) return 0;

    var priority = 1.0;
    if (state.isPinned) priority += 3.0;

    // Installed apps → update correctness depends on this source.
    priority += math.min(state.installedAppCount, 20) * 0.15;

    // Never-synced repositories are the user's most recent intent.
    if (state.lastSuccessAt == null) priority += 4.0;

    final overdueRatio = _overdueRatio(state, now);
    priority += math.min(overdueRatio, 4.0) * 1.5;

    // Sources that change often are worth checking often.
    final changeRecency = state.lastChangeAt == null
        ? null
        : now.difference(state.lastChangeAt!).inDays;
    if (changeRecency != null) {
      if (changeRecency <= 7) {
        priority += 1.0;
      } else if (changeRecency > 180) {
        priority -= 0.75;
      }
    }

    // Repeated failures are de-prioritised but never permanently excluded.
    priority -= math.min(state.consecutiveFailures, 6) * 0.4;

    return priority.clamp(0.0, 10.0);
  }

  /// The adaptive interval for a repository.
  ///
  /// Quiet sources back off geometrically toward [SyncPolicy.maximumInterval];
  /// sources with installed apps or recent changes tighten toward the minimum.
  Duration intervalFor(RepositorySyncState state, DateTime now) {
    var seconds = policy.baseInterval.inSeconds.toDouble();

    final lastChange = state.lastChangeAt;
    if (lastChange != null) {
      final quietDays = now.difference(lastChange).inDays;
      if (quietDays > 365) {
        seconds *= 8;
      } else if (quietDays > 90) {
        seconds *= 4;
      } else if (quietDays > 30) {
        seconds *= 2;
      } else if (quietDays <= 3) {
        seconds *= 0.5;
      }
    }

    if (state.installedAppCount > 0) seconds *= 0.6;
    if (state.isPinned) seconds *= 0.5;

    return Duration(
      seconds: seconds
          .clamp(
            policy.minimumInterval.inSeconds.toDouble(),
            policy.maximumInterval.inSeconds.toDouble(),
          )
          .round(),
    );
  }

  /// Backoff delay after [failures] consecutive failures, with jitter.
  Duration backoffFor(int failures) {
    if (failures <= 0) return Duration.zero;
    final exponent = math.min(failures - 1, 12);
    final raw = policy.backoffBase.inMilliseconds * math.pow(2, exponent);
    final capped = math.min(raw.toDouble(), policy.backoffCap.inMilliseconds.toDouble());
    final jitter = 1 + (_random.nextDouble() * 2 - 1) * policy.jitterRatio;
    return Duration(milliseconds: (capped * jitter).round().clamp(0, 1 << 31));
  }

  /// Whether [state] is eligible to sync at [now].
  bool isDue(RepositorySyncState state, DateTime now) {
    if (!state.isEnabled) return false;
    if (state.lastAttemptAt == null) return true;

    final sinceAttempt = now.difference(state.lastAttemptAt!);
    if (state.consecutiveFailures > 0) {
      // Deterministic component of backoff, jitter is applied when enqueuing.
      final exponent = math.min(state.consecutiveFailures - 1, 12);
      final backoffMs = math.min(
        policy.backoffBase.inMilliseconds * math.pow(2, exponent).toDouble(),
        policy.backoffCap.inMilliseconds.toDouble(),
      );
      return sinceAttempt.inMilliseconds >= backoffMs;
    }

    if (sinceAttempt < policy.minimumInterval) return false;
    return sinceAttempt >= intervalFor(state, now);
  }

  /// Builds a bounded, priority-ordered work plan.
  ///
  /// This is the entry point the engine calls each cycle; it never returns
  /// more than [SyncPolicy.maxTasksPerRound] tasks, which is what makes the
  /// design safe for thousands of repositories.
  List<SyncTask> plan(
    Iterable<RepositorySyncState> states, {
    required DateTime now,
    Set<String> forced = const {},
    SyncTrigger trigger = SyncTrigger.periodic,
  }) {
    final tasks = <SyncTask>[];
    for (final state in states) {
      final isForced = forced.contains(state.repositoryId);
      if (!isForced && !isDue(state, now)) continue;
      if (!isForced && !state.isEnabled) continue;

      tasks.add(SyncTask(
        repositoryId: state.repositoryId,
        priority: isForced ? 10.0 : priorityFor(state, now),
        trigger: isForced
            ? SyncTrigger.manual
            : state.lastSuccessAt == null
                ? SyncTrigger.firstSync
                : state.consecutiveFailures > 0
                    ? SyncTrigger.backoffRetry
                    : trigger,
        etag: state.etag,
        lastModified: state.lastModified,
      ));
    }

    tasks.sort((a, b) {
      final byPriority = b.priority.compareTo(a.priority);
      if (byPriority != 0) return byPriority;
      return a.repositoryId.compareTo(b.repositoryId); // deterministic
    });

    return tasks.length > policy.maxTasksPerRound
        ? tasks.sublist(0, policy.maxTasksPerRound)
        : tasks;
  }

  double _overdueRatio(RepositorySyncState state, DateTime now) {
    final last = state.lastAttemptAt;
    if (last == null) return 4.0;
    final interval = intervalFor(state, now).inSeconds;
    if (interval <= 0) return 0;
    return now.difference(last).inSeconds / interval;
  }
}

/// Outcome of syncing one repository, fed back into scheduler state.
enum SyncOutcome {
  /// Server returned 304 or the content hash matched — nothing to write.
  notModified,

  /// New or changed content was persisted.
  updated,

  /// Fetch or parse failed.
  failed,
}

/// Applies an outcome to a state, producing the next persisted state.
///
/// Kept as a free function so the reducer can be unit tested without any I/O.
RepositorySyncState applySyncOutcome(
  RepositorySyncState state,
  SyncOutcome outcome, {
  required DateTime now,
  String? etag,
  String? lastModified,
  String? contentHash,
}) {
  switch (outcome) {
    case SyncOutcome.notModified:
      return state.copyWith(
        lastAttemptAt: now,
        lastSuccessAt: now,
        consecutiveFailures: 0,
        etag: etag ?? state.etag,
        lastModified: lastModified ?? state.lastModified,
      );
    case SyncOutcome.updated:
      return state.copyWith(
        lastAttemptAt: now,
        lastSuccessAt: now,
        lastChangeAt: now,
        consecutiveFailures: 0,
        etag: etag,
        lastModified: lastModified,
        contentHash: contentHash,
      );
    case SyncOutcome.failed:
      return state.copyWith(
        lastAttemptAt: now,
        consecutiveFailures: state.consecutiveFailures + 1,
      );
  }
}
