import '../../models/app_entity.dart';
import '../../models/release_entity.dart';

/// Repository interface for app-related operations
/// Following Clean Architecture - domain defines the contract
abstract class AppRepository {
  /// Get all apps from enabled repositories
  Future<List<AppSummary>> getAllApps({
    int page = 0,
    int pageSize = 20,
    String? category,
    String? repositoryId,
  });

  /// Get app by ID
  Future<AppEntity?> getAppById(String appId);

  /// Get apps by category
  Future<List<AppSummary>> getAppsByCategory(
    String category, {
    int page = 0,
    int pageSize = 20,
  });

  /// Get releases for an app
  Future<List<ReleaseEntity>> getReleasesForApp(String appId);

  /// Get featured apps
  Future<List<AppSummary>> getFeaturedApps();

  /// Get trending apps
  Future<List<AppSummary>> getTrendingApps({int limit = 20});

  /// Get recently updated apps
  Future<List<AppSummary>> getRecentlyUpdatedApps({int limit = 20});

  /// Get new releases
  Future<List<AppSummary>> getNewReleases({int limit = 20});

  /// Get recommended apps
  Future<List<AppSummary>> getRecommendedApps({int limit = 20});

  /// Search apps
  Future<List<AppSummary>> searchApps(
    String query, {
    int page = 0,
    int pageSize = 20,
    String? category,
    String? repositoryId,
  });

  /// Get favorite apps
  Future<List<AppSummary>> getFavoriteApps();

  /// Toggle favorite status
  Future<void> toggleFavorite(String appId);

  /// Check if app is favorite
  Future<bool> isFavorite(String appId);

  /// Save/update app data
  Future<void> saveApps(List<AppEntity> apps);

  /// Delete app data
  Future<void> deleteApp(String appId);

  /// Get installed version
  Future<String?> getInstalledVersion(String appId);

  /// Mark app as installed
  Future<void> markInstalled(String appId, String version);

  /// Mark app as uninstalled
  Future<void> markUninstalled(String appId);

  /// Get apps with available updates
  Future<List<AppSummary>> getUpdatableApps();
}
