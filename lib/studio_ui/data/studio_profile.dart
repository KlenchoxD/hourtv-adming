import 'package:flutter/foundation.dart';

@immutable
class StudioProfile {
  const StudioProfile({
    required this.id,
    required this.name,
    required this.avatarKey,
    this.isKids = false,
    this.isLocked = false,
  });

  final String id;
  final String name;
  final String avatarKey;
  final bool isKids;
  final bool isLocked;

  StudioProfile copyWith({
    String? name,
    String? avatarKey,
    bool? isKids,
    bool? isLocked,
  }) {
    return StudioProfile(
      id: id,
      name: name ?? this.name,
      avatarKey: avatarKey ?? this.avatarKey,
      isKids: isKids ?? this.isKids,
      isLocked: isLocked ?? this.isLocked,
    );
  }

  Map<String, Object> toJson() => <String, Object>{
    'id': id,
    'name': name,
    'avatarKey': avatarKey,
    'isKids': isKids,
    'isLocked': isLocked,
  };

  factory StudioProfile.fromJson(Map<String, dynamic> json) {
    return StudioProfile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      avatarKey: json['avatarKey']?.toString() ?? 'emerald',
      isKids: json['isKids'] == true,
      isLocked: json['isLocked'] == true,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is StudioProfile &&
        other.id == id &&
        other.name == name &&
        other.avatarKey == avatarKey &&
        other.isKids == isKids &&
        other.isLocked == isLocked;
  }

  @override
  int get hashCode => Object.hash(id, name, avatarKey, isKids, isLocked);
}
