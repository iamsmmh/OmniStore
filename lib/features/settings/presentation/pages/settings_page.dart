import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/monitoring/monitoring_service.dart';
import '../../../../core/platform/platform_capabilities.dart';
import '../../../../infrastructure/sync/sync_engine.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final capabilities = ref.watch(platformCapabilitiesProvider);
    final syncEngine = ref.watch(syncEngineProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Column(children: [
              Consumer(builder: (context, ref, _) {
                final mode = ref.watch(themeModeProvider);
                return ListTile(
                  leading: const Icon(Icons.brightness_6),
                  title: const Text('Theme'),
                  subtitle: Text(mode.name),
                  trailing: DropdownButton<ThemeMode>(
                    value: mode,
                    underline: const SizedBox.shrink(),
                    items: const [DropdownMenuItem(value: ThemeMode.system, child: Text('System')), DropdownMenuItem(value: ThemeMode.light, child: Text('Light')), DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark'))],
                    onChanged: (v) { if (v != null) ref.read(themeModeProvider.notifier).state = v; },
                  ),
                );
              }),
              SwitchListTile(
                secondary: const Icon(Icons.palette),
                title: const Text('Dynamic colors'),
                subtitle: const Text('Use system palette on supported devices'),
                value: ref.watch(dynamicColorProvider),
                onChanged: (v) => ref.read(dynamicColorProvider.notifier).state = v,
              ),
            ]),
          ),
          const SizedBox(height: 20),
          Text('Sync & Data', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.sync),
                title: const Text('Sync now'),
                subtitle: const Text('Refresh all enabled sources'),
                trailing: IconButton(icon: const Icon(Icons.play_arrow), onPressed: () => syncEngine.syncAll()),
              ),
              ListTile(
                leading: const Icon(Icons.cloud_off),
                title: const Text('Offline mode'),
                subtitle: const Text('Cached data is shown when offline. Pull to refresh when online.'),
                trailing: const Icon(Icons.check, color: Colors.green),
              ),
              ListTile(
                leading: const Icon(Icons.storage),
                title: const Text('Catalog cache'),
                subtitle: Text('${capabilities.catalogCacheBudget} max entries • offline-first'),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          Text('Security & Platform', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Column(children: [
              ListTile(leading: const Icon(Icons.security), title: const Text('HTTPS enforced'), subtitle: const Text('All repository and download URLs must use HTTPS')),
              ListTile(leading: const Icon(Icons.verified_user), title: const Text('Checksum verification'), subtitle: const Text('Downloads are verified with SHA-256 when published')),
              ListTile(leading: Icon(capabilities.canInstallPackages ? Icons.install_mobile : Icons.download), title: Text(capabilities.canInstallPackages ? 'Install supported' : 'Browse only'), subtitle: Text('Platform: ${capabilities.target.name} • ${capabilities.canInstallPackages ? 'Full install via adapters' : 'Download / open source page'}')),
            ]),
          ),
          const SizedBox(height: 20),
          Text('Diagnostics', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Column(children: [
              ListTile(leading: const Icon(Icons.bug_report), title: const Text('View logs'), subtitle: const Text('Sync, validation, health'), onTap: () => _showLogs(context)),
              ListTile(leading: const Icon(Icons.health_and_safety), title: const Text('Health reports'), onTap: () => _showLogs(context)),
              ListTile(leading: const Icon(Icons.analytics), title: const Text('Analytics (opt-in)'), subtitle: Text(ref.watch(analyticsServiceProvider).isEnabled ? 'Enabled • local only' : 'Disabled • no data collected'), trailing: Switch(value: ref.watch(analyticsServiceProvider).isEnabled, onChanged: (v) { ref.read(analyticsServiceProvider).setEnabled(v); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(v ? 'Analytics enabled (local only)' : 'Analytics disabled'))); })),
            ]),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('About OmniStore', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text('The Intelligent App Store and Repository Manager for the Decentralized iOS Ecosystem.\nSupports 8 repository types and 5 installers with trust, health and update intelligence.'),
                const SizedBox(height: 8),
                Text('Version 1.0.0 • Flutter • Offline-first', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogs(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: const [
            Text('Diagnostics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            SizedBox(height: 12),
            Text('Logs are collected locally and never uploaded. In production they are persisted to secure storage and can be exported for bug reports.\n\n• Sync logs: last sync attempts, durations, failures\n• Validation logs: repository validation issues\n• Health reports: app health scores\n• Trust reports: trust categories\n\nAll engines run on-device and offline.', style: TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
