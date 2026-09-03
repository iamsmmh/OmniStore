import 'package:freezed_annotation/freezed_annotation.dart';

part 'discover_entity.freezed.dart';
part 'discover_entity.g.dart';

/// Discover section types
enum DiscoverSectionType {
  featured,
  trending,
  recentlyUpdated,
  newReleases,
  recommended,
  categories,
}

/// Discover section
@freezed
class DiscoverSection with _$DiscoverSection {
  const factory DiscoverSection({
    required String id,
    required String title,
    required DiscoverSectionType type,
    required List<String> appIds,
    String? subtitle,
    String? actionLabel,
    String? actionUrl,
  }) = _DiscoverSection;

  factory DiscoverSection.fromJson(Map<String, dynamic> json) =>
      _$DiscoverSectionFromJson(json);
}

/// Category entity
@freezed
class CategoryEntity with _$CategoryEntity {
  const factory CategoryEntity({
    required String id,
    required String name,
    required String icon,
    required String color,
    int? appCount,
  }) = _CategoryEntity;

  factory CategoryEntity.fromJson(Map<String, dynamic> json) =>
      _$CategoryEntityFromJson(json);
}

/// Featured item for home screen
@freezed
class FeaturedItem with _$FeaturedItem {
  const factory FeaturedItem({
    required String appId,
    required String title,
    required String subtitle,
    required String imageUrl,
    required String backgroundColor,
    String? actionLabel,
  }) = _FeaturedItem;

  factory FeaturedItem.fromJson(Map<String, dynamic> json) =>
      _$FeaturedItemFromJson(json);
}
