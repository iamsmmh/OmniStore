
import '../tables/app_table.dart';

/// Data Access Object for app operations with offline-first guarantees,
/// conflict resolution and efficient indexing.
class AppDao {
  final dynamic _isar;

  AppDao(this._isar);

  List<AppTable> _asAppList(dynamic value) => (value as List).cast<AppTable>();

  AppTable? _asApp(dynamic value) => value as AppTable?;

  int _asInt(dynamic value) => value as int;

  Future<List<AppTable>> getAll({
    int offset = 0,
    int limit = 20,
    String? repositoryId,
    String? category,
  }) async {
    // Use indexed queries where possible
    if (repositoryId != null && category != null) {
      return _asAppList(await _isar.appTables
          .where()
          .filter()
          .repositoryIdEqualTo(repositoryId)
          .and()
          .categoriesContains(category)
          .offset(offset)
          .limit(limit)
          .findAll());
    }
    if (repositoryId != null) {
      return _asAppList(await _isar.appTables
          .where()
          .filter()
          .repositoryIdEqualTo(repositoryId)
          .offset(offset)
          .limit(limit)
          .findAll());
    }
    if (category != null) {
      return _asAppList(await _isar.appTables
          .where()
          .filter()
          .categoriesContains(category)
          .offset(offset)
          .limit(limit)
          .findAll());
    }
    // No filter: use sorted query for deterministic pagination
    return _asAppList(await _isar.appTables.where().sortByReleaseDateDesc().offset(offset).limit(limit).findAll());
  }

  Future<AppTable?> getById(String appId) async {
    return _asApp(await _isar.appTables.where().filter().appIdEqualTo(appId).findFirst());
  }

  Future<List<AppTable>> getByCategory(String category, {int offset = 0, int limit = 20}) async {
    return _asAppList(await _isar.appTables.where().filter().categoriesContains(category).offset(offset).limit(limit).findAll());
  }

  Future<List<AppTable>> getRecentlyUpdated({int limit = 20}) async {
    return _asAppList(await _isar.appTables.where().sortByReleaseDateDesc().limit(limit).findAll());
  }

  Future<List<AppTable>> getFavorites() async {
    return _asAppList(await _isar.appTables.where().filter().isFavoriteEqualTo(true).findAll());
  }

  Future<List<AppTable>> getInstalled() async {
    return _asAppList(await _isar.appTables.where().filter().isInstalledEqualTo(true).findAll());
  }

  Future<void> save(AppTable app) async {
    await _isar.writeTxn(() async {
      // Conflict resolution: last-write wins but preserve user state (favorite/installed)
      final existing = await getById(app.appId);
      if (existing != null) {
        app.isFavorite = existing.isFavorite;
        app.isInstalled = existing.isInstalled;
        app.installedVersion = existing.installedVersion;
        app.id = existing.id;
      }
      await _isar.appTables.put(app);
    });
  }

  /// Batch save with deduplication and incremental merge.
  Future<void> saveAll(List<AppTable> apps) async {
    if (apps.isEmpty) return;
    // Deduplicate incoming batch by appId, keeping latest releaseDate
    final deduped = <String, AppTable>{};
    for (final app in apps) {
      final existing = deduped[app.appId];
      if (existing == null || app.releaseDate.isAfter(existing.releaseDate)) {
        deduped[app.appId] = app;
      }
    }
    final uniqueApps = deduped.values.toList();
    await _isar.writeTxn(() async {
      // Fetch existing for merge
      final existingMap = <String, AppTable>{};
      for (final app in uniqueApps) {
        final e = _asApp(await _isar.appTables
            .where()
            .filter()
            .appIdEqualTo(app.appId)
            .findFirst());
        if (e != null) existingMap[app.appId] = e;
      }
      for (final app in uniqueApps) {
        final existing = existingMap[app.appId];
        if (existing != null) {
          app.id = existing.id;
          app.isFavorite = existing.isFavorite;
          app.isInstalled = existing.isInstalled;
          app.installedVersion = existing.installedVersion;
        }
      }
      await _isar.appTables.putAll(uniqueApps);
    });
  }

  Future<void> toggleFavorite(String appId) async {
    final app = await getById(appId);
    if (app != null) {
      await _isar.writeTxn(() async {
        app.isFavorite = !app.isFavorite;
        await _isar.appTables.put(app);
      });
    }
  }

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

  Future<void> delete(String appId) async {
    await _isar.writeTxn(() async {
      final app = await getById(appId);
      if (app != null && app.id != null) {
        await _isar.appTables.delete(app.id!);
      }
    });
  }

  /// Delete all apps for a repository (used when repository removed).
  Future<void> deleteByRepository(String repositoryId) async {
    await _isar.writeTxn(() async {
      await _isar.appTables.where().filter().repositoryIdEqualTo(repositoryId).deleteAll();
    });
  }

  Future<List<AppTable>> search(String query, {int offset = 0, int limit = 20}) async {
    final lowerQuery = query.toLowerCase().trim();
    if (lowerQuery.isEmpty) return [];
    // Use indexed search with limit to avoid full scan where possible
    return _asAppList(await _isar.appTables
        .where()
        .filter()
        .nameContains(lowerQuery, caseSensitive: false)
        .or()
        .developerContains(lowerQuery, caseSensitive: false)
        .or()
        .descriptionContains(lowerQuery, caseSensitive: false)
        .offset(offset)
        .limit(limit)
        .findAll());
  }

  Future<int> countByRepository(String repositoryId) async {
    return _asInt(await _isar.appTables.where().filter().repositoryIdEqualTo(repositoryId).count());
  }

  Future<int> countAll() async => _asInt(await _isar.appTables.count());

  Future<List<AppTable>> getByRepository(String repositoryId) async {
    return _asAppList(await _isar.appTables.where().filter().repositoryIdEqualTo(repositoryId).findAll());
  }
}
