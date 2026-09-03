import 'package:freezed_annotation/freezed_annotation.dart';

part 'collection_entity.freezed.dart';
part 'collection_entity.g.dart';

/// Collection entity for organizing apps
@freezed
class CollectionEntity with _$CollectionEntity {
  const factory CollectionEntity({
    required String id,
    required String name,
    required String icon,
    required String color,
    required List<String> appIds,
    DateTime? createdAt,
    String? description,
    DateTime? updatedAt,
    bool? isSystem,
  }) = _CollectionEntity;

  factory CollectionEntity.fromJson(Map<String, dynamic> json) =>
      _$CollectionEntityFromJson(json);
}

/// Default collections
class DefaultCollections {
  DefaultCollections._();

  static const music = CollectionEntity(
    id: 'music',
    name: 'Music',
    icon: 'music_note',
    color: '#E91E63',
    appIds: [],
    createdAt: null,
    isSystem: true,
  );

  static const productivity = CollectionEntity(
    id: 'productivity',
    name: 'Productivity',
    icon: 'work',
    color: '#2196F3',
    appIds: [],
    createdAt: null,
    isSystem: true,
  );

  static const social = CollectionEntity(
    id: 'social',
    name: 'Social',
    icon: 'people',
    color: '#4CAF50',
    appIds: [],
    createdAt: null,
    isSystem: true,
  );

  static const development = CollectionEntity(
    id: 'development',
    name: 'Development',
    icon: 'code',
    color: '#FF9800',
    appIds: [],
    createdAt: null,
    isSystem: true,
  );

  static const all = [music, productivity, social, development];
}
