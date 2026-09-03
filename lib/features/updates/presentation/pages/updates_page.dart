import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../domain/updates/update_intelligence.dart';
import '../../../../core/versioning/semantic_version.dart';

final updatesProvider = FutureProvider<List<UpdateVerdict>>((ref) async {
  final appRepo = ref.watch(appRepositoryProvider);
  final intel = ref.watch(updateIntelligenceProvider);
  final installed = await appRepo.getInstalled();
  // Build candidates from installed vs latest
  final candidates = <ReleaseCandidate>[];
  for (final summary in installed) {
    try {
      final entity = await appRepo.getAppById(summary.id);
      if (entity == null) continue;
      if (entity.version == summary.installedVersion) continue;
      // Only newer versions
      final newer = SemanticVersion.tryParse(entity.version) != null && SemanticVersion.tryParse(summary.installedVersion ?? '0.0.0') != null
          ? SemanticVersion.parse(entity.version).compareTo(SemanticVersion.parse(summary.installedVersion!)) > 0
          : entity.version != summary.installedVersion;
      if (!newer) continue;
      candidates.add(ReleaseCandidate(
        appId: entity.id,
        installedVersion: summary.installedVersion ?? '0.0.0',
        latestVersion: entity.version,
        changelog: entity.changelog,
        releaseDate: entity.releaseDate,
        downloadSize: entity.downloadSize,
        sha256: entity.sha256,
        minOsVersion: entity.minOsVersion,
      ));
    } catch (_) {}
  }
  return intel.analyzeAll(candidates);
});

class UpdatesPage extends ConsumerWidget {
  const UpdatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(updatesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Updates'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(updatesProvider)),
        ],
      ),
      body: async.when(
        data: (verdicts) {
          if (verdicts.isEmpty) {
            return const EmptyState(icon: Icons.system_update, title: 'All up to date', subtitle: 'No updates available. We check automatically in the background.');
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(updatesProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SummaryBar(verdicts: verdicts),
                const SizedBox(height: 16),
                ...verdicts.map((v) => _UpdateTile(verdict: v)),
              ],
            ),
          );
        },
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 4,
          itemBuilder: (_, __) => const Padding(padding: EdgeInsets.only(bottom: 12), child: ShimmerLoading(height: 96)),
        ),
        error: (e, _) => EmptyState(icon: Icons.error_outline, title: 'Failed to load updates', subtitle: e.toString(), actionLabel: 'Retry', onAction: () => ref.invalidate(updatesProvider)),
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final List<UpdateVerdict> verdicts;
  const _SummaryBar({required this.verdicts});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final critical = verdicts.where((v) => v.urgency == UpdateUrgency.critical).length;
    final important = verdicts.where((v) => v.urgency == UpdateUrgency.important).length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(Icons.system_update, color: theme.colorScheme.onPrimaryContainer, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${verdicts.length} updates available', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                critical > 0 ? '$critical critical, $important important' : important > 0 ? '$important important updates' : 'All routine updates',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8)),
              ),
            ]),
          ),
          if (critical > 0 || important > 0)
            FilledButton(onPressed: () {}, child: const Text('Update all')),
        ],
      ),
    );
  }
}

class _UpdateTile extends StatelessWidget {
  final UpdateVerdict verdict;
  const _UpdateTile({required this.verdict});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              Expanded(child: Text('${verdict.appId}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
              _UrgencyBadge(urgency: verdict.urgency),
            ],
          ),
          const SizedBox(height: 4),
          Text('${verdict.fromVersion} → ${verdict.toVersion} • ${verdict.bumpType.name}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text(verdict.summary, style: theme.textTheme.bodyMedium),
          if (verdict.signals.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: verdict.signals.map((s) => Chip(label: Text(s.label, style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact)).toList()),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => context.push('/app/${verdict.appId}'), child: const Text('Details'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(onPressed: () {}, child: const Text('Update'))),
          ]),
        ]),
      ),
    );
  }
}

class _UrgencyBadge extends StatelessWidget {
  final UpdateUrgency urgency;
  const _UrgencyBadge({required this.urgency});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (urgency) {
      UpdateUrgency.critical => ('Critical', theme.colorScheme.error),
      UpdateUrgency.important => ('High', Colors.orange),
      UpdateUrgency.routine => ('Medium', theme.colorScheme.primary),
      UpdateUrgency.optional => ('Low', theme.colorScheme.outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
      child: Text(label, style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}
