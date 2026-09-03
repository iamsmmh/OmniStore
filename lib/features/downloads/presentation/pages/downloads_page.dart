import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../domain/models/download_entity.dart';

final downloadsProvider = FutureProvider<List<DownloadEntity>>((ref) async {
  final repo = ref.watch(downloadRepositoryProvider);
  return repo.getAllDownloads();
});

final activeDownloadsProvider = FutureProvider<List<DownloadEntity>>((ref) async {
  final repo = ref.watch(downloadRepositoryProvider);
  return repo.getActiveDownloads();
});

class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(activeDownloadsProvider);
    final allAsync = ref.watch(downloadsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              final repo = ref.read(downloadRepositoryProvider);
              if (v == 'clear') await repo.clearCompletedDownloads();
              ref.invalidate(downloadsProvider);
              ref.invalidate(activeDownloadsProvider);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'clear', child: Text('Clear completed')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(downloadsProvider);
          ref.invalidate(activeDownloadsProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: activeAsync.when(
                data: (active) => active.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Active', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          ...active.map((d) => _DownloadTile(entity: d, isActive: true)),
                        ]),
                      ),
                loading: () => const Padding(padding: EdgeInsets.all(16), child: ShimmerLoading(height: 80)),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
            SliverToBoxAdapter(
              child: allAsync.when(
                data: (all) {
                  final completed = all.where((d) => d.status == DownloadStatus.completed).toList();
                  final failed = all.where((d) => d.status == DownloadStatus.failed).toList();
                  if (all.isEmpty) {
                    return const EmptyState(icon: Icons.download_outlined, title: 'No downloads', subtitle: 'Downloads for your apps will appear here. Progress, verification and resume are handled automatically.');
                  }
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (failed.isNotEmpty) ...[
                        Text('Failed', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        ...failed.map((d) => _DownloadTile(entity: d)),
                        const SizedBox(height: 16),
                      ],
                      Text('History', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      ...completed.take(20).map((d) => _DownloadTile(entity: d)),
                    ]),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (e, _) => EmptyState(icon: Icons.error_outline, title: 'Failed to load downloads', subtitle: e.toString()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadTile extends ConsumerWidget {
  final DownloadEntity entity;
  final bool isActive;
  const _DownloadTile({required this.entity, this.isActive = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(10)), child: Icon(isActive ? Icons.downloading : Icons.file_download_done, color: theme.colorScheme.onPrimaryContainer)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(entity.appName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600), maxLines: 1),
                Text('${entity.fileName} • ${entity.status.name}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ]),
            ),
            if (isActive && entity.status == DownloadStatus.downloading)
              IconButton(icon: const Icon(Icons.pause), onPressed: () async { await ref.read(downloadRepositoryProvider).pauseDownload(entity.id); ref.invalidate(activeDownloadsProvider); })
            else if (entity.status == DownloadStatus.paused || entity.status == DownloadStatus.failed)
              IconButton(icon: const Icon(Icons.play_arrow), onPressed: () async { await ref.read(downloadRepositoryProvider).resumeDownload(entity.id); ref.invalidate(activeDownloadsProvider); })
            else
              PopupMenuButton<String>(
                onSelected: (v) async {
                  final repo = ref.read(downloadRepositoryProvider);
                  if (v == 'retry') await repo.retryDownload(entity.id);
                  if (v == 'delete') await repo.deleteDownload(entity.id);
                  ref.invalidate(downloadsProvider);
                  ref.invalidate(activeDownloadsProvider);
                },
                itemBuilder: (_) => [
                  if (entity.status == DownloadStatus.failed) const PopupMenuItem(value: 'retry', child: Text('Retry')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
          ]),
          if (isActive) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: entity.progress != null ? entity.progress! / 100 : null, borderRadius: BorderRadius.circular(4)),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${entity.progress ?? 0}%', style: theme.textTheme.labelSmall),
              Text('${entity.downloadedSize} / ${entity.totalSize} bytes', style: theme.textTheme.labelSmall),
            ]),
          ],
          if (entity.errorMessage != null && entity.status == DownloadStatus.failed) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(8)),
              child: Text(entity.errorMessage!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onErrorContainer)),
            ),
          ],
        ]),
      ),
    );
  }
}
