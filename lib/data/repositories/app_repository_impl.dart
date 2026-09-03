import 'package:isar/isar.dart';
import 'package:logging/logging.dart';

import '../../core/logger/app_logger.dart';
import '../../domain/models/app_entity.dart';
import '../../domain/models/release_entity.dart';
import '../../domain/repositories/app_repository.dart';
import '../../infrastructure/database/database_provider.dart';

/// Implementation of AppRepository
class AppRepositoryImpl implements AppRepository {
  final DatabaseService _database;
  final _logger = AppLogger.getLogger('AppRepositoryImpl');

  AppRepositoryImpl({
    required Isar database,
  })  : _database = DatabaseService(database);

  @override
  Future<List<AppSummary>> getAllApps({
    int page = 0,
    int pageSize = 20,
    String? category,
    String? repositoryId,
  }) async {
    try {
      final apps = await _database.appDao.getAll(
        offset: page * pageSize,
        limit: pageSize,
        repositoryId: repositoryId,
        category: category,
      );
      return apps.map((a) => _toSummary(a.toEntity())).toList();
    } catch (e, stack) {
      _logger.severe('Failed to get all apps', e, stack);
      return [];
    }
  }

  @override
  Future<AppEntity?> getAppById(String appId) async {
    try {
      final app = await _database.appDao.getById(appId);
      if (app == null) return null;
      return AppEntity.fromJson(app.toEntity());
    } catch (e, stack) {
      _logger.severe('Failed to get app by id: $appId', e, stack);
      return null;
    }
  }

  @override
  Future<List<AppSummary>> getAppsByCategory(
    String category, {
    int page = 0,
    int pageSize = 20,
  }) async {
    try {
      final apps = await _database.appDao.getByCategory(
        category,
        offset: page * pageSize,
        limit: pageSize,
      );
      return apps.map((a) => _toSummary(a.toEntity())).toList();
    } catch (e, stack) {
      _logger.severe('Failed to get apps by category: $category', e, stack);
      return [];
    }
  }

  @override
  Future<List<ReleaseEntity>> getReleasesForApp(String appId) async {
    try {
      // In production, this would query the repository for releases
      // For now, return empty list
      return [];
    } catch (e, stack) {
      _logger.severe('Failed to get releases for app: $appId', e, stack);
      return [];
    }
  }

  @override
  Future<List<AppSummary>> getFeaturedApps() async {
    return getAllApps(page: 0, pageSize: 10);
  }

  @override
  Future<List<AppSummary>> getTrendingApps({int limit = 20}) async {
    return getAllApps(page: 0, pageSize: limit);
  }

  @override
  Future<List<AppSummary>> getRecentlyUpdatedApps({int limit = 20}) async {
    try {
      final apps = await _database.appDao.getRecentlyUpdated(limit: limit);
      return apps.map((a) => _toSummary(a.toEntity())).toList();
    } catch (e, stack) {
      _logger.severe('Failed to get recently updated apps', e, stack);
      return [];
    }
  }

  @override
  Future<List<AppSummary>> getNewReleases({int limit = 20}) async {
    return getRecentlyUpdatedApps(limit: limit);
  }

  @override
  Future<List<AppSummary>> getRecommendedApps({int limit = 20}) async {
    return getAllApps(page: 0, pageSize: limit);
  }

  @override
  Future<List<AppSummary>> searchApps(
    String query, {
    int page = 0,
    int pageSize = 20,
    String? category,
    String? repositoryId,
  }) async {
    try {
      final apps = await _database.appDao.search(
        query,
        offset: page * pageSize,
        limit: pageSize,
      );
      return apps.map((a) => _toSummary(a.toEntity())).toList();
    } catch (e, stack) {
      _logger.severe('Failed to search apps: $query', e, stack);
      return [];
    }
  }

  @override
  Future<List<AppSummary>> getFavoriteApps() async {
    try {
      final apps = await _database.appDao.getFavorites();
      return apps.map((a) => _toSummary(a.toEntity())).toList();
    } catch (e, stack) {
      _logger.severe('Failed to get favorite apps', e, stack);
      return [];
    }
  }

  @override
  Future<void> toggleFavorite(String appId) async {
    try {
      await _database.appDao.toggleFavorite(appId);
    } catch (e, stack) {
      _logger.severe('Failed to toggle favorite: $appId', e, stack);
    }
  }

  @override
  Future<bool> isFavorite(String appId) async {
    try {
      final app = await _database.appDao.getById(appId);
      return app?.isFavorite ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> saveApps(List<AppEntity> apps) async {
    try {
      final tables = apps.map((a) => AppTable.fromEntity(a.toJson())).toList();
      await _database.appDao.saveAll(tables);
    } catch (e, stack) {
      _logger.severe('Failed to save apps', e, stack);
    }
  }

  @override
  Future<void> deleteApp(String appId) async {
    try {
      await _database.appDao.delete(appId);
    } catch (e, stack) {
      _logger.severe('Failed to delete app: $appId', e, stack);
    }
  }

  @override
  Future<String?> getInstalledVersion(String appId) async {
    try {
      final app = await _database.appDao.getById(appId);
      return app?.installedVersion;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> markInstalled(String appId, String version) async {
    try {
      await _database.appDao.markInstalled(appId, version);
    } catch (e, stack) {
      _logger.severe('Failed to mark installed: $appId', e, stack);
    }
  }

  @override
  Future<void> markUninstalled(String appId) async {
    try {
      await _database.appDao.markUninstalled(appId);
    } catch (e, stack) {
      _logger.severe('Failed to mark uninstalled: $appId', e, stack);
    }
  }

  @override
  Future<List<AppSummary>> getUpdatableApps() async {
    try {
      final installed = await _database.appDao.getInstalled();
      final updatable = <AppSummary>[];

      for (final app in installed) {
        if (app.installedVersion != null &&
            app.installedVersion != app.version) {
          updatable.add(_toSummary(app.toEntity()));
        }
      }

      return updatable;
    } catch (e, stack) {
      _logger.severe('Failed to get updatable apps', e, stack);
      return [];
    }
  }

  AppSummary _toSummary(Map<String, dynamic> data) {
    return AppSummary(
      id: data['id'] as String,
      name: data['name'] as String,
      bundleId: data['bundleId'] as String,
      developer: data['developer'] as String,
      iconUrl: data['iconUrl'] as String,
      version: data['version'] as String,
      releaseDate: data['releaseDate'] as DateTime,
      categories: List<String>.from(data['categories'] as List),
      isFavorite: data['isFavorite'] as bool?,
      isInstalled: data['isInstalled'] as bool?,
      installedVersion: data['installedVersion'] as String?,
    );
  }
}
