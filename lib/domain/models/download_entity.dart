import 'package:equatable/equatable.dart';

enum DownloadStatus { pending, downloading, paused, completed, failed, cancelled }

class DownloadEntity extends Equatable {
  final String id;
  final String appId;
  final String appName;
  final String url;
  final String fileName;
  final String savePath;
  final int totalSize;
  final int downloadedSize;
  final DownloadStatus status;
  final DateTime createdAt;
  final String? version;
  final String? sha256;
  final String? errorMessage;
  final int? progress;
  final DateTime? completedAt;

  const DownloadEntity({
    required this.id,
    required this.appId,
    required this.appName,
    required this.url,
    required this.fileName,
    required this.savePath,
    required this.totalSize,
    required this.downloadedSize,
    required this.status,
    required this.createdAt,
    this.version,
    this.sha256,
    this.errorMessage,
    this.progress,
    this.completedAt,
  });

  factory DownloadEntity.fromJson(Map<String, dynamic> json) => DownloadEntity(
        id: json['id'] as String,
        appId: json['appId'] as String,
        appName: json['appName'] as String,
        url: json['url'] as String,
        fileName: json['fileName'] as String,
        savePath: json['savePath'] as String,
        totalSize: json['totalSize'] as int? ?? 0,
        downloadedSize: json['downloadedSize'] as int? ?? 0,
        status: DownloadStatus.values.firstWhere((e) => e.name == json['status'], orElse: () => DownloadStatus.pending),
        createdAt: json['createdAt'] is String ? DateTime.parse(json['createdAt'] as String) : json['createdAt'] as DateTime,
        version: json['version'] as String?,
        sha256: json['sha256'] as String?,
        errorMessage: json['errorMessage'] as String?,
        progress: json['progress'] as int?,
        completedAt: json['completedAt'] == null ? null : (json['completedAt'] is String ? DateTime.tryParse(json['completedAt'] as String) : json['completedAt'] as DateTime?),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'appId': appId,
        'appName': appName,
        'url': url,
        'fileName': fileName,
        'savePath': savePath,
        'totalSize': totalSize,
        'downloadedSize': downloadedSize,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'version': version,
        'sha256': sha256,
        'errorMessage': errorMessage,
        'progress': progress,
        'completedAt': completedAt?.toIso8601String(),
      };

  double get progressPercentage => totalSize == 0 ? 0 : (downloadedSize / totalSize) * 100;
  bool get canResume => status == DownloadStatus.paused || status == DownloadStatus.failed;
  bool get isActive => status == DownloadStatus.downloading || status == DownloadStatus.pending;

  @override
  List<Object?> get props => [id, appId, url, status, progress];
}
