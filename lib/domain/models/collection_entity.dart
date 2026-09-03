import 'package:equatable/equatable.dart';

class CollectionEntity extends Equatable {
  final String id;
  final String name;
  final String icon;
  final String color;
  final List<String> appIds;
  final DateTime createdAt;
  final String? description;
  final DateTime? updatedAt;
  final bool? isSystem;

  const CollectionEntity({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.appIds,
    required this.createdAt,
    this.description,
    this.updatedAt,
    this.isSystem,
  });

  factory CollectionEntity.fromJson(Map<String, dynamic> json) => CollectionEntity(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String,
        color: json['color'] as String,
        appIds: List<String>.from(json['appIds'] as List? ?? []),
        createdAt: json['createdAt'] is String ? DateTime.parse(json['createdAt'] as String) : json['createdAt'] as DateTime,
        description: json['description'] as String?,
        updatedAt: json['updatedAt'] == null ? null : (json['updatedAt'] is String ? DateTime.tryParse(json['updatedAt'] as String) : json['updatedAt'] as DateTime?),
        isSystem: json['isSystem'] as bool?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'color': color,
        'appIds': appIds,
        'createdAt': createdAt.toIso8601String(),
        'description': description,
        'updatedAt': updatedAt?.toIso8601String(),
        'isSystem': isSystem,
      };

  @override
  List<Object?> get props => [id, name];
}

class DefaultCollections {
  DefaultCollections._();

  static final music = CollectionEntity(
    id: 'music',
    name: 'Music',
    icon: 'music_note',
    color: '#E91E63',
    appIds: const [],
    createdAt: DateTime(2024, 1, 1),
    isSystem: true,
  );

  static final productivity = CollectionEntity(
    id: 'productivity',
    name: 'Productivity',
    icon: 'work',
    color: '#2196F3',
    appIds: const [],
    createdAt: DateTime(2024, 1, 1),
    isSystem: true,
  );

  static final social = CollectionEntity(
    id: 'social',
    name: 'Social',
    icon: 'people',
    color: '#4CAF50',
    appIds: const [],
    createdAt: DateTime(2024, 1, 1),
    isSystem: true,
  );

  static final development = CollectionEntity(
    id: 'development',
    name: 'Development',
    icon: 'code',
    color: '#FF9800',
    appIds: const [],
    createdAt: DateTime(2024, 1, 1),
    isSystem: true,
  );

  static List<CollectionEntity> get all => [music, productivity, social, development];
}
