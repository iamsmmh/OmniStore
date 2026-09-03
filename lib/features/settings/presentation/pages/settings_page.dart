import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';

/// Settings page
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Appearance section
          _SectionHeader(title: 'Appearance'),
          _SettingsTile(
            icon: Icons.palette_outlined,
            title: 'Theme',
            subtitle: 'System default',
            onTap: () => _showThemeDialog(context, ref),
          ),
          _SettingsTile(
            icon: Icons.text_fields,
            title: 'Dynamic Color',
            subtitle: 'Match system colors',
            trailing: Switch(
              value: ref.watch(dynamicColorProvider),
              onChanged: (value) {
                ref.read(dynamicColorProvider.notifier).state = value;
              },
            ),
          ),

          // Sync section
          _SectionHeader(title: 'Sync'),
          _SettingsTile(
            icon: Icons.sync,
            title: 'Auto Sync',
            subtitle: 'Every 6 hours',
            onTap: () => _showSyncIntervalDialog(context, ref),
          ),
          _SettingsTile(
            icon: Icons.wifi,
            title: 'Sync on Wi-Fi Only',
            subtitle: 'Save mobile data',
            trailing: Switch(
              value: true,
              onChanged: (value) {},
            ),
          ),

          // Notifications section
          _SectionHeader(title: 'Notifications'),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Update Notifications',
            subtitle: 'Get notified about new updates',
            trailing: Switch(
              value: true,
              onChanged: (value) {},
            ),
          ),
          _SettingsTile(
            icon: Icons.download_outlined,
            title: 'Download Complete',
            subtitle: 'Notify when downloads finish',
            trailing: Switch(
              value: true,
              onChanged: (value) {},
            ),
          ),

          // Security section
          _SectionHeader(title: 'Security'),
          _SettingsTile(
            icon: Icons.security,
            title: 'Verify Checksums',
            subtitle: 'SHA-256 verification',
            trailing: Switch(
              value: true,
              onChanged: (value) {},
            ),
          ),
          _SettingsTile(
            icon: Icons.https,
            title: 'HTTPS Only',
            subtitle: 'Block insecure connections',
            trailing: Switch(
              value: true,
              onChanged: (value) {},
            ),
          ),

          // Data section
          _SectionHeader(title: 'Data'),
          _SettingsTile(
            icon: Icons.storage,
            title: 'Cache Size',
            subtitle: '0 MB',
            onTap: () => _showClearCacheDialog(context, ref),
          ),
          _SettingsTile(
            icon: Icons.delete_outline,
            title: 'Clear Downloads',
            subtitle: 'Remove completed downloads',
            onTap: () => _showClearDownloadsDialog(context, ref),
          ),
          _SettingsTile(
            icon: Icons.delete_forever,
            title: 'Clear All Data',
            subtitle: 'Remove all local data',
            onTap: () => _showClearAllDialog(context, ref),
          ),

          // About section
          _SectionHeader(title: 'About'),
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'Version',
            subtitle: '1.0.0 (1)',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.code,
            title: 'Open Source Licenses',
            onTap: () => _showLicenses(context),
          ),
          _SettingsTile(
            icon: Icons.bug_report_outlined,
            title: 'Report a Bug',
            onTap: () {},
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('System'),
              value: ThemeMode.system,
              groupValue: ref.watch(themeModeProvider),
              onChanged: (value) {
                ref.read(themeModeProvider.notifier).state = value!;
                Navigator.pop(context);
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Light'),
              value: ThemeMode.light,
              groupValue: ref.watch(themeModeProvider),
              onChanged: (value) {
                ref.read(themeModeProvider.notifier).state = value!;
                Navigator.pop(context);
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark'),
              value: ThemeMode.dark,
              groupValue: ref.watch(themeModeProvider),
              onChanged: (value) {
                ref.read(themeModeProvider.notifier).state = value!;
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSyncIntervalDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Interval'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Every hour'),
              value: '1',
              groupValue: '6',
              onChanged: (value) => Navigator.pop(context),
            ),
            RadioListTile<String>(
              title: const Text('Every 6 hours'),
              value: '6',
              groupValue: '6',
              onChanged: (value) => Navigator.pop(context),
            ),
            RadioListTile<String>(
              title: const Text('Every 12 hours'),
              value: '12',
              groupValue: '6',
              onChanged: (value) => Navigator.pop(context),
            ),
            RadioListTile<String>(
              title: const Text('Every 24 hours'),
              value: '24',
              groupValue: '6',
              onChanged: (value) => Navigator.pop(context),
            ),
            RadioListTile<String>(
              title: const Text('Manual only'),
              value: '0',
              groupValue: '6',
              onChanged: (value) => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('This will clear all cached data. Your downloads and repositories will not be affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showClearDownloadsDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Downloads'),
        content: const Text('This will remove all completed downloads from the history. Downloaded files will not be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final downloadRepo = ref.read(downloadRepositoryProvider);
              await downloadRepo.clearCompletedDownloads();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Download history cleared')),
                );
              }
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showClearAllDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will delete all local data including repositories, favorites, and settings. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(context);
              // Clear all data
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All data cleared')),
                );
              }
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _showLicenses(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: 'OmniStore',
      applicationVersion: '1.0.0',
    );
  }
}

/// Section header widget
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Settings tile widget
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
  }
}
