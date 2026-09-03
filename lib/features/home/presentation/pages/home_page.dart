import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../providers/navigation_provider.dart';
import '../../../discover/presentation/pages/discover_page.dart' as discover;
import '../../../search/presentation/pages/search_page.dart' as search;
import '../../../updates/presentation/pages/updates_page.dart' as updates;
import '../../../downloads/presentation/pages/downloads_page.dart' as downloads;
import '../../../repositories/presentation/pages/repositories_page.dart' as repos;
import '../../../settings/presentation/pages/settings_page.dart' as settings;

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(currentIndexProvider);

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: const [
          _HomeTab(),
          discover.DiscoverPage(),
          search.SearchPage(),
          updates.UpdatesPage(),
          downloads.DownloadsPage(),
          repos.RepositoriesPage(),
          settings.SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) => ref.read(currentIndexProvider.notifier).state = index,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Discover'),
          NavigationDestination(icon: Icon(Icons.search), selectedIcon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.system_update_outlined), selectedIcon: Icon(Icons.system_update), label: 'Updates'),
          NavigationDestination(icon: Icon(Icons.download_outlined), selectedIcon: Icon(Icons.download), label: 'Downloads'),
          NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: 'Sources'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final syncEngine = ref.watch(syncEngineProvider);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: const Text('OmniStore'),
          actions: [
            StreamBuilder(
              stream: syncEngine.statusStream,
              builder: (context, snapshot) {
                final isSyncing = syncEngine.isSyncing;
                return IconButton(
                  icon: isSyncing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync),
                  onPressed: isSyncing ? null : () => syncEngine.syncAll(),
                  tooltip: 'Sync all',
                );
              },
            ),
            IconButton(icon: const Icon(Icons.search), onPressed: () => ref.read(currentIndexProvider.notifier).state = 2, tooltip: 'Search'),
          ],
          pinned: true,
          floating: true,
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _FeaturedBanner(onExplore: () => ref.read(currentIndexProvider.notifier).state = 1),
              const SizedBox(height: 24),
              Text('Quick Actions', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(children: [
                _QuickActionCard(icon: Icons.system_update, label: 'Updates', color: theme.colorScheme.primary, onTap: () => ref.read(currentIndexProvider.notifier).state = 3),
                const SizedBox(width: 12),
                _QuickActionCard(icon: Icons.favorite, label: 'Favorites', color: theme.colorScheme.tertiary, onTap: () async { final favs = await ref.read(appRepositoryProvider).getFavoriteApps(); if (context.mounted) _showListSheet(context, 'Favorites', favs.map((f) => f.name).toList()); }),
                const SizedBox(width: 12),
                _QuickActionCard(icon: Icons.history, label: 'Recent', color: theme.colorScheme.secondary, onTap: () => ref.read(currentIndexProvider.notifier).state = 2),
                const SizedBox(width: 12),
                _QuickActionCard(icon: Icons.folder, label: 'Sources', color: theme.colorScheme.error, onTap: () => ref.read(currentIndexProvider.notifier).state = 5),
              ]),
              const SizedBox(height: 24),
              Text('Recently Updated', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Offline-ready • cached catalog', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: _RecentlyUpdatedStrip(),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 8),
              Text('Discover', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Curated collections, trending and hidden gems from all your sources', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
            ]),
          ),
        ),
        SliverToBoxAdapter(child: _DiscoverPreview()),
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }

  void _showListSheet(BuildContext context, String title, List<String> items) {
    showModalBottomSheet(context: context, builder: (_) => ListView(padding: const EdgeInsets.all(16), shrinkWrap: true, children: [Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 12), if (items.isEmpty) const Text('Nothing here yet.'), ...items.map((n) => ListTile(title: Text(n))) ]));
  }
}

class _RecentlyUpdatedStrip extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recentlyUpdatedProvider);
    return SizedBox(
      height: 160,
      child: async.when(
        data: (apps) {
          if (apps.isEmpty) return const Center(child: Text('Add sources to see updates'));
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: apps.length > 10 ? 10 : apps.length,
            itemBuilder: (context, index) {
              final app = apps[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _AppCard(name: app.name, developer: app.developer, version: app.version, iconUrl: app.iconUrl, onTap: () => context.push('/app/${app.id}')),
              );
            },
          );
        },
        loading: () => ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: 4, itemBuilder: (_, __) => const Padding(padding: EdgeInsets.only(right: 12), child: ShimmerLoading(width: 140, height: 140))),
        error: (_, __) => const Center(child: Text('Failed to load')),
      ),
    );
  }
}

class _DiscoverPreview extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(discoverPreviewProvider);
    return SizedBox(
      height: 160,
      child: async.when(
        data: (apps) {
          if (apps.isEmpty) return const Center(child: Text('No recommendations yet'));
          return ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: apps.length > 10 ? 10 : apps.length, itemBuilder: (context, index) {
            final app = apps[index];
            return Padding(padding: const EdgeInsets.only(right: 12), child: _AppCard(name: app.name, developer: app.developer, version: app.version, iconUrl: app.iconUrl, onTap: () => context.push('/app/${app.id}')));
          });
        },
        loading: () => ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: 4, itemBuilder: (_, __) => const Padding(padding: EdgeInsets.only(right: 12), child: ShimmerLoading(width: 140, height: 140))),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }
}

final recentlyUpdatedProvider = FutureProvider((ref) async {
  final repo = ref.watch(appRepositoryProvider);
  return repo.getRecentlyUpdatedApps(limit: 12);
});

final discoverPreviewProvider = FutureProvider((ref) async {
  final discovery = ref.watch(discoveryServiceProvider);
  // Ensure warmed
  try {
    await discovery.warmUp();
    final trending = discovery.trending(limit: 8);
    // Map to summaries for display; fallback to repo if empty
    if (trending.isNotEmpty) {
      return trending.map((d) => _DocToSummary(d)).toList();
    }
  } catch (_) {}
  final repo = ref.watch(appRepositoryProvider);
  return repo.getTrendingApps(limit: 8);
});

_IntroSummary _DocToSummary(dynamic doc) {
  try {
    return _IntroSummary(id: doc.id as String, name: doc.name as String, developer: doc.developer as String? ?? '', version: '1.0.0', iconUrl: '');
  } catch (_) {
    return _IntroSummary(id: 'x', name: 'App', developer: '', version: '1.0.0', iconUrl: '');
  }
}

class _IntroSummary {
  final String id, name, developer, version, iconUrl;
  _IntroSummary({required this.id, required this.name, required this.developer, required this.version, required this.iconUrl});
}

class _FeaturedBanner extends StatelessWidget {
  final VoidCallback onExplore;
  const _FeaturedBanner({required this.onExplore});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.primaryContainer], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Stack(children: [
        Positioned(right: -20, bottom: -20, child: Icon(Icons.apps, size: 180, color: theme.colorScheme.onPrimary.withOpacity(0.1))),
        Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Welcome to OmniStore', style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Discover and manage your favorite apps\nfrom trusted repositories.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onPrimary.withOpacity(0.8))),
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: onExplore, child: const Text('Explore')),
        ])),
      ]),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Material(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Column(children: [Icon(icon, color: color, size: 28), const SizedBox(height: 8), Text(label, style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600))]))),
      ),
    );
  }
}

class _AppCard extends StatelessWidget {
  final String name;
  final String developer;
  final String version;
  final String iconUrl;
  final VoidCallback onTap;
  const _AppCard({required this.name, required this.developer, required this.version, required this.iconUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: SizedBox(width: 140, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)), child: iconUrl.isNotEmpty ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(iconUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.apps, color: theme.colorScheme.onPrimaryContainer))) : Icon(Icons.apps, color: theme.colorScheme.onPrimaryContainer)),
        const SizedBox(height: 12),
        Text(name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(developer.isEmpty ? 'Unknown' : developer, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text('v$version', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)),
      ])))),
    );
  }
}
