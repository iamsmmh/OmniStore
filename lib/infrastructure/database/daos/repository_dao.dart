import 'package:isar/isar.dart';
import '../tables/repository_table.dart';

/// Data Access Object for repository operations
class RepositoryDao {
  final Isar _isar;

  RepositoryDao(this._isar);

  /// Get all repositories
  Future<List<RepositoryTable>> getAll() async {
    return _isar.repositoryTables.where().findAll();
  }

  /// Get enabled repositories
  Future<List<RepositoryTable>> getEnabled() async {
    return _isar.repositoryTables
        .where()
        .filter()
        .isEnabledEqualTo(true)
        .findAll();
  }

  /// Get repository by ID
  Future<RepositoryTable?> getById(String repositoryId) async {
    return _isar.repositoryTables
        .where()
        .filter()
        .repositoryIdEqualTo(repositoryId)
        .findFirst();
  }

  /// Get repository by URL
  Future<RepositoryTable?> getByUrl(String url) async {
    return _isar.repositoryTables
        .where()
        .filter()
        .urlEqualTo(url)
        .findFirst();
  }

  /// Check if repository exists
  Future<bool> exists(String url) async {
    final repo = await getByUrl(url);
    return repo != null;
  }

  /// Save repository
  Future<void> save(RepositoryTable repo) async {
    await _isar.writeTxn(() async {
      await _isar.repositoryTables.put(repo);
    });
  }

  /// Update last sync time
  Future<void> updateLastSynced(String repositoryId, DateTime time) async {
    final repo = await getById(repositoryId);
    if (repo != null) {
      await _isar.writeTxn(() async {
        repo.lastSynced = time;
        await _isar.repositoryTables.put(repo);
      });
    }
  }

  /// Update last error
  Future<void> updateLastError(String repositoryId, String? error) async {
    final repo = await getById(repositoryId);
    if (repo != null) {
      await _isar.writeTxn(() async {
        repo.lastError = error;
        repo.isValid = error == null;
        await _isar.repositoryTables.put(repo);
      });
    }
  }

  /// Toggle enabled status
  Future<void> setEnabled(String repositoryId, bool enabled) async {
    final repo = await getById(repositoryId);
    if (repo != null) {
      await _isar.writeTxn(() async {
        repo.isEnabled = enabled;
        await _isar.repositoryTables.put(repo);
      });
    }
  }

  /// Update app count
  Future<void> updateAppCount(String repositoryId, int count) async {
    final repo = await getById(repositoryId);
    if (repo != null) {
      await _isar.writeTxn(() async {
        repo.appCount = count;
        await _isar.repositoryTables.put(repo);
      });
    }
  }

  /// Delete repository
  Future<void> delete(String repositoryId) async {
    await _isar.writeTxn(() async {
      final repo = await getById(repositoryId);
      if (repo != null) {
        await _isar.repositoryTables.delete(repo.id!);
      }
    });
  }

  /// Get repository count
  Future<int> count() async {
    return _isar.repositoryTables.count();
  }
}
