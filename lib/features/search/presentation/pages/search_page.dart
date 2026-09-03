import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../providers/search_provider.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final q = _controller.text;
      ref.read(searchNotifierProvider.notifier).searchDebounced(q);
      if (q.length >= 2) ref.read(searchNotifierProvider.notifier).getSuggestions(q);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(68),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'Search apps, developers, categories',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _controller.clear();
                              ref.read(searchNotifierProvider.notifier).search('');
                            },
                          )
                        : null,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (v) => ref.read(searchNotifierProvider.notifier).search(v),
                ),
                const SizedBox(height: 8),
                _FilterChips(),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(state, theme),
    );
  }

  Widget _buildBody(SearchState state, ThemeData theme) {
    if (state.isLoading) {
      return ListView.builder(
        itemCount: 6,
        padding: const EdgeInsets.all(16),
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: ShimmerLoading(height: 72, borderRadius: BorderRadius.all(Radius.circular(16))),
        ),
      );
    }
    if (state.error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Search failed',
        subtitle: state.error,
        actionLabel: 'Retry',
        onAction: () => ref.read(searchNotifierProvider.notifier).search(state.query),
      );
    }
    if (state.query.isEmpty) {
      if (state.recentSearches.isEmpty && state.suggestions.isEmpty) {
        return EmptyState(
          icon: Icons.search,
          title: 'Search OmniStore',
          subtitle: 'Find apps across all your trusted repositories.\nTry searching for a name, developer or category.',
        );
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (state.suggestions.isNotEmpty) ...[
            Text('Suggestions', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: state.suggestions
                  .map((s) => ActionChip(label: Text(s), onPressed: () {
                        _controller.text = s;
                        ref.read(searchNotifierProvider.notifier).search(s);
                      }))
                  .toList(),
            ),
            const SizedBox(height: 20),
          ],
          if (state.recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent searches', style: theme.textTheme.titleMedium),
                TextButton(
                  onPressed: () => ref.read(searchNotifierProvider.notifier).clearRecentSearches(),
                  child: const Text('Clear'),
                ),
              ],
            ),
            ...state.recentSearches.map((r) => ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(r),
                  onTap: () {
                    _controller.text = r;
                    ref.read(searchNotifierProvider.notifier).search(r);
                  },
                  trailing: const Icon(Icons.north_west, size: 16),
                )),
          ],
        ],
      );
    }
    if (state.results.isEmpty) {
      final correction = state.correctedQuery;
      return EmptyState(
        icon: Icons.search_off,
        title: 'No results',
        subtitle: correction != null
            ? 'No results for "${state.query}". Did you mean "$correction"?'
            : 'No apps matched "${state.query}". Try a different term.',
        actionLabel: correction != null ? 'Search "$correction"' : null,
        onAction: correction != null
            ? () {
                _controller.text = correction;
                ref.read(searchNotifierProvider.notifier).search(correction);
              }
            : null,
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text('${state.results.length} results', style: theme.textTheme.labelLarge),
              if (state.correctedQuery != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text('Showing results for "${state.query}"',
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ),
              ],
              const Spacer(),
              if (state.isOffline) const Icon(Icons.cloud_off, size: 18),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: state.results.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final app = state.results[index];
              return Card(
                child: ListTile(
                  leading: app.iconUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(app.iconUrl, width: 48, height: 48, errorBuilder: (_, __, ___) => _FallbackIcon()),
                        )
                      : _FallbackIcon(),
                  title: Text(app.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${app.developer} • v${app.version}', maxLines: 1),
                  trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
                  onTap: () => context.push('/app/${app.id}'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterChips extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(selectedCategoryProvider);
    final source = ref.watch(selectedSourceProvider);
    final categories = ['Games', 'Productivity', 'Utilities', 'Social', 'Music', 'Developer'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            label: Text(category ?? 'All categories'),
            selected: category != null,
            onSelected: (_) => _showCategorySheet(context, ref),
            avatar: const Icon(Icons.category, size: 18),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(source == null ? 'All sources' : source),
            selected: source != null,
            onSelected: (_) => _showSourceSheet(context, ref),
            avatar: const Icon(Icons.source, size: 18),
          ),
          if (category != null || source != null) ...[
            const SizedBox(width: 8),
            ActionChip(
              label: const Text('Clear'),
              avatar: const Icon(Icons.clear, size: 18),
              onPressed: () {
                ref.read(selectedCategoryProvider.notifier).state = null;
                ref.read(selectedSourceProvider.notifier).state = null;
                final q = ref.read(searchQueryProvider);
                if (q.isNotEmpty) ref.read(searchNotifierProvider.notifier).search(q);
              },
            ),
          ],
        ],
      ),
    );
  }

  void _showCategorySheet(BuildContext context, WidgetRef ref) {
    final categories = ['Games', 'Productivity', 'Utilities', 'Social', 'Music', 'Developer', 'Photo', 'Health'];
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('Select category', style: TextStyle(fontWeight: FontWeight.w600))),
          ListTile(title: const Text('All categories'), onTap: () { ref.read(selectedCategoryProvider.notifier).state = null; Navigator.pop(context); final q = ref.read(searchQueryProvider); if (q.isNotEmpty) ref.read(searchNotifierProvider.notifier).search(q); }),
          ...categories.map((c) => ListTile(title: Text(c), onTap: () { ref.read(searchNotifierProvider.notifier).setCategory(c); Navigator.pop(context); })),
        ],
      ),
    );
  }

  void _showSourceSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final reposAsync = ref.watch(repositoriesListProvider);
          return ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('Select source', style: TextStyle(fontWeight: FontWeight.w600))),
              ListTile(title: const Text('All sources'), onTap: () { ref.read(searchNotifierProvider.notifier).setSource(null); Navigator.pop(context); }),
              ...reposAsync.when(
                data: (repos) => repos.map((r) => ListTile(title: Text(r.name), subtitle: Text(r.url), onTap: () { ref.read(searchNotifierProvider.notifier).setSource(r.id); Navigator.pop(context); })).toList(),
                loading: () => const [ListTile(title: Text('Loading...'))],
                error: (_, __) => const [ListTile(title: Text('Failed to load sources'))],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
      child: Icon(Icons.apps, color: theme.colorScheme.onPrimaryContainer),
    );
  }
}

// Provider to fetch repositories for filter sheet
final repositoriesListProvider = FutureProvider((ref) async {
  final manager = ref.watch(repositoryManagerProvider);
  return manager.getAllRepositories();
});
