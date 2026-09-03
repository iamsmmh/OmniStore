import 'package:isar/isar.dart';

part 'app_table.g.dart';

/// Database table for app entities
@collection
class AppTable {
  Id? id;

  @Index(unique: true, type: IndexType.value)
  late String appId;

  late String name;
  late String bundleId;
  late String developer;
  late String description;
  late String version;
  late String buildNumber;
  late DateTime releaseDate;
  late String iconUrl;

  @Index()
  late String repositoryId;

  List<String> screenshots = [];
  List<String> categories = [];
  List<String> tags = [];

  late int downloadSize;
  late String minOsVersion;
  late String sourceUrl;

  String? changelog;
  String? sha256;
  String? downloadUrl;

  @Index()
  bool isInstalled = false;

  String? installedVersion;

  @Index()
  bool isFavorite = false;

  DateTime? lastUpdated;

  AppTable();

  /// Create from domain entity
  factory AppTable.fromEntity(Map<String, dynamic> entity) {
    final table = AppTable()
      ..appId = entity['id'] as String
      ..name = entity['name'] as String
      ..bundleId = entity['bundleId'] as String
      ..developer = entity['developer'] as String
      ..description = entity['description'] as String
      ..version = entity['version'] as String
      ..buildNumber = entity['buildNumber'] as String
      ..releaseDate = entity['releaseDate'] as DateTime
      ..iconUrl = entity['iconUrl'] as String
      ..repositoryId = entity['repositoryId'] as String
      ..screenshots = List<String>.from(entity['screenshots'] as List)
      ..categories = List<String>.from(entity['categories'] as List)
      ..tags = List<String>.from(entity['tags'] as List)
      ..downloadSize = entity['downloadSize'] as int
      ..minOsVersion = entity['minOsVersion'] as String
      ..sourceUrl = entity['sourceUrl'] as String
      ..changelog = entity['changelog'] as String?
      ..sha256 = entity['sha256'] as String?
      ..downloadUrl = entity['downloadUrl'] as String?
      ..isInstalled = entity['isInstalled'] as bool? ?? false
      ..installedVersion = entity['installedVersion'] as String?
      ..isFavorite = entity['isFavorite'] as bool? ?? false
      ..lastUpdated = DateTime.now();

    return table;
  }

  /// Convert to domain entity map
  Map<String, dynamic> toEntity() {
    return {
      'id': appId,
      'name': name,
      'bundleId': bundleId,
      'developer': developer,
      'description': description,
      'version': version,
      'buildNumber': buildNumber,
      'releaseDate': releaseDate,
      'iconUrl': iconUrl,
      'repositoryId': repositoryId,
      'screenshots': screenshots,
      'categories': categories,
      'tags': tags,
      'downloadSize': downloadSize,
      'minOsVersion': minOsVersion,
      'sourceUrl': sourceUrl,
      'changelog': changelog,
      'sha256': sha256,
      'downloadUrl': downloadUrl,
      'isInstalled': isInstalled,
      'installedVersion': installedVersion,
      'isFavorite': isFavorite,
      'lastUpdated': lastUpdated,
    };
  }
}
