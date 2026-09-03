import 'package:freezed_annotation/freezed_annotation.dart';

part 'download_entity.freezed.dart';
part 'download_entity.g.dart';

/// Download status enum
enum DownloadStatus {
  pending,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

/// Download entity representing a file download
@freezed
class DownloadEntity with _$DownloadEntity {
  const factory DownloadEntity({
    required String id,
    required String appId,
    required String appName,
    required String url,
    required String fileName,
    required String savePath,
    required int totalSize,
    required int downloadedSize,
    required DownloadStatus status,
    required DateTime createdAt,
    String? version,
    String? sha256,
    String? errorMessage,
    int? progress,
    DateTime? completedAt,
  }) = _DownloadEntity;

  factory DownloadEntity.fromJson(Map<String, dynamic> json) =>
      _$DownloadEntityFromJson(json);

  const DownloadEntity._();

  /// Calculate download progress as percentage
  double get progressPercentage {
    if (totalSize == 0) return 0;
    return (downloadedSize / totalSize) * 100;
  }

  /// Check if download can be resumed
  bool get canResume =>
      status == DownloadStatus.paused || status == DownloadStatus.failed;

  /// Check if download is active
  bool get isActive =>
      status == DownloadStatus.downloading ||
      status == DownloadStatus.pending;
}
