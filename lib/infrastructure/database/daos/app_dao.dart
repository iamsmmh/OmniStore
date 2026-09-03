import 'package:isar/isar.dart';
import '../tables/app_table.dart';

/// Data Access Object for app operations
class AppDao {
  final Isar _isar;

  AppDao(this._isar);

  /// Get all apps
  Future<List<AppTable>> getAll({
    int offset = 0,
    int limit = 20,
    String? repositoryId,
    String? category,
  }) async {
    var query = _isar.appTables.filter();

    if (repositoryId != null) {
      query = query.repositoryIdEqualTo(repositoryId);
    }

    if (category != null) {
      query = query.categoriesElementEqualTo(category);
    }

    return query.offset(offset).limit(limit).findAll();
  }

  /// Get app by ID
  Future<AppTable?> getById(String appId) async {
    return _isar.appTables
        .where()
        .filter()
        .appIdEqualTo(appId)
        .findFirst();
  }

  /// Get apps by category
  Future<List<AppTable>> getByCategory(String category, {
    int offset = 0,
    int limit = 20,
  }) async {
    return _isar.appTables
        .where()
        .filter()
        .categoriesElementEqualTo(category)
        .offset(offset)
        .limit(limit)
        .findAll();
  }

  /// Get recently updated apps
  Future<List<AppTable>> getRecentlyUpdated({int limit = 20}) async {
    return _isar.appTables
        .where()
        .sortByReleaseDateDesc()
        .limit(limit)
        .findAll();
  }

  /// Get favorite apps
  Future<List<AppTable>> getFavorites() async {
    return _isar.appTables
        .where()
        .filter()
        .isFavoriteEqualTo(true)
        .findAll();
  }

  /// Get installed apps
  Future<List<AppTable>> getInstalled() async {
    return _isar.appTables
        .where()
        .filter()
        .isInstalledEqualTo(true)
        .findAll();
  }

  /// Save app (insert or update)
  Future<void> save(AppTable app) async {
    await _isar.writeTxn(() async {
      await _isar.appTables.put(app);
    });
  }

  /// Save multiple apps
  Future<void> saveAll(List<AppTable> apps) async {
    await _isar.writeTxn(() async {
      await _isar.appTables.putAll(apps);
    });
  }

  /// Update favorite status
  Future<void> toggleFavorite(String appId) async {
    final app = await getById(appId);
    if (app != null) {
      await _isar.writeTxn(() async {
        app.isFavorite = !app.isFavorite;
        await _isar.appTables.put(app);
      });
    }
  }

  /// Mark as installed
  Future<void> markInstalled(String appId, String version) async {
    final app = await getById(appId);
    if (app != null) {
      await _isar.writeTxn(() async {
        app.isInstalled = true;
        app.installedVersion = version;
        await _isar.appTables.put(app);
      });
    }
  }

  /// Mark as uninstalled
  Future<void> markUninstalled(String appId) async {
    final app = await getById(appId);
    if (app != null) {
      await _isar.writeTxn(() async {
        app.isInstalled = false;
        app.installedVersion = null;
        await _isar.appTables.put(app);
      });
    }
  }

  /// Delete app
  Future<void> delete(String appId) async {
    await _isar.writeTxn(() async {
      final app = await getById(appId);
      if (app != null) {
        await _isar.appTables.delete(app.id!);
      }
    });
  }

  /// Search apps
  Future<List<AppTable>> search(String query, {
    int offset = 0,
    int limit = 20,
  }) async {
    final lowerQuery = query.toLowerCase();
    return _isar.appTables
        .where()
        .filter()
        .nameContains(lowerQuery, caseSensitive: false)
        .or()
        .developerContains(lowerQuery, caseSensitive: false)
        .or()
        .descriptionContains(lowerQuery, caseSensitive: false)
        .offset(offset)
        .limit(limit)
        .findAll();
  }

  /// Get app count by repository
  Future<int> countByRepository(String repositoryId) async {
    return _isar.appTables
        .where()
        .filter()
        .repositoryIdEqualTo(repositoryId)
        .count();
  }
}
