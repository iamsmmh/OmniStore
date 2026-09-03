import 'package:isar/isar.dart';

part 'download_table.g.dart';

/// Database table for download entities
@collection
class DownloadTable {
  Id? id;

  @Index(unique: true, type: IndexType.value)
  late String downloadId;

  @Index()
  late String appId;

  late String appName;
  late String url;
  late String fileName;
  late String savePath;
  late int totalSize;
  late int downloadedSize;

  @Index()
  late String status; // DownloadStatus enum value

  late DateTime createdAt;

  String? version;
  String? sha256;
  String? errorMessage;
  int? progress;
  DateTime? completedAt;

  DownloadTable();

  factory DownloadTable.fromEntity(Map<String, dynamic> entity) {
    final table = DownloadTable()
      ..downloadId = entity['id'] as String
      ..appId = entity['appId'] as String
      ..appName = entity['appName'] as String
      ..url = entity['url'] as String
      ..fileName = entity['fileName'] as String
      ..savePath = entity['savePath'] as String
      ..totalSize = entity['totalSize'] as int
      ..downloadedSize = entity['downloadedSize'] as int
      ..status = entity['status'] as String
      ..createdAt = entity['createdAt'] as DateTime
      ..version = entity['version'] as String?
      ..sha256 = entity['sha256'] as String?
      ..errorMessage = entity['errorMessage'] as String?
      ..progress = entity['progress'] as int?
      ..completedAt = entity['completedAt'] as DateTime?;

    return table;
  }

  Map<String, dynamic> toEntity() {
    return {
      'id': downloadId,
      'appId': appId,
      'appName': appName,
      'url': url,
      'fileName': fileName,
      'savePath': savePath,
      'totalSize': totalSize,
      'downloadedSize': downloadedSize,
      'status': status,
      'createdAt': createdAt,
      'version': version,
      'sha256': sha256,
      'errorMessage': errorMessage,
      'progress': progress,
      'completedAt': completedAt,
    };
  }
}
