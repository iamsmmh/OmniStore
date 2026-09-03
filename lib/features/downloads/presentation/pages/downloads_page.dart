import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

import '../../../../core/di/providers.dart';
import '../../../../domain/models/download_entity.dart';

/// Downloads management page
class DownloadsPage extends ConsumerStatefulWidget {
  const DownloadsPage({super.key});

  @override
  ConsumerState<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends ConsumerState<DownloadsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDownloads();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDownloads() async {
    ref.invalidate(downloadsProvider);
    ref.invalidate(activeDownloadsProvider);
    ref.invalidate(completedDownloadsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDownloads,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
            Tab(text: 'Queue'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ActiveDownloadsTab(),
          _CompletedDownloadsTab(),
          _QueueTab(),
        ],
      ),
    );
  }
}

/// Provider for all downloads
final downloadsProvider = FutureProvider<List<DownloadEntity>>((ref) async {
  final downloadRepo = ref.watch(downloadRepositoryProvider);
  return downloadRepo.getAllDownloads();
});

/// Provider for active downloads
final activeDownloadsProvider =
    FutureProvider<List<DownloadEntity>>((ref) async {
  final downloadRepo = ref.watch(downloadRepositoryProvider);
  return downloadRepo.getActiveDownloads();
});

/// Provider for completed downloads
final completedDownloadsProvider =
    FutureProvider<List<DownloadEntity>>((ref) async {
  final downloadRepo = ref.watch(downloadRepositoryProvider);
  final history = await downloadRepo.getDownloadHistory();
  return history
      .where((d) =>
          d.status == DownloadStatus.completed ||
          d.status == DownloadStatus.failed ||
          d.status == DownloadStatus.cancelled)
      .toList();
});

class _ActiveDownloadsTab extends ConsumerWidget {
  const _ActiveDownloadsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadsAsync = ref.watch(activeDownloadsProvider);
    final theme = Theme.of(context);

    return downloadsAsync.when(
      data: (downloads) {
        if (downloads.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.download_outlined,
                  size: 64,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Active Downloads',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Downloads in progress will appear here',
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
            ref.invalidate(activeDownloadsProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: downloads.length,
            itemBuilder: (context, index) {
              final download = downloads[index];
              return _ActiveDownloadCard(
                download: download,
                onPause: () => _pauseDownload(ref, download),
                onResume: () => _resumeDownload(ref, download),
                onCancel: () => _cancelDownload(ref, download),
                onRetry: () => _retryDownload(ref, download),
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
              onPressed: () => ref.invalidate(activeDownloadsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pauseDownload(WidgetRef ref, DownloadEntity download) async {
    try {
      final downloadRepo = ref.read(downloadRepositoryProvider);
      await downloadRepo.pauseDownload(download.id);
      ref.invalidate(activeDownloadsProvider);
    } catch (e) {
      debugPrint('Failed to pause download: $e');
    }
  }

  Future<void> _resumeDownload(WidgetRef ref, DownloadEntity download) async {
    try {
      final downloadRepo = ref.read(downloadRepositoryProvider);
      await downloadRepo.resumeDownload(download.id);
      ref.invalidate(activeDownloadsProvider);
    } catch (e) {
      debugPrint('Failed to resume download: $e');
    }
  }

  Future<void> _cancelDownload(WidgetRef ref, DownloadEntity download) async {
    try {
      final downloadRepo = ref.read(downloadRepositoryProvider);
      await downloadRepo.cancelDownload(download.id);
      ref.invalidate(activeDownloadsProvider);
    } catch (e) {
      debugPrint('Failed to cancel download: $e');
    }
  }

  Future<void> _retryDownload(WidgetRef ref, DownloadEntity download) async {
    try {
      final downloadRepo = ref.read(downloadRepositoryProvider);
      await downloadRepo.retryDownload(download.id);
      ref.invalidate(activeDownloadsProvider);
    } catch (e) {
      debugPrint('Failed to retry download: $e');
    }
  }
}

class _CompletedDownloadsTab extends ConsumerWidget {
  const _CompletedDownloadsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadsAsync = ref.watch(completedDownloadsProvider);
    final theme = Theme.of(context);

    return downloadsAsync.when(
      data: (downloads) {
        if (downloads.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 64,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Download History',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Completed and failed downloads appear here',
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
            ref.invalidate(completedDownloadsProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: downloads.length,
            itemBuilder: (context, index) {
              final download = downloads[index];
              return _CompletedDownloadCard(
                download: download,
                onDelete: () => _deleteDownload(ref, download),
                onRetry: () => _retryDownload(ref, download),
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
          ],
        ),
      ),
    );
  }

  Future<void> _deleteDownload(WidgetRef ref, DownloadEntity download) async {
    try {
      final downloadRepo = ref.read(downloadRepositoryProvider);
      await downloadRepo.deleteDownload(download.id);
      ref.invalidate(completedDownloadsProvider);
    } catch (e) {
      debugPrint('Failed to delete download: $e');
    }
  }

  Future<void> _retryDownload(WidgetRef ref, DownloadEntity download) async {
    try {
      final downloadRepo = ref.read(downloadRepositoryProvider);
      await downloadRepo.retryDownload(download.id);
      ref.invalidate(completedDownloadsProvider);
      ref.invalidate(activeDownloadsProvider);
    } catch (e) {
      debugPrint('Failed to retry download: $e');
    }
  }
}

class _QueueTab extends ConsumerWidget {
  const _QueueTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadsAsync = ref.watch(activeDownloadsProvider);
    final theme = Theme.of(context);

    return downloadsAsync.when(
      data: (downloads) {
        final pendingDownloads =
            downloads.where((d) => d.status == DownloadStatus.pending).toList();

        if (pendingDownloads.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.queue,
                  size: 64,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'Queue Empty',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Pending downloads will appear here',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pendingDownloads.length,
          itemBuilder: (context, index) {
            final download = pendingDownloads[index];
            return _QueuedDownloadCard(
              download: download,
              position: index + 1,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }
}

class _ActiveDownloadCard extends StatelessWidget {
  final DownloadEntity download;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback onRetry;

  const _ActiveDownloadCard({
    required this.download,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = download.totalSize > 0
        ? download.downloadedSize / download.totalSize
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getStatusIcon(),
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        download.appName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (download.version != null)
                        Text(
                          'v${download.version}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                ),
                _buildStatusChip(theme),
              ],
            ),
            const SizedBox(height: 16),
            LinearPercentIndicator(
              padding: EdgeInsets.zero,
              lineHeight: 8,
              percent: progress.clamp(0.0, 1.0),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              progressColor: _getProgressColor(theme),
              barRadius: const Radius.circular(4),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatBytes(download.downloadedSize),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(1)}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatBytes(download.totalSize),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (download.status == DownloadStatus.downloading)
                  IconButton(
                    icon: const Icon(Icons.pause),
                    onPressed: onPause,
                    tooltip: 'Pause',
                  ),
                if (download.status == DownloadStatus.paused)
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: onResume,
                    tooltip: 'Resume',
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onCancel,
                  tooltip: 'Cancel',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (download.status) {
      case DownloadStatus.pending:
        return Icons.hourglass_empty;
      case DownloadStatus.downloading:
        return Icons.downloading;
      case DownloadStatus.paused:
        return Icons.pause;
      case DownloadStatus.completed:
        return Icons.check_circle;
      case DownloadStatus.failed:
        return Icons.error;
      case DownloadStatus.cancelled:
        return Icons.cancel;
    }
  }

  Widget _buildStatusChip(ThemeData theme) {
    Color chipColor;
    String label;

    switch (download.status) {
      case DownloadStatus.pending:
        chipColor = Colors.orange;
        label = 'Queued';
        break;
      case DownloadStatus.downloading:
        chipColor = theme.colorScheme.primary;
        label = 'Downloading';
        break;
      case DownloadStatus.paused:
        chipColor = Colors.blue;
        label = 'Paused';
        break;
      case DownloadStatus.completed:
        chipColor = Colors.green;
        label = 'Completed';
        break;
      case DownloadStatus.failed:
        chipColor = theme.colorScheme.error;
        label = 'Failed';
        break;
      case DownloadStatus.cancelled:
        chipColor = Colors.grey;
        label = 'Cancelled';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: chipColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getProgressColor(ThemeData theme) {
    switch (download.status) {
      case DownloadStatus.failed:
        return theme.colorScheme.error;
      case DownloadStatus.paused:
        return Colors.blue;
      default:
        return theme.colorScheme.primary;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }
}

class _CompletedDownloadCard extends StatelessWidget {
  final DownloadEntity download;
  final VoidCallback onDelete;
  final VoidCallback onRetry;

  const _CompletedDownloadCard({
    required this.download,
    required this.onDelete,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getStatusColor(theme).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getStatusIcon(),
            color: _getStatusColor(theme),
          ),
        ),
        title: Text(download.appName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (download.version != null) Text('v${download.version}'),
            Text(
              _formatDate(download.completedAt ?? download.createdAt),
              style: theme.textTheme.labelSmall,
            ),
            if (download.status == DownloadStatus.failed &&
                download.errorMessage != null)
              Text(
                download.errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (download.status == DownloadStatus.failed)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: onRetry,
                tooltip: 'Retry',
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (download.status) {
      case DownloadStatus.completed:
        return Icons.check_circle;
      case DownloadStatus.failed:
        return Icons.error;
      case DownloadStatus.cancelled:
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  Color _getStatusColor(ThemeData theme) {
    switch (download.status) {
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.failed:
        return theme.colorScheme.error;
      case DownloadStatus.cancelled:
        return Colors.grey;
      default:
        return theme.colorScheme.outline;
    }
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _QueuedDownloadCard extends StatelessWidget {
  final DownloadEntity download;
  final int position;

  const _QueuedDownloadCard({
    required this.download,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            '$position',
            style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
          ),
        ),
        title: Text(download.appName),
        subtitle: download.version != null ? Text('v${download.version}') : null,
        trailing: const Icon(Icons.schedule),
      ),
    );
  }
}
