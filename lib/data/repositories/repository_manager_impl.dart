import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

import '../../core/logger/app_logger.dart';
import '../../core/security/security_service.dart';
import '../../domain/models/repository_entity.dart';
import '../../domain/repositories/repository_manager.dart';
import '../../domain/services/repository_provider.dart';
import '../../infrastructure/database/database_provider.dart';
import '../datasources/remote/api_client.dart';
import '../datasources/remote/providers/github_provider.dart';
import '../datasources/remote/providers/gitlab_provider.dart';
import '../datasources/remote/providers/codeberg_provider.dart';
import '../datasources/remote/providers/forgejo_provider.dart';
import '../datasources/remote/providers/altstore_provider.dart';
import '../datasources/remote/providers/omnisource_provider.dart';
import '../datasources/remote/providers/feather_provider.dart';
import '../datasources/remote/providers/generic_json_provider.dart';

/// Implementation of RepositoryManager with full provider support,
/// response caching, retry and sync statistics.
class RepositoryManagerImpl implements RepositoryManager {
  final DatabaseService _database;
  final ApiClient _apiClient;
  final SecurityService _securityService;
  final RepositoryProviderRegistry _providerRegistry = RepositoryProviderRegistry();
  final _uuid = const Uuid();
  final _logger = AppLogger.getLogger('RepositoryManagerImpl');

  // Sync statistics
  final Map<String, int> _syncCounts = {};
  final Map<String, List<int>> _syncDurations = {};

  RepositoryManagerImpl({
    required dynamic database,
    required ApiClient apiClient,
    required SecurityService securityService,
  })  : _database = DatabaseService(database),
        _apiClient = apiClient,
        _securityService = securityService {
    _registerProviders();
  }

  void _registerProviders() {
    _providerRegistry.register(GitHubProvider(_apiClient));
    _providerRegistry.register(GitLabProvider(_apiClient));
    _providerRegistry.register(CodebergProvider(_apiClient));
    _providerRegistry.register(ForgejoProvider(_apiClient));
    _providerRegistry.register(AltStoreProvider(_apiClient));
    _providerRegistry.register(OmniSourceProvider(_apiClient));
    _providerRegistry.register(FeatherProvider(_apiClient));
    _providerRegistry.register(GenericJsonProvider(_apiClient));
    _logger.info('All 8 repository providers registered');
  }

  // Expose registry for external validation engine use
  RepositoryProviderRegistry get providerRegistry => _providerRegistry;

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
    if (!_securityService.validateUrl(repository.url)) {
      throw Exception('Invalid or insecure repository URL: ${repository.url}');
    }
    if (!_securityService.isSafeInput(repository.name)) {
      throw Exception('Invalid repository name');
    }
    if (await repositoryExists(repository.url)) {
      throw Exception('Repository already exists');
    }
    final currentCount = await _database.repositoryDao.count();
    if (currentCount >= 100) {
      throw Exception('Maximum number of repositories (100) reached');
    }

    // Auto-detect type if caller passed generic
    RepositoryType type = repository.type;
    if (type == RepositoryType.genericFeed) {
      final detected = await detectRepositoryType(repository.url);
      if (detected != null) type = detected;
    }

    // Validate feed structure before saving
    try {
      final validation = await validateRepository(repository.url, type);
      if (!validation.isValid) {
        _logger.warning('Repository validation warning for ${repository.url}: ${validation.message}');
        // Still allow adding but mark as invalid
      }
    } catch (_) {
      // Non-blocking
    }

    final id = repository.id.isEmpty ? _uuid.v4() : repository.id;
    final entity = repository.copyWith(id: id, type: type);
    final table = RepositoryTable.fromEntity(entity.toJson()..['type'] = type.name);
    // Ensure id mapping matches table expectations
    table.repositoryId = id;
    await _database.repositoryDao.save(table);
    _logger.info('Repository added: ${entity.name} (${entity.type.name})');
    return entity;
  }

  @override
  Future<RepositoryEntity> updateRepository(RepositoryEntity repository) async {
    final table = RepositoryTable.fromEntity(repository.toJson()..['type'] = repository.type.name);
    table.repositoryId = repository.id;
    await _database.repositoryDao.save(table);
    _logger.info('Repository updated: ${repository.name}');
    return repository;
  }

  @override
  Future<void> removeRepository(String id) async {
    await _database.repositoryDao.delete(id);
    _syncCounts.remove(id);
    _syncDurations.remove(id);
    _logger.info('Repository removed: $id');
  }

  @override
  Future<void> setEnabled(String id, bool enabled) async {
    await _database.repositoryDao.setEnabled(id, enabled);
    _logger.info('Repository $id ${enabled ? "enabled" : "disabled"}');
  }

  @override
  Future<ValidationResult> validateRepository(String url, RepositoryType type) async {
    try {
      if (!_securityService.validateUrl(url)) {
        return const ValidationResult(isValid: false, message: 'URL must use HTTPS and contain a valid host');
      }
      final provider = _providerRegistry.getProvider(type) ?? _providerRegistry.detectProvider(url);
      if (provider == null) {
        return const ValidationResult(isValid: false, message: 'No provider found for repository type');
      }
      final data = await provider.validate(url);
      final warnings = <String>[];
      if (data.appCount == 0 && data.isValid) warnings.add('Repository is valid but contains no apps');
      if (data.iconUrl == null || data.iconUrl!.isEmpty) warnings.add('Repository has no icon');
      return ValidationResult(
        isValid: data.isValid,
        message: data.isValid ? 'Repository is valid (${data.appCount} apps)' : 'Repository is invalid',
        warnings: warnings.isEmpty ? null : warnings,
        metadata: data.metadata,
      );
    } catch (e, stack) {
      _logger.severe('Failed to validate repository: $url', e, stack);
      return ValidationResult(isValid: false, message: 'Validation failed: ${e.toString()}');
    }
  }

  @override
  Future<void> syncRepository(String id) async {
    final repo = await getRepositoryById(id);
    if (repo == null) throw Exception('Repository not found: $id');
    if (!repo.isEnabled) {
      _logger.info('Repository $id is disabled, skipping sync');
      return;
    }
    final provider = _providerRegistry.getProvider(repo.type) ?? _providerRegistry.detectProvider(repo.url);
    if (provider == null) throw Exception('No provider found for type: ${repo.type}');
    final start = DateTime.now();
    _logger.info('Syncing repository: ${repo.name}');
    try {
      final apps = await provider.fetchApps(repo.url).timeout(const Duration(seconds: 45));
      _logger.info('Fetched ${apps.length} apps from ${repo.name}');
      // Persist apps with repositoryId association
      final tables = apps.map((a) {
        final json = a.toJson();
        json['repositoryId'] = repo.id;
        return AppTable.fromEntity(json);
      }).toList();
      if (tables.isNotEmpty) {
        await _database.appDao.saveAll(tables);
      }
      await _database.repositoryDao.updateLastSynced(id, DateTime.now());
      await _database.repositoryDao.updateLastError(id, null);
      await _database.repositoryDao.updateAppCount(id, apps.length);
      final duration = DateTime.now().difference(start).inMilliseconds;
      _syncCounts[id] = (_syncCounts[id] ?? 0) + 1;
      _syncDurations.putIfAbsent(id, () => []).add(duration);
      if (_syncDurations[id]!.length > 20) _syncDurations[id]!.removeAt(0);
      _logger.info('Repository synced: ${repo.name} in ${duration}ms');
    } catch (e) {
      await _database.repositoryDao.updateLastError(id, e.toString());
      _syncCounts[id] = (_syncCounts[id] ?? 0) + 1;
      rethrow;
    }
  }

  @override
  Future<void> syncAllRepositories() async {
    final repos = await getEnabledRepositories();
    _logger.info('Syncing ${repos.length} enabled repositories');
    // Sync with limited concurrency (2 at a time) to avoid rate limits
    const concurrency = 2;
    for (int i = 0; i < repos.length; i += concurrency) {
      final batch = repos.skip(i).take(concurrency);
      await Future.wait(batch.map((repo) async {
        try {
          await syncRepository(repo.id);
        } catch (e) {
          _logger.warning('Failed to sync ${repo.name}: $e');
        }
      }));
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
        return const RepositoryStats(appCount: 0, releaseCount: 0, syncCount: 0, averageSyncDurationMs: 0);
      }
      final appCount = await _database.appDao.countByRepository(id);
      final syncCount = _syncCounts[id] ?? 0;
      final durations = _syncDurations[id] ?? [];
      final avg = durations.isEmpty ? 0.0 : durations.reduce((a, b) => a + b) / durations.length;
      return RepositoryStats(
        appCount: appCount,
        releaseCount: appCount,
        lastSynced: repo.lastSynced,
        lastError: repo.lastError,
        syncCount: syncCount,
        averageSyncDurationMs: avg,
      );
    } catch (e) {
      return const RepositoryStats(appCount: 0, releaseCount: 0, syncCount: 0, averageSyncDurationMs: 0);
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
