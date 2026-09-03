import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/app_entity.dart';

/// Provider for discover page state
final discoverAppsProvider = StateNotifierProvider<DiscoverNotifier, DiscoverState>(
  (ref) => DiscoverNotifier(),
);

class DiscoverState {
  final List<AppSummary> featured;
  final List<AppSummary> trending;
  final List<AppSummary> recentlyUpdated;
  final List<AppSummary> newReleases;
  final bool isLoading;
  final String? error;

  const DiscoverState({
    this.featured = const [],
    this.trending = const [],
    this.recentlyUpdated = const [],
    this.newReleases = const [],
    this.isLoading = false,
    this.error,
  });

  DiscoverState copyWith({
    List<AppSummary>? featured,
    List<AppSummary>? trending,
    List<AppSummary>? recentlyUpdated,
    List<AppSummary>? newReleases,
    bool? isLoading,
    String? error,
  }) {
    return DiscoverState(
      featured: featured ?? this.featured,
      trending: trending ?? this.trending,
      recentlyUpdated: recentlyUpdated ?? this.recentlyUpdated,
      newReleases: newReleases ?? this.newReleases,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class DiscoverNotifier extends StateNotifier<DiscoverState> {
  DiscoverNotifier() : super(const DiscoverState());

  Future<void> loadDiscoverData() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Load data from repository
      // This would be implemented with actual API calls
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await loadDiscoverData();
  }
}
