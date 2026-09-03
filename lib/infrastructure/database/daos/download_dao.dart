
import '../tables/download_table.dart';

/// Data Access Object for download operations
class DownloadDao {
  final dynamic _isar;

  DownloadDao(this._isar);

  List<DownloadTable> _asDownloadTableList(dynamic value) =>
      (value as List).cast<DownloadTable>();

  DownloadTable? _asDownloadTable(dynamic value) => value as DownloadTable?;

  /// Get all downloads
  Future<List<DownloadTable>> getAll() async {
    return _asDownloadTableList(await _isar.downloadTables.where().sortByCreatedAtDesc().findAll());
  }

  /// Get active downloads (pending or downloading)
  Future<List<DownloadTable>> getActive() async {
    return _asDownloadTableList(await _isar.downloadTables
        .where()
        .filter()
        .statusEqualTo('downloading')
        .or()
        .statusEqualTo('pending')
        .findAll());
  }

  /// Get download history
  Future<List<DownloadTable>> getHistory({
    int offset = 0,
    int limit = 50,
  }) async {
    return _asDownloadTableList(await _isar.downloadTables
        .where()
        .filter()
        .statusEqualTo('completed')
        .or()
        .statusEqualTo('failed')
        .or()
        .statusEqualTo('cancelled')
        .sortByCreatedAtDesc()
        .offset(offset)
        .limit(limit)
        .findAll());
  }

  /// Get download by ID
  Future<DownloadTable?> getById(String downloadId) async {
    return _asDownloadTable(await _isar.downloadTables
        .where()
        .filter()
        .downloadIdEqualTo(downloadId)
        .findFirst());
  }

  /// Get download for app version
  Future<DownloadTable?> getByAppVersion(
    String appId,
    String version,
  ) async {
    return _asDownloadTable(await _isar.downloadTables
        .where()
        .filter()
        .appIdEqualTo(appId)
        .and()
        .versionEqualTo(version)
        .findFirst());
  }

  /// Save download
  Future<void> save(DownloadTable download) async {
    await _isar.writeTxn(() async {
      await _isar.downloadTables.put(download);
    });
  }

  /// Update progress
  Future<void> updateProgress(
    String downloadId,
    int downloaded,
    int total,
  ) async {
    final download = await getById(downloadId);
    if (download != null) {
      await _isar.writeTxn(() async {
        download.downloadedSize = downloaded;
        download.totalSize = total;
        download.progress =
            total > 0 ? ((downloaded / total) * 100).toInt() : 0;
        await _isar.downloadTables.put(download);
      });
    }
  }

  /// Update status
  Future<void> updateStatus(String downloadId, String status) async {
    final download = await getById(downloadId);
    if (download != null) {
      await _isar.writeTxn(() async {
        download.status = status;
        if (status == 'completed') {
          download.completedAt = DateTime.now();
        }
        await _isar.downloadTables.put(download);
      });
    }
  }

  /// Mark as failed
  Future<void> markFailed(String downloadId, String error) async {
    final download = await getById(downloadId);
    if (download != null) {
      await _isar.writeTxn(() async {
        download.status = 'failed';
        download.errorMessage = error;
        await _isar.downloadTables.put(download);
      });
    }
  }

  /// Delete download
  Future<void> delete(String downloadId) async {
    await _isar.writeTxn(() async {
      final download = await getById(downloadId);
      if (download != null) {
        await _isar.downloadTables.delete(download.id!);
      }
    });
  }

  /// Clear completed downloads
  Future<void> clearCompleted() async {
    await _isar.writeTxn(() async {
      await _isar.downloadTables
          .where()
          .filter()
          .statusEqualTo('completed')
          .deleteAll();
    });
  }

  /// Get queue position
  Future<int> getQueuePosition(String downloadId) async {
    final pending = (await _isar.downloadTables
            .where()
            .filter()
            .statusEqualTo('pending')
            .or()
            .statusEqualTo('downloading')
            .sortByCreatedAt()
            .findAll()
        as List)
        .cast<DownloadTable>();

    final index = pending.indexWhere((d) => d.downloadId == downloadId);
    return index >= 0 ? index : -1;
  }
}
