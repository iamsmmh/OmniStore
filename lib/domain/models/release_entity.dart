import 'package:freezed_annotation/freezed_annotation.dart';

part 'release_entity.freezed.dart';
part 'release_entity.g.dart';

/// Release entity representing a specific version of an application
@freezed
class ReleaseEntity with _$ReleaseEntity {
  const factory ReleaseEntity({
    required String id,
    required String appId,
    required String version,
    required String buildNumber,
    required DateTime releaseDate,
    required List<ReleaseAsset> assets,
    String? changelog,
    String? minOsVersion,
    bool? isPrerelease,
  }) = _ReleaseEntity;

  factory ReleaseEntity.fromJson(Map<String, dynamic> json) =>
      _$ReleaseEntityFromJson(json);
}

/// Release asset (downloadable file)
@freezed
class ReleaseAsset with _$ReleaseAsset {
  const factory ReleaseAsset({
    required String id,
    required String name,
    required String url,
    required int size,
    required String contentType,
    String? sha256,
    String? minSdkVersion,
    String? targetArch,
  }) = _ReleaseAsset;

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) =>
      _$ReleaseAssetFromJson(json);
}
