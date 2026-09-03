import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../data/services/discovery_service.dart';
import '../../../../domain/discovery/search_index.dart';
import '../../../../domain/models/app_entity.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedCategoryProvider = StateProvider<String?>((ref) => null);
final selectedSourceProvider = StateProvider<String?>((ref) => null);

final searchNotifierProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  final discovery = ref.watch(discoveryServiceProvider);
  final searchService = ref.watch(searchServiceProvider);
  return SearchNotifier(discovery: discovery, searchService: searchService, ref: ref);
});

class SearchState {
  final List<AppSummary> results;
  final List<SearchHit> rankedResults;
  final List<String> recentSearches;
  final List<String> suggestions;
  final bool isLoading;
  final String? error;
  final bool isOffline;
  final String query;
  final String? correctedQuery;

  const SearchState({
    this.results = const [],
    this.rankedResults = const [],
    this.recentSearches = const [],
    this.suggestions = const [],
    this.isLoading = false,
    this.error,
    this.isOffline = false,
    this.query = '',
    this.correctedQuery,
  });

  SearchState copyWith({
    List<AppSummary>? results,
    List<SearchHit>? rankedResults,
    List<String>? recentSearches,
    List<String>? suggestions,
    bool? isLoading,
    String? error,
    bool? isOffline,
    String? query,
    String? correctedQuery,
  }) {
    return SearchState(
      results: results ?? this.results,
      rankedResults: rankedResults ?? this.rankedResults,
      recentSearches: recentSearches ?? this.recentSearches,
      suggestions: suggestions ?? this.suggestions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isOffline: isOffline ?? this.isOffline,
      query: query ?? this.query,
      correctedQuery: correctedQuery,
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  final DiscoveryService discovery;
  final dynamic searchService;
  final Ref ref;
  Timer? _debounce;

  SearchNotifier({required this.discovery, required this.searchService, required this.ref}) : super(const SearchState()) {
    try {
      final recents = (searchService as dynamic).recentSearches as List<String>?;
      if (recents != null) state = state.copyWith(recentSearches: recents);
    } catch (_) {}
  }

  Future<void> search(String query) async {
    final trimmed = query.trim();
    ref.read(searchQueryProvider.notifier).state = trimmed;
    if (trimmed.isEmpty) {
      state = state.copyWith(results: [], rankedResults: [], isLoading: false, query: '', error: null, correctedQuery: null);
      return;
    }
    state = state.copyWith(isLoading: true, error: null, query: trimmed);

    try {
      final category = ref.read(selectedCategoryProvider);
      final source = ref.read(selectedSourceProvider);
      final filter = SearchFilter(category: category, repositoryId: source);

      // Try indexed offline search first
      List<SearchHit> hits = [];
      try {
        hits = discovery.search(trimmed, filter: filter, limit: 50);
      } catch (_) {}

      if (hits.isNotEmpty) {
        final summaries = hits.map((h) => AppSummary(
              id: h.document.id,
              name: h.document.name,
              bundleId: h.document.id,
              developer: h.document.developer,
              iconUrl: '',
              version: '1.0.0',
              releaseDate: h.document.lastReleaseAt ?? DateTime.now(),
              categories: h.document.categories,
            )).toList();
        final corrected = discovery.spellingCorrection(trimmed);
        state = state.copyWith(
          isLoading: false,
          results: summaries,
          rankedResults: hits,
          recentSearches: _updateRecents(trimmed),
          isOffline: false,
          correctedQuery: corrected != null && corrected != trimmed ? corrected : null,
        );
        return;
      }

      // Fallback to repository DB search
      final results = await (searchService as dynamic).search(trimmed, category: category, repositoryId: source) as List<AppSummary>? ?? [];
      state = state.copyWith(
        isLoading: false,
        results: results,
        rankedResults: [],
        recentSearches: _updateRecents(trimmed),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void searchDebounced(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () => search(query));
  }

  Future<void> getSuggestions(String query) async {
    if (query.trim().isEmpty) {
      state = state.copyWith(suggestions: []);
      return;
    }
    try {
      final suggestions = discovery.suggest(query, limit: 6);
      if (suggestions.isNotEmpty) {
        state = state.copyWith(suggestions: suggestions);
        return;
      }
      final list = await (searchService as dynamic).getSuggestions(query) as List<String>? ?? [];
      state = state.copyWith(suggestions: list);
    } catch (_) {
      state = state.copyWith(suggestions: []);
    }
  }

  void clearRecentSearches() {
    try {
      (searchService as dynamic).clearRecentSearches();
    } catch (_) {}
    state = state.copyWith(recentSearches: []);
  }

  void setCategory(String? category) {
    ref.read(selectedCategoryProvider.notifier).state = category;
    if (state.query.isNotEmpty) search(state.query);
  }

  void setSource(String? source) {
    ref.read(selectedSourceProvider.notifier).state = source;
    if (state.query.isNotEmpty) search(state.query);
  }

  List<String> _updateRecents(String query) {
    return [query, ...state.recentSearches.where((s) => s != query)].take(20).toList();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
