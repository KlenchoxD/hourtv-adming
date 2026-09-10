import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/hourtv_account_profile.dart';
import 'profile_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository({
    this.client,
    this.api,
    required this.currentUserId,
  });

  final SupabaseClient? client;
  final dynamic api;
  final String? Function() currentUserId;

  String _requireUserId() {
    final uid = currentUserId();
    if (uid == null || uid.trim().isEmpty) {
      throw StateError('Usuario no autenticado para operaciones de perfil.');
    }
    return uid;
  }

  @override
  Future<List<HourTvAccountProfile>> list() async {
    final userId = _requireUserId();
    if (api != null) {
      final rows = await api.select(userId);
      final list = (rows as List)
          .map((r) => HourTvAccountProfile.fromJson(Map<String, dynamic>.from(r)))
          .toList();
      list.sort((a, b) => a.position.compareTo(b.position));
      return list;
    }

    final response = await client!
        .from('account_profiles')
        .select()
        .eq('owner_id', userId)
        .order('position');

    return (response as List)
        .map((r) => HourTvAccountProfile.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  @override
  Future<HourTvAccountProfile> create(ProfileDraft draft) async {
    final userId = _requireUserId();
    final existing = await list();
    if (existing.length >= 5) {
      throw const ProfileLimitException();
    }

    final position = existing.isEmpty
        ? 0
        : (existing.map((e) => e.position).reduce((a, b) => a > b ? a : b) + 1);

    final row = {
      'owner_id': userId,
      'name': draft.name.trim(),
      'avatar_id': draft.avatarId.trim(),
      'is_kids': draft.isKids,
      'position': position,
    };

    if (api != null) {
      try {
        final inserted = await api.insert(row);
        return HourTvAccountProfile.fromJson(Map<String, dynamic>.from(inserted));
      } catch (e) {
        if (_isLimitViolation(e)) {
          throw const ProfileLimitException();
        }
        rethrow;
      }
    }

    try {
      final response = await client!
          .from('account_profiles')
          .insert(row)
          .select()
          .single();
      return HourTvAccountProfile.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      if (_isLimitViolation(e)) {
        throw const ProfileLimitException();
      }
      rethrow;
    }
  }

  @override
  Future<HourTvAccountProfile> update(HourTvAccountProfile profile) async {
    final userId = _requireUserId();
    final updates = {
      'name': profile.name.trim(),
      'avatar_id': profile.avatarId.trim(),
      'is_kids': profile.isKids,
    };

    if (api != null) {
      final updated = await api.update(profile.id, userId, updates);
      return HourTvAccountProfile.fromJson(Map<String, dynamic>.from(updated));
    }

    final response = await client!
        .from('account_profiles')
        .update(updates)
        .eq('id', profile.id)
        .eq('owner_id', userId)
        .select()
        .single();
    return HourTvAccountProfile.fromJson(Map<String, dynamic>.from(response));
  }

  @override
  Future<void> delete(String profileId) async {
    final userId = _requireUserId();
    if (api != null) {
      await api.delete(profileId, userId);
      return;
    }

    await client!
        .from('account_profiles')
        .delete()
        .eq('id', profileId)
        .eq('owner_id', userId);
  }

  bool _isLimitViolation(Object error) {
    final str = error.toString().toLowerCase();
    return str.contains('23514') || str.contains('profile_limit_exceeded');
  }
}
