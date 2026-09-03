import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../domain/compatibility/compatibility_engine.dart';
import '../../../../domain/health/health_engine.dart';
import '../../../../domain/security/trust_engine.dart';
import '../../../../domain/updates/update_intelligence.dart';
import '../../../../core/versioning/semantic_version.dart';

final appDetailsProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, appId) async {
  final repo = ref.watch(appRepositoryProvider);
  final app = await repo.getAppById(appId);
  if (app == null) return null;
  return app.toJson();
});

class AppDetailsPage extends ConsumerWidget {
  final String appId;
  const AppDetailsPage({super.key, required this.appId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(appDetailsProvider(appId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('App Details')),
      body: async.when(
        data: (data) {
          if (data == null) return EmptyState(icon: Icons.apps_outlined, title: 'App not found', subtitle: 'This app may have been removed from its repository.', actionLabel: 'Go back', onAction: () => Navigator.pop(context));
          return _DetailsBody(data: data, appId: appId);
        },
        loading: () => ListView(padding: const EdgeInsets.all(16), children: const [ShimmerLoading(height: 120), SizedBox(height: 16), ShimmerLoading(height: 80), SizedBox(height: 12), ShimmerLoading(height: 80)]),
        error: (e, _) => EmptyState(icon: Icons.error_outline, title: 'Failed to load', subtitle: e.toString()),
      ),
    );
  }
}

class _DetailsBody extends ConsumerWidget {
  final Map<String, dynamic> data;
  final String appId;
  const _DetailsBody({required this.data, required this.appId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final manager = ref.watch(installerManagerProvider);
    final capabilities = ref.watch(platformCapabilitiesProvider);

    final name = data['name'] as String? ?? 'Unknown';
    final developer = data['developer'] as String? ?? '';
    final version = data['version'] as String? ?? '0.0.0';
    final description = data['description'] as String? ?? '';
    final changelog = data['changelog'] as String?;
    final iconUrl = data['iconUrl'] as String? ?? '';
    final screenshots = List<String>.from(data['screenshots'] as List? ?? []);
    final categories = List<String>.from(data['categories'] as List? ?? []);
    final downloadUrl = data['downloadUrl'] as String?;
    final sha256 = data['sha256'] as String?;
    final minOs = data['minOsVersion'] as String? ?? '';
    final isInstalled = data['isInstalled'] as bool? ?? false;
    final installedVersion = data['installedVersion'] as String?;
    final releaseDate = data['releaseDate'] as DateTime? ?? DateTime.now();
    final repositoryId = data['repositoryId'] as String? ?? '';

    // Health, trust, compatibility, update intelligence
    final healthEngine = ref.watch(appHealthAnalyzerProvider);
    final healthScore = HealthEngine(analyzer: healthEngine).evaluate(appId: appId, releaseDates: [releaseDate], brokenDownloads: 0);

    // Trust: synthesize from available metadata
    final trustEngine = ref.watch(trustAnalyzerProvider);
    final trust = TrustEngine(analyzer: trustEngine).evaluate(RepositoryTrustInput(
      repositoryId: repositoryId,
      url: data['sourceUrl'] as String? ?? 'https://example.com',
      checksumCoverage: sha256 != null ? 1 : 0,
      httpsAssetRatio: downloadUrl != null && downloadUrl.startsWith('https') ? 1 : 0,
      metadataCompleteness: description.isNotEmpty && name.isNotEmpty ? 1 : 0.5,
      appCount: 1,
    ));

    final compat = const CompatibilityEngine().checkCompatibility(appId: appId, appMinOsVersion: minOs.isEmpty ? null : minOs, deviceOsVersion: '17.0');

    final hasUpdate = isInstalled && installedVersion != null && installedVersion != version;
    UpdateVerdict? verdict;
    if (hasUpdate) {
      verdict = const UpdateIntelligence().analyze(ReleaseCandidate(appId: appId, installedVersion: '1.0.0', latestVersion: '1.0.0'));
      // Override with real versions
      final intel = const UpdateIntelligence();
      verdict = intel.analyze(ReleaseCandidate(appId: appId, installedVersion: installedVersion, latestVersion: version, changelog: changelog, sha256: sha256, minOsVersion: minOs));
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList.list(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 72, height: 72, clipBehavior: Clip.hardEdge, decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(16)), child: iconUrl.isNotEmpty ? Image.network(iconUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.apps, color: theme.colorScheme.onPrimaryContainer, size: 36)) : Icon(Icons.apps, color: theme.colorScheme.onPrimaryContainer, size: 36)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  Text(developer, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, children: [
                    ...categories.take(2).map((c) => Chip(label: Text(c, style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact)),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(8)), child: Text('v$version', style: theme.textTheme.labelSmall)),
                  ]),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            // Action buttons based on install affordance
            _InstallActions(downloadUrl: downloadUrl, bundleId: data['bundleId'] as String? ?? appId, version: version, hasUpdate: hasUpdate, verdict: verdict, manager: manager, capabilities: capabilities),
            const SizedBox(height: 16),
            // Health / Trust / Compatibility badges
            Wrap(spacing: 8, runSpacing: 8, children: [
              _Badge(icon: Icons.health_and_safety, label: 'Health: ${healthScore.status.label} ${healthScore.score}/100', color: healthScore.status == AppHealthStatus.healthy ? Colors.green : healthScore.status == AppHealthStatus.warning ? Colors.orange : Colors.red, accessible: healthScore.status.name),
              _Badge(icon: Icons.shield, label: 'Trust: ${trust.category.label} ${trust.score}/100', color: trust.category == TrustCategory.verified || trust.category == TrustCategory.trusted ? Colors.green : trust.category == TrustCategory.risky ? Colors.red : Colors.orange, accessible: trust.category.label),
              _Badge(icon: Icons.phone_iphone, label: compat.status.label, color: compat.status == CompatibilityStatus.compatible ? Colors.green : compat.status == CompatibilityStatus.warning ? Colors.orange : Colors.red, accessible: compat.status.label),
              if (verdict != null) _Badge(icon: Icons.system_update, label: verdict.urgency.name, color: verdict.urgency == UpdateUrgency.critical ? Colors.red : Colors.orange, accessible: verdict.urgency.name),
            ]),
            const SizedBox(height: 20),
            if (screenshots.isNotEmpty) ...[
              Text('Screenshots', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SizedBox(height: 220, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: screenshots.length, itemBuilder: (c, i) => Padding(padding: const EdgeInsets.only(right: 12), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(screenshots[i], width: 130, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 130, color: theme.colorScheme.surfaceContainerLow, child: const Icon(Icons.image))))))),
              const SizedBox(height: 20),
            ],
            Text('About', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(description.isEmpty ? 'No description provided.' : description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 20),
            if (changelog != null && changelog.isNotEmpty) ...[
              Text('Changelog', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)), child: Text(changelog, style: theme.textTheme.bodySmall)),
              const SizedBox(height: 20),
            ],
            Text('Information', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _InfoRow(label: 'Bundle ID', value: data['bundleId'] as String? ?? appId),
            _InfoRow(label: 'Version', value: version),
            _InfoRow(label: 'Release date', value: releaseDate.toString().split(' ').first),
            _InfoRow(label: 'Size', value: '${data['downloadSize'] ?? 0} bytes'),
            _InfoRow(label: 'Repository', value: repositoryId.isEmpty ? 'Unknown' : repositoryId),
            if (sha256 != null) _InfoRow(label: 'SHA-256', value: '${sha256.substring(0, 16)}...'),
            _InfoRow(label: 'Trust score', value: '${trust.score} (${trust.category.label})'),
            _InfoRow(label: 'Health score', value: '${healthScore.score} (${healthScore.status.label})'),
            _InfoRow(label: 'Compatibility', value: compat.message),
            const SizedBox(height: 12),
            if (downloadUrl != null) ...[
              Text('Source', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              InkWell(onTap: () async { final uri = Uri.tryParse(downloadUrl); if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication); }, child: Text(downloadUrl, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, decoration: TextDecoration.underline))),
            ],
          ]),
        ),
      ],
    );
  }
}

class _InstallActions extends StatelessWidget {
  final String? downloadUrl;
  final String bundleId;
  final String version;
  final bool hasUpdate;
  final UpdateVerdict? verdict;
  final dynamic manager;
  final PlatformCapabilities capabilities;
  const _InstallActions({required this.downloadUrl, required this.bundleId, required this.version, required this.hasUpdate, required this.verdict, required this.manager, required this.capabilities});

  @override
  Widget build(BuildContext context) {
    final canInstall = capabilities.canInstallPackages && downloadUrl != null;
    final hasSupportedInstaller = manager.getSupportedAdapters().isNotEmpty;
    if (downloadUrl == null) {
      return FilledButton.icon(onPressed: null, icon: const Icon(Icons.block), label: const Text('No download available'));
    }
    if (hasUpdate) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (verdict != null) Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)), child: Text(verdict!.summary, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer, fontWeight: FontWeight.w600))),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.system_update), label: const Text('Update')),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () async { final uri = Uri.tryParse(downloadUrl!); if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication); }, child: const Text('Open source page')),
      ]);
    }
    if (canInstall && hasSupportedInstaller) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.install_mobile), label: const Text('Install')),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () async { final uri = Uri.tryParse(downloadUrl!); if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication); }, child: const Text('Download only')),
      ]);
    }
    if (capabilities.hasFilesystemDownloads && downloadUrl != null) {
      return FilledButton.icon(onPressed: () async { final uri = Uri.tryParse(downloadUrl!); if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication); }, icon: const Icon(Icons.download), label: const Text('Download'));
    }
    return OutlinedButton.icon(onPressed: () async { final uri = Uri.tryParse(downloadUrl!); if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication); }, icon: const Icon(Icons.open_in_new), label: const Text('Open source page'));
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String accessible;
  const _Badge({required this.icon, required this.label, required this.color, required this.accessible});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: accessible,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: color), const SizedBox(width: 6), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12))]),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [Expanded(child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))), Expanded(child: Text(value, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600), textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis))]),
    );
  }
}
