import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/di/providers.dart';
import '../../../../domain/models/repository_entity.dart';

/// Repositories management page
class RepositoriesPage extends ConsumerStatefulWidget {
  const RepositoriesPage({super.key});

  @override
  ConsumerState<RepositoriesPage> createState() => _RepositoriesPageState();
}

class _RepositoriesPageState extends ConsumerState<RepositoriesPage> {
  bool _isLoading = false;
  bool _isAddingRepo = false;

  @override
  void initState() {
    super.initState();
    _loadRepositories();
  }

  Future<void> _loadRepositories() async {
    setState(() => _isLoading = true);
    try {
      // Force refresh the providers
      ref.invalidate(repositoriesProvider);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addRepository() async {
    final result = await showDialog<RepositoryEntity>(
      context: context,
      builder: (context) => const _AddRepositoryDialog(),
    );

    if (result != null) {
      await _loadRepositories();
    }
  }

  Future<void> _deleteRepository(RepositoryEntity repo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Repository'),
        content: Text('Are you sure you want to remove "${repo.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repoManager = ref.read(repositoryManagerProvider);
        await repoManager.removeRepository(repo.id);
        await _loadRepositories();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${repo.name} removed')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove: $e')),
          );
        }
      }
    }
  }

  Future<void> _toggleRepository(RepositoryEntity repo) async {
    try {
      final repoManager = ref.read(repositoryManagerProvider);
      await repoManager.setEnabled(repo.id, !repo.isEnabled);
      await _loadRepositories();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    }
  }

  Future<void> _syncRepository(RepositoryEntity repo) async {
    try {
      final syncEngine = ref.read(syncEngineProvider);
      await syncEngine.syncRepository(repo.id);
      await _loadRepositories();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${repo.name} synced')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repositoriesAsync = ref.watch(repositoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sources'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRepositories,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: repositoriesAsync.when(
        data: (repositories) {
          if (repositories.isEmpty) {
            return _EmptyState(onAdd: _addRepository);
          }

          return RefreshIndicator(
            onRefresh: _loadRepositories,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: repositories.length,
              itemBuilder: (context, index) {
                final repo = repositories[index];
                return _RepositoryCard(
                  repository: repo,
                  onToggle: () => _toggleRepository(repo),
                  onSync: () => _syncRepository(repo),
                  onDelete: () => _deleteRepository(repo),
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
                onPressed: _loadRepositories,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isAddingRepo ? null : _addRepository,
        icon: const Icon(Icons.add),
        label: const Text('Add Source'),
      ),
    );
  }
}

/// Provider for repositories list
final repositoriesProvider = FutureProvider<List<RepositoryEntity>>((ref) async {
  final repoManager = ref.watch(repositoryManagerProvider);
  return repoManager.getAllRepositories();
});

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

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
              Icons.folder_off_outlined,
              size: 80,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 24),
            Text(
              'No Sources',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Add a repository source to discover applications',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add Source'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepositoryCard extends StatelessWidget {
  final RepositoryEntity repository;
  final VoidCallback onToggle;
  final VoidCallback onSync;
  final VoidCallback onDelete;

  const _RepositoryCard({
    required this.repository,
    required this.onToggle,
    required this.onSync,
    required this.onDelete,
  });

  IconData _getRepoIcon() {
    switch (repository.type) {
      case RepositoryType.github:
        return Icons.code;
      case RepositoryType.gitlab:
        return Icons.merge_type;
      case RepositoryType.codeberg:
        return Icons.hub;
      case RepositoryType.forgejo:
        return Icons.developer_mode;
      case RepositoryType.altstore:
        return Icons.apple;
      case RepositoryType.omnsource:
        return Icons.rss_feed;
      case RepositoryType.feather:
        return Icons.flutter_dash;
      case RepositoryType.genericFeed:
        return Icons.source;
    }
  }

  Color _getRepoColor(ThemeData theme) {
    switch (repository.type) {
      case RepositoryType.github:
        return Colors.black87;
      case RepositoryType.gitlab:
        return Colors.orange;
      case RepositoryType.codeberg:
        return Colors.blue;
      case RepositoryType.forgejo:
        return Colors.purple;
      case RepositoryType.altstore:
        return Colors.grey;
      case RepositoryType.omnsource:
        return Colors.teal;
      case RepositoryType.feather:
        return Colors.cyan;
      case RepositoryType.genericFeed:
        return theme.colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repoColor = _getRepoColor(theme);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: repository.isEnabled ? 1.0 : 0.6,
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
                      color: repoColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getRepoIcon(),
                      color: repoColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          repository.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          repository.type.name.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: repoColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: repository.isEnabled,
                    onChanged: (_) => onToggle(),
                  ),
                ],
              ),
              if (repository.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  repository.description!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (repository.appCount != null) ...[
                    Icon(
                      Icons.apps,
                      size: 16,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${repository.appCount} apps',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (repository.lastSynced != null) ...[
                    Icon(
                      Icons.sync,
                      size: 16,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatLastSync(repository.lastSynced!),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (repository.lastError != null)
                    Tooltip(
                      message: repository.lastError!,
                      child: Icon(
                        Icons.warning_amber,
                        size: 20,
                        color: theme.colorScheme.error,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onSync,
                    icon: const Icon(Icons.sync, size: 18),
                    label: const Text('Sync'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    label: Text(
                      'Remove',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatLastSync(DateTime lastSync) {
    final diff = DateTime.now().difference(lastSync);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _AddRepositoryDialog extends ConsumerStatefulWidget {
  const _AddRepositoryDialog();

  @override
  ConsumerState<_AddRepositoryDialog> createState() =>
      _AddRepositoryDialogState();
}

class _AddRepositoryDialogState extends ConsumerState<_AddRepositoryDialog> {
  final _urlController = TextEditingController();
  RepositoryType _selectedType = RepositoryType.github;
  bool _isValidating = false;
  bool _isAdding = false;
  String? _errorMessage;
  RepositoryValidationData? _validationData;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _validateUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a URL';
        _validationData = null;
      });
      return;
    }

    // Auto-detect repository type if not manually set
    if (_selectedType == RepositoryType.github &&
        (url.contains('gitlab') || url.contains('gitlab.com'))) {
      _selectedType = RepositoryType.gitlab;
    } else if (_selectedType == RepositoryType.github &&
        (url.contains('codeberg') || url.contains('codeberg.org'))) {
      _selectedType = RepositoryType.codeberg;
    }

    setState(() {
      _isValidating = true;
      _errorMessage = null;
      _validationData = null;
    });

    try {
      final repoManager = ref.read(repositoryManagerProvider);
      final result = await repoManager.validateRepository(url, _selectedType);

      if (result.isValid) {
        setState(() {
          _validationData = RepositoryValidationData(
            isValid: true,
            name: result.metadata?['name'] as String? ?? 'Repository',
            description: result.description,
            iconUrl: result.metadata?['iconUrl'] as String?,
            appCount: result.metadata?['appCount'] as int? ?? 0,
            metadata: result.metadata ?? {},
          );
        });
      } else {
        setState(() {
          _errorMessage = result.message;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Validation failed: $e';
      });
    } finally {
      setState(() => _isValidating = false);
    }
  }

  Future<void> _addRepository() async {
    if (_validationData == null) {
      await _validateUrl();
      return;
    }

    setState(() => _isAdding = true);

    try {
      final repoManager = ref.read(repositoryManagerProvider);
      final url = _urlController.text.trim();

      final repo = RepositoryEntity(
        id: const Uuid().v4(),
        name: _validationData!.name,
        url: url,
        type: _selectedType,
        isEnabled: true,
        addedAt: DateTime.now(),
        description: _validationData!.description,
        iconUrl: _validationData!.iconUrl,
        appCount: _validationData!.appCount,
        isValid: true,
      );

      await repoManager.addRepository(repo);

      // Trigger initial sync
      final syncEngine = ref.read(syncEngineProvider);
      syncEngine.syncRepository(repo.id);

      if (mounted) {
        Navigator.pop(context, repo);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to add: $e';
        _isAdding = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Add Source'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Repository URL',
                hintText: 'https://github.com/user/repo',
                prefixIcon: Icon(Icons.link),
              ),
              onSubmitted: (_) => _validateUrl(),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<RepositoryType>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Type',
                prefixIcon: Icon(Icons.category),
              ),
              items: RepositoryType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_getTypeName(type)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedType = value);
                }
              },
            ),
            if (_isValidating) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_validationData != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _validationData!.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (_validationData!.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _validationData!.description!,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${_validationData!.appCount} apps available',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: theme.colorScheme.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isAdding ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isAdding ? null : _addRepository,
          child: _isAdding
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }

  String _getTypeName(RepositoryType type) {
    switch (type) {
      case RepositoryType.github:
        return 'GitHub';
      case RepositoryType.gitlab:
        return 'GitLab';
      case RepositoryType.codeberg:
        return 'Codeberg';
      case RepositoryType.forgejo:
        return 'Forgejo';
      case RepositoryType.altstore:
        return 'AltStore';
      case RepositoryType.omnsource:
        return 'OmniSource';
      case RepositoryType.feather:
        return 'Feather';
      case RepositoryType.genericFeed:
        return 'Generic Feed';
    }
  }
}
