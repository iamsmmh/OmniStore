import 'package:flutter_test/flutter_test.dart';
import 'package:omnistore/domain/models/app_entity.dart';

void main() {
  group('AppEntity Tests', () {
    test('should create valid app entity', () {
      final app = AppEntity(
        id: 'app-123',
        name: 'Test App',
        bundleId: 'com.test.app',
        developer: 'Test Developer',
        description: 'A test application',
        version: '1.0.0',
        buildNumber: '100',
        releaseDate: DateTime(2024, 1, 15),
        iconUrl: 'https://example.com/icon.png',
        screenshots: ['https://example.com/screen1.png'],
        categories: ['Utilities', 'Productivity'],
        tags: ['test', 'demo'],
        downloadSize: 50000000,
        minOsVersion: '14.0',
        sourceUrl: 'https://github.com/test/app',
        repositoryId: 'repo-456',
        changelog: 'Initial release',
        sha256: 'abc123def456',
        downloadUrl: 'https://github.com/test/app/releases/download/1.0.0/app.ipa',
      );

      expect(app.id, equals('app-123'));
      expect(app.name, equals('Test App'));
      expect(app.bundleId, equals('com.test.app'));
      expect(app.version, equals('1.0.0'));
      expect(app.categories.length, equals(2));
      expect(app.downloadSize, equals(50000000));
    });

    test('should serialize to JSON correctly', () {
      final app = AppEntity(
        id: 'json-test',
        name: 'JSON Test App',
        bundleId: 'com.json.test',
        developer: 'JSON Dev',
        description: 'Test JSON serialization',
        version: '2.0.0',
        buildNumber: '200',
        releaseDate: DateTime(2024, 3, 1),
        iconUrl: 'https://example.com/icon.png',
        screenshots: [],
        categories: ['Games'],
        tags: [],
        downloadSize: 100000000,
        minOsVersion: '15.0',
        sourceUrl: 'https://example.com/source',
        repositoryId: 'repo-789',
      );

      final json = app.toJson();

      expect(json['id'], equals('json-test'));
      expect(json['name'], equals('JSON Test App'));
      expect(json['bundleId'], equals('com.json.test'));
      expect(json['version'], equals('2.0.0'));
      expect(json['categories'], equals(['Games']));
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'id': 'from-json',
        'name': 'From JSON App',
        'bundleId': 'com.fromjson',
        'developer': 'JSON Import',
        'description': 'Test JSON deserialization',
        'version': '3.0.0',
        'buildNumber': '300',
        'releaseDate': DateTime(2024, 5, 1).toIso8601String(),
        'iconUrl': 'https://example.com/icon.png',
        'screenshots': ['https://example.com/screen.png'],
        'categories': ['Social', 'News'],
        'tags': ['social', 'connect'],
        'downloadSize': 75000000,
        'minOsVersion': '13.0',
        'sourceUrl': 'https://gitlab.com/test/app',
        'repositoryId': 'repo-123',
        'changelog': 'Bug fixes',
        'sha256': 'xyz789',
        'downloadUrl': 'https://gitlab.com/test/app/-/releases',
      };

      final app = AppEntity.fromJson(json);

      expect(app.id, equals('from-json'));
      expect(app.name, equals('From JSON App'));
      expect(app.version, equals('3.0.0'));
      expect(app.categories, equals(['Social', 'News']));
      expect(app.changelog, equals('Bug fixes'));
    });

    test('should handle optional fields', () {
      final app = AppEntity(
        id: 'minimal',
        name: 'Minimal App',
        bundleId: 'com.minimal',
        developer: 'Minimal Dev',
        description: 'Minimal description',
        version: '1.0.0',
        buildNumber: '1',
        releaseDate: DateTime.now(),
        iconUrl: '',
        screenshots: [],
        categories: [],
        tags: [],
        downloadSize: 0,
        minOsVersion: '',
        sourceUrl: '',
        repositoryId: '',
      );

      expect(app.changelog, isNull);
      expect(app.sha256, isNull);
      expect(app.downloadUrl, isNull);
      expect(app.isInstalled, isNull);
      expect(app.isFavorite, isNull);
    });
  });

  group('AppSummary Tests', () {
    test('should create valid app summary', () {
      final summary = AppSummary(
        id: 'summary-123',
        name: 'Summary App',
        bundleId: 'com.summary.app',
        developer: 'Summary Dev',
        iconUrl: 'https://example.com/icon.png',
        version: '1.5.0',
        releaseDate: DateTime(2024, 2, 1),
        categories: ['Productivity'],
        isFavorite: true,
        isInstalled: true,
        installedVersion: '1.0.0',
      );

      expect(summary.id, equals('summary-123'));
      expect(summary.name, equals('Summary App'));
      expect(summary.isFavorite, isTrue);
      expect(summary.isInstalled, isTrue);
      expect(summary.installedVersion, equals('1.0.0'));
    });

    test('should serialize app summary to JSON', () {
      final summary = AppSummary(
        id: 'json-summary',
        name: 'JSON Summary',
        bundleId: 'com.jsonsummary',
        developer: 'JSON Dev',
        iconUrl: 'https://example.com/icon.png',
        version: '2.0.0',
        releaseDate: DateTime(2024, 4, 1),
        categories: ['Games'],
      );

      final json = summary.toJson();

      expect(json['id'], equals('json-summary'));
      expect(json['name'], equals('JSON Summary'));
      expect(json['version'], equals('2.0.0'));
    });

    test('should deserialize app summary from JSON', () {
      final json = {
        'id': 'from-json-summary',
        'name': 'From JSON Summary',
        'bundleId': 'com.fromjson',
        'developer': 'JSON Dev',
        'iconUrl': '',
        'version': '1.0.0',
        'releaseDate': DateTime(2024, 6, 1).toIso8601String(),
        'categories': <String>[],
      };

      final summary = AppSummary.fromJson(json);

      expect(summary.id, equals('from-json-summary'));
      expect(summary.name, equals('From JSON Summary'));
      expect(summary.isFavorite, isNull);
      expect(summary.isInstalled, isNull);
    });
  });
}
