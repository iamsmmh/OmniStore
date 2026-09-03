class AppConstants {
  AppConstants._();

  static const String appName = 'OmniStore';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';

  // Network
  static const Duration httpTimeout = Duration(seconds: 30);
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  static const int maxConcurrentDownloads = 3;

  // Cache
  static const Duration defaultCacheDuration = Duration(hours: 1);
  static const Duration feedCacheDuration = Duration(minutes: 30);
  static const Duration imageCacheDuration = Duration(days: 7);

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Database
  static const String databaseName = 'omnistore.db';

  // Security
  static const int sha256Length = 64;
  static const bool enforceHttps = true;

  // Sync
  static const Duration defaultSyncInterval = Duration(hours: 6);
  static const Duration minimumSyncInterval = Duration(minutes: 15);

  // Limits
  static const int maxRepositories = 100;
  static const int maxRecentSearches = 20;
  static const int maxDownloadHistory = 1000;
}
