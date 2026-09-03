import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/logger/app_logger.dart';
import '../../core/network/http_client.dart';
import '../../domain/models/download_entity.dart';
import '../../domain/repositories/download_repository.dart';
import '../../infrastructure/database/database_provider.dart';

/// Implementation of DownloadRepository
class DownloadRepositoryImpl implements DownloadRepository {
  final DatabaseService _database;
  final HttpClient _httpClient;
  final _uuid = const Uuid();
  final _logger = AppLogger.getLogger('DownloadRepositoryImpl');

  // Active download cancel tokens
  final Map<String, CancelToken> _activeDownloads = {};

  DownloadRepositoryImpl({
    required dynamic database,
    required HttpClient httpClient,
  })  : _database = DatabaseService(database),
        _httpClient = httpClient;

  @override
  Future<List<DownloadEntity>> getAllDownloads() async {
    try {
      final downloads = await _database.downloadDao.getAll();
      return downloads.map((d) => _toEntity(d.toEntity())).toList();
    } catch (e, stack) {
      _logger.severe('Failed to get all downloads', e, stack);
      return [];
    }
  }

  @override
  Future<List<DownloadEntity>> getActiveDownloads() async {
    try {
      final downloads = await _database.downloadDao.getActive();
      return downloads.map((d) => _toEntity(d.toEntity())).toList();
    } catch (e, stack) {
      _logger.severe('Failed to get active downloads', e, stack);
      return [];
    }
  }

  @override
  Future<List<DownloadEntity>> getDownloadHistory({
    int page = 0,
    int pageSize = 50,
  }) async {
    try {
      final downloads = await _database.downloadDao.getHistory(
        offset: page * pageSize,
        limit: pageSize,
      );
      return downloads.map((d) => _toEntity(d.toEntity())).toList();
    } catch (e, stack) {
      _logger.severe('Failed to get download history', e, stack);
      return [];
    }
  }

  @override
  Future<DownloadEntity?> getDownloadById(String id) async {
    try {
      final download = await _database.downloadDao.getById(id);
      if (download == null) return null;
      return _toEntity(download.toEntity());
    } catch (e) {
      return null;
    }
  }

  @override
  Future<DownloadEntity> startDownload({
    required String appId,
    required String appName,
    required String url,
    required String fileName,
    required String savePath,
    String? version,
    String? sha256,
  }) async {
    // Check for duplicate downloads
    if (version != null && await downloadExists(appId, version)) {
      throw Exception('Download already exists for this app version');
    }

    final downloadId = _uuid.v4();

    final download = DownloadEntity(
      id: downloadId,
      appId: appId,
      appName: appName,
      url: url,
      fileName: fileName,
      savePath: savePath,
      totalSize: 0,
      downloadedSize: 0,
      status: DownloadStatus.downloading,
      createdAt: DateTime.now(),
      version: version,
      sha256: sha256,
    );

    // Save to database
    final table = DownloadTable.fromEntity(download.toJson());
    await _database.downloadDao.save(table);

    // Start the actual download
    _startFileDownload(download);

    _logger.info('Download started: $appName ($downloadId)');
    return download;
  }

  Future<void> _startFileDownload(DownloadEntity download) async {
    final cancelToken = CancelToken();
    _activeDownloads[download.id] = cancelToken;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final fullPath = '${dir.path}/${download.savePath}/${download.fileName}';

      // Ensure directory exists
      await Directory('${dir.path}/${download.savePath}').create(recursive: true);

      await _httpClient.download(
        download.url,
        fullPath,
        onReceiveProgress: (received, total) {
          _updateProgress(download.id, received, total);
        },
        cancelToken: cancelToken,
      );

      // Download completed
      await _database.downloadDao.updateStatus(download.id, 'completed');
      _activeDownloads.remove(download.id);

      _logger.info('Download completed: ${download.appName}');
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        _logger.info('Download cancelled: ${download.appName}');
        await _database.downloadDao.updateStatus(download.id, 'cancelled');
      } else {
        _logger.severe('Download failed: ${download.appName}', e);
        await _database.downloadDao.markFailed(download.id, e.toString());
      }
      _activeDownloads.remove(download.id);
    }
  }

  void _updateProgress(String id, int downloaded, int total) {
    _database.downloadDao.updateProgress(id, downloaded, total);
  }

  @override
  Future<void> pauseDownload(String id) async {
    final cancelToken = _activeDownloads[id];
    cancelToken?.cancel('Paused by user');
    _activeDownloads.remove(id);
    await _database.downloadDao.updateStatus(id, 'paused');
    _logger.info('Download paused: $id');
  }

  @override
  Future<void> resumeDownload(String id) async {
    final download = await getDownloadById(id);
    if (download == null) throw Exception('Download not found');
    if (!download.canResume) throw Exception('Download cannot be resumed');

    await _database.downloadDao.updateStatus(id, 'downloading');
    _startFileDownload(download);
    _logger.info('Download resumed: $id');
  }

  @override
  Future<void> cancelDownload(String id) async {
    final cancelToken = _activeDownloads[id];
    cancelToken?.cancel('Cancelled by user');
    _activeDownloads.remove(id);
    await _database.downloadDao.updateStatus(id, 'cancelled');
    _logger.info('Download cancelled: $id');
  }

  @override
  Future<void> retryDownload(String id) async {
    final download = await getDownloadById(id);
    if (download == null) throw Exception('Download not found');

    await _database.downloadDao.updateStatus(id, 'downloading');
    _startFileDownload(download);
    _logger.info('Download retry: $id');
  }

  @override
  Future<void> deleteDownload(String id) async {
    // Cancel if active
    final cancelToken = _activeDownloads[id];
    cancelToken?.cancel('Deleted by user');
    _activeDownloads.remove(id);

    await _database.downloadDao.delete(id);
    _logger.info('Download deleted: $id');
  }

  @override
  Future<void> clearCompletedDownloads() async {
    await _database.downloadDao.clearCompleted();
    _logger.info('Completed downloads cleared');
  }

  @override
  Future<void> updateProgress(String id, int downloaded, int total) async {
    await _database.downloadDao.updateProgress(id, downloaded, total);
  }

  @override
  Future<void> markCompleted(String id) async {
    await _database.downloadDao.updateStatus(id, 'completed');
  }

  @override
  Future<void> markFailed(String id, String errorMessage) async {
    await _database.downloadDao.markFailed(id, errorMessage);
  }

  @override
  Future<bool> downloadExists(String appId, String version) async {
    final download = await _database.downloadDao.getByAppVersion(appId, version);
    return download != null;
  }

  @override
  Future<DownloadEntity?> getDownloadForAppVersion(
    String appId,
    String version,
  ) async {
    final download = await _database.downloadDao.getByAppVersion(appId, version);
    if (download == null) return null;
    return _toEntity(download.toEntity());
  }

  @override
  Future<void> clearQueue() async {
    // Cancel all pending downloads
    for (final entry in _activeDownloads.entries) {
      entry.value.cancel('Queue cleared');
    }
    _activeDownloads.clear();
    _logger.info('Download queue cleared');
  }

  @override
  Future<int> getQueuePosition(String id) async {
    return _database.downloadDao.getQueuePosition(id);
  }

  DownloadEntity _toEntity(Map<String, dynamic> data) {
    return DownloadEntity(
      id: data['id'] as String,
      appId: data['appId'] as String,
      appName: data['appName'] as String,
      url: data['url'] as String,
      fileName: data['fileName'] as String,
      savePath: data['savePath'] as String,
      totalSize: data['totalSize'] as int,
      downloadedSize: data['downloadedSize'] as int,
      status: DownloadStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => DownloadStatus.pending,
      ),
      createdAt: data['createdAt'] as DateTime,
      version: data['version'] as String?,
      sha256: data['sha256'] as String?,
      errorMessage: data['errorMessage'] as String?,
      progress: data['progress'] as int?,
      completedAt: data['completedAt'] as DateTime?,
    );
  }
}
