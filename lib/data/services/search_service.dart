import 'dart:async';
import '../../core/logger/app_logger.dart';
import '../../domain/models/app_entity.dart';
import '../../domain/repositories/app_repository.dart';

/// Search service with indexing and caching
class SearchService {
  final AppRepository _appRepository;
  final _logger = AppLogger.getLogger('SearchService');

  // Search cache
  final Map<String, List<AppSummary>> _searchCache = {};
  final List<String> _recentSearches = [];
  static const int _maxRecentSearches = 20;

  // Debounce timer
  Timer? _debounceTimer;
  final Duration _debounceDuration = const Duration(milliseconds: 300);

  SearchService({required AppRepository appRepository})
      : _appRepository = appRepository;

  /// Recent searches list
  List<String> get recentSearches => List.unmodifiable(_recentSearches);

  /// Search apps with debouncing
  Future<List<AppSummary>> search(
    String query, {
    bool addToRecent = true,
    String? category,
    String? repositoryId,
  }) async {
    if (query.trim().isEmpty) return [];

    // Check cache first
    final cacheKey = _buildCacheKey(query, category, repositoryId);
    if (_searchCache.containsKey(cacheKey)) {
      return _searchCache[cacheKey]!;
    }

    // Perform search
    try {
      final results = await _appRepository.searchApps(
        query,
        category: category,
        repositoryId: repositoryId,
      );

      // Cache results
      _searchCache[cacheKey] = results;

      // Add to recent searches
      if (addToRecent) {
        _addRecentSearch(query);
      }

      return results;
    } catch (e, stack) {
      _logger.severe('Search failed: $query', e, stack);
      return [];
    }
  }

  /// Search with debounce (for live search)
  Future<List<AppSummary>> searchDebounced(
    String query, {
    String? category,
    String? repositoryId,
  }) async {
    _debounceTimer?.cancel();

    final completer = Completer<List<AppSummary>>();

    _debounceTimer = Timer(_debounceDuration, () async {
      final results = await search(
        query,
        addToRecent: false,
        category: category,
        repositoryId: repositoryId,
      );
      completer.complete(results);
    });

    return completer.future;
  }

  /// Get search suggestions based on query
  Future<List<String>> getSuggestions(String query) async {
    if (query.trim().isEmpty) return [];

    final results = await _appRepository.searchApps(query, pageSize: 5);
    final suggestions = <String>{};

    // Add app names
    for (final app in results) {
      if (app.name.toLowerCase().contains(query.toLowerCase())) {
        suggestions.add(app.name);
      }
    }

    // Add developer names
    for (final app in results) {
      if (app.developer.toLowerCase().contains(query.toLowerCase())) {
        suggestions.add(app.developer);
      }
    }

    // Add category names
    for (final app in results) {
      for (final cat in app.categories) {
        if (cat.toLowerCase().contains(query.toLowerCase())) {
          suggestions.add(cat);
        }
      }
    }

    return suggestions.toList().take(10).toList();
  }

  /// Add to recent searches
  void _addRecentSearch(String query) {
    _recentSearches.remove(query);
    _recentSearches.insert(0, query);

    if (_recentSearches.length > _maxRecentSearches) {
      _recentSearches.removeLast();
    }
  }

  /// Clear recent searches
  void clearRecentSearches() {
    _recentSearches.clear();
  }

  /// Clear search cache
  void clearCache() {
    _searchCache.clear();
  }

  /// Build cache key
  String _buildCacheKey(
    String query,
    String? category,
    String? repositoryId,
  ) {
    return '${query.toLowerCase()}|${category ?? ""}|${repositoryId ?? ""}';
  }

  /// Dispose resources
  void dispose() {
    _debounceTimer?.cancel();
  }
}
