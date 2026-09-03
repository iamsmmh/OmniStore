import 'package:flutter_test/flutter_test.dart';
import 'package:omnistore/domain/models/repository_entity.dart';

void main() {
  group('Repository Entity Tests', () {
    test('should create valid repository entity', () {
      final repo = RepositoryEntity(
        id: 'test-id-123',
        name: 'Test Repository',
        url: 'https://github.com/test/repo',
        type: RepositoryType.github,
        isEnabled: true,
        addedAt: DateTime.now(),
        description: 'A test repository',
        appCount: 10,
      );

      expect(repo.id, equals('test-id-123'));
      expect(repo.name, equals('Test Repository'));
      expect(repo.type, equals(RepositoryType.github));
      expect(repo.isEnabled, isTrue);
      expect(repo.appCount, equals(10));
    });

    test('should create repository from JSON', () {
      final json = {
        'id': 'json-id-456',
        'name': 'JSON Repository',
        'url': 'https://gitlab.com/test/project',
        'type': 'gitlab',
        'isEnabled': false,
        'addedAt': DateTime.now().toIso8601String(),
        'description': 'A repository from JSON',
      };

      final repo = RepositoryEntity.fromJson(json);

      expect(repo.id, equals('json-id-456'));
      expect(repo.name, equals('JSON Repository'));
      expect(repo.type, equals(RepositoryType.gitlab));
      expect(repo.isEnabled, isFalse);
    });

    test('should convert repository to JSON', () {
      final repo = RepositoryEntity(
        id: 'to-json-id',
        name: 'To JSON Repo',
        url: 'https://codeberg.org/test/repo',
        type: RepositoryType.codeberg,
        isEnabled: true,
        addedAt: DateTime(2024, 1, 1),
      );

      final json = repo.toJson();

      expect(json['id'], equals('to-json-id'));
      expect(json['name'], equals('To JSON Repo'));
      expect(json['type'], equals('codeberg'));
    });

    test('should support all repository types', () {
      for (final type in RepositoryType.values) {
        final repo = RepositoryEntity(
          id: 'type-test-${type.name}',
          name: 'Test ${type.name}',
          url: 'https://example.com/test',
          type: type,
          isEnabled: true,
          addedAt: DateTime.now(),
        );

        expect(repo.type, equals(type));
      }
    });
  });

  group('ValidationResult Tests', () {
    test('should create valid validation result', () {
      const result = ValidationResult(
        isValid: true,
        message: 'Repository is valid',
        metadata: {'appCount': 5},
      );

      expect(result.isValid, isTrue);
      expect(result.message, equals('Repository is valid'));
    });

    test('should handle invalid validation result', () {
      const result = ValidationResult(
        isValid: false,
        message: 'Repository not found',
      );

      expect(result.isValid, isFalse);
      expect(result.message, equals('Repository not found'));
    });
  });
}
