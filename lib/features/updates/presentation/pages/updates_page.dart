import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../domain/models/app_entity.dart';

/// Updates page showing available app updates
class UpdatesPage extends ConsumerStatefulWidget {
  const UpdatesPage({super.key});

  @override
  ConsumerState<UpdatesPage> createState() => _UpdatesPageState();
}

class _UpdatesPageState extends ConsumerState<UpdatesPage> {
  bool _isRefreshing = false;

  Future<void> _checkForUpdates() async {
    setState(() => _isRefreshing = true);
    try {
      ref.invalidate(updatableAppsProvider);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final updatesAsync = ref.watch(updatableAppsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Updates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _checkForUpdates,
            tooltip: 'Check for updates',
          ),
        ],
      ),
      body: updatesAsync.when(
        data: (apps) {
          if (apps.isEmpty) {
            return _NoUpdatesState(onRefresh: _checkForUpdates);
          }

          return RefreshIndicator(
            onRefresh: _checkForUpdates,
            child: Column(
              children: [
                _UpdateAllHeader(appCount: apps.length),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: apps.length,
                    itemBuilder: (context, index) {
                      final app = apps[index];
                      return _UpdateCard(
                        app: app,
                        onTap: () => context.push('/app/${app.id}'),
                        onUpdate: () => _updateApp(app),
                      );
                    },
                  ),
                ),
              ],
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
                onPressed: _checkForUpdates,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateApp(AppSummary app) async {
    try {
      // Get the full app entity
      final appRepo = ref.read(appRepositoryProvider);
      final fullApp = await appRepo.getAppById(app.id);

      if (fullApp == null) {
        throw Exception('App not found');
      }

      // Start download
      if (fullApp.downloadUrl != null) {
        final downloadRepo = ref.read(downloadRepositoryProvider);
        await downloadRepo.startDownload(
          appId: fullApp.id,
          appName: fullApp.name,
          url: fullApp.downloadUrl!,
          fileName: '${fullApp.bundleId}_${fullApp.version}.ipa',
          savePath: 'downloads',
          version: fullApp.version,
          sha256: fullApp.sha256,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download started for ${fullApp.name}'),
              action: SnackBarAction(
                label: 'View',
                onPressed: () {
                  // Navigate to downloads tab
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start update: $e')),
        );
      }
    }
  }
}

/// Provider for updatable apps
final updatableAppsProvider = FutureProvider<List<AppSummary>>((ref) async {
  final appRepo = ref.watch(appRepositoryProvider);
  return appRepo.getUpdatableApps();
});

class _NoUpdatesState extends StatelessWidget {
  final VoidCallback onRefresh;

  const _NoUpdatesState({required this.onRefresh});

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
              Icons.check_circle_outline,
              size: 80,
              color: Colors.green.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              'All Caught Up!',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'All your apps are up to date',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Check Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdateAllHeader extends StatelessWidget {
  final int appCount;

  const _UpdateAllHeader({required this.appCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.system_update,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$appCount Update${appCount == 1 ? '' : 's'} Available',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Pull to refresh',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () {
              // Update all apps
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Updating all apps...')),
              );
            },
            child: const Text('Update All'),
          ),
        ],
      ),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  final AppSummary app;
  final VoidCallback onTap;
  final VoidCallback onUpdate;

  const _UpdateCard({
    required this.app,
    required this.onTap,
    required this.onUpdate,
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
          padding: const EdgeInsets.all(16),
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            app.installedVersion ?? '?',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 14),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            app.version,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: onUpdate,
                child: const Text('Update'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
