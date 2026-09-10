final class HourTvAccountProfile {
  const HourTvAccountProfile({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.avatarId,
    required this.isKids,
    required this.position,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final String avatarId;
  final bool isKids;
  final int position;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory HourTvAccountProfile.fromJson(Map<String, dynamic> json) {
    return HourTvAccountProfile(
      id: json['id'] as String? ?? '',
      ownerId: json['owner_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarId: json['avatar_id'] as String? ?? '',
      isKids: json['is_kids'] as bool? ?? false,
      position: (json['position'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner_id': ownerId,
        'name': name,
        'avatar_id': avatarId,
        'is_kids': isKids,
        'position': position,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };

  Map<String, dynamic> toInsertJson() => {
        'owner_id': ownerId,
        'name': name.trim(),
        'avatar_id': avatarId.trim(),
        'is_kids': isKids,
        'position': position,
      };

  HourTvAccountProfile copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? avatarId,
    bool? isKids,
    int? position,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HourTvAccountProfile(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      avatarId: avatarId ?? this.avatarId,
      isKids: isKids ?? this.isKids,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HourTvAccountProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          ownerId == other.ownerId &&
          name == other.name &&
          avatarId == other.avatarId &&
          isKids == other.isKids &&
          position == other.position;

  @override
  int get hashCode =>
      id.hashCode ^
      ownerId.hashCode ^
      name.hashCode ^
      avatarId.hashCode ^
      isKids.hashCode ^
      position.hashCode;
}

final class ProfileDraft {
  const ProfileDraft({
    required this.name,
    required this.avatarId,
    this.isKids = false,
  });

  final String name;
  final String avatarId;
  final bool isKids;
}

class ProfileLimitException implements Exception {
  final String message;
  const ProfileLimitException([this.message = 'Se alcanzó el límite máximo de 5 perfiles.']);
  @override
  String toString() => message;
}
