import 'package:equatable/equatable.dart';

class AppEntity extends Equatable {
  final String id;
  final String name;
  final String bundleId;
  final String developer;
  final String description;
  final String version;
  final String buildNumber;
  final DateTime releaseDate;
  final String iconUrl;
  final List<String> screenshots;
  final List<String> categories;
  final List<String> tags;
  final int downloadSize;
  final String minOsVersion;
  final String sourceUrl;
  final String repositoryId;
  final String? changelog;
  final String? sha256;
  final String? downloadUrl;
  final bool? isInstalled;
  final String? installedVersion;
  final bool? isFavorite;
  final DateTime? lastUpdated;

  const AppEntity({
    required this.id,
    required this.name,
    required this.bundleId,
    required this.developer,
    required this.description,
    required this.version,
    required this.buildNumber,
    required this.releaseDate,
    required this.iconUrl,
    required this.screenshots,
    required this.categories,
    required this.tags,
    required this.downloadSize,
    required this.minOsVersion,
    required this.sourceUrl,
    required this.repositoryId,
    this.changelog,
    this.sha256,
    this.downloadUrl,
    this.isInstalled,
    this.installedVersion,
    this.isFavorite,
    this.lastUpdated,
  });

  factory AppEntity.fromJson(Map<String, dynamic> json) => AppEntity(
        id: json['id'] as String,
        name: json['name'] as String,
        bundleId: json['bundleId'] as String,
        developer: json['developer'] as String,
        description: json['description'] as String,
        version: json['version'] as String,
        buildNumber: json['buildNumber'] as String,
        releaseDate: json['releaseDate'] is String ? DateTime.parse(json['releaseDate'] as String) : json['releaseDate'] as DateTime,
        iconUrl: json['iconUrl'] as String,
        screenshots: List<String>.from(json['screenshots'] as List? ?? []),
        categories: List<String>.from(json['categories'] as List? ?? []),
        tags: List<String>.from(json['tags'] as List? ?? []),
        downloadSize: json['downloadSize'] as int? ?? 0,
        minOsVersion: json['minOsVersion'] as String? ?? '',
        sourceUrl: json['sourceUrl'] as String? ?? '',
        repositoryId: json['repositoryId'] as String? ?? '',
        changelog: json['changelog'] as String?,
        sha256: json['sha256'] as String?,
        downloadUrl: json['downloadUrl'] as String?,
        isInstalled: json['isInstalled'] as bool?,
        installedVersion: json['installedVersion'] as String?,
        isFavorite: json['isFavorite'] as bool?,
        lastUpdated: json['lastUpdated'] is String ? DateTime.tryParse(json['lastUpdated'] as String) : json['lastUpdated'] as DateTime?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'bundleId': bundleId,
        'developer': developer,
        'description': description,
        'version': version,
        'buildNumber': buildNumber,
        'releaseDate': releaseDate.toIso8601String(),
        'iconUrl': iconUrl,
        'screenshots': screenshots,
        'categories': categories,
        'tags': tags,
        'downloadSize': downloadSize,
        'minOsVersion': minOsVersion,
        'sourceUrl': sourceUrl,
        'repositoryId': repositoryId,
        'changelog': changelog,
        'sha256': sha256,
        'downloadUrl': downloadUrl,
        'isInstalled': isInstalled,
        'installedVersion': installedVersion,
        'isFavorite': isFavorite,
        'lastUpdated': lastUpdated?.toIso8601String(),
      };

  AppEntity copyWith({
    String? id,
    String? name,
    String? bundleId,
    String? developer,
    String? description,
    String? version,
    String? buildNumber,
    DateTime? releaseDate,
    String? iconUrl,
    List<String>? screenshots,
    List<String>? categories,
    List<String>? tags,
    int? downloadSize,
    String? minOsVersion,
    String? sourceUrl,
    String? repositoryId,
    String? changelog,
    String? sha256,
    String? downloadUrl,
    bool? isInstalled,
    String? installedVersion,
    bool? isFavorite,
    DateTime? lastUpdated,
  }) =>
      AppEntity(
        id: id ?? this.id,
        name: name ?? this.name,
        bundleId: bundleId ?? this.bundleId,
        developer: developer ?? this.developer,
        description: description ?? this.description,
        version: version ?? this.version,
        buildNumber: buildNumber ?? this.buildNumber,
        releaseDate: releaseDate ?? this.releaseDate,
        iconUrl: iconUrl ?? this.iconUrl,
        screenshots: screenshots ?? this.screenshots,
        categories: categories ?? this.categories,
        tags: tags ?? this.tags,
        downloadSize: downloadSize ?? this.downloadSize,
        minOsVersion: minOsVersion ?? this.minOsVersion,
        sourceUrl: sourceUrl ?? this.sourceUrl,
        repositoryId: repositoryId ?? this.repositoryId,
        changelog: changelog ?? this.changelog,
        sha256: sha256 ?? this.sha256,
        downloadUrl: downloadUrl ?? this.downloadUrl,
        isInstalled: isInstalled ?? this.isInstalled,
        installedVersion: installedVersion ?? this.installedVersion,
        isFavorite: isFavorite ?? this.isFavorite,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );

  @override
  List<Object?> get props => [id, name, bundleId, version, releaseDate, repositoryId];
}

class AppSummary extends Equatable {
  final String id;
  final String name;
  final String bundleId;
  final String developer;
  final String iconUrl;
  final String version;
  final DateTime releaseDate;
  final List<String> categories;
  final bool? isFavorite;
  final bool? isInstalled;
  final String? installedVersion;

  const AppSummary({
    required this.id,
    required this.name,
    required this.bundleId,
    required this.developer,
    required this.iconUrl,
    required this.version,
    required this.releaseDate,
    required this.categories,
    this.isFavorite,
    this.isInstalled,
    this.installedVersion,
  });

  factory AppSummary.fromJson(Map<String, dynamic> json) => AppSummary(
        id: json['id'] as String,
        name: json['name'] as String,
        bundleId: json['bundleId'] as String,
        developer: json['developer'] as String,
        iconUrl: json['iconUrl'] as String,
        version: json['version'] as String,
        releaseDate: json['releaseDate'] is String ? DateTime.parse(json['releaseDate'] as String) : json['releaseDate'] as DateTime,
        categories: List<String>.from(json['categories'] as List? ?? []),
        isFavorite: json['isFavorite'] as bool?,
        isInstalled: json['isInstalled'] as bool?,
        installedVersion: json['installedVersion'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'bundleId': bundleId,
        'developer': developer,
        'iconUrl': iconUrl,
        'version': version,
        'releaseDate': releaseDate.toIso8601String(),
        'categories': categories,
        'isFavorite': isFavorite,
        'isInstalled': isInstalled,
        'installedVersion': installedVersion,
      };

  @override
  List<Object?> get props => [id, name, version];
}
