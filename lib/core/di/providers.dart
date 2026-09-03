import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

import 'package:omnistore/core/network/http_client.dart';
import 'package:omnistore/core/security/security_service.dart';
import 'package:omnistore/core/storage/secure_storage.dart';
import 'package:omnistore/core/../infrastructure/database/database_provider.dart';
import 'package:omnistore/core/../infrastructure/notifications/notification_service.dart';
import 'package:omnistore/core/../infrastructure/sync/sync_engine.dart';
import 'package:omnistore/core/../infrastructure/installer/installer_manager.dart';
import 'package:omnistore/core/../domain/repositories/app_repository.dart';
import 'package:omnistore/core/../domain/repositories/repository_manager.dart';
import 'package:omnistore/core/../domain/repositories/download_repository.dart';
import 'package:omnistore/core/../data/repositories/app_repository_impl.dart';
import 'package:omnistore/core/../data/repositories/repository_manager_impl.dart';
import 'package:omnistore/core/../data/repositories/download_repository_impl.dart';
import 'package:omnistore/core/../data/datasources/remote/api_client.dart';
import 'package:omnistore/core/../data/services/search_service.dart';
import 'package:omnistore/core/analytics/analytics.dart';
import 'package:omnistore/core/platform/platform_capabilities.dart';
import 'package:omnistore/core/platform/platform_detector.dart';
import 'package:omnistore/core/../data/services/discovery_service.dart';
import 'package:omnistore/core/../data/services/repository_catalog_source.dart';
import 'package:omnistore/core/../domain/community/community_contracts.dart';
import 'package:omnistore/core/../domain/health/app_health.dart';
import 'package:omnistore/core/../domain/security/trust_analyzer.dart';
import 'package:omnistore/core/../domain/updates/update_intelligence.dart';
import 'package:omnistore/core/../infrastructure/sync/sync_scheduler.dart';

// ─── Theme Providers ─────────────────────────────────────────

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

final dynamicColorProvider = StateProvider<bool>((ref) => true);

// ─── Network Providers ───────────────────────────────────────

final httpClientProvider = Provider<HttpClient>((ref) {
  return HttpClient();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final httpClient = ref.watch(httpClientProvider);
  final securityService = ref.watch(securityServiceProvider);
  return ApiClient(httpClient: httpClient, securityService: securityService);
});

// ─── Security Providers ──────────────────────────────────────

final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService();
});

// ─── Storage Providers ───────────────────────────────────────

final secureStorageProvider = Provider<SecureStorage>((ref) {
  return SecureStorage();
});

// ─── Database Provider (resolved) ────────────────────────────

/// Provides the Isar instance (blocks until database is ready)
final isarProvider = Provider<Isar>((ref) {
  final asyncIsar = ref.watch(databaseProvider);
  return asyncIsar.requireValue;
});

// ─── Repository Providers ────────────────────────────────────

final appRepositoryProvider = Provider<AppRepository>((ref) {
  final database = ref.watch(isarProvider);
  final apiClient = ref.watch(apiClientProvider);
  return AppRepositoryImpl(database: database, apiClient: apiClient);
});

final repositoryManagerProvider = Provider<RepositoryManager>((ref) {
  final database = ref.watch(isarProvider);
  final apiClient = ref.watch(apiClientProvider);
  final securityService = ref.watch(securityServiceProvider);
  return RepositoryManagerImpl(
    database: database,
    apiClient: apiClient,
    securityService: securityService,
  );
});

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  final database = ref.watch(isarProvider);
  final httpClient = ref.watch(httpClientProvider);
  return DownloadRepositoryImpl(database: database, httpClient: httpClient);
});

// ─── Service Providers ───────────────────────────────────────

final searchServiceProvider = Provider<SearchService>((ref) {
  final appRepository = ref.watch(appRepositoryProvider);
  return SearchService(appRepository: appRepository);
});

// ─── Infrastructure Providers ────────────────────────────────

final installerManagerProvider = Provider<InstallerManager>((ref) {
  return InstallerManager();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final repositoryManager = ref.watch(repositoryManagerProvider);
  final appRepository = ref.watch(appRepositoryProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  return SyncEngine(
    repositoryManager: repositoryManager,
    appRepository: appRepository,
    notificationService: notificationService,
  );
});

// ─── Discovery / Intelligence Providers ──────────────────────

/// Analytics is opt-in: the default sink records nothing at all.
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService(sink: LocalAnalytics(), enabled: false);
});

final catalogSourceProvider = Provider<CatalogSource>((ref) {
  return RepositoryCatalogSource(
    appRepository: ref.watch(appRepositoryProvider),
  );
});

/// Owns the in-memory search index; kept alive for the app's lifetime.
final discoveryServiceProvider = Provider<DiscoveryService>((ref) {
  final service = DiscoveryService(
    source: ref.watch(catalogSourceProvider),
    analytics: ref.watch(analyticsServiceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Resolves once the catalog has been indexed, so screens can await readiness
/// instead of rendering an empty state during startup.
final discoveryWarmupProvider = FutureProvider<void>((ref) async {
  await ref.watch(discoveryServiceProvider).warmUp();
});

final updateIntelligenceProvider = Provider<UpdateIntelligence>((ref) {
  return const UpdateIntelligence();
});

final trustAnalyzerProvider = Provider<TrustAnalyzer>((ref) {
  return const TrustAnalyzer();
});

final appHealthAnalyzerProvider = Provider<AppHealthAnalyzer>((ref) {
  return const AppHealthAnalyzer();
});

final syncSchedulerProvider = Provider<SyncScheduler>((ref) {
  return SyncScheduler();
});

/// Community features are disabled until a moderated backend exists.
final communityServiceProvider = Provider<CommunityService>((ref) {
  return const DisabledCommunityService();
});

final platformCapabilitiesProvider = Provider<PlatformCapabilities>((ref) {
  return detectPlatformCapabilities();
});
