import 'package:freezed_annotation/freezed_annotation.dart';

part 'repository_entity.freezed.dart';
part 'repository_entity.g.dart';

/// Supported repository types
enum RepositoryType {
  github,
  gitlab,
  codeberg,
  forgejo,
  omnsource,
  altstore,
  feather,
  genericFeed,
}

/// Repository entity representing a source of applications
@freezed
class RepositoryEntity with _$RepositoryEntity {
  const factory RepositoryEntity({
    required String id,
    required String name,
    required String url,
    required RepositoryType type,
    required bool isEnabled,
    required DateTime addedAt,
    String? description,
    String? iconUrl,
    String? maintainer,
    int? appCount,
    DateTime? lastSynced,
    String? lastError,
    bool? isValid,
    Map<String, dynamic>? metadata,
  }) = _RepositoryEntity;

  factory RepositoryEntity.fromJson(Map<String, dynamic> json) =>
      _$RepositoryEntityFromJson(json);
}

/// Repository validation result
@freezed
class ValidationResult with _$ValidationResult {
  const factory ValidationResult({
    required bool isValid,
    required String message,
    List<String>? warnings,
    Map<String, dynamic>? metadata,
  }) = _ValidationResult;

  factory ValidationResult.fromJson(Map<String, dynamic> json) =>
      _$ValidationResultFromJson(json);
}
