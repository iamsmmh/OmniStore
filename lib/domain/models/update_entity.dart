import 'package:freezed_annotation/freezed_annotation.dart';

part 'update_entity.freezed.dart';
part 'update_entity.g.dart';

/// Update entity representing an available app update
@freezed
class UpdateEntity with _$UpdateEntity {
  const factory UpdateEntity({
    required String appId,
    required String appName,
    required String iconUrl,
    required String installedVersion,
    required String latestVersion,
    required String buildNumber,
    required DateTime releaseDate,
    required int downloadSize,
    required String repositoryId,
    String? changelog,
    String? downloadUrl,
    String? sha256,
    bool? isIgnored,
    DateTime? detectedAt,
  }) = _UpdateEntity;

  factory UpdateEntity.fromJson(Map<String, dynamic> json) =>
      _$UpdateEntityFromJson(json);

  const UpdateEntity._();

  /// Check if update is available
  bool get isAvailable => installedVersion != latestVersion;
}

/// Update preferences
@freezed
class UpdatePreferences with _$UpdatePreferences {
  const factory UpdatePreferences({
    @Default(true) bool autoCheck,
    @Default(true) bool notifyUpdates,
    @Default(false) bool includePrereleases,
    @Default(false) bool autoDownload,
    @Default(false) bool autoInstall,
    @Default(360) int checkIntervalMinutes,
  }) = _UpdatePreferences;

  factory UpdatePreferences.fromJson(Map<String, dynamic> json) =>
      _$UpdatePreferencesFromJson(json);
}
