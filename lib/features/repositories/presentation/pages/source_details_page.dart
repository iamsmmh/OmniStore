import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../domain/health/health_engine.dart';
import '../../../../domain/models/repository_entity.dart';
import '../../../../domain/security/trust_analyzer.dart';
import '../../../../domain/security/trust_engine.dart';

class SourceDetailsPage extends ConsumerWidget {
  final String repositoryId;
  const SourceDetailsPage({super.key, required this.repositoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(repositoryDetailsProvider(repositoryId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Source Details')),
      body: async.when(
        data: (repo) {
          if (repo == null) return const EmptyState(icon: Icons.folder_off, title: 'Source not found');
          final appCount = repo.appCount ?? 0;
          final healthEngine = ref.watch(healthEngineProvider);
          final trustEngine = ref.watch(trustEngineProvider);

          // Synthesize health/trust for repo
          final health = healthEngine.evaluate(appId: repo.id, releaseDates: repo.lastSynced != null ? [repo.lastSynced!] : []);
          final trust = trustEngine.evaluate(RepositoryTrustInput(repositoryId: repo.id, url: repo.url, appCount: appCount, checksumCoverage: 0.8, metadataCompleteness: 0.9, httpsAssetRatio: 1));

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList.list(children: [
                  Row(children: [
                    Container(width: 64, height: 64, decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(16)), child: repo.iconUrl != null && repo.iconUrl!.isNotEmpty ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(repo.iconUrl!, errorBuilder: (_, __, ___) => Icon(Icons.folder, color: theme.colorScheme.onPrimaryContainer, size: 32))) : Icon(Icons.folder, color: theme.colorScheme.onPrimaryContainer, size: 32)),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(repo.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)), Text(repo.url, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant), maxLines: 2), const SizedBox(height: 4), Text('${repo.type.name} • ${repo.isEnabled ? "Enabled" : "Disabled"}', style: theme.textTheme.labelSmall)])),
                  ]),
                  const SizedBox(height: 16),
                  if (repo.description != null) ...[Text(repo.description!, style: theme.textTheme.bodyMedium), const SizedBox(height: 16)],
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _ScoreBadge(label: 'Health ${health.score}', status: health.status.label, color: health.status == AppHealthStatus.healthy ? Colors.green : health.status == AppHealthStatus.warning ? Colors.orange : Colors.red),
                    _ScoreBadge(label: 'Trust ${trust.score}', status: trust.category.label, color: trust.category == TrustCategory.verified || trust.category == TrustCategory.trusted ? Colors.green : trust.category == TrustCategory.risky ? Colors.red : Colors.orange),
                    _ScoreBadge(label: '$appCount apps', status: 'Catalog', color: theme.colorScheme.primary),
                  ]),
                  const SizedBox(height: 24),
                  Text('Details', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(children: [
                      _DetailTile(icon: Icons.person, label: 'Maintainer', value: repo.maintainer ?? 'Unknown'),
                      _DetailTile(icon: Icons.calendar_today, label: 'Added', value: repo.addedAt.toString().split(' ').first),
                      _DetailTile(icon: Icons.sync, label: 'Last sync', value: repo.lastSynced?.toString().split(' ').first ?? 'Never'),
                      _DetailTile(icon: Icons.apps, label: 'App count', value: '$appCount'),
                      _DetailTile(icon: Icons.link, label: 'URL', value: repo.url),
                      if (repo.lastError != null) Padding(padding: const EdgeInsets.all(12), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)), child: Row(children: [Icon(Icons.error, color: theme.colorScheme.onErrorContainer, size: 18), const SizedBox(width: 8), Expanded(child: Text(repo.lastError!, style: TextStyle(color: theme.colorScheme.onErrorContainer, fontSize: 12)))]))),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Text('Actions', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(children: [
                      ListTile(leading: const Icon(Icons.sync), title: const Text('Sync now'), onTap: () async { final m = ref.read(repositoryManagerProvider); await m.syncRepository(repo.id); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sync completed'))); ref.invalidate(repositoryDetailsProvider(repo.id)); }),
                      ListTile(leading: Icon(repo.isEnabled ? Icons.pause : Icons.play_arrow), title: Text(repo.isEnabled ? 'Disable' : 'Enable'), onTap: () async { final m = ref.read(repositoryManagerProvider); await m.setEnabled(repo.id, !repo.isEnabled); ref.invalidate(repositoryDetailsProvider(repo.id)); }),
                      ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text('Remove source', style: TextStyle(color: Colors.red)), onTap: () async { final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Remove source?'), content: const Text('Apps from this source will be removed.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove'))])); if (confirm == true) { final m = ref.read(repositoryManagerProvider); await m.removeRepository(repo.id); if (context.mounted) Navigator.pop(context); } }),
                    ]),
                  ),
                ]),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(icon: Icons.error_outline, title: 'Failed to load', subtitle: e.toString()),
      ),
    );
  }
}

final repositoryDetailsProvider = FutureProvider.family<RepositoryEntity?, String>((ref, id) async {
  final m = ref.watch(repositoryManagerProvider);
  return m.getRepositoryById(id);
});

class _ScoreBadge extends StatelessWidget {
  final String label;
  final String status;
  final Color color;
  const _ScoreBadge({required this.label, required this.status, required this.color});

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))), child: Text('$label • $status', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)));
}

class _DetailTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => ListTile(leading: Icon(icon, size: 20), title: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)), subtitle: Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)), isThreeLine: value.length > 40);
}
