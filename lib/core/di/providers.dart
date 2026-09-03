import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

import '../network/http_client.dart';
import '../security/security_service.dart';
import '../storage/secure_storage.dart';
import '../constants/app_constants.dart';
import '../../infrastructure/database/database_provider.dart';
import '../../infrastructure/notifications/notification_service.dart';
import '../../infrastructure/sync/sync_engine.dart';
import '../../infrastructure/installer/installer_manager.dart';
import '../../domain/repositories/app_repository.dart';
import '../../domain/repositories/repository_manager.dart';
import '../../domain/repositories/download_repository.dart';
import '../../data/repositories/app_repository_impl.dart';
import '../../data/repositories/repository_manager_impl.dart';
import '../../data/repositories/download_repository_impl.dart';
import '../../data/datasources/remote/api_client.dart';
import '../../data/services/search_service.dart';
import '../theme/app_theme.dart';

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
