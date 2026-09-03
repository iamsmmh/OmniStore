import 'package:equatable/equatable.dart';

class ReleaseEntity extends Equatable {
  final String id;
  final String appId;
  final String version;
  final String buildNumber;
  final DateTime releaseDate;
  final List<ReleaseAsset> assets;
  final String? changelog;
  final String? minOsVersion;
  final bool? isPrerelease;

  const ReleaseEntity({
    required this.id,
    required this.appId,
    required this.version,
    required this.buildNumber,
    required this.releaseDate,
    required this.assets,
    this.changelog,
    this.minOsVersion,
    this.isPrerelease,
  });

  factory ReleaseEntity.fromJson(Map<String, dynamic> json) => ReleaseEntity(
        id: json['id'] as String,
        appId: json['appId'] as String,
        version: json['version'] as String,
        buildNumber: json['buildNumber'] as String,
        releaseDate: json['releaseDate'] is String ? DateTime.parse(json['releaseDate'] as String) : json['releaseDate'] as DateTime,
        assets: (json['assets'] as List? ?? []).map((e) => ReleaseAsset.fromJson(e as Map<String, dynamic>)).toList(),
        changelog: json['changelog'] as String?,
        minOsVersion: json['minOsVersion'] as String?,
        isPrerelease: json['isPrerelease'] as bool?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'appId': appId,
        'version': version,
        'buildNumber': buildNumber,
        'releaseDate': releaseDate.toIso8601String(),
        'assets': assets.map((e) => e.toJson()).toList(),
        'changelog': changelog,
        'minOsVersion': minOsVersion,
        'isPrerelease': isPrerelease,
      };

  @override
  List<Object?> get props => [id, appId, version];
}

class ReleaseAsset extends Equatable {
  final String id;
  final String name;
  final String url;
  final int size;
  final String contentType;
  final String? sha256;
  final String? minSdkVersion;
  final String? targetArch;

  const ReleaseAsset({
    required this.id,
    required this.name,
    required this.url,
    required this.size,
    required this.contentType,
    this.sha256,
    this.minSdkVersion,
    this.targetArch,
  });

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) => ReleaseAsset(
        id: json['id'] as String,
        name: json['name'] as String,
        url: json['url'] as String,
        size: json['size'] as int? ?? 0,
        contentType: json['contentType'] as String? ?? 'application/octet-stream',
        sha256: json['sha256'] as String?,
        minSdkVersion: json['minSdkVersion'] as String?,
        targetArch: json['targetArch'] as String?,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'url': url, 'size': size, 'contentType': contentType, 'sha256': sha256, 'minSdkVersion': minSdkVersion, 'targetArch': targetArch};

  @override
  List<Object?> get props => [id, url];
}
