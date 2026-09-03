import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/common_widgets.dart';
import '../../../../domain/discovery/search_index.dart';
import '../providers/discover_provider.dart';

class DiscoverPage extends ConsumerWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(discoverAppsProvider);
    final notifier = ref.read(discoverAppsProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => notifier.refresh()),
        ],
      ),
      body: _buildBody(context, state, notifier, theme),
    );
  }

  Widget _buildBody(BuildContext context, DiscoverState state, DiscoverNotifier notifier, ThemeData theme) {
    if (state.isLoading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ShimmerLoading(height: 180, borderRadius: BorderRadius.all(Radius.circular(20))),
          const SizedBox(height: 24),
          const ShimmerLoading(height: 24, width: 160),
          const SizedBox(height: 12),
          SizedBox(height: 160, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: 4, itemBuilder: (_, __) => const Padding(padding: EdgeInsets.only(right: 12), child: ShimmerLoading(width: 140, height: 140)))),
        ],
      );
    }
    if (state.error != null) {
      return EmptyState(icon: Icons.explore_off, title: 'Failed to load', subtitle: state.error, actionLabel: 'Retry', onAction: () => notifier.loadDiscoverData());
    }
    if (state.featured.isEmpty && state.trending.isEmpty && state.newReleases.isEmpty) {
      return EmptyState(
        icon: Icons.explore,
        title: 'No content yet',
        subtitle: 'Add repositories to discover apps. Your catalog is offline-ready once synced.',
        actionLabel: 'Manage Sources',
        onAction: () => context.go('/repositories'),
      );
    }

    return RefreshIndicator(
      onRefresh: () => notifier.refresh(),
      child: CustomScrollView(
        slivers: [
          if (state.isOffline)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [Icon(Icons.cloud_off, color: theme.colorScheme.onErrorContainer), const SizedBox(width: 8), Expanded(child: Text('Offline — showing cached content', style: TextStyle(color: theme.colorScheme.onErrorContainer)))]),
              ),
            ),
          if (state.featured.isNotEmpty) ...[
            SliverToBoxAdapter(child: _SectionHeader(title: 'Featured', subtitle: 'Hand-picked for you')),
            SliverToBoxAdapter(child: SizedBox(height: 190, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: state.featured.length, itemBuilder: (c, i) => _AppCard(doc: state.featured[i])))),
          ],
          if (state.trending.isNotEmpty) ...[
            SliverToBoxAdapter(child: _SectionHeader(title: 'Trending', subtitle: 'Popular right now', onSeeAll: () {})),
            SliverToBoxAdapter(child: SizedBox(height: 160, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: state.trending.length, itemBuilder: (c, i) => _AppCard(doc: state.trending[i])))),
          ],
          if (state.newReleases.isNotEmpty) ...[
            SliverToBoxAdapter(child: _SectionHeader(title: 'New & Updated', subtitle: 'Fresh from repositories')),
            SliverToBoxAdapter(child: SizedBox(height: 160, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: state.newReleases.length, itemBuilder: (c, i) => _AppCard(doc: state.newReleases[i])))),
          ],
          if (state.hiddenGems.isNotEmpty) ...[
            SliverToBoxAdapter(child: _SectionHeader(title: 'Hidden Gems', subtitle: 'Great apps you may have missed')),
            SliverToBoxAdapter(child: SizedBox(height: 160, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: state.hiddenGems.length, itemBuilder: (c, i) => _AppCard(doc: state.hiddenGems[i])))),
          ],
          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;
  const _SectionHeader({required this.title, this.subtitle, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              if (subtitle != null) Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ]),
          ),
          if (onSeeAll != null) TextButton(onPressed: onSeeAll, child: const Text('See all')),
        ],
      ),
    );
  }
}

class _AppCard extends StatelessWidget {
  final SearchDocument doc;
  const _AppCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/app/${doc.id}'),
          child: SizedBox(
            width: 140,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 48, height: 48, decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.apps, color: theme.colorScheme.onPrimaryContainer)),
                const SizedBox(height: 12),
                Text(doc.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(doc.developer.isEmpty ? 'Unknown' : doc.developer, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(doc.categories.isNotEmpty ? doc.categories.first : 'App', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
