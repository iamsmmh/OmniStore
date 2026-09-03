import 'package:equatable/equatable.dart';

class UpdateEntity extends Equatable {
  final String appId;
  final String appName;
  final String iconUrl;
  final String installedVersion;
  final String latestVersion;
  final String buildNumber;
  final DateTime releaseDate;
  final int downloadSize;
  final String repositoryId;
  final String? changelog;
  final String? downloadUrl;
  final String? sha256;
  final bool? isIgnored;
  final DateTime? detectedAt;

  const UpdateEntity({
    required this.appId,
    required this.appName,
    required this.iconUrl,
    required this.installedVersion,
    required this.latestVersion,
    required this.buildNumber,
    required this.releaseDate,
    required this.downloadSize,
    required this.repositoryId,
    this.changelog,
    this.downloadUrl,
    this.sha256,
    this.isIgnored,
    this.detectedAt,
  });

  factory UpdateEntity.fromJson(Map<String, dynamic> json) => UpdateEntity(
        appId: json['appId'] as String,
        appName: json['appName'] as String,
        iconUrl: json['iconUrl'] as String,
        installedVersion: json['installedVersion'] as String,
        latestVersion: json['latestVersion'] as String,
        buildNumber: json['buildNumber'] as String,
        releaseDate: json['releaseDate'] is String ? DateTime.parse(json['releaseDate'] as String) : json['releaseDate'] as DateTime,
        downloadSize: json['downloadSize'] as int? ?? 0,
        repositoryId: json['repositoryId'] as String,
        changelog: json['changelog'] as String?,
        downloadUrl: json['downloadUrl'] as String?,
        sha256: json['sha256'] as String?,
        isIgnored: json['isIgnored'] as bool?,
        detectedAt: json['detectedAt'] == null ? null : (json['detectedAt'] is String ? DateTime.tryParse(json['detectedAt'] as String) : json['detectedAt'] as DateTime?),
      );

  Map<String, dynamic> toJson() => {
        'appId': appId,
        'appName': appName,
        'iconUrl': iconUrl,
        'installedVersion': installedVersion,
        'latestVersion': latestVersion,
        'buildNumber': buildNumber,
        'releaseDate': releaseDate.toIso8601String(),
        'downloadSize': downloadSize,
        'repositoryId': repositoryId,
        'changelog': changelog,
        'downloadUrl': downloadUrl,
        'sha256': sha256,
        'isIgnored': isIgnored,
        'detectedAt': detectedAt?.toIso8601String(),
      };

  bool get isAvailable => installedVersion != latestVersion;

  @override
  List<Object?> get props => [appId, installedVersion, latestVersion];
}

class UpdatePreferences extends Equatable {
  final bool autoCheck;
  final bool notifyUpdates;
  final bool includePrereleases;
  final bool autoDownload;
  final bool autoInstall;
  final int checkIntervalMinutes;

  const UpdatePreferences({
    this.autoCheck = true,
    this.notifyUpdates = true,
    this.includePrereleases = false,
    this.autoDownload = false,
    this.autoInstall = false,
    this.checkIntervalMinutes = 360,
  });

  factory UpdatePreferences.fromJson(Map<String, dynamic> json) => UpdatePreferences(
        autoCheck: json['autoCheck'] as bool? ?? true,
        notifyUpdates: json['notifyUpdates'] as bool? ?? true,
        includePrereleases: json['includePrereleases'] as bool? ?? false,
        autoDownload: json['autoDownload'] as bool? ?? false,
        autoInstall: json['autoInstall'] as bool? ?? false,
        checkIntervalMinutes: json['checkIntervalMinutes'] as int? ?? 360,
      );

  Map<String, dynamic> toJson() => {
        'autoCheck': autoCheck,
        'notifyUpdates': notifyUpdates,
        'includePrereleases': includePrereleases,
        'autoDownload': autoDownload,
        'autoInstall': autoInstall,
        'checkIntervalMinutes': checkIntervalMinutes,
      };

  @override
  List<Object?> get props => [autoCheck, notifyUpdates, checkIntervalMinutes];
}
