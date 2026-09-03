import '../../models/repository_entity.dart';

/// Repository interface for source management operations
abstract class RepositoryManager {
  /// Get all repositories
  Future<List<RepositoryEntity>> getAllRepositories();

  /// Get enabled repositories
  Future<List<RepositoryEntity>> getEnabledRepositories();

  /// Get repository by ID
  Future<RepositoryEntity?> getRepositoryById(String id);

  /// Add a new repository
  Future<RepositoryEntity> addRepository(RepositoryEntity repository);

  /// Update an existing repository
  Future<RepositoryEntity> updateRepository(RepositoryEntity repository);

  /// Remove a repository
  Future<void> removeRepository(String id);

  /// Enable/disable a repository
  Future<void> setEnabled(String id, bool enabled);

  /// Validate a repository URL
  Future<ValidationResult> validateRepository(String url, RepositoryType type);

  /// Sync a specific repository
  Future<void> syncRepository(String id);

  /// Sync all enabled repositories
  Future<void> syncAllRepositories();

  /// Get repository by URL
  Future<RepositoryEntity?> getRepositoryByUrl(String url);

  /// Check if repository URL already exists
  Future<bool> repositoryExists(String url);

  /// Get repository statistics
  Future<RepositoryStats> getRepositoryStats(String id);

  /// Auto-detect repository type from URL
  Future<RepositoryType?> detectRepositoryType(String url);
}

/// Repository statistics
class RepositoryStats {
  final int appCount;
  final int releaseCount;
  final DateTime? lastSynced;
  final String? lastError;
  final int syncCount;
  final double averageSyncDurationMs;

  const RepositoryStats({
    required this.appCount,
    required this.releaseCount,
    this.lastSynced,
    this.lastError,
    required this.syncCount,
    required this.averageSyncDurationMs,
  });
}
