import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../domain/models/app_entity.dart';

/// Discover page for browsing apps by category
class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({super.key});

  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Utilities',
    'Games',
    'Productivity',
    'Entertainment',
    'Social',
    'News',
    'Music',
    'Photography',
    'Developer Tools',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {
      _selectedCategory = _categories[_tabController.index];
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              title: const Text('Discover'),
              pinned: true,
              floating: true,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: _categories.map((c) => Tab(text: c)).toList(),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: () => _showFilterSheet(context),
                  tooltip: 'Filter',
                ),
              ],
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: _categories.map((category) {
            return _CategoryContent(
              category: category,
              onAppTap: (app) => context.push('/app/${app.id}'),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => const _FilterSheet(),
    );
  }
}

/// Category content widget
class _CategoryContent extends ConsumerWidget {
  final String category;
  final void Function(AppSummary) onAppTap;

  const _CategoryContent({
    required this.category,
    required this.onAppTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Get apps for this category
    final appsAsync = category == 'All'
        ? ref.watch(allAppsProvider)
        : ref.watch(categoryAppsProvider(category));

    return appsAsync.when(
      data: (apps) {
        if (apps.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.apps_outlined,
                  size: 64,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Apps Found',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Add a repository to see apps',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            if (category == 'All') {
              ref.invalidate(allAppsProvider);
            } else {
              ref.invalidate(categoryAppsProvider(category));
            }
          },
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: apps.length,
            itemBuilder: (context, index) {
              final app = apps[index];
              return _AppGridCard(
                app: app,
                onTap: () => onAppTap(app),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text('Error: $error'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (category == 'All') {
                  ref.invalidate(allAppsProvider);
                } else {
                  ref.invalidate(categoryAppsProvider(category));
                }
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Provider for all apps
final allAppsProvider = FutureProvider<List<AppSummary>>((ref) async {
  final appRepo = ref.watch(appRepositoryProvider);
  return appRepo.getAllApps();
});

/// Provider for apps by category
final categoryAppsProvider =
    FutureProvider.family<List<AppSummary>, String>((ref, category) async {
  final appRepo = ref.watch(appRepositoryProvider);
  return appRepo.getAppsByCategory(category);
});

/// App grid card widget
class _AppGridCard extends StatelessWidget {
  final AppSummary app;
  final VoidCallback onTap;

  const _AppGridCard({
    required this.app,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                color: theme.colorScheme.primaryContainer,
                child: app.iconUrl.isNotEmpty
                    ? Image.network(
                        app.iconUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(theme),
                      )
                    : _buildPlaceholder(theme),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.name,
                      style: theme.textTheme.titleSmall?.copyWith(
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
                    const Spacer(),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'v${app.version}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (app.isFavorite == true)
                          Icon(
                            Icons.favorite,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Center(
      child: Icon(
        Icons.apps,
        size: 48,
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );
  }
}

/// Filter sheet
class _FilterSheet extends StatefulWidget {
  const _FilterSheet();

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String _sortBy = 'name';
  bool _showInstalledOnly = false;
  bool _showWithUpdates = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filters',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _sortBy = 'name';
                    _showInstalledOnly = false;
                    _showWithUpdates = false;
                  });
                },
                child: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Sort by',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Name'),
                selected: _sortBy == 'name',
                onSelected: (selected) {
                  if (selected) setState(() => _sortBy = 'name');
                },
              ),
              ChoiceChip(
                label: const Text('Date'),
                selected: _sortBy == 'date',
                onSelected: (selected) {
                  if (selected) setState(() => _sortBy = 'date');
                },
              ),
              ChoiceChip(
                label: const Text('Developer'),
                selected: _sortBy == 'developer',
                onSelected: (selected) {
                  if (selected) setState(() => _sortBy = 'developer');
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Installed only'),
            value: _showInstalledOnly,
            onChanged: (value) => setState(() => _showInstalledOnly = value),
          ),
          SwitchListTile(
            title: const Text('With updates available'),
            value: _showWithUpdates,
            onChanged: (value) => setState(() => _showWithUpdates = value),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
