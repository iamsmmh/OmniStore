import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../domain/models/app_entity.dart';

/// Search page for finding apps
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounceTimer;
  String _query = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _loadRecentSearches() {
    // Load from secure storage or preferences
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _query = query;
        _isSearching = query.isNotEmpty;
      });
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _query = '';
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: 'Search apps...',
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearSearch,
                  )
                : null,
          ),
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: (query) {
            if (query.isNotEmpty) {
              _performSearch(query);
            }
          },
        ),
      ),
      body: _query.isEmpty ? _buildSuggestions() : _buildResults(),
    );
  }

  Widget _buildSuggestions() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Categories section
          Text(
            'Categories',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CategoryChip(label: 'Utilities', icon: Icons.build),
              _CategoryChip(label: 'Games', icon: Icons.games),
              _CategoryChip(label: 'Productivity', icon: Icons.work),
              _CategoryChip(label: 'Entertainment', icon: Icons.movie),
              _CategoryChip(label: 'Social', icon: Icons.people),
              _CategoryChip(label: 'News', icon: Icons.newspaper),
            ],
          ),
          const SizedBox(height: 24),
          // Popular searches
          Text(
            'Popular',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _SearchSuggestionItem(
            icon: Icons.trending_up,
            title: 'Trending Apps',
            onTap: () => _performSearch('trending'),
          ),
          _SearchSuggestionItem(
            icon: Icons.star,
            title: 'Top Rated',
            onTap: () => _performSearch('top rated'),
          ),
          _SearchSuggestionItem(
            icon: Icons.access_time,
            title: 'Recently Updated',
            onTap: () => _performSearch('recent'),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    return SearchResults(query: _query);
  }

  void _performSearch(String query) {
    setState(() {
      _query = query;
      _searchController.text = query;
      _isSearching = true;
    });
  }
}

/// Category chip widget
class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap ?? () {},
    );
  }
}

/// Search suggestion item
class _SearchSuggestionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SearchSuggestionItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.outline),
      title: Text(title),
      trailing: const Icon(Icons.north_west, size: 18),
      onTap: onTap,
    );
  }
}

/// Search results widget
class SearchResults extends ConsumerWidget {
  final String query;

  const SearchResults({super.key, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(searchResultsProvider(query));

    return resultsAsync.when(
      data: (apps) {
        if (apps.isEmpty) {
          return _NoResultsState(query: query);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: apps.length,
          itemBuilder: (context, index) {
            final app = apps[index];
            return _SearchResultCard(
              app: app,
              onTap: () => context.push('/app/${app.id}'),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text('Search failed: $error'),
          ],
        ),
      ),
    );
  }
}

/// Provider for search results
final searchResultsProvider =
    FutureProvider.family<List<AppSummary>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final appRepo = ref.watch(appRepositoryProvider);
  return appRepo.searchApps(query);
});

/// No results state
class _NoResultsState extends StatelessWidget {
  final String query;

  const _NoResultsState({required this.query});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No Results',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'No apps found for "$query"',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Search result card
class _SearchResultCard extends StatelessWidget {
  final AppSummary app;
  final VoidCallback onTap;

  const _SearchResultCard({
    required this.app,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: app.iconUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          app.iconUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.apps,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.apps,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      app.developer,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (app.categories.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              app.categories.first,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          'v${app.version}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (app.isFavorite == true)
                Icon(
                  Icons.favorite,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
