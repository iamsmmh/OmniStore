import 'package:omnistore/domain/models/download_entity.dart';

/// Repository interface for download management operations
abstract class DownloadRepository {
  /// Get all downloads
  Future<List<DownloadEntity>> getAllDownloads();

  /// Get active downloads
  Future<List<DownloadEntity>> getActiveDownloads();

  /// Get download history
  Future<List<DownloadEntity>> getDownloadHistory({
    int page = 0,
    int pageSize = 50,
  });

  /// Get download by ID
  Future<DownloadEntity?> getDownloadById(String id);

  /// Start a download
  Future<DownloadEntity> startDownload({
    required String appId,
    required String appName,
    required String url,
    required String fileName,
    required String savePath,
    String? version,
    String? sha256,
  });

  /// Pause a download
  Future<void> pauseDownload(String id);

  /// Resume a download
  Future<void> resumeDownload(String id);

  /// Cancel a download
  Future<void> cancelDownload(String id);

  /// Retry a failed download
  Future<void> retryDownload(String id);

  /// Delete a download
  Future<void> deleteDownload(String id);

  /// Clear all completed downloads
  Future<void> clearCompletedDownloads();

  /// Update download progress
  Future<void> updateProgress(String id, int downloaded, int total);

  /// Mark download as completed
  Future<void> markCompleted(String id);

  /// Mark download as failed
  Future<void> markFailed(String id, String errorMessage);

  /// Check if download already exists for app version
  Future<bool> downloadExists(String appId, String version);

  /// Get download for app version
  Future<DownloadEntity?> getDownloadForAppVersion(
    String appId,
    String version,
  );

  /// Clear download queue
  Future<void> clearQueue();

  /// Get queue position
  Future<int> getQueuePosition(String id);
}
