import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/providers.dart';
import '../../../../domain/models/app_entity.dart';

/// App details page
class AppDetailsPage extends ConsumerStatefulWidget {
  final String appId;

  const AppDetailsPage({super.key, required this.appId});

  @override
  ConsumerState<AppDetailsPage> createState() => _AppDetailsPageState();
}

class _AppDetailsPageState extends ConsumerState<AppDetailsPage> {
  bool _isDownloading = false;
  bool _isInstalling = false;

  @override
  Widget build(BuildContext context) {
    final appAsync = ref.watch(appDetailsProvider(widget.appId));
    final theme = Theme.of(context);

    return Scaffold(
      body: appAsync.when(
        data: (app) {
          if (app == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64),
                  const SizedBox(height: 16),
                  const Text('App not found'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              _buildAppBar(app, theme),
              SliverToBoxAdapter(
                child: _buildContent(app, theme),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(AppEntity app, ThemeData theme) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      actions: [
        IconButton(
          icon: Icon(
            app.isFavorite == true ? Icons.favorite : Icons.favorite_border,
            color: app.isFavorite == true ? Colors.red : null,
          ),
          onPressed: () => _toggleFavorite(app),
        ),
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: () => _shareApp(app),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Background gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.primaryContainer,
                    theme.colorScheme.surface,
                  ],
                ),
              ),
            ),
            // App icon and info
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: app.iconUrl.isNotEmpty
                            ? Image.network(
                                app.iconUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: theme.colorScheme.primaryContainer,
                                  child: Icon(
                                    Icons.apps,
                                    size: 48,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              )
                            : Container(
                                color: theme.colorScheme.primaryContainer,
                                child: Icon(
                                  Icons.apps,
                                  size: 48,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      app.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      app.developer,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildVersionChip(app, theme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionChip(AppEntity app, ThemeData theme) {
    final hasUpdate = app.isInstalled == true &&
        app.installedVersion != null &&
        app.installedVersion != app.version;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: hasUpdate
                ? theme.colorScheme.error.withValues(alpha: 0.1)
                : theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'v${app.version}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: hasUpdate
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (hasUpdate) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Update available',
              style: theme.textTheme.labelMedium?.copyWith(
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildContent(AppEntity app, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Action buttons
          _buildActionButtons(app, theme),
          const SizedBox(height: 24),

          // Description
          if (app.description.isNotEmpty) ...[
            Text(
              'Description',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              app.description,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
          ],

          // Info cards
          _buildInfoSection(app, theme),
          const SizedBox(height: 24),

          // Changelog
          if (app.changelog != null && app.changelog!.isNotEmpty) ...[
            _buildChangelogSection(app, theme),
            const SizedBox(height: 24),
          ],

          // Source link
          if (app.sourceUrl.isNotEmpty) ...[
            _buildSourceSection(app, theme),
            const SizedBox(height: 24),
          ],

          // Categories and tags
          if (app.categories.isNotEmpty || app.tags.isNotEmpty) ...[
            _buildTagsSection(app, theme),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildActionButtons(AppEntity app, ThemeData theme) {
    final isDownloaded = app.downloadUrl != null;
    final isInstalled = app.isInstalled == true;

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _isDownloading || _isInstalling
                ? null
                : () => _handleAction(app),
            icon: _isDownloading || _isInstalling
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_getActionIcon(app)),
            label: Text(_getActionLabel(app)),
          ),
        ),
        if (isInstalled) ...[
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () => _uninstallApp(app),
            child: const Text('Uninstall'),
          ),
        ],
      ],
    );
  }

  IconData _getActionIcon(AppEntity app) {
    if (app.isInstalled == true) {
      return Icons.system_update;
    }
    if (app.downloadUrl != null) {
      return Icons.download;
    }
    return Icons.open_in_browser;
  }

  String _getActionLabel(AppEntity app) {
    if (app.isInstalled == true) {
      return 'Update';
    }
    if (app.downloadUrl != null) {
      return 'Download';
    }
    return 'View Source';
  }

  Widget _buildInfoSection(AppEntity app, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _InfoRow(
              icon: Icons.storage,
              label: 'Size',
              value: _formatBytes(app.downloadSize),
            ),
            const Divider(),
            _InfoRow(
              icon: Icons.calendar_today,
              label: 'Released',
              value: _formatDate(app.releaseDate),
            ),
            if (app.minOsVersion.isNotEmpty) ...[
              const Divider(),
              _InfoRow(
                icon: Icons.phone_android,
                label: 'Minimum iOS',
                value: app.minOsVersion,
              ),
            ],
            if (app.sha256 != null && app.sha256!.isNotEmpty) ...[
              const Divider(),
              _InfoRow(
                icon: Icons.verified,
                label: 'SHA-256',
                value: '${app.sha256!.substring(0, 16)}...',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChangelogSection(AppEntity app, ThemeData theme) {
    return ExpansionTile(
      title: Text(
        'Changelog',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      initiallyExpanded: true,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            app.changelog!,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildSourceSection(AppEntity app, ThemeData theme) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.source),
        title: const Text('Source'),
        subtitle: Text(
          app.sourceUrl,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => _openUrl(app.sourceUrl),
      ),
    );
  }

  Widget _buildTagsSection(AppEntity app, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (app.categories.isNotEmpty) ...[
          Text(
            'Categories',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: app.categories.map((c) {
              return Chip(
                label: Text(c),
                backgroundColor: theme.colorScheme.secondaryContainer,
              );
            }).toList(),
          ),
        ],
        if (app.tags.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Tags',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: app.tags.map((t) {
              return ActionChip(
                label: Text(t),
                onPressed: () {
                  // Search for tag
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Future<void> _handleAction(AppEntity app) async {
    if (app.isInstalled == true) {
      // Update
      await _downloadApp(app);
    } else if (app.downloadUrl != null) {
      // Download
      await _downloadApp(app);
    } else {
      // Open source
      await _openUrl(app.sourceUrl);
    }
  }

  Future<void> _downloadApp(AppEntity app) async {
    if (app.downloadUrl == null) return;

    setState(() => _isDownloading = true);

    try {
      final downloadRepo = ref.read(downloadRepositoryProvider);
      await downloadRepo.startDownload(
        appId: app.id,
        appName: app.name,
        url: app.downloadUrl!,
        fileName: '${app.bundleId}_${app.version}.ipa',
        savePath: 'downloads',
        version: app.version,
        sha256: app.sha256,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download started for ${app.name}'),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                // Navigate to downloads
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _installApp(AppEntity app) async {
    setState(() => _isInstalling = true);

    try {
      final installerManager = ref.read(installerManagerProvider);
      final result = await installerManager.installApp(
        filePath: '${app.id}/${app.version}.ipa',
        bundleId: app.bundleId,
        metadata: {'version': app.version},
      );

      if (mounted) {
        if (result.success) {
          final appRepo = ref.read(appRepositoryProvider);
          await appRepo.markInstalled(app.id, app.version);
          ref.invalidate(appDetailsProvider(widget.appId));

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${app.name} installed successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Installation failed: ${result.error}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Installation failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isInstalling = false);
    }
  }

  Future<void> _uninstallApp(AppEntity app) async {
    try {
      final appRepo = ref.read(appRepositoryProvider);
      await appRepo.markUninstalled(app.id);
      ref.invalidate(appDetailsProvider(widget.appId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${app.name} uninstalled')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to uninstall: $e')),
        );
      }
    }
  }

  Future<void> _toggleFavorite(AppEntity app) async {
    try {
      final appRepo = ref.read(appRepositoryProvider);
      await appRepo.toggleFavorite(app.id);
      ref.invalidate(appDetailsProvider(widget.appId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update favorite: $e')),
        );
      }
    }
  }

  Future<void> _shareApp(AppEntity app) async {
    final shareText = 'Check out ${app.name} on OmniStore!\n${app.sourceUrl}';
    // Use share_plus in production
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return 'Unknown';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Provider for app details
final appDetailsProvider = FutureProvider.family<AppEntity?, String>((ref, appId) async {
  final appRepo = ref.watch(appRepositoryProvider);
  return appRepo.getAppById(appId);
});

/// Info row widget
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.outline),
          const SizedBox(width: 12),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
