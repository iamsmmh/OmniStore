/// In-memory inverted index powering OmniStore's smart search.
///
/// Design goals:
///  * O(matching postings) query cost instead of O(catalog) scans, so search
///    stays responsive with hundreds of thousands of indexed releases.
///  * Field-weighted ranking (name > alias > developer > tag > description).
///  * Typo tolerance and alias matching without a server round-trip.
///  * Zero Flutter/plugin dependencies so the same engine runs on mobile,
///    desktop and web builds.
library;

import 'dart:math' as math;

import '../../core/search/text_matching.dart';

/// A single searchable record. Kept deliberately narrow so the index can hold
/// a large catalog in memory (~200 bytes/app of retained strings).
class SearchDocument {
  final String id;
  final String name;
  final String developer;
  final String repositoryId;
  final List<String> categories;
  final List<String> tags;

  /// Alternative names users may type ("vlc", "code" for "Visual Studio Code").
  final List<String> aliases;

  final String description;

  /// Optional popularity signal in `[0, 1]`, sourced from opt-in analytics or
  /// OmniSource feeds. Missing data must not penalise an app, so `null`
  /// behaves as a neutral 0.
  final double? popularity;

  /// When the app last shipped a release; drives freshness boosting.
  final DateTime? lastReleaseAt;

  const SearchDocument({
    required this.id,
    required this.name,
    required this.developer,
    required this.repositoryId,
    this.categories = const [],
    this.tags = const [],
    this.aliases = const [],
    this.description = '',
    this.popularity,
    this.lastReleaseAt,
  });
}

/// Which field produced a match, used for ranking and UI highlighting.
enum MatchField { name, alias, developer, tag, category, description }

/// A ranked search result.
class SearchHit {
  final SearchDocument document;
  final double score;
  final Set<MatchField> matchedFields;

  /// `true` when the query only matched after typo correction — the UI shows
  /// a "showing results for…" affordance in this case.
  final bool isFuzzy;

  const SearchHit({
    required this.document,
    required this.score,
    required this.matchedFields,
    required this.isFuzzy,
  });
}

/// Optional constraints applied before ranking.
class SearchFilter {
  final String? repositoryId;
  final String? category;
  final String? developer;
  final String? tag;

  const SearchFilter({
    this.repositoryId,
    this.category,
    this.developer,
    this.tag,
  });

  bool get isEmpty =>
      repositoryId == null &&
      category == null &&
      developer == null &&
      tag == null;

  bool allows(SearchDocument doc) {
    if (repositoryId != null && doc.repositoryId != repositoryId) return false;
    if (category != null &&
        !doc.categories.any(
            (c) => normalizeForSearch(c) == normalizeForSearch(category!))) {
      return false;
    }
    if (developer != null &&
        normalizeForSearch(doc.developer) != normalizeForSearch(developer!)) {
      return false;
    }
    if (tag != null &&
        !doc.tags
            .any((t) => normalizeForSearch(t) == normalizeForSearch(tag!))) {
      return false;
    }
    return true;
  }
}

class _Posting {
  final int docIndex;
  final MatchField field;
  const _Posting(this.docIndex, this.field);
}

/// Field weights, tuned so an exact developer match never outranks an exact
/// app-name match, but a tag match still beats a description-only match.
const Map<MatchField, double> _fieldWeights = {
  MatchField.name: 1.0,
  MatchField.alias: 0.9,
  MatchField.developer: 0.62,
  MatchField.tag: 0.5,
  MatchField.category: 0.42,
  MatchField.description: 0.25,
};

/// A rebuildable inverted index over [SearchDocument]s.
class SearchIndex {
  final List<SearchDocument> _documents = [];
  final Map<String, List<_Posting>> _postings = {};

  /// Distinct token vocabulary, used for typo correction and suggestions.
  final Map<String, int> _tokenFrequency = {};

  int get documentCount => _documents.length;
  int get tokenCount => _postings.length;

  /// Replaces the entire index contents. Cheap enough (linear) to run after a
  /// sync; incremental callers should prefer [upsert].
  void rebuild(Iterable<SearchDocument> documents) {
    _documents.clear();
    _postings.clear();
    _tokenFrequency.clear();
    for (final document in documents) {
      _addDocument(document);
    }
  }

  /// Adds or replaces a single document.
  ///
  /// Replacement leaves stale postings behind but they are filtered at query
  /// time by identity check, keeping incremental sync O(1) per app. Call
  /// [compact] after large delta batches to reclaim memory.
  void upsert(SearchDocument document) {
    final existing = _documents.indexWhere((d) => d.id == document.id);
    if (existing >= 0) {
      _documents[existing] = document;
      _indexFields(document, existing);
    } else {
      _addDocument(document);
    }
  }

  void remove(String id) {
    final index = _documents.indexWhere((d) => d.id == id);
    if (index < 0) return;
    _documents.removeAt(index);
    compact();
  }

  /// Rebuilds postings from the retained documents, dropping stale entries.
  void compact() => rebuild(List<SearchDocument>.from(_documents));

  void _addDocument(SearchDocument document) {
    _documents.add(document);
    _indexFields(document, _documents.length - 1);
  }

  void _indexFields(SearchDocument document, int docIndex) {
    void index(String text, MatchField field) {
      for (final token in tokenize(text)) {
        (_postings[token] ??= <_Posting>[]).add(_Posting(docIndex, field));
        _tokenFrequency[token] = (_tokenFrequency[token] ?? 0) + 1;
      }
    }

    index(document.name, MatchField.name);
    for (final alias in document.aliases) {
      index(alias, MatchField.alias);
    }
    index(document.developer, MatchField.developer);
    for (final tag in document.tags) {
      index(tag, MatchField.tag);
    }
    for (final category in document.categories) {
      index(category, MatchField.category);
    }
    // Descriptions are truncated: the tail of a long README adds noise and
    // memory without improving precision.
    index(
      document.description.length > 400
          ? document.description.substring(0, 400)
          : document.description,
      MatchField.description,
    );
  }

  /// Executes a ranked query.
  ///
  /// [now] is injectable to keep freshness scoring deterministic in tests.
  List<SearchHit> search(
    String query, {
    int limit = 25,
    SearchFilter filter = const SearchFilter(),
    bool fuzzy = true,
    DateTime? now,
  }) {
    final queryTokens = tokenize(query);
    if (queryTokens.isEmpty) {
      // An empty query with filters is a valid "browse" request.
      if (filter.isEmpty) return const [];
      final browse = _documents.where(filter.allows).toList()
        ..sort((a, b) => (b.popularity ?? 0).compareTo(a.popularity ?? 0));
      return browse
          .take(limit)
          .map((d) => SearchHit(
                document: d,
                score: 0,
                matchedFields: const {},
                isFuzzy: false,
              ))
          .toList();
    }

    final scores = <int, double>{};
    final fields = <int, Set<MatchField>>{};
    final fuzzyOnly = <int>{};
    final matchedTokenCount = <int, int>{};

    for (final token in queryTokens) {
      final exact = _postings[token];
      if (exact != null) {
        _accumulate(exact, token, token, scores, fields, matchedTokenCount,
            isFuzzy: false, fuzzyOnly: fuzzyOnly);
      }

      // Prefix expansion powers as-you-type search ("phot" -> "photos").
      if (token.length >= 2) {
        for (final entry in _postings.entries) {
          if (entry.key == token || !entry.key.startsWith(token)) continue;
          _accumulate(entry.value, token, entry.key, scores, fields,
              matchedTokenCount,
              isFuzzy: false, fuzzyOnly: fuzzyOnly, penalty: 0.85);
        }
      }

      if (!fuzzy || token.length < 3) continue;
      final maxDistance = token.length <= 5 ? 1 : 2;
      for (final entry in _postings.entries) {
        if (entry.key == token || entry.key.startsWith(token)) continue;
        final distance =
            boundedEditDistance(token, entry.key, maxDistance: maxDistance);
        if (distance > maxDistance) continue;
        _accumulate(entry.value, token, entry.key, scores, fields,
            matchedTokenCount,
            isFuzzy: true,
            fuzzyOnly: fuzzyOnly,
            penalty: 0.55 - 0.1 * distance);
      }
    }

    final reference = now ?? DateTime.now();
    final hits = <SearchHit>[];
    scores.forEach((docIndex, rawScore) {
      if (docIndex >= _documents.length) return; // stale posting
      final document = _documents[docIndex];
      if (!filter.allows(document)) return;

      // Reward documents matching more of the query — "dark reader" should
      // rank a two-token match above either single-token match.
      final coverage = (matchedTokenCount[docIndex] ?? 1) / queryTokens.length;
      var score = rawScore * (0.55 + 0.45 * coverage);

      // Whole-phrase similarity against the display name is a strong signal
      // that token-level scoring alone under-weights.
      score += similarityScore(query, document.name) * 0.55;

      score *= 1 + 0.25 * (document.popularity ?? 0);
      score *= _freshnessMultiplier(document.lastReleaseAt, reference);

      hits.add(SearchHit(
        document: document,
        score: score,
        matchedFields: fields[docIndex] ?? const {},
        isFuzzy: fuzzyOnly.contains(docIndex),
      ));
    });

    hits.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.document.name.compareTo(b.document.name); // stable ordering
    });
    return hits.length > limit ? hits.sublist(0, limit) : hits;
  }

  void _accumulate(
    List<_Posting> postings,
    String queryToken,
    String indexToken,
    Map<int, double> scores,
    Map<int, Set<MatchField>> fields,
    Map<int, int> matchedTokenCount, {
    required bool isFuzzy,
    required Set<int> fuzzyOnly,
    double penalty = 1.0,
  }) {
    // Rare tokens are more discriminative than ubiquitous ones ("free", "app").
    final frequency = _tokenFrequency[indexToken] ?? 1;
    final idf = math.log((_documents.length + 1) / frequency) + 1;
    final lengthRatio = queryToken.length / math.max(indexToken.length, 1);

    final counted = <int>{};
    for (final posting in postings) {
      final weight = _fieldWeights[posting.field] ?? 0.2;
      final contribution = weight * idf * penalty * (0.6 + 0.4 * lengthRatio);
      scores[posting.docIndex] =
          (scores[posting.docIndex] ?? 0) + contribution;
      (fields[posting.docIndex] ??= <MatchField>{}).add(posting.field);
      if (counted.add(posting.docIndex)) {
        matchedTokenCount[posting.docIndex] =
            (matchedTokenCount[posting.docIndex] ?? 0) + 1;
      }
      if (isFuzzy) {
        fuzzyOnly.add(posting.docIndex);
      } else {
        fuzzyOnly.remove(posting.docIndex);
      }
    }
  }

  double _freshnessMultiplier(DateTime? lastRelease, DateTime now) {
    if (lastRelease == null) return 1.0;
    final days = now.difference(lastRelease).inDays;
    if (days <= 30) return 1.12;
    if (days <= 180) return 1.05;
    if (days <= 365) return 1.0;
    if (days <= 730) return 0.95;
    return 0.9; // stale, but never excluded
  }

  /// Autocomplete suggestions drawn from the indexed vocabulary and app names.
  List<String> suggest(String prefix, {int limit = 8}) {
    final normalized = normalizeForSearch(prefix);
    if (normalized.isEmpty) return const [];

    final names = <String>[];
    for (final document in _documents) {
      final candidate = normalizeForSearch(document.name);
      if (candidate.startsWith(normalized)) names.add(document.name);
      if (names.length >= limit) break;
    }
    if (names.length >= limit) return names;

    final tokens = _postings.keys
        .where((t) => t.startsWith(normalized) && t != normalized)
        .toList()
      ..sort((a, b) =>
          (_tokenFrequency[b] ?? 0).compareTo(_tokenFrequency[a] ?? 0));

    for (final token in tokens) {
      if (names.length >= limit) break;
      if (!names.any((n) => normalizeForSearch(n) == token)) names.add(token);
    }
    return names;
  }

  /// Best-effort spelling correction for a whole query ("did you mean").
  String? correct(String query) {
    final tokens = tokenize(query);
    if (tokens.isEmpty) return null;

    var changed = false;
    final corrected = <String>[];
    for (final token in tokens) {
      if (_postings.containsKey(token) || token.length < 4) {
        corrected.add(token);
        continue;
      }
      String? best;
      var bestScore = -1;
      for (final candidate in _postings.keys) {
        final distance = boundedEditDistance(token, candidate, maxDistance: 2);
        if (distance > 2) continue;
        final frequency = _tokenFrequency[candidate] ?? 0;
        final score = (2 - distance) * 1000 + frequency;
        if (score > bestScore) {
          bestScore = score;
          best = candidate;
        }
      }
      if (best != null) {
        changed = true;
        corrected.add(best);
      } else {
        corrected.add(token);
      }
    }
    return changed ? corrected.join(' ') : null;
  }

  /// All indexed documents (unmodifiable) — used by recommendation and
  /// collection builders that need to scan the catalog.
  List<SearchDocument> get documents => List.unmodifiable(_documents);
}
