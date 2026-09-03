import '../../core/search/text_matching.dart';
import 'search_index.dart';
import '../health/app_health.dart';

enum DiscoverySection { related, popular, trending, verified }

class DiscoverySuggestion {
  final String repositoryId;
  final String name;
  final String url;
  final double score;
  final DiscoverySection reason;
  final String explanation;

  const DiscoverySuggestion({
    required this.repositoryId,
    required this.name,
    required this.url,
    required this.score,
    required this.reason,
    required this.explanation,
  });
}

class RepositoryProfile {
  final String id;
  final String name;
  final String url;
  final List<String> categories;
  final List<String> tags;
  final bool isVerified;
  final DateTime addedAt;
  final int appCount;
  final double popularity;

  const RepositoryProfile({
    required this.id,
    required this.name,
    required this.url,
    this.categories = const [],
    this.tags = const [],
    this.isVerified = false,
    required this.addedAt,
    this.appCount = 0,
    this.popularity = 0,
  });
}

/// Smart discovery: suggests related/popular/trending/verified repositories
/// when user adds a source.
class SmartDiscoveryEngine {
  const SmartDiscoveryEngine();

  List<DiscoverySuggestion> suggestRepositories({
    required RepositoryProfile anchor,
    required List<RepositoryProfile> catalog,
    required Map<String, HealthReport> healthByRepo,
    int limit = 8,
  }) {
    final candidates = catalog.where((r) => r.id != anchor.id).toList();
    final scored = <DiscoverySuggestion>[];

    for (final repo in candidates) {
      double score = 0;
      DiscoverySection reason = DiscoverySection.related;
      String explanation = '';

      // Related: shared categories/tags via Jaccard
      final relatedScore = _relatedScore(anchor, repo);
      if (relatedScore > 0.3) {
        score = relatedScore * 0.5;
        reason = DiscoverySection.related;
        explanation = 'Shares categories with ${anchor.name}';
      }

      // Popular: high app count and popularity
      final popularScore = (repo.popularity * 0.6) + (repo.appCount / 200).clamp(0, 0.4);
      if (popularScore > 0.6 && popularScore > score) {
        score = popularScore * 0.7;
        reason = DiscoverySection.popular;
        explanation = 'Popular repository with ${repo.appCount} apps';
      }

      // Trending: recently added
      final daysSinceAdded = DateTime.now().difference(repo.addedAt).inDays;
      if (daysSinceAdded < 45 && repo.appCount > 5) {
        final trending = (1 - (daysSinceAdded / 45)) * 0.5;
        if (trending > score) {
          score = trending;
          reason = DiscoverySection.trending;
          explanation = 'Trending — added ${daysSinceAdded} days ago';
        }
      }

      // Verified
      if (repo.isVerified) {
        score += 0.25;
        if (reason == DiscoverySection.related) {
          explanation += ' and verified';
        } else if (score < 0.5) {
          reason = DiscoverySection.verified;
          explanation = 'Verified repository';
        }
      }

      // Health boost
      final health = healthByRepo[repo.id];
      if (health != null) {
        if (health.status == HealthStatus.healthy) score += 0.15;
        if (health.status == HealthStatus.potentiallyAbandoned) score -= 0.3;
      }

      if (score > 0.2) {
        scored.add(DiscoverySuggestion(
          repositoryId: repo.id,
          name: repo.name,
          url: repo.url,
          score: score.clamp(0, 1),
          reason: reason,
          explanation: explanation,
        ));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).toList();
  }

  double _relatedScore(RepositoryProfile a, RepositoryProfile b) {
    final aTerms = {...a.categories.map(normalizeForSearch), ...a.tags.map(normalizeForSearch)}.where((s) => s.isNotEmpty).toSet();
    final bTerms = {...b.categories.map(normalizeForSearch), ...b.tags.map(normalizeForSearch)}.where((s) => s.isNotEmpty).toSet();
    if (aTerms.isEmpty || bTerms.isEmpty) return 0;
    final inter = aTerms.intersection(bTerms).length;
    final union = aTerms.union(bTerms).length;
    return inter / union;
  }
}
