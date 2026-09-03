/// Discovery service: the single façade the presentation layer talks to for
/// search, recommendations, collections and health/trust badges.
///
/// Responsibilities:
///  * own the in-memory [SearchIndex] lifecycle (build once, update on delta);
///  * keep derived insight (health reports) warm so list rows never compute
///    them during scroll;
///  * degrade gracefully offline by operating purely on locally cached data.
///
/// Everything here is synchronous once warmed, which is what makes
/// as-you-type search feel instant on a large catalog.
library;

import 'dart:async';

import '../../core/analytics/analytics.dart';
import '../../core/logger/app_logger.dart';
import '../../domain/discovery/recommendation_engine.dart';
import '../../domain/discovery/search_index.dart';
import '../../domain/health/app_health.dart';

/// Everything the discovery layer needs about one app. Supplied by the data
/// layer so this service stays storage-agnostic (Isar today, IndexedDB or
/// SQLite on other targets).
class CatalogRecord {
  final String id;
  final String name;
  final String developer;
  final String repositoryId;
  final String description;
  final List<String> categories;
  final List<String> tags;
  final List<String> aliases;

  /// All known release timestamps for this app, used for health scoring.
  final List<DateTime> releaseDates;

  const CatalogRecord({
    required this.id,
    required this.name,
    required this.developer,
    required this.repositoryId,
    this.description = '',
    this.categories = const [],
    this.tags = const [],
    this.aliases = const [],
    this.releaseDates = const [],
  });
}

/// Supplies catalog records to the discovery service.
abstract class CatalogSource {
  /// Streams the full catalog in chunks so a large sync never materialises
  /// hundreds of thousands of records at once.
  Stream<List<CatalogRecord>> streamAll({int chunkSize});

  /// Fetches records changed since the last index build.
  Future<List<CatalogRecord>> changedSince(DateTime? since);
}

class DiscoveryService {
  final CatalogSource _source;
  final AnalyticsService _analytics;
  final AppHealthAnalyzer _healthAnalyzer;
  final _logger = AppLogger.getLogger('DiscoveryService');

  final SearchIndex _index = SearchIndex();
  final Map<String, HealthReport> _health = {};

  RecommendationEngine? _recommendations;
  DateTime? _lastIndexedAt;
  bool _isWarming = false;

  final StreamController<void> _indexChanged =
      StreamController<void>.broadcast();

  DiscoveryService({
    required CatalogSource source,
    AnalyticsService? analytics,
    AppHealthAnalyzer healthAnalyzer = const AppHealthAnalyzer(),
  })  : _source = source,
        _analytics = analytics ?? AnalyticsService(),
        _healthAnalyzer = healthAnalyzer;

  /// Emits whenever the index changes so UI can refresh derived lists.
  Stream<void> get indexChanged => _indexChanged.stream;

  bool get isReady => _lastIndexedAt != null;
  int get indexedAppCount => _index.documentCount;
  DateTime? get lastIndexedAt => _lastIndexedAt;

  /// Builds the index from scratch. Safe to call repeatedly; concurrent calls
  /// are coalesced so a sync completing during startup does not double-work.
  Future<void> warmUp({int chunkSize = 500, DateTime? now}) async {
    if (_isWarming) return;
    _isWarming = true;
    final started = DateTime.now();
    try {
      final documents = <SearchDocument>[];
      await for (final chunk in _source.streamAll(chunkSize: chunkSize)) {
        for (final record in chunk) {
          documents.add(_toDocument(record));
          _health[record.id] = _healthAnalyzer.analyze(
            appId: record.id,
            releaseDates: record.releaseDates,
            now: now,
          );
        }
        // Yield to the event loop between chunks so indexing a huge catalog
        // never blocks a frame.
        await Future<void>.delayed(Duration.zero);
      }
      _index.rebuild(documents);
      _recommendations =
          RecommendationEngine(index: _index, health: Map.of(_health));
      _lastIndexedAt = DateTime.now();
      _logger.info(
        'Indexed ${documents.length} apps in '
        '${_lastIndexedAt!.difference(started).inMilliseconds}ms',
      );
      _indexChanged.add(null);
    } catch (e, stack) {
      _logger.severe('Index warm-up failed', e, stack);
    } finally {
      _isWarming = false;
    }
  }

  /// Applies an incremental update after a delta sync — O(changed records)
  /// rather than a full rebuild.
  Future<void> applyDelta({DateTime? now}) async {
    try {
      final changed = await _source.changedSince(_lastIndexedAt);
      if (changed.isEmpty) return;
      for (final record in changed) {
        _index.upsert(_toDocument(record));
        _health[record.id] = _healthAnalyzer.analyze(
          appId: record.id,
          releaseDates: record.releaseDates,
          now: now,
        );
      }
      // Stale postings accumulate on replace; compact when they could matter.
      if (changed.length > _index.documentCount ~/ 4) _index.compact();
      _recommendations =
          RecommendationEngine(index: _index, health: Map.of(_health));
      _lastIndexedAt = DateTime.now();
      _logger.info('Applied delta for ${changed.length} apps');
      _indexChanged.add(null);
    } catch (e, stack) {
      _logger.severe('Delta index update failed', e, stack);
    }
  }

  SearchDocument _toDocument(CatalogRecord record) {
    final popularity = _analytics.isEnabled ? _popularity[record.id] : null;
    final releases = record.releaseDates.toList()..sort();
    return SearchDocument(
      id: record.id,
      name: record.name,
      developer: record.developer,
      repositoryId: record.repositoryId,
      description: record.description,
      categories: record.categories,
      tags: record.tags,
      aliases: record.aliases,
      popularity: popularity,
      lastReleaseAt: releases.isEmpty ? null : releases.last,
    );
  }

  Map<String, double> _popularity = const {};

  /// Feeds opt-in popularity signals into ranking. No-op when analytics are
  /// disabled, so ranking stays deterministic for privacy-conscious users.
  void updatePopularity(Map<String, double> popularity) {
    if (!_analytics.isEnabled) return;
    _popularity = popularity;
  }

  // ── Query API ───────────────────────────────────────────────

  List<SearchHit> search(
    String query, {
    int limit = 25,
    SearchFilter filter = const SearchFilter(),
    DateTime? now,
  }) {
    final hits = _index.search(query, limit: limit, filter: filter, now: now);
    unawaited(_analytics.track(
      hits.isEmpty
          ? AnalyticsEvent.searchNoResults
          : AnalyticsEvent.searchPerformed,
      dimensions: {'term': query},
      value: hits.length,
    ));
    return hits;
  }

  List<String> suggest(String prefix, {int limit = 8}) =>
      _index.suggest(prefix, limit: limit);

  String? spellingCorrection(String query) => _index.correct(query);

  HealthReport? healthFor(String appId) => _health[appId];

  Map<String, HealthReport> get healthReports => Map.unmodifiable(_health);

  List<Recommendation> similarTo(String appId, {int limit = 12}) =>
      _recommendations?.similarTo(appId, limit: limit) ?? const [];

  List<Recommendation> recommendationsFor(UserSignals signals,
          {int limit = 20}) =>
      _recommendations?.forUser(signals, limit: limit) ?? const [];

  List<SearchDocument> trending({int limit = 20, DateTime? now}) =>
      _recommendations?.trending(limit: limit, now: now) ?? const [];

  List<SearchDocument> newReleases({int limit = 20, DateTime? now}) =>
      _recommendations?.newReleases(limit: limit, now: now) ?? const [];

  List<SearchDocument> hiddenGems({int limit = 15, DateTime? now}) =>
      _recommendations?.hiddenGems(limit: limit, now: now) ?? const [];

  List<DynamicCollection> collections({DateTime? now, int perCollection = 12}) =>
      _recommendations?.buildCollections(now: now, perCollection: perCollection) ??
      const [];

  void dispose() {
    _indexChanged.close();
  }
}
