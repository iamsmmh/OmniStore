import 'package:flutter_test/flutter_test.dart';
import 'package:omnistore/domain/discovery/search_index.dart';

SearchDocument doc(
  String id,
  String name, {
  String developer = 'Someone',
  String repositoryId = 'repo-a',
  List<String> categories = const [],
  List<String> tags = const [],
  List<String> aliases = const [],
  String description = '',
  double? popularity,
  DateTime? lastReleaseAt,
}) {
  return SearchDocument(
    id: id,
    name: name,
    developer: developer,
    repositoryId: repositoryId,
    categories: categories,
    tags: tags,
    aliases: aliases,
    description: description,
    popularity: popularity,
    lastReleaseAt: lastReleaseAt,
  );
}

void main() {
  final now = DateTime(2026, 9, 3);

  late SearchIndex index;

  setUp(() {
    index = SearchIndex()
      ..rebuild([
        doc('vlc', 'VLC Media Player',
            developer: 'VideoLAN',
            categories: ['Music', 'Video'],
            tags: ['opensource', 'player'],
            aliases: ['vlc'],
            description: 'Plays every video and audio file you throw at it.',
            popularity: 0.9,
            lastReleaseAt: DateTime(2026, 8, 20)),
        doc('nova', 'Nova Player',
            developer: 'Nova Team',
            categories: ['Music'],
            tags: ['player'],
            description: 'A modern music player with a clean interface.',
            popularity: 0.3,
            lastReleaseAt: DateTime(2026, 7, 1)),
        doc('gitcli', 'Git Companion',
            developer: 'VideoLAN',
            categories: ['Developer'],
            tags: ['git', 'cli'],
            description: 'Terminal helper for git workflows.',
            popularity: 0.1,
            lastReleaseAt: DateTime(2024, 1, 1)),
        doc('notes', 'Quick Notes',
            developer: 'Acme',
            repositoryId: 'repo-b',
            categories: ['Productivity'],
            description: 'Capture notes fast.',
            lastReleaseAt: DateTime(2026, 8, 30)),
      ]);
  });

  group('indexing', () {
    test('reports document and token counts', () {
      expect(index.documentCount, 4);
      expect(index.tokenCount, greaterThan(10));
    });

    test('upsert replaces an existing document', () {
      index.upsert(doc('nova', 'Nova Player Pro'));
      expect(index.documentCount, 4);
      final hits = index.search('pro', now: now);
      expect(hits.first.document.id, 'nova');
    });

    test('upsert adds a new document', () {
      index.upsert(doc('new', 'Brand New App'));
      expect(index.documentCount, 5);
    });

    test('remove drops the document from results', () {
      index.remove('vlc');
      expect(index.documentCount, 3);
      expect(index.search('vlc', now: now), isEmpty);
    });
  });

  group('search', () {
    test('finds an exact name match first', () {
      final hits = index.search('nova player', now: now);
      expect(hits.first.document.id, 'nova');
    });

    test('matches a prefix as you type', () {
      final hits = index.search('nov', now: now);
      expect(hits.map((h) => h.document.id), contains('nova'));
    });

    test('tolerates a typo and flags the result as fuzzy', () {
      final hits = index.search('novva', now: now);
      expect(hits, isNotEmpty);
      expect(hits.first.document.id, 'nova');
      expect(hits.first.isFuzzy, isTrue);
    });

    test('matches an alias', () {
      final hits = index.search('vlc', now: now);
      expect(hits.first.document.id, 'vlc');
      expect(hits.first.matchedFields, contains(MatchField.name));
    });

    test('matches a developer name', () {
      final hits = index.search('videolan', now: now);
      expect(hits.map((h) => h.document.id), containsAll(['vlc', 'gitcli']));
      expect(hits.first.matchedFields, contains(MatchField.developer));
    });

    test('matches a tag', () {
      final hits = index.search('opensource', now: now);
      expect(hits.first.document.id, 'vlc');
      expect(hits.first.matchedFields, contains(MatchField.tag));
    });

    test('ranks multi-token coverage above single-token matches', () {
      final hits = index.search('nova player', now: now);
      expect(hits.first.document.id, 'nova');
      expect(hits.length, greaterThan(1)); // "player" also hits VLC
    });

    test('returns nothing for a blank query without filters', () {
      expect(index.search('   ', now: now), isEmpty);
    });

    test('respects the result limit', () {
      expect(index.search('player', limit: 1, now: now).length, 1);
    });

    test('fuzzy matching can be disabled', () {
      expect(index.search('novva', fuzzy: false, now: now), isEmpty);
    });
  });

  group('filters', () {
    test('filters by repository', () {
      final hits = index.search('notes',
          filter: const SearchFilter(repositoryId: 'repo-a'), now: now);
      expect(hits, isEmpty);
    });

    test('filters by category', () {
      final hits = index.search('player',
          filter: const SearchFilter(category: 'music'), now: now);
      expect(hits.map((h) => h.document.id), containsAll(['vlc', 'nova']));
    });

    test('filters by developer', () {
      final hits = index.search('videolan',
          filter: const SearchFilter(developer: 'VideoLAN'), now: now);
      expect(hits.length, 2);
    });

    test('an empty query with a filter browses that facet', () {
      final hits = index.search('',
          filter: const SearchFilter(category: 'Productivity'), now: now);
      expect(hits.single.document.id, 'notes');
    });
  });

  group('suggest and correct', () {
    test('suggests app names by prefix', () {
      expect(index.suggest('nov'), contains('Nova Player'));
    });

    test('returns no suggestions for empty input', () {
      expect(index.suggest('  '), isEmpty);
    });

    test('corrects a misspelled token', () {
      expect(index.correct('playerr'), 'player');
    });

    test('returns null when nothing needs correcting', () {
      expect(index.correct('player'), isNull);
    });
  });

  test('freshness boosts recently released apps', () {
    final fresh = SearchIndex()
      ..rebuild([
        doc('old', 'Sample App', lastReleaseAt: DateTime(2020, 1, 1)),
        doc('new', 'Sample App', lastReleaseAt: DateTime(2026, 8, 25)),
      ]);
    final hits = fresh.search('sample app', now: now);
    expect(hits.first.document.id, 'new');
  });
}
