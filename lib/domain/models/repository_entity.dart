import 'package:equatable/equatable.dart';

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

class RepositoryEntity extends Equatable {
  final String id;
  final String name;
  final String url;
  final RepositoryType type;
  final bool isEnabled;
  final DateTime addedAt;
  final String? description;
  final String? iconUrl;
  final String? maintainer;
  final int? appCount;
  final DateTime? lastSynced;
  final String? lastError;
  final bool? isValid;
  final Map<String, dynamic>? metadata;

  const RepositoryEntity({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    required this.isEnabled,
    required this.addedAt,
    this.description,
    this.iconUrl,
    this.maintainer,
    this.appCount,
    this.lastSynced,
    this.lastError,
    this.isValid,
    this.metadata,
  });

  factory RepositoryEntity.fromJson(Map<String, dynamic> json) => RepositoryEntity(
        id: json['id'] as String,
        name: json['name'] as String,
        url: json['url'] as String,
        type: RepositoryType.values.firstWhere((t) => t.name == json['type'], orElse: () => RepositoryType.genericFeed),
        isEnabled: json['isEnabled'] as bool,
        addedAt: json['addedAt'] is String ? DateTime.parse(json['addedAt'] as String) : json['addedAt'] as DateTime,
        description: json['description'] as String?,
        iconUrl: json['iconUrl'] as String?,
        maintainer: json['maintainer'] as String?,
        appCount: json['appCount'] as int?,
        lastSynced: json['lastSynced'] == null ? null : (json['lastSynced'] is String ? DateTime.tryParse(json['lastSynced'] as String) : json['lastSynced'] as DateTime?),
        lastError: json['lastError'] as String?,
        isValid: json['isValid'] as bool?,
        metadata: json['metadata'] as Map<String, dynamic>?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'type': type.name,
        'isEnabled': isEnabled,
        'addedAt': addedAt.toIso8601String(),
        'description': description,
        'iconUrl': iconUrl,
        'maintainer': maintainer,
        'appCount': appCount,
        'lastSynced': lastSynced?.toIso8601String(),
        'lastError': lastError,
        'isValid': isValid,
        'metadata': metadata,
      };

  RepositoryEntity copyWith({
    String? id,
    String? name,
    String? url,
    RepositoryType? type,
    bool? isEnabled,
    DateTime? addedAt,
    String? description,
    String? iconUrl,
    String? maintainer,
    int? appCount,
    DateTime? lastSynced,
    String? lastError,
    bool? isValid,
    Map<String, dynamic>? metadata,
  }) =>
      RepositoryEntity(
        id: id ?? this.id,
        name: name ?? this.name,
        url: url ?? this.url,
        type: type ?? this.type,
        isEnabled: isEnabled ?? this.isEnabled,
        addedAt: addedAt ?? this.addedAt,
        description: description ?? this.description,
        iconUrl: iconUrl ?? this.iconUrl,
        maintainer: maintainer ?? this.maintainer,
        appCount: appCount ?? this.appCount,
        lastSynced: lastSynced ?? this.lastSynced,
        lastError: lastError ?? this.lastError,
        isValid: isValid ?? this.isValid,
        metadata: metadata ?? this.metadata,
      );

  @override
  List<Object?> get props => [id, url, type, isEnabled];
}

class ValidationResult extends Equatable {
  final bool isValid;
  final String message;
  final List<String>? warnings;
  final Map<String, dynamic>? metadata;

  const ValidationResult({required this.isValid, required this.message, this.warnings, this.metadata});

  factory ValidationResult.fromJson(Map<String, dynamic> json) => ValidationResult(
        isValid: json['isValid'] as bool,
        message: json['message'] as String,
        warnings: json['warnings'] == null ? null : List<String>.from(json['warnings'] as List),
        metadata: json['metadata'] as Map<String, dynamic>?,
      );

  Map<String, dynamic> toJson() => {'isValid': isValid, 'message': message, 'warnings': warnings, 'metadata': metadata};

  @override
  List<Object?> get props => [isValid, message];
}
