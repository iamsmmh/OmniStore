import 'dart:async';
import 'dart:collection';

import '../../core/logger/app_logger.dart';
import '../../domain/models/app_entity.dart';
import '../../domain/repositories/app_repository.dart';

/// Search service with bounded caching, debouncing and deduplication.
class SearchService {
  final AppRepository _appRepository;
  final _logger = AppLogger.getLogger('SearchService');

  // Bounded LRU cache — prevents unbounded growth noted in F-11.
  final LinkedHashMap<String, List<AppSummary>> _searchCache = LinkedHashMap();
  static const int _maxCacheEntries = 80;
  static const int _maxRecentSearches = 20;
  final List<String> _recentSearches = [];

  Timer? _debounceTimer;
  Completer<List<AppSummary>>? _pendingCompleter;
  final Duration _debounceDuration = const Duration(milliseconds: 280);

  // Invalidation token — incremented on sync so stale entries aren't served.
  int _cacheGeneration = 0;

  SearchService({required AppRepository appRepository})
      : _appRepository = appRepository;

  List<String> get recentSearches => List.unmodifiable(_recentSearches);

  /// Call when catalog data changes to prevent stale results.
  void invalidateCache() {
    _searchCache.clear();
    _cacheGeneration++;
  }

  Future<List<AppSummary>> search(
    String query, {
    bool addToRecent = true,
    String? category,
    String? repositoryId,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    if (trimmed.length > 200) return [];

    final cacheKey = _buildCacheKey(trimmed, category, repositoryId);
    final cached = _searchCache[cacheKey];
    if (cached != null) {
      // Move to end for LRU ordering
      _searchCache.remove(cacheKey);
      _searchCache[cacheKey] = cached;
      if (addToRecent) _addRecentSearch(trimmed);
      return cached;
    }

    try {
      final results = await _appRepository.searchApps(
        trimmed,
        category: category,
        repositoryId: repositoryId,
      );
      _putCache(cacheKey, results);
      if (addToRecent) _addRecentSearch(trimmed);
      return results;
    } catch (e, stack) {
      _logger.severe('Search failed: $trimmed', e, stack);
      return [];
    }
  }

  /// Debounced search for live typing. Cancels previous pending future
  /// and completes it with empty list instead of hanging forever (F-06 fix).
  Future<List<AppSummary>> searchDebounced(
    String query, {
    String? category,
    String? repositoryId,
  }) async {
    _debounceTimer?.cancel();
    // Complete previous pending with empty to avoid leak
    if (_pendingCompleter != null && !_pendingCompleter!.isCompleted) {
      _pendingCompleter!.complete([]);
    }
    final completer = Completer<List<AppSummary>>();
    _pendingCompleter = completer;

    _debounceTimer = Timer(_debounceDuration, () async {
      try {
        final results = await search(
          query,
          addToRecent: false,
          category: category,
          repositoryId: repositoryId,
        );
        if (!completer.isCompleted) completer.complete(results);
      } catch (e) {
        if (!completer.isCompleted) completer.complete([]);
      }
    });

    return completer.future;
  }

  Future<List<String>> getSuggestions(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    if (trimmed.length > 100) return [];
    try {
      final results = await _appRepository.searchApps(trimmed, pageSize: 8);
      final suggestions = <String>{};
      final lower = trimmed.toLowerCase();
      for (final app in results) {
        if (app.name.toLowerCase().contains(lower)) suggestions.add(app.name);
        if (app.developer.toLowerCase().contains(lower)) suggestions.add(app.developer);
        for (final cat in app.categories) {
          if (cat.toLowerCase().contains(lower)) suggestions.add(cat);
        }
        if (suggestions.length >= 10) break;
      }
      return suggestions.take(10).toList();
    } catch (e) {
      return [];
    }
  }

  void _addRecentSearch(String query) {
    _recentSearches.remove(query);
    _recentSearches.insert(0, query);
    if (_recentSearches.length > _maxRecentSearches) {
      _recentSearches.removeLast();
    }
  }

  void clearRecentSearches() {
    _recentSearches.clear();
  }

  void clearCache() {
    _searchCache.clear();
  }

  void _putCache(String key, List<AppSummary> value) {
    if (_searchCache.length >= _maxCacheEntries) {
      // Remove oldest entry
      _searchCache.remove(_searchCache.keys.first);
    }
    _searchCache[key] = value;
  }

  String _buildCacheKey(String query, String? category, String? repositoryId) {
    return '${query.toLowerCase()}|${category ?? ""}|${repositoryId ?? ""}|$_cacheGeneration';
  }

  void dispose() {
    _debounceTimer?.cancel();
    if (_pendingCompleter != null && !_pendingCompleter!.isCompleted) {
      _pendingCompleter!.complete([]);
    }
  }
}
