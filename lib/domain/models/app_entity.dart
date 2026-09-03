import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_entity.freezed.dart';
part 'app_entity.g.dart';

/// Core application entity representing an app in the store
@freezed
class AppEntity with _$AppEntity {
  const factory AppEntity({
    required String id,
    required String name,
    required String bundleId,
    required String developer,
    required String description,
    required String version,
    required String buildNumber,
    required DateTime releaseDate,
    required String iconUrl,
    required List<String> screenshots,
    required List<String> categories,
    required List<String> tags,
    required int downloadSize,
    required String minOsVersion,
    required String sourceUrl,
    required String repositoryId,
    String? changelog,
    String? sha256,
    String? downloadUrl,
    bool? isInstalled,
    String? installedVersion,
    bool? isFavorite,
    DateTime? lastUpdated,
  }) = _AppEntity;

  factory AppEntity.fromJson(Map<String, dynamic> json) =>
      _$AppEntityFromJson(json);
}

/// Lightweight app info for list displays
@freezed
class AppSummary with _$AppSummary {
  const factory AppSummary({
    required String id,
    required String name,
    required String bundleId,
    required String developer,
    required String iconUrl,
    required String version,
    required DateTime releaseDate,
    required List<String> categories,
    bool? isFavorite,
    bool? isInstalled,
    String? installedVersion,
  }) = _AppSummary;

  factory AppSummary.fromJson(Map<String, dynamic> json) =>
      _$AppSummaryFromJson(json);
}
