import 'dart:async';
import 'package:logging/logging.dart';

import '../../core/logger/app_logger.dart';
import '../../domain/repositories/repository_manager.dart';
import '../../domain/repositories/app_repository.dart';
import '../notifications/notification_service.dart';

/// Synchronization engine for repository and app data
class SyncEngine {
  final RepositoryManager _repositoryManager;
  final AppRepository _appRepository;
  final NotificationService _notificationService;
  final _logger = AppLogger.getLogger('SyncEngine');

  Timer? _syncTimer;
  bool _isSyncing = false;
  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();

  SyncEngine({
    required RepositoryManager repositoryManager,
    required AppRepository appRepository,
    required NotificationService notificationService,
  })  : _repositoryManager = repositoryManager,
        _appRepository = appRepository,
        _notificationService = notificationService;

  /// Stream of sync status updates
  Stream<SyncStatus> get statusStream => _statusController.stream;

  /// Whether a sync is currently in progress
  bool get isSyncing => _isSyncing;

  /// Initialize the sync engine
  Future<void> initialize() async {
    _logger.info('Sync engine initialized');
  }

  /// Start periodic sync
  void startPeriodicSync(Duration interval) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) => syncAll());
    _logger.info('Periodic sync started with interval: $interval');
  }

  /// Stop periodic sync
  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _logger.info('Periodic sync stopped');
  }

  /// Sync all enabled repositories
  Future<void> syncAll() async {
    if (_isSyncing) {
      _logger.warning('Sync already in progress, skipping');
      return;
    }

    _isSyncing = true;
    _statusController.add(SyncStatus.started());

    try {
      _logger.info('Starting sync of all repositories');
      await _repositoryManager.syncAllRepositories();
      _statusController.add(SyncStatus.completed());
      _logger.info('All repositories synced successfully');
    } catch (e, stack) {
      _logger.severe('Sync failed', e, stack);
      _statusController.add(SyncStatus.failed(e.toString()));

      // Notify user of sync failure
      await _notificationService.showSyncAlert(
        title: 'Sync Failed',
        body: 'Failed to sync repositories: ${e.toString()}',
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync a specific repository
  Future<void> syncRepository(String repositoryId) async {
    if (_isSyncing) {
      _logger.warning('Sync already in progress, skipping');
      return;
    }

    _isSyncing = true;
    _statusController.add(SyncStatus.started(repositoryId: repositoryId));

    try {
      _logger.info('Starting sync of repository: $repositoryId');
      await _repositoryManager.syncRepository(repositoryId);
      _statusController.add(SyncStatus.completed(repositoryId: repositoryId));
      _logger.info('Repository synced successfully: $repositoryId');
    } catch (e, stack) {
      _logger.severe('Repository sync failed: $repositoryId', e, stack);
      _statusController.add(SyncStatus.failed(
        repositoryId: repositoryId,
        error: e.toString(),
      ));
    } finally {
      _isSyncing = false;
    }
  }

  /// Check for updates across all repositories
  Future<List<String>> checkForUpdates() async {
    _logger.info('Checking for updates');

    try {
      final updatableApps = await _appRepository.getUpdatableApps();

      if (updatableApps.isNotEmpty) {
        _logger.info('Found ${updatableApps.length} available updates');

        // Notify user of available updates
        await _notificationService.showUpdateAlert(
          updateCount: updatableApps.length,
          appNames: updatableApps.map((a) => a.name).take(3).toList(),
        );
      }

      return updatableApps.map((a) => a.id).toList();
    } catch (e, stack) {
      _logger.severe('Update check failed', e, stack);
      return [];
    }
  }

  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _statusController.close();
  }
}

/// Sync status model
class SyncStatus {
  final bool isStarted;
  final bool isCompleted;
  final bool isFailed;
  final String? repositoryId;
  final String? error;
  final DateTime timestamp;

  SyncStatus({
    this.isStarted = false,
    this.isCompleted = false,
    this.isFailed = false,
    this.repositoryId,
    this.error,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory SyncStatus.started({String? repositoryId}) => SyncStatus(
        isStarted: true,
        repositoryId: repositoryId,
      );

  factory SyncStatus.completed({String? repositoryId}) => SyncStatus(
        isCompleted: true,
        repositoryId: repositoryId,
      );

  factory SyncStatus.failed({String? repositoryId, String? error}) =>
      SyncStatus(
        isFailed: true,
        repositoryId: repositoryId,
        error: error,
      );
}
