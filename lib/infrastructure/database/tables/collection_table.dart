import 'package:isar/isar.dart';

part 'collection_table.g.dart';

/// Database table for collection entities
@collection
class CollectionTable {
  Id? id;

  @Index(unique: true, type: IndexType.value)
  late String collectionId;

  late String name;
  late String icon;
  late String color;
  List<String> appIds = [];
  DateTime? createdAt;

  String? description;
  DateTime? updatedAt;
  bool isSystem = false;

  CollectionTable();

  factory CollectionTable.fromEntity(Map<String, dynamic> entity) {
    final table = CollectionTable()
      ..collectionId = entity['id'] as String
      ..name = entity['name'] as String
      ..icon = entity['icon'] as String
      ..color = entity['color'] as String
      ..appIds = List<String>.from(entity['appIds'] as List)
      ..createdAt = entity['createdAt'] as DateTime?
      ..description = entity['description'] as String?
      ..updatedAt = entity['updatedAt'] as DateTime?
      ..isSystem = entity['isSystem'] as bool? ?? false;

    return table;
  }

  Map<String, dynamic> toEntity() {
    return {
      'id': collectionId,
      'name': name,
      'icon': icon,
      'color': color,
      'appIds': appIds,
      'createdAt': createdAt,
      'description': description,
      'updatedAt': updatedAt,
      'isSystem': isSystem,
    };
  }
}
