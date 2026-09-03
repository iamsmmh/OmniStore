import 'package:equatable/equatable.dart';

enum DiscoverSectionType { featured, trending, recentlyUpdated, newReleases, recommended, categories }

class DiscoverSection extends Equatable {
  final String id;
  final String title;
  final DiscoverSectionType type;
  final List<String> appIds;
  final String? subtitle;
  final String? actionLabel;
  final String? actionUrl;

  const DiscoverSection({
    required this.id,
    required this.title,
    required this.type,
    required this.appIds,
    this.subtitle,
    this.actionLabel,
    this.actionUrl,
  });

  factory DiscoverSection.fromJson(Map<String, dynamic> json) => DiscoverSection(
        id: json['id'] as String,
        title: json['title'] as String,
        type: DiscoverSectionType.values.firstWhere((e) => e.name == json['type'], orElse: () => DiscoverSectionType.featured),
        appIds: List<String>.from(json['appIds'] as List),
        subtitle: json['subtitle'] as String?,
        actionLabel: json['actionLabel'] as String?,
        actionUrl: json['actionUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'type': type.name, 'appIds': appIds, 'subtitle': subtitle, 'actionLabel': actionLabel, 'actionUrl': actionUrl};

  @override
  List<Object?> get props => [id, title, type];
}

class CategoryEntity extends Equatable {
  final String id;
  final String name;
  final String icon;
  final String color;
  final int? appCount;

  const CategoryEntity({required this.id, required this.name, required this.icon, required this.color, this.appCount});

  factory CategoryEntity.fromJson(Map<String, dynamic> json) => CategoryEntity(id: json['id'] as String, name: json['name'] as String, icon: json['icon'] as String, color: json['color'] as String, appCount: json['appCount'] as int?);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'icon': icon, 'color': color, 'appCount': appCount};

  @override
  List<Object?> get props => [id, name];
}

class FeaturedItem extends Equatable {
  final String appId;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String backgroundColor;
  final String? actionLabel;

  const FeaturedItem({required this.appId, required this.title, required this.subtitle, required this.imageUrl, required this.backgroundColor, this.actionLabel});

  factory FeaturedItem.fromJson(Map<String, dynamic> json) => FeaturedItem(appId: json['appId'] as String, title: json['title'] as String, subtitle: json['subtitle'] as String, imageUrl: json['imageUrl'] as String, backgroundColor: json['backgroundColor'] as String, actionLabel: json['actionLabel'] as String?);

  Map<String, dynamic> toJson() => {'appId': appId, 'title': title, 'subtitle': subtitle, 'imageUrl': imageUrl, 'backgroundColor': backgroundColor, 'actionLabel': actionLabel};

  @override
  List<Object?> get props => [appId, title];
}
