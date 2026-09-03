import 'package:flutter_test/flutter_test.dart';
import 'package:omnistore/domain/models/release_entity.dart';
import 'package:omnistore/domain/models/update_entity.dart';
import 'package:omnistore/domain/models/collection_entity.dart';
import 'package:omnistore/domain/models/discover_entity.dart';

void main() {
  group('ReleaseEntity Tests', () {
    test('should create valid release entity', () {
      final release = ReleaseEntity(
        id: 'release-123',
        appId: 'app-456',
        version: '1.0.0',
        buildNumber: '100',
        releaseDate: DateTime(2024, 1, 1),
        assets: const [],
      );
      expect(release.id, equals('release-123'));
      expect(release.appId, equals('app-456'));
      expect(release.version, equals('1.0.0'));
    });

    test('should serialize to JSON', () {
      final release = ReleaseEntity(
        id: 'json-release',
        appId: 'app-json',
        version: '2.0.0',
        buildNumber: '200',
        releaseDate: DateTime(2024, 1, 1),
        assets: const [],
        changelog: 'Bug fixes',
      );

      final json = release.toJson();

      expect(json['id'], equals('json-release'));
      expect(json['version'], equals('2.0.0'));
    });
  });

  group('ReleaseAsset Tests', () {
    test('should create valid release asset', () {
      const asset = ReleaseAsset(
        id: 'asset-123',
        name: 'app.ipa',
        url: 'https://example.com/download',
        size: 50000000,
        contentType: 'application/octet-stream',
        sha256: 'abc123',
      );

      expect(asset.id, equals('asset-123'));
      expect(asset.name, equals('app.ipa'));
      expect(asset.size, equals(50000000));
    });
  });

  group('UpdateEntity Tests', () {
    test('should detect available update', () {
      final update = UpdateEntity(
        appId: 'app-123',
        appName: 'Test App',
        iconUrl: '',
        installedVersion: '1.0.0',
        latestVersion: '1.5.0',
        buildNumber: '150',
        releaseDate: DateTime(2024, 1, 1),
        downloadSize: 0,
        repositoryId: '',
      );

      expect(update.isAvailable, isTrue);
    });

    test('should detect no update when versions match', () {
      final update = UpdateEntity(
        appId: 'app-456',
        appName: 'Another App',
        iconUrl: '',
        installedVersion: '2.0.0',
        latestVersion: '2.0.0',
        buildNumber: '200',
        releaseDate: DateTime(2024, 1, 1),
        downloadSize: 0,
        repositoryId: '',
      );

      expect(update.isAvailable, isFalse);
    });
  });

  group('UpdatePreferences Tests', () {
    test('should use default values', () {
      const prefs = UpdatePreferences();

      expect(prefs.autoCheck, isTrue);
      expect(prefs.notifyUpdates, isTrue);
      expect(prefs.includePrereleases, isFalse);
      expect(prefs.autoDownload, isFalse);
      expect(prefs.autoInstall, isFalse);
      expect(prefs.checkIntervalMinutes, equals(360));
    });

    test('should serialize to JSON', () {
      const prefs = UpdatePreferences(
        autoCheck: false,
        autoDownload: true,
      );

      final json = prefs.toJson();

      expect(json['autoCheck'], isFalse);
      expect(json['autoDownload'], isTrue);
    });
  });

  group('CollectionEntity Tests', () {
    test('should create valid collection', () {
      final collection = CollectionEntity(
        id: 'collection-123',
        name: 'My Collection',
        icon: 'star',
        color: '#FF5722',
        appIds: ['app-1', 'app-2', 'app-3'],
        createdAt: DateTime(2024, 1, 1),
        description: 'A test collection',
      );

      expect(collection.id, equals('collection-123'));
      expect(collection.name, equals('My Collection'));
      expect(collection.appIds.length, equals(3));
    });

    test('should serialize to JSON', () {
      final collection = CollectionEntity(
        id: 'json-collection',
        name: 'JSON Collection',
        icon: 'folder',
        color: '#673AB7',
        appIds: const ['app-a', 'app-b'],
        createdAt: DateTime(2024, 2, 1),
      );

      final json = collection.toJson();

      expect(json['id'], equals('json-collection'));
      expect(json['name'], equals('JSON Collection'));
      expect(json['appIds'], equals(['app-a', 'app-b']));
    });
  });

  group('DefaultCollections Tests', () {
    test('should have all default collections', () {
      final all = DefaultCollections.all;

      expect(all.length, equals(4));
      expect(all.any((c) => c.id == 'music'), isTrue);
      expect(all.any((c) => c.id == 'productivity'), isTrue);
      expect(all.any((c) => c.id == 'social'), isTrue);
      expect(all.any((c) => c.id == 'development'), isTrue);
    });

    test('should have system collections marked as system', () {
      for (final collection in DefaultCollections.all) {
        expect(collection.isSystem, isTrue);
      }
    });
  });

  group('CategoryEntity Tests', () {
    test('should create valid category', () {
      const category = CategoryEntity(
        id: 'category-123',
        name: 'Games',
        icon: 'games',
        color: '#E91E63',
        appCount: 42,
      );

      expect(category.id, equals('category-123'));
      expect(category.name, equals('Games'));
      expect(category.appCount, equals(42));
    });

    test('should serialize to JSON', () {
      const category = CategoryEntity(
        id: 'json-category',
        name: 'Utilities',
        icon: 'build',
        color: '#607D8B',
      );

      final json = category.toJson();

      expect(json['id'], equals('json-category'));
      expect(json['name'], equals('Utilities'));
    });
  });

  group('FeaturedItem Tests', () {
    test('should create valid featured item', () {
      const featured = FeaturedItem(
        appId: 'featured-app',
        title: 'Featured App',
        subtitle: 'A great app',
        imageUrl: 'https://example.com/featured.png',
        backgroundColor: '#3F51B5',
        actionLabel: 'Install',
      );

      expect(featured.appId, equals('featured-app'));
      expect(featured.title, equals('Featured App'));
      expect(featured.actionLabel, equals('Install'));
    });

    test('should serialize to JSON', () {
      const featured = FeaturedItem(
        appId: 'json-featured',
        title: 'JSON Featured',
        subtitle: 'From JSON',
        imageUrl: 'https://example.com/image.png',
        backgroundColor: '#FF9800',
      );

      final json = featured.toJson();

      expect(json['appId'], equals('json-featured'));
      expect(json['title'], equals('JSON Featured'));
    });
  });
}
