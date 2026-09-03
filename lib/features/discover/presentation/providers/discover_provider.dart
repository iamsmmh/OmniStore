import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../data/services/discovery_service.dart';
import '../../../../domain/discovery/search_index.dart';
import '../../../../domain/models/app_entity.dart';

final discoverAppsProvider = StateNotifierProvider<DiscoverNotifier, DiscoverState>((ref) {
  final discovery = ref.watch(discoveryServiceProvider);
  final appRepo = ref.watch(appRepositoryProvider);
  return DiscoverNotifier(discovery: discovery, appRepository: appRepo, ref: ref);
});

class DiscoverState {
  final List<SearchDocument> featured;
  final List<SearchDocument> trending;
  final List<SearchDocument> recentlyUpdated;
  final List<SearchDocument> newReleases;
  final List<SearchDocument> recommended;
  final List<SearchDocument> hiddenGems;
  final bool isLoading;
  final String? error;
  final bool isOffline;

  const DiscoverState({
    this.featured = const [],
    this.trending = const [],
    this.recentlyUpdated = const [],
    this.newReleases = const [],
    this.recommended = const [],
    this.hiddenGems = const [],
    this.isLoading = false,
    this.error,
    this.isOffline = false,
  });

  DiscoverState copyWith({
    List<SearchDocument>? featured,
    List<SearchDocument>? trending,
    List<SearchDocument>? recentlyUpdated,
    List<SearchDocument>? newReleases,
    List<SearchDocument>? recommended,
    List<SearchDocument>? hiddenGems,
    bool? isLoading,
    String? error,
    bool? isOffline,
  }) {
    return DiscoverState(
      featured: featured ?? this.featured,
      trending: trending ?? this.trending,
      recentlyUpdated: recentlyUpdated ?? this.recentlyUpdated,
      newReleases: newReleases ?? this.newReleases,
      recommended: recommended ?? this.recommended,
      hiddenGems: hiddenGems ?? this.hiddenGems,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

class DiscoverNotifier extends StateNotifier<DiscoverState> {
  final DiscoveryService discovery;
  final dynamic appRepository;
  final Ref ref;

  DiscoverNotifier({required this.discovery, required this.appRepository, required this.ref}) : super(const DiscoverState(isLoading: true)) {
    loadDiscoverData();
    // Listen to index changes for live updates
    discovery.indexChanged.listen((_) => _refreshFromIndex());
  }

  Future<void> loadDiscoverData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await discovery.warmUp();
      _refreshFromIndex();
    } catch (e) {
      // Fallback to repository data if index not ready
      try {
        final trending = await appRepository.getTrendingApps(limit: 12) as List<AppSummary>;
        final recent = await appRepository.getRecentlyUpdatedApps(limit: 12) as List<AppSummary>;
        state = state.copyWith(
          isLoading: false,
          trending: trending.map(_toDoc).toList(),
          recentlyUpdated: recent.map(_toDoc).toList(),
          isOffline: true,
        );
      } catch (e2) {
        state = state.copyWith(isLoading: false, error: e2.toString());
      }
    }
  }

  void _refreshFromIndex() {
    try {
      final collections = discovery.collections(perCollection: 8);
      // Map collections to state fields where possible
      final trending = discovery.trending(limit: 12);
      final newReleases = discovery.newReleases(limit: 12);
      final gems = discovery.hiddenGems(limit: 8);
      // Featured: use first collection or trending
      final featured = collections.isNotEmpty ? collections.first.apps.take(6).toList() : trending.take(6).toList();

      state = state.copyWith(
        isLoading: false,
        featured: featured,
        trending: trending,
        newReleases: newReleases,
        hiddenGems: gems,
        recentlyUpdated: discovery.trending(limit: 12).reversed.take(8).toList(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await discovery.applyDelta();
    _refreshFromIndex();
  }

  SearchDocument _toDoc(AppSummary a) => SearchDocument(
        id: a.id,
        name: a.name,
        developer: a.developer,
        repositoryId: '',
        categories: a.categories,
        description: '',
      );
}
