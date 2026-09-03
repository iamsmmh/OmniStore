import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../domain/models/repository_entity.dart';
import '../../../../domain/validation/repository_validator.dart';

final repositoriesProvider = FutureProvider<List<RepositoryEntity>>((ref) async {
  final manager = ref.watch(repositoryManagerProvider);
  return manager.getAllRepositories();
});

class RepositoriesPage extends ConsumerStatefulWidget {
  const RepositoriesPage({super.key});

  @override
  ConsumerState<RepositoriesPage> createState() => _RepositoriesPageState();
}

class _RepositoriesPageState extends ConsumerState<RepositoriesPage> {
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(repositoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sources')),
      body: async.when(
        data: (repos) => repos.isEmpty
            ? EmptyState(
                icon: Icons.folder_outlined,
                title: 'No sources yet',
                subtitle: 'Add a repository to start discovering apps. Supports GitHub, GitLab, Codeberg, Forgejo, AltStore, Feather, OmniSource and generic JSON.',
                actionLabel: 'Add Source',
                onAction: () => _showAddDialog(context),
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(repositoriesProvider),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _AddSourceCard(onAdd: () => _showAddDialog(context)),
                    const SizedBox(height: 16),
                    ...repos.map((r) => _RepositoryTile(repository: r)),
                  ],
                ),
              ),
        loading: () => ListView.builder(padding: const EdgeInsets.all(16), itemCount: 4, itemBuilder: (_, __) => const Padding(padding: EdgeInsets.only(bottom: 12), child: ShimmerLoading(height: 88))),
        error: (e, _) => EmptyState(icon: Icons.error_outline, title: 'Failed to load sources', subtitle: e.toString(), actionLabel: 'Retry', onAction: () => ref.invalidate(repositoriesProvider)),
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _showAddDialog(context), icon: const Icon(Icons.add), label: const Text('Add')),
    );
  }

  void _showAddDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    String selectedType = RepositoryType.github.name;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Source'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(labelText: 'Repository URL', hintText: 'https://...'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'URL required' : (Uri.tryParse(v)?.hasScheme == true ? null : 'Invalid URL'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedType,
              decoration: const InputDecoration(labelText: 'Type (auto-detected if generic)'),
              items: RepositoryType.values.map((t) => DropdownMenuItem(value: t.name, child: Text(t.name))).toList(),
              onChanged: (v) => selectedType = v ?? selectedType,
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              await _addRepository(_urlController.text.trim(), selectedType);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addRepository(String url, String typeName) async {
    final manager = ref.read(repositoryManagerProvider);
    final security = ref.read(securityServiceProvider);
    final scaffold = ScaffoldMessenger.of(context);

    // Show validating
    showDialog<void>(context: context, barrierDismissible: false, builder: (_) => const AlertDialog(content: Row(children: [CircularProgressIndicator(), SizedBox(width: 16), Text('Validating repository...')])));

    try {
      final type = RepositoryType.values.firstWhere((t) => t.name == typeName, orElse: () => RepositoryType.genericFeed);
      // Use validator for thorough checks
      final validator = RepositoryValidator(securityService: security, registry: (manager as dynamic).providerRegistry);
      final report = await validator.validate(url, expectedType: type);
      if (!mounted) return;
      Navigator.pop(context);

      if (!report.isValid) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Validation issues'),
            content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: report.issues.map((i) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(i.severity == ValidationIssueSeverity.error ? Icons.error : Icons.warning, size: 18, color: i.severity == ValidationIssueSeverity.error ? Colors.red : Colors.orange), const SizedBox(width: 8), Expanded(child: Text('${i.code}: ${i.message}', style: const TextStyle(fontSize: 12)))]))).toList())),
            actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add anyway'))],
          ),
        );
        if (proceed != true) return;
      }

      final repo = RepositoryEntity(
        id: '',
        name: report.metadata?['name'] as String? ?? Uri.parse(url).host,
        url: url,
        type: report.detectedType ?? type,
        isEnabled: true,
        addedAt: DateTime.now(),
        description: report.metadata?['description'] as String?,
        iconUrl: report.metadata?['iconUrl'] as String? ?? report.metadata?['iconURL'] as String?,
        appCount: report.appCount,
      );
      await manager.addRepository(repo);
      ref.invalidate(repositoriesProvider);
      scaffold.showSnackBar(SnackBar(content: Text('Added ${repo.name}')));
      _urlController.clear();
    } catch (e) {
      if (mounted) Navigator.pop(context);
      scaffold.showSnackBar(SnackBar(content: Text('Failed to add: $e'), backgroundColor: Theme.of(context).colorScheme.error));
    }
  }
}

class _AddSourceCard extends StatelessWidget {
  final VoidCallback onAdd;
  const _AddSourceCard({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(Icons.add_link, color: theme.colorScheme.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Add a new source', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w700)), Text('Supports 8 repository types with validation', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onPrimaryContainer)) ])),
          FilledButton.tonal(onPressed: onAdd, child: const Text('Add')),
        ]),
      ),
    );
  }
}

class _RepositoryTile extends ConsumerWidget {
  final RepositoryEntity repository;
  const _RepositoryTile({required this.repository});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetails(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.folder, color: theme.colorScheme.onSecondaryContainer)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(repository.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600), maxLines: 1),
                Text('${repository.type.name} • ${repository.url}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  _StatusDot(enabled: repository.isEnabled),
                  const SizedBox(width: 6),
                  Text(repository.isEnabled ? 'Enabled' : 'Disabled', style: theme.textTheme.labelSmall),
                  const SizedBox(width: 12),
                  Icon(Icons.apps, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('${repository.appCount ?? 0} apps', style: theme.textTheme.labelSmall),
                  if (repository.lastSynced != null) ...[const SizedBox(width: 8), Text('• ${_timeAgo(repository.lastSynced!)}', style: theme.textTheme.labelSmall)],
                ]),
              ]),
            ),
            PopupMenuButton<String>(
              onSelected: (v) => _handleMenu(v, context, ref),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'sync', child: Text('Sync now')),
                PopupMenuItem(value: repository.isEnabled ? 'disable' : 'enable', child: Text(repository.isEnabled ? 'Disable' : 'Enable')),
                const PopupMenuItem(value: 'delete', child: Text('Remove')),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        expand: false,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          children: [
            Text(repository.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(repository.url, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            _DetailRow(label: 'Type', value: repository.type.name),
            _DetailRow(label: 'Added', value: repository.addedAt.toString().split(' ').first),
            _DetailRow(label: 'Apps', value: '${repository.appCount ?? 0}'),
            _DetailRow(label: 'Last sync', value: repository.lastSynced?.toString() ?? 'Never'),
            if (repository.lastError != null) ...[
              const SizedBox(height: 12),
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)), child: Text('Last error: ${repository.lastError}', style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer))),
            ],
            const SizedBox(height: 24),
            FilledButton(onPressed: () async { Navigator.pop(context); await ref.read(repositoryManagerProvider).syncRepository(repository.id); ref.invalidate(repositoriesProvider); }, child: const Text('Sync now')),
          ],
        ),
      ),
    );
  }

  void _handleMenu(String value, BuildContext context, WidgetRef ref) async {
    final manager = ref.read(repositoryManagerProvider);
    switch (value) {
      case 'sync':
        try {
          await manager.syncRepository(repository.id);
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sync completed')));
        } catch (e) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
        }
        ref.invalidate(repositoriesProvider);
        break;
      case 'enable':
        await manager.setEnabled(repository.id, true);
        ref.invalidate(repositoriesProvider);
        break;
      case 'disable':
        await manager.setEnabled(repository.id, false);
        ref.invalidate(repositoriesProvider);
        break;
      case 'delete':
        final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Remove source?'), content: Text('Remove ${repository.name}? Apps from this source will be removed from your catalog.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove'))]));
        if (confirm == true) {
          await manager.removeRepository(repository.id);
          ref.invalidate(repositoriesProvider);
        }
        break;
    }
  }

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _StatusDot extends StatelessWidget {
  final bool enabled;
  const _StatusDot({required this.enabled});
  @override
  Widget build(BuildContext context) => Container(width: 8, height: 8, decoration: BoxDecoration(color: enabled ? Colors.green : Colors.grey, shape: BoxShape.circle));
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)), Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600))]));
}
