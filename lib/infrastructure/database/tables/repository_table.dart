import 'package:isar/isar.dart';

part 'repository_table.g.dart';

/// Database table for repository entities
@collection
class RepositoryTable {
  Id? id;

  @Index(unique: true, type: IndexType.value)
  late String repositoryId;

  late String name;
  late String url;
  late String type; // RepositoryType enum value
  late bool isEnabled;
  late DateTime addedAt;

  String? description;
  String? iconUrl;
  String? maintainer;
  int? appCount;
  DateTime? lastSynced;
  String? lastError;
  bool isValid = true;

  String? metadataJson; // Serialized metadata

  RepositoryTable();

  factory RepositoryTable.fromEntity(Map<String, dynamic> entity) {
    final table = RepositoryTable()
      ..repositoryId = entity['id'] as String
      ..name = entity['name'] as String
      ..url = entity['url'] as String
      ..type = entity['type'] as String
      ..isEnabled = entity['isEnabled'] as bool
      ..addedAt = entity['addedAt'] as DateTime
      ..description = entity['description'] as String?
      ..iconUrl = entity['iconUrl'] as String?
      ..maintainer = entity['maintainer'] as String?
      ..appCount = entity['appCount'] as int?
      ..lastSynced = entity['lastSynced'] as DateTime?
      ..lastError = entity['lastError'] as String?
      ..isValid = entity['isValid'] as bool? ?? true;

    return table;
  }

  Map<String, dynamic> toEntity() {
    return {
      'id': repositoryId,
      'name': name,
      'url': url,
      'type': type,
      'isEnabled': isEnabled,
      'addedAt': addedAt,
      'description': description,
      'iconUrl': iconUrl,
      'maintainer': maintainer,
      'appCount': appCount,
      'lastSynced': lastSynced,
      'lastError': lastError,
      'isValid': isValid,
    };
  }
}
