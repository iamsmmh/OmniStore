/// Recommendations and dynamically generated collections.
///
/// Everything here is computed on-device from the synced catalog plus optional
/// local signals. No user profile leaves the device and no server-side
/// recommender is required, which keeps the feature available offline and
/// privacy-preserving by construction.
library;

import 'dart:math' as math;

import '../../core/search/text_matching.dart';
import '../health/app_health.dart';
import 'search_index.dart';

/// Local, non-identifying interaction signals used to personalise ordering.
class UserSignals {
  final Set<String> installedAppIds;
  final Set<String> favoriteAppIds;

  /// App ids the user opened details for, most recent last.
  final List<String> recentlyViewedAppIds;

  const UserSignals({
    this.installedAppIds = const {},
    this.favoriteAppIds = const {},
    this.recentlyViewedAppIds = const [],
  });

  static const UserSignals empty = UserSignals();
}

/// A recommended app with an explanation ("because you installed X").
class Recommendation {
  final SearchDocument document;
  final double score;
  final String reason;

  const Recommendation({
    required this.document,
    required this.score,
    required this.reason,
  });
}

/// A dynamically generated collection.
class DynamicCollection {
  final String id;
  final String title;
  final String subtitle;
  final List<SearchDocument> apps;

  /// Why these apps qualify — shown in the UI so curation is transparent.
  final String rationale;

  const DynamicCollection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.apps,
    required this.rationale,
  });

  bool get isEmpty => apps.isEmpty;
}

/// Computes similarity, recommendations and collections over the catalog.
class RecommendationEngine {
  final SearchIndex _index;
  final Map<String, HealthReport> _health;

  RecommendationEngine({
    required SearchIndex index,
    Map<String, HealthReport> health = const {},
  })  : _index = index,
        _health = health;

  /// Apps similar to [appId], using tag/category/developer overlap plus
  /// lexical similarity of names and descriptions.
  List<Recommendation> similarTo(String appId, {int limit = 12}) {
    final documents = _index.documents;
    final source = documents.firstWhere(
      (d) => d.id == appId,
      orElse: () => const SearchDocument(
        id: '',
        name: '',
        developer: '',
        repositoryId: '',
      ),
    );
    if (source.id.isEmpty) return const [];

    final sourceTags = _normalizedSet(source.tags);
    final sourceCategories = _normalizedSet(source.categories);
    final sourceTerms = _descriptionTerms(source);

    final results = <Recommendation>[];
    for (final candidate in documents) {
      if (candidate.id == source.id) continue;

      final tagOverlap =
          _jaccard(sourceTags, _normalizedSet(candidate.tags));
      final categoryOverlap =
          _jaccard(sourceCategories, _normalizedSet(candidate.categories));
      final sameDeveloper =
          normalizeForSearch(candidate.developer) ==
                  normalizeForSearch(source.developer) &&
              source.developer.trim().isNotEmpty;
      final termOverlap =
          _jaccard(sourceTerms, _descriptionTerms(candidate));

      var score = tagOverlap * 3.0 +
          categoryOverlap * 2.0 +
          termOverlap * 1.5 +
          (sameDeveloper ? 1.2 : 0);
      if (score <= 0.05) continue;

      score *= _healthMultiplier(candidate.id);
      score *= 1 + 0.2 * (candidate.popularity ?? 0);

      results.add(Recommendation(
        document: candidate,
        score: score,
        reason: sameDeveloper && tagOverlap == 0
            ? 'Also from ${candidate.developer}'
            : categoryOverlap > 0 || tagOverlap > 0
                ? 'Similar to ${source.name}'
                : 'Related to ${source.name}',
      ));
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(limit).toList();
  }

  /// Personalised recommendations derived from local signals only.
  List<Recommendation> forUser(
    UserSignals signals, {
    int limit = 20,
  }) {
    if (signals.installedAppIds.isEmpty &&
        signals.favoriteAppIds.isEmpty &&
        signals.recentlyViewedAppIds.isEmpty) {
      // Cold start: fall back to well-maintained, popular apps.
      final coldStart = _index.documents
          .map((d) => Recommendation(
                document: d,
                score: (d.popularity ?? 0) * _healthMultiplier(d.id),
                reason: 'Popular and well maintained',
              ))
          .where((r) => r.score > 0)
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score));
      return coldStart.take(limit).toList();
    }

    final seeds = <String, double>{};
    for (final id in signals.favoriteAppIds) {
      seeds[id] = 1.0;
    }
    for (final id in signals.installedAppIds) {
      seeds[id] = math.max(seeds[id] ?? 0, 0.8);
    }
    final recent = signals.recentlyViewedAppIds;
    for (var i = 0; i < recent.length; i++) {
      // More recent views weigh more.
      final weight = 0.3 + 0.4 * ((i + 1) / recent.length);
      seeds[recent[i]] = math.max(seeds[recent[i]] ?? 0, weight);
    }

    final aggregate = <String, double>{};
    final reasons = <String, String>{};
    seeds.forEach((seedId, seedWeight) {
      for (final rec in similarTo(seedId, limit: 15)) {
        final id = rec.document.id;
        if (signals.installedAppIds.contains(id)) continue;
        final contribution = rec.score * seedWeight;
        if (contribution > (aggregate[id] ?? 0)) {
          reasons[id] = rec.reason;
        }
        aggregate[id] = (aggregate[id] ?? 0) + contribution;
      }
    });

    final byId = {for (final d in _index.documents) d.id: d};
    final results = aggregate.entries
        .where((e) => byId.containsKey(e.key))
        .map((e) => Recommendation(
              document: byId[e.key]!,
              score: e.value,
              reason: reasons[e.key] ?? 'Recommended for you',
            ))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return results.take(limit).toList();
  }

  /// Trending: recent release activity weighted by popularity.
  ///
  /// Uses a Hacker-News-style time decay so a burst of activity fades rather
  /// than pinning the same apps at the top indefinitely.
  List<SearchDocument> trending({int limit = 20, DateTime? now}) {
    final reference = now ?? DateTime.now();
    final scored = <MapEntry<SearchDocument, double>>[];
    for (final document in _index.documents) {
      final released = document.lastReleaseAt;
      if (released == null) continue;
      final ageHours =
          math.max(reference.difference(released).inHours, 1).toDouble();
      if (ageHours > 24 * 120) continue;
      final gravity = math.pow(ageHours + 2, 1.5).toDouble();
      final base = 1 + 4 * (document.popularity ?? 0);
      scored.add(MapEntry(document, (base / gravity) * _healthMultiplier(document.id)));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(limit).map((e) => e.key).toList();
  }

  /// Recently published apps, newest first.
  List<SearchDocument> newReleases({int limit = 20, DateTime? now}) {
    final reference = now ?? DateTime.now();
    final recent = _index.documents
        .where((d) =>
            d.lastReleaseAt != null &&
            !d.lastReleaseAt!.isAfter(reference) &&
            reference.difference(d.lastReleaseAt!).inDays <= 45)
        .toList()
      ..sort((a, b) => b.lastReleaseAt!.compareTo(a.lastReleaseAt!));
    return recent.take(limit).toList();
  }

  /// Hidden gems: healthy, actively maintained apps with low popularity.
  ///
  /// Counteracts the rich-get-richer bias of popularity-only ranking, which is
  /// especially damaging in independent software ecosystems.
  List<SearchDocument> hiddenGems({int limit = 15, DateTime? now}) {
    final scored = <MapEntry<SearchDocument, double>>[];
    for (final document in _index.documents) {
      final health = _health[document.id];
      if (health == null) continue;
      if (health.status != HealthStatus.healthy &&
          health.status != HealthStatus.active) {
        continue;
      }
      final popularity = document.popularity ?? 0;
      if (popularity > 0.35) continue;
      // High quality, low reach.
      scored.add(MapEntry(document, health.score * (1 - popularity)));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(limit).map((e) => e.key).toList();
  }

  /// Builds the standard dynamic collections shown on Discover.
  ///
  /// Collections are *derived*, never hand-maintained lists, so they stay
  /// correct as repositories are added or removed.
  List<DynamicCollection> buildCollections({DateTime? now, int perCollection = 12}) {
    final reference = now ?? DateTime.now();
    final collections = <DynamicCollection>[];

    void add(
      String id,
      String title,
      String subtitle,
      String rationale,
      List<SearchDocument> apps,
    ) {
      if (apps.isEmpty) return;
      collections.add(DynamicCollection(
        id: id,
        title: title,
        subtitle: subtitle,
        apps: apps.take(perCollection).toList(),
        rationale: rationale,
      ));
    }

    add(
      'editor_picks',
      'Editor Picks',
      'High-quality, well-maintained apps',
      'Apps with a health score of 70+ that publish checksums and complete '
          'metadata, ranked by health then popularity.',
      _byHealth(minimumScore: 70),
    );

    add(
      'open_source_essentials',
      'Open Source Essentials',
      'Free software worth having',
      'Apps tagged as open source or carrying a recognised licence tag.',
      _byTagAny(const [
        'opensource',
        'open source',
        'foss',
        'libre',
        'gpl',
        'mit',
        'apache',
      ]),
    );

    add(
      'music',
      'Music Apps',
      'Players, editors and streaming clients',
      'Apps in the music or audio categories.',
      _byCategoryAny(const ['music', 'audio', 'podcast', 'radio']),
    );

    add(
      'productivity',
      'Productivity Apps',
      'Get more done',
      'Apps in the productivity, notes or task categories.',
      _byCategoryAny(
          const ['productivity', 'notes', 'tasks', 'office', 'utilities']),
    );

    add(
      'developer_tools',
      'Developer Tools',
      'Editors, terminals and toolchains',
      'Apps in developer categories or tagged with developer tooling terms.',
      _byCategoryAny(const ['developer', 'development', 'programming', 'tools'],
          extraTags: const ['terminal', 'ide', 'editor', 'git', 'ssh', 'cli']),
    );

    add(
      'new_and_noteworthy',
      'New & Noteworthy',
      'Fresh from the repositories',
      'Apps released in the last 45 days.',
      newReleases(limit: perCollection, now: reference),
    );

    add(
      'hidden_gems',
      'Hidden Gems',
      'Great apps you have probably missed',
      'Well-maintained apps with low install counts.',
      hiddenGems(limit: perCollection, now: reference),
    );

    return collections;
  }

  List<SearchDocument> _byHealth({required int minimumScore}) {
    final results = _index.documents
        .where((d) => (_health[d.id]?.score ?? 0) >= minimumScore)
        .toList()
      ..sort((a, b) {
        final byHealth =
            (_health[b.id]?.score ?? 0).compareTo(_health[a.id]?.score ?? 0);
        if (byHealth != 0) return byHealth;
        return (b.popularity ?? 0).compareTo(a.popularity ?? 0);
      });
    return results;
  }

  List<SearchDocument> _byTagAny(List<String> tags) {
    final wanted = _normalizedSet(tags);
    return _index.documents
        .where((d) => _normalizedSet([...d.tags, ...d.categories])
            .any(wanted.contains))
        .toList()
      ..sort(_byQuality);
  }

  List<SearchDocument> _byCategoryAny(
    List<String> categories, {
    List<String> extraTags = const [],
  }) {
    final wantedCategories = _normalizedSet(categories);
    final wantedTags = _normalizedSet(extraTags);
    return _index.documents.where((d) {
      final docCategories = _normalizedSet(d.categories);
      if (docCategories.any(wantedCategories.contains)) return true;
      if (wantedTags.isEmpty) return false;
      return _normalizedSet(d.tags).any(wantedTags.contains);
    }).toList()
      ..sort(_byQuality);
  }

  int _byQuality(SearchDocument a, SearchDocument b) {
    final healthA = _health[a.id]?.score ?? 0;
    final healthB = _health[b.id]?.score ?? 0;
    final scoreA = healthA + (a.popularity ?? 0) * 40;
    final scoreB = healthB + (b.popularity ?? 0) * 40;
    final byScore = scoreB.compareTo(scoreA);
    if (byScore != 0) return byScore;
    return a.name.compareTo(b.name);
  }

  double _healthMultiplier(String appId) {
    final report = _health[appId];
    if (report == null) return 1.0;
    return switch (report.status) {
      HealthStatus.healthy => 1.15,
      HealthStatus.active => 1.05,
      HealthStatus.unknown => 1.0,
      HealthStatus.maintenance => 0.9,
      HealthStatus.potentiallyAbandoned => 0.65,
    };
  }

  static Set<String> _normalizedSet(Iterable<String> values) =>
      values.map(normalizeForSearch).where((v) => v.isNotEmpty).toSet();

  static final Set<String> _stopWords = {
    'the', 'and', 'for', 'with', 'this', 'that', 'you', 'your', 'app',
    'application', 'from', 'are', 'can', 'all', 'has', 'have', 'not', 'but',
    'its', 'it', 'a', 'an', 'of', 'to', 'in', 'on', 'is', 'as', 'by', 'or',
  };

  static Set<String> _descriptionTerms(SearchDocument document) {
    return tokenize(document.description)
        .where((t) => t.length > 2 && !_stopWords.contains(t))
        .take(60)
        .toSet();
  }

  static double _jaccard(Set<String> a, Set<String> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final intersection = a.intersection(b).length;
    if (intersection == 0) return 0;
    return intersection / a.union(b).length;
  }
}
