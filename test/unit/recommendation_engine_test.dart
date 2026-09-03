import 'package:flutter_test/flutter_test.dart';
import 'package:omnistore/domain/discovery/recommendation_engine.dart';
import 'package:omnistore/domain/discovery/search_index.dart';
import 'package:omnistore/domain/health/app_health.dart';

void main() {
  final now = DateTime(2026, 9, 3);
  const analyzer = AppHealthAnalyzer();

  SearchDocument doc(
    String id,
    String name, {
    String developer = 'Dev',
    List<String> categories = const [],
    List<String> tags = const [],
    String description = '',
    double? popularity,
    DateTime? lastReleaseAt,
  }) =>
      SearchDocument(
        id: id,
        name: name,
        developer: developer,
        repositoryId: 'repo',
        categories: categories,
        tags: tags,
        description: description,
        popularity: popularity,
        lastReleaseAt: lastReleaseAt,
      );

  HealthReport health(String id, int releases, {int lastDaysAgo = 10}) =>
      analyzer.analyze(
        appId: id,
        releaseDates: List.generate(
          releases,
          (i) => now.subtract(Duration(days: lastDaysAgo + i * 30)),
        ),
        now: now,
      );

  late SearchIndex index;
  late RecommendationEngine engine;

  setUp(() {
    index = SearchIndex()
      ..rebuild([
        doc('player-a', 'Nova Player',
            developer: 'Nova Team',
            categories: ['Music'],
            tags: ['player', 'audio', 'opensource'],
            description: 'A music player for local audio libraries.',
            popularity: 0.8,
            lastReleaseAt: now.subtract(const Duration(days: 5))),
        doc('player-b', 'Harmony Audio',
            developer: 'Harmony',
            categories: ['Music'],
            tags: ['player', 'audio'],
            description: 'Another music player for local audio libraries.',
            popularity: 0.2,
            lastReleaseAt: now.subtract(const Duration(days: 12))),
        doc('player-c', 'Nova Radio',
            developer: 'Nova Team',
            categories: ['Radio'],
            tags: ['streaming'],
            description: 'Internet radio streaming.',
            popularity: 0.1,
            lastReleaseAt: now.subtract(const Duration(days: 20))),
        doc('ide', 'Code Forge',
            developer: 'Forge',
            categories: ['Developer'],
            tags: ['ide', 'git'],
            description: 'A programming environment.',
            popularity: 0.05,
            lastReleaseAt: now.subtract(const Duration(days: 400))),
        doc('notes', 'Quick Notes',
            developer: 'Acme',
            categories: ['Productivity'],
            tags: ['notes'],
            description: 'Capture notes fast.',
            popularity: 0.4,
            lastReleaseAt: now.subtract(const Duration(days: 3))),
      ]);

    engine = RecommendationEngine(index: index, health: {
      'player-a': health('player-a', 10),
      'player-b': health('player-b', 8),
      'player-c': health('player-c', 3, lastDaysAgo: 20),
      'ide': health('ide', 2, lastDaysAgo: 400),
      'notes': health('notes', 9),
    });
  });

  group('similarTo', () {
    test('ranks apps sharing tags and categories highest', () {
      final similar = engine.similarTo('player-a');
      expect(similar.first.document.id, 'player-b');
    });

    test('never includes the source app', () {
      expect(engine.similarTo('player-a').map((r) => r.document.id),
          isNot(contains('player-a')));
    });

    test('includes same-developer apps with an explanatory reason', () {
      final similar = engine.similarTo('player-a');
      final radio =
          similar.firstWhere((r) => r.document.id == 'player-c');
      expect(radio.reason, isNotEmpty);
    });

    test('returns empty for an unknown app', () {
      expect(engine.similarTo('does-not-exist'), isEmpty);
    });

    test('respects the limit', () {
      expect(engine.similarTo('player-a', limit: 1).length, 1);
    });

    test('excludes wholly unrelated apps', () {
      expect(engine.similarTo('notes').map((r) => r.document.id),
          isNot(contains('ide')));
    });
  });

  group('forUser', () {
    test('recommends similar apps to what is installed', () {
      final recs = engine.forUser(
          const UserSignals(installedAppIds: {'player-a'}));
      expect(recs.map((r) => r.document.id), contains('player-b'));
    });

    test('never recommends an already installed app', () {
      final recs = engine.forUser(
          const UserSignals(installedAppIds: {'player-a', 'player-b'}));
      expect(recs.map((r) => r.document.id),
          isNot(contains('player-b')));
    });

    test('falls back to popular apps on a cold start', () {
      final recs = engine.forUser(UserSignals.empty, limit: 3);
      expect(recs, isNotEmpty);
      expect(recs.length, lessThanOrEqualTo(3));
      expect(recs.first.document.id, 'player-a');
    });

    test('weights favorites and recent views', () {
      final recs = engine.forUser(const UserSignals(
        favoriteAppIds: {'player-a'},
        recentlyViewedAppIds: ['ide'],
      ));
      expect(recs, isNotEmpty);
    });
  });

  group('feeds', () {
    test('trending favours recent, popular releases', () {
      final trending = engine.trending(now: now);
      expect(trending.first.id, anyOf('player-a', 'notes'));
      expect(trending.map((d) => d.id), isNot(contains('ide')));
    });

    test('new releases are ordered newest first', () {
      final releases = engine.newReleases(now: now);
      expect(releases.first.id, 'notes');
      expect(releases.map((d) => d.id), isNot(contains('ide')));
    });

    test('hidden gems surface healthy but unpopular apps', () {
      final gems = engine.hiddenGems(now: now);
      expect(gems.map((d) => d.id), contains('player-b'));
      expect(gems.map((d) => d.id), isNot(contains('player-a')));
    });

    test('feeds respect their limits', () {
      expect(engine.trending(limit: 1, now: now).length, 1);
      expect(engine.newReleases(limit: 1, now: now).length, 1);
    });
  });

  group('collections', () {
    test('generates the standard collections', () {
      final ids =
          engine.buildCollections(now: now).map((c) => c.id).toSet();
      expect(ids, contains('editor_picks'));
      expect(ids, contains('music'));
      expect(ids, contains('developer_tools'));
      expect(ids, contains('new_and_noteworthy'));
    });

    test('music collection contains only music apps', () {
      final music = engine
          .buildCollections(now: now)
          .firstWhere((c) => c.id == 'music');
      expect(music.apps.map((a) => a.id), containsAll(['player-a', 'player-b']));
      expect(music.apps.map((a) => a.id), isNot(contains('notes')));
    });

    test('open source collection matches by tag', () {
      final collections = engine.buildCollections(now: now);
      final oss = collections
          .where((c) => c.id == 'open_source_essentials')
          .toList();
      expect(oss.single.apps.map((a) => a.id), contains('player-a'));
    });

    test('collections are never empty and always explain themselves', () {
      for (final collection in engine.buildCollections(now: now)) {
        expect(collection.isEmpty, isFalse);
        expect(collection.rationale, isNotEmpty);
        expect(collection.title, isNotEmpty);
      }
    });

    test('respects the per-collection size limit', () {
      for (final collection
          in engine.buildCollections(now: now, perCollection: 1)) {
        expect(collection.apps.length, 1);
      }
    });

    test('an empty catalog produces no collections', () {
      final empty = RecommendationEngine(index: SearchIndex());
      expect(empty.buildCollections(now: now), isEmpty);
    });
  });
}
