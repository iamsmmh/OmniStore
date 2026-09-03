import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/app_entity.dart';

/// Provider for search query
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Provider for search state
final searchNotifierProvider =
    StateNotifierProvider<SearchNotifier, SearchState>(
  (ref) => SearchNotifier(),
);

class SearchState {
  final List<AppSummary> results;
  final List<String> recentSearches;
  final List<String> suggestions;
  final bool isLoading;
  final String? error;

  const SearchState({
    this.results = const [],
    this.recentSearches = const [],
    this.suggestions = const [],
    this.isLoading = false,
    this.error,
  });

  SearchState copyWith({
    List<AppSummary>? results,
    List<String>? recentSearches,
    List<String>? suggestions,
    bool? isLoading,
    String? error,
  }) {
    return SearchState(
      results: results ?? this.results,
      recentSearches: recentSearches ?? this.recentSearches,
      suggestions: suggestions ?? this.suggestions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier() : super(const SearchState());

  Future<void> search(String query) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Perform search via repository
      // Results would come from the search service
      state = state.copyWith(
        isLoading: false,
        recentSearches: [
          query,
          ...state.recentSearches.where((s) => s != query),
        ].take(20).toList(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> getSuggestions(String query) async {
    if (query.isEmpty) {
      state = state.copyWith(suggestions: []);
      return;
    }

    try {
      // Get suggestions from search service
      state = state.copyWith(suggestions: []);
    } catch (e) {
      // Ignore suggestion errors
    }
  }

  void clearRecentSearches() {
    state = state.copyWith(recentSearches: []);
  }
}
