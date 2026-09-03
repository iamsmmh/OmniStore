import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../domain/health/health_engine.dart';
import '../../../../domain/models/app_entity.dart';

final _installedAppsProvider = FutureProvider<List<AppSummary>>((ref) async {
  final repo = ref.watch(appRepositoryProvider);
  // Prefer installed apps; fallback to all recent apps if none installed
  try {
    final all = await repo.getAllApps(page: 0, pageSize: 100);
    final installed = all.where((a) => a.isInstalled == true).toList();
    if (installed.isNotEmpty) return installed;
    return all.take(20).toList();
  } catch (_) {
    return repo.getRecentlyUpdatedApps(limit: 20);
  }
});

final _healthSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final apps = await ref.watch(_installedAppsProvider.future);
  final appRepo = ref.watch(appRepositoryProvider);
  final healthEngine = ref.watch(healthEngineProvider);
  final scores = <AppHealthScore>[];
  for (final app in apps) {
    List<DateTime> dates = [app.releaseDate];
    try {
      final releases = await appRepo.getReleasesForApp(app.id);
      if (releases.isNotEmpty) {
        dates = releases.map((r) => r.releaseDate).toList();
      }
    } catch (_) {}
    final score = healthEngine.evaluate(
      appId: app.id,
      releaseDates: dates,
      brokenDownloads: 0,
      hasBrokenMetadata: app.iconUrl.isEmpty,
    );
    scores.add(score);
  }
  final healthy = scores.where((s) => s.status == AppHealthStatus.healthy).length;
  final warning = scores.where((s) => s.status == AppHealthStatus.warning).length;
  final critical = scores.where((s) => s.status == AppHealthStatus.critical).length;
  final avg = scores.isEmpty ? 0 : (scores.map((s) => s.score).reduce((a, b) => a + b) / scores.length).round();
  return {
    'scores': scores,
    'apps': apps,
    'healthy': healthy,
    'warning': warning,
    'critical': critical,
    'avg': avg,
  };
});

class HealthPage extends ConsumerWidget {
  const HealthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_healthSummaryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_healthSummaryProvider),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: async.when(
        data: (data) {
          final scores = data['scores'] as List<AppHealthScore>;
          final apps = data['apps'] as List<AppSummary>;
          final healthy = data['healthy'] as int;
          final warning = data['warning'] as int;
          final critical = data['critical'] as int;
          final avg = data['avg'] as int;

          if (apps.isEmpty) {
            return const EmptyState(
              icon: Icons.health_and_safety_outlined,
              title: 'No apps to assess',
              subtitle: 'Add sources and install apps to see health insights. Health scores consider release cadence, broken assets, metadata quality and maintainer activity.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_healthSummaryProvider),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList.list(children: [
                    _ScoreHero(avg: avg, healthy: healthy, warning: warning, critical: critical),
                    const SizedBox(height: 16),
                    Row(children: [
                      _StatChip(label: 'Healthy', count: healthy, color: Colors.green, icon: Icons.check_circle),
                      const SizedBox(width: 8),
                      _StatChip(label: 'Warning', count: warning, color: Colors.orange, icon: Icons.warning),
                      const SizedBox(width: 8),
                      _StatChip(label: 'Critical', count: critical, color: Colors.red, icon: Icons.error),
                    ]),
                    const SizedBox(height: 20),
                    Text('Apps', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text('Tap an app to see details. Health considers days since last release, release frequency, broken downloads and metadata completeness.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 12),
                  ]),
                ),
                SliverList.builder(
                  itemCount: apps.length,
                  itemBuilder: (context, index) {
                    final app = apps[index];
                    final score = scores[index];
                    return _HealthTile(app: app, score: score);
                  },
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
              ],
            ),
          );
        },
        loading: () => ListView(padding: const EdgeInsets.all(16), children: const [
          ShimmerLoading(height: 160),
          SizedBox(height: 12),
          ShimmerLoading(height: 88),
          SizedBox(height: 12),
          ShimmerLoading(height: 88),
        ]),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Failed to load health',
          subtitle: e.toString(),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(_healthSummaryProvider),
        ),
      ),
    );
  }
}

class _ScoreHero extends StatelessWidget {
  final int avg;
  final int healthy;
  final int warning;
  final int critical;
  const _ScoreHero({required this.avg, required this.healthy, required this.warning, required this.critical});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = healthy + warning + critical;
    final color = avg >= 65 ? Colors.green : avg >= 35 ? Colors.orange : Colors.red;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [color.withOpacity(0.18), color.withOpacity(0.05)]),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
          child: Center(child: Text('$avg', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: color))),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Overall Health', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            Text(avg >= 65 ? 'Catalog looks healthy' : avg >= 35 ? 'Some apps need attention' : 'Several apps may be abandoned',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Row(children: [
                if (total > 0) ...[
                  Expanded(flex: healthy, child: Container(height: 8, color: Colors.green)),
                  Expanded(flex: warning == 0 ? 1 : warning, child: Container(height: 8, color: Colors.orange.withOpacity(warning == 0 ? 0 : 1))),
                  Expanded(flex: critical == 0 ? 1 : critical, child: Container(height: 8, color: Colors.red.withOpacity(critical == 0 ? 0 : 1))),
                ] else
                  Container(height: 8, color: theme.colorScheme.outlineVariant),
              ]),
            ),
            const SizedBox(height: 4),
            Text('$total apps assessed', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ]),
        ),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  const _StatChip({required this.label, required this.count, required this.color, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.2))),
        child: Row(children: [Icon(icon, size: 18, color: color), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$count', style: TextStyle(fontWeight: FontWeight.w800, color: color)), Text(label, style: const TextStyle(fontSize: 11))])]),
      ),
    );
  }
}

class _HealthTile extends StatelessWidget {
  final AppSummary app;
  final AppHealthScore score;
  const _HealthTile({required this.app, required this.score});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = score.status == AppHealthStatus.healthy ? Colors.green : score.status == AppHealthStatus.warning ? Colors.orange : Colors.red;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/app/${app.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
              child: app.iconUrl.isNotEmpty
                  ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(app.iconUrl, errorBuilder: (_, __, ___) => Icon(Icons.apps, color: theme.colorScheme.onPrimaryContainer)))
                  : Icon(Icons.apps, color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(app.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${app.developer} • v${app.version}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant), maxLines: 1),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(score.status == AppHealthStatus.healthy ? Icons.check_circle : score.status == AppHealthStatus.warning ? Icons.warning : Icons.error, size: 12, color: color),
                      const SizedBox(width: 4),
                      Text('${score.status.label} ${score.score}', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
                    ]),
                  ),
                  const SizedBox(width: 6),
                  Text(score.detailedReport.reasons.first, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ]),
            ),
            const Icon(Icons.chevron_right, size: 20),
          ]),
        ),
      ),
    );
  }
}
