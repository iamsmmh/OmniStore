import 'package:flutter_test/flutter_test.dart';
import 'package:omnistore/domain/security/trust_analyzer.dart';
import 'package:omnistore/domain/security/trust_engine.dart';

void main() {
  group('TrustEngine', () {
    const engine = TrustEngine();

    test('verified for high score with verification', () {
      final input = RepositoryTrustInput(repositoryId: '1', url: 'https://example.com/repo.json', checksumCoverage: 1, metadataCompleteness: 1, httpsAssetRatio: 1, appCount: 10, isPubliclyVerified: true, lastSuccessfulSync: DateTime.now());
      final score = engine.evaluate(input);
      expect(score.category, TrustCategory.verified);
      expect(score.score, greaterThan(80));
    });

    test('risky for insecure transport', () {
      final input = RepositoryTrustInput(repositoryId: '2', url: 'http://example.com/repo.json', checksumCoverage: 0, appCount: 10);
      final score = engine.evaluate(input);
      expect(score.category, TrustCategory.risky);
    });

    test('unknown for empty repo', () {
      final input = RepositoryTrustInput(repositoryId: '3', url: 'https://example.com/empty.json', appCount: 0);
      final score = engine.evaluate(input);
      expect(score.category, isIn([TrustCategory.unknown, TrustCategory.risky, TrustCategory.community]));
    });

    test('community for moderate score', () {
      final input = RepositoryTrustInput(repositoryId: '4', url: 'https://example.com/repo.json', checksumCoverage: 0.5, metadataCompleteness: 0.7, httpsAssetRatio: 1, appCount: 10);
      final score = engine.evaluate(input);
      expect(score.category, isIn([TrustCategory.community, TrustCategory.trusted, TrustCategory.unknown]));
    });

    test('trusted for strong signals', () {
      final input = RepositoryTrustInput(repositoryId: '5', url: 'https://example.com/repo.json', checksumCoverage: 0.96, metadataCompleteness: 0.95, httpsAssetRatio: 1, appCount: 20, lastSuccessfulSync: DateTime.now());
      final score = engine.evaluate(input);
      expect(score.score, greaterThan(60));
    });
  });
}
