/// Offline-first cache policy.
///
/// OmniStore's value proposition — browsing a catalog of independently
/// distributed software — should not disappear when the network does. This
/// module defines *when cached data is good enough*, so UI code never has to
/// choose between "show stale data" and "show a spinner": it asks the policy
/// and always gets an answer plus a freshness label.
library;

/// How fresh a piece of cached data is.
enum Freshness {
  /// Within its TTL; use directly, no revalidation needed.
  fresh,

  /// Past TTL but usable; show it immediately and revalidate in background.
  stale,

  /// Too old to present without a caveat, but better than nothing offline.
  expired,

  /// Nothing cached.
  missing,
}

/// Categories of cached content, each with its own tolerance for staleness.
enum CacheKind {
  /// Repository catalog: app lists and metadata.
  catalog,

  /// Rendered changelog / release notes.
  changelog,

  /// Discovery feeds from OmniSource.
  feed,

  /// Screenshots and icons.
  media,

  /// Computed health / trust reports.
  derivedInsight,
}

/// Time-to-live and hard-expiry per [CacheKind].
class CachePolicy {
  final Map<CacheKind, Duration> ttl;
  final Map<CacheKind, Duration> hardExpiry;

  const CachePolicy({required this.ttl, required this.hardExpiry});

  static const CachePolicy standard = CachePolicy(
    ttl: {
      CacheKind.catalog: Duration(hours: 6),
      CacheKind.changelog: Duration(days: 30),
      CacheKind.feed: Duration(minutes: 30),
      CacheKind.media: Duration(days: 14),
      CacheKind.derivedInsight: Duration(hours: 12),
    },
    hardExpiry: {
      // Catalogs stay usable offline for a long time: a month-old app list is
      // still far more useful than an empty screen.
      CacheKind.catalog: Duration(days: 60),
      CacheKind.changelog: Duration(days: 365),
      CacheKind.feed: Duration(days: 7),
      CacheKind.media: Duration(days: 90),
      CacheKind.derivedInsight: Duration(days: 30),
    },
  );

  /// Metered/low-data profile: tolerate staleness far longer before spending
  /// the user's bandwidth.
  static const CachePolicy dataSaver = CachePolicy(
    ttl: {
      CacheKind.catalog: Duration(days: 2),
      CacheKind.changelog: Duration(days: 90),
      CacheKind.feed: Duration(hours: 12),
      CacheKind.media: Duration(days: 60),
      CacheKind.derivedInsight: Duration(days: 3),
    },
    hardExpiry: {
      CacheKind.catalog: Duration(days: 120),
      CacheKind.changelog: Duration(days: 365),
      CacheKind.feed: Duration(days: 30),
      CacheKind.media: Duration(days: 180),
      CacheKind.derivedInsight: Duration(days: 60),
    },
  );

  Freshness evaluate({
    required CacheKind kind,
    required DateTime? storedAt,
    DateTime? now,
  }) {
    if (storedAt == null) return Freshness.missing;
    final reference = now ?? DateTime.now();
    final age = reference.difference(storedAt);
    if (age.isNegative) return Freshness.fresh; // clock skew: trust the cache
    if (age <= (ttl[kind] ?? const Duration(hours: 1))) return Freshness.fresh;
    if (age <= (hardExpiry[kind] ?? const Duration(days: 30))) {
      return Freshness.stale;
    }
    return Freshness.expired;
  }
}

/// The decision returned to a repository/UI layer.
class CacheDecision {
  final bool useCache;
  final bool revalidateInBackground;
  final bool blockOnNetwork;
  final Freshness freshness;

  /// Message for the offline banner, or `null` when data is fresh.
  final String? staleNotice;

  const CacheDecision({
    required this.useCache,
    required this.revalidateInBackground,
    required this.blockOnNetwork,
    required this.freshness,
    this.staleNotice,
  });
}

/// Resolves what to do given cache state and connectivity.
///
/// Rule of thumb encoded here: **never show an empty screen when any cached
/// data exists.** Offline users get the data plus an honest freshness label.
CacheDecision decideCacheUsage({
  required CacheKind kind,
  required DateTime? storedAt,
  required bool isOnline,
  CachePolicy policy = CachePolicy.standard,
  DateTime? now,
}) {
  final freshness = policy.evaluate(kind: kind, storedAt: storedAt, now: now);
  final reference = now ?? DateTime.now();
  final ageDays =
      storedAt == null ? null : reference.difference(storedAt).inDays;

  switch (freshness) {
    case Freshness.fresh:
      return const CacheDecision(
        useCache: true,
        revalidateInBackground: false,
        blockOnNetwork: false,
        freshness: Freshness.fresh,
      );
    case Freshness.stale:
      return CacheDecision(
        useCache: true,
        revalidateInBackground: isOnline,
        blockOnNetwork: false,
        freshness: Freshness.stale,
        staleNotice: isOnline ? null : _offlineNotice(ageDays),
      );
    case Freshness.expired:
      return CacheDecision(
        // Offline: still show it. Online: refresh before rendering.
        useCache: !isOnline,
        revalidateInBackground: false,
        blockOnNetwork: isOnline,
        freshness: Freshness.expired,
        staleNotice: _offlineNotice(ageDays),
      );
    case Freshness.missing:
      return CacheDecision(
        useCache: false,
        revalidateInBackground: false,
        blockOnNetwork: isOnline,
        freshness: Freshness.missing,
        staleNotice: isOnline
            ? null
            : 'No cached data available. Connect to the internet to sync.',
      );
  }
}

String _offlineNotice(int? ageDays) {
  if (ageDays == null) return 'Showing cached data.';
  if (ageDays <= 0) return 'Showing cached data from today.';
  if (ageDays == 1) return 'Showing cached data from yesterday.';
  return 'Showing cached data from $ageDays days ago.';
}
