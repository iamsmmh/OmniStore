import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../../core/logger/app_logger.dart';
import '../../core/security/security_service.dart';
import '../../domain/models/repository_entity.dart';
import '../../domain/repositories/repository_manager.dart';
import '../../domain/services/repository_provider.dart';
import '../../infrastructure/database/database_provider.dart';
import '../datasources/remote/api_client.dart';
import '../datasources/remote/providers/github_provider.dart';
import '../datasources/remote/providers/altstore_provider.dart';
import '../datasources/remote/providers/omnisource_provider.dart';

/// Implementation of RepositoryManager
class RepositoryManagerImpl implements RepositoryManager {
  final DatabaseService _database;
  final ApiClient _apiClient;
  final SecurityService _securityService;
  final RepositoryProviderRegistry _providerRegistry =
      RepositoryProviderRegistry();
  final _uuid = const Uuid();
  final _logger = AppLogger.getLogger('RepositoryManagerImpl');

  RepositoryManagerImpl({
    required Isar database,
    required ApiClient apiClient,
    required SecurityService securityService,
  })  : _database = DatabaseService(database),
        _apiClient = apiClient,
        _securityService = securityService {
    _registerProviders();
  }

  void _registerProviders() {
    _providerRegistry.register(GitHubProvider(_apiClient));
    _providerRegistry.register(AltStoreProvider(_apiClient));
    _providerRegistry.register(OmniSourceProvider(_apiClient));
    _logger.info('Repository providers registered');
  }

  @override
  Future<List<RepositoryEntity>> getAllRepositories() async {
    try {
      final repos = await _database.repositoryDao.getAll();
      return repos.map((r) => _toEntity(r.toEntity())).toList();
    } catch (e, stack) {
      _logger.severe('Failed to get all repositories', e, stack);
      return [];
    }
  }

  @override
  Future<List<RepositoryEntity>> getEnabledRepositories() async {
    try {
      final repos = await _database.repositoryDao.getEnabled();
      return repos.map((r) => _toEntity(r.toEntity())).toList();
    } catch (e, stack) {
      _logger.severe('Failed to get enabled repositories', e, stack);
      return [];
    }
  }

  @override
  Future<RepositoryEntity?> getRepositoryById(String id) async {
    try {
      final repo = await _database.repositoryDao.getById(id);
      if (repo == null) return null;
      return _toEntity(repo.toEntity());
    } catch (e, stack) {
      _logger.severe('Failed to get repository by id: $id', e, stack);
      return null;
    }
  }

  @override
  Future<RepositoryEntity> addRepository(RepositoryEntity repository) async {
    try {
      // Validate URL
      if (!_securityService.validateUrl(repository.url)) {
        throw Exception('Invalid or insecure repository URL');
      }

      // Check for duplicates
      if (await repositoryExists(repository.url)) {
        throw Exception('Repository already exists');
      }

      // Create table entry
      final table = RepositoryTable.fromEntity(repository.toJson()
        ..['id'] = repository.id.isEmpty ? _uuid.v4() : repository.id);

      await _database.repositoryDao.save(table);

      _logger.info('Repository added: ${repository.name}');
      return repository;
    } catch (e, stack) {
      _logger.severe('Failed to add repository', e, stack);
      rethrow;
    }
  }

  @override
  Future<RepositoryEntity> updateRepository(
    RepositoryEntity repository,
  ) async {
    try {
      final table = RepositoryTable.fromEntity(repository.toJson());
      await _database.repositoryDao.save(table);
      _logger.info('Repository updated: ${repository.name}');
      return repository;
    } catch (e, stack) {
      _logger.severe('Failed to update repository', e, stack);
      rethrow;
    }
  }

  @override
  Future<void> removeRepository(String id) async {
    try {
      await _database.repositoryDao.delete(id);
      _logger.info('Repository removed: $id');
    } catch (e, stack) {
      _logger.severe('Failed to remove repository: $id', e, stack);
      rethrow;
    }
  }

  @override
  Future<void> setEnabled(String id, bool enabled) async {
    try {
      await _database.repositoryDao.setEnabled(id, enabled);
      _logger.info('Repository $id ${enabled ? "enabled" : "disabled"}');
    } catch (e, stack) {
      _logger.severe('Failed to set enabled for repository: $id', e, stack);
    }
  }

  @override
  Future<ValidationResult> validateRepository(
    String url,
    RepositoryType type,
  ) async {
    try {
      final provider = _providerRegistry.getProvider(type);
      if (provider == null) {
        return const ValidationResult(
          isValid: false,
          message: 'No provider found for repository type',
        );
      }

      final data = await provider.validate(url);
      return ValidationResult(
        isValid: data.isValid,
        message: data.isValid ? 'Repository is valid' : 'Repository is invalid',
        metadata: data.metadata,
      );
    } catch (e, stack) {
      _logger.severe('Failed to validate repository: $url', e, stack);
      return ValidationResult(
        isValid: false,
        message: 'Validation failed: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> syncRepository(String id) async {
    try {
      final repo = await getRepositoryById(id);
      if (repo == null) {
        throw Exception('Repository not found: $id');
      }

      if (!repo.isEnabled) {
        _logger.info('Repository $id is disabled, skipping sync');
        return;
      }

      final provider = _providerRegistry.getProvider(repo.type);
      if (provider == null) {
        throw Exception('No provider found for type: ${repo.type}');
      }

      final startTime = DateTime.now();
      _logger.info('Syncing repository: ${repo.name}');

      try {
        // Fetch apps from the repository
        final apps = await provider.fetchApps(repo.url);
        _logger.info('Fetched ${apps.length} apps from ${repo.name}');

        // Update repository sync info
        await _database.repositoryDao.updateLastSynced(id, DateTime.now());
        await _database.repositoryDao.updateLastError(id, null);
        await _database.repositoryDao.updateAppCount(id, apps.length);

        _logger.info(
          'Repository synced: ${repo.name} in '
          '${DateTime.now().difference(startTime).inMilliseconds}ms',
        );
      } catch (e) {
        await _database.repositoryDao.updateLastError(id, e.toString());
        rethrow;
      }
    } catch (e, stack) {
      _logger.severe('Failed to sync repository: $id', e, stack);
      rethrow;
    }
  }

  @override
  Future<void> syncAllRepositories() async {
    try {
      final repos = await getEnabledRepositories();
      _logger.info('Syncing ${repos.length} enabled repositories');

      for (final repo in repos) {
        try {
          await syncRepository(repo.id);
        } catch (e) {
          _logger.warning('Failed to sync ${repo.name}: $e');
          // Continue syncing other repos
        }
      }
    } catch (e, stack) {
      _logger.severe('Failed to sync all repositories', e, stack);
    }
  }

  @override
  Future<RepositoryEntity?> getRepositoryByUrl(String url) async {
    try {
      final repo = await _database.repositoryDao.getByUrl(url);
      if (repo == null) return null;
      return _toEntity(repo.toEntity());
    } catch (e) {
      return null;
    }
  }

  @override
  Future<bool> repositoryExists(String url) async {
    return _database.repositoryDao.exists(url);
  }

  @override
  Future<RepositoryStats> getRepositoryStats(String id) async {
    try {
      final repo = await _database.repositoryDao.getById(id);
      if (repo == null) {
        return const RepositoryStats(
          appCount: 0,
          releaseCount: 0,
          syncCount: 0,
          averageSyncDurationMs: 0,
        );
      }

      final appCount = await _database.appDao.countByRepository(id);

      return RepositoryStats(
        appCount: appCount,
        releaseCount: 0, // TODO: Track releases separately
        lastSynced: repo.lastSynced,
        lastError: repo.lastError,
        syncCount: 0, // TODO: Track sync count
        averageSyncDurationMs: 0, // TODO: Track sync duration
      );
    } catch (e) {
      return const RepositoryStats(
        appCount: 0,
        releaseCount: 0,
        syncCount: 0,
        averageSyncDurationMs: 0,
      );
    }
  }

  @override
  Future<RepositoryType?> detectRepositoryType(String url) async {
    final provider = _providerRegistry.detectProvider(url);
    return provider?.type;
  }

  RepositoryEntity _toEntity(Map<String, dynamic> data) {
    return RepositoryEntity(
      id: data['id'] as String,
      name: data['name'] as String,
      url: data['url'] as String,
      type: RepositoryType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => RepositoryType.genericFeed,
      ),
      isEnabled: data['isEnabled'] as bool,
      addedAt: data['addedAt'] as DateTime,
      description: data['description'] as String?,
      iconUrl: data['iconUrl'] as String?,
      maintainer: data['maintainer'] as String?,
      appCount: data['appCount'] as int?,
      lastSynced: data['lastSynced'] as DateTime?,
      lastError: data['lastError'] as String?,
      isValid: data['isValid'] as bool?,
    );
  }
}
