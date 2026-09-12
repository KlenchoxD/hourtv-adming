import 'package:supabase_flutter/supabase_flutter.dart';

/// Contrato abstracto para la comunicación remota de sincronización de perfiles.
abstract class ProfileSyncGateway {
  Future<List<Map<String, dynamic>>> pushOperations(
    String profileId,
    List<Map<String, dynamic>> operations,
  );

  Future<Map<String, dynamic>> pullChanges(
    String profileId, {
    int sinceRevision = 0,
    int limit = 100,
  });

  Future<Map<String, dynamic>> getProfileSnapshot(String profileId);

  Future<void> updateGuestImportAudit({
    required String profileId,
    required String importBatchId,
    required String status,
    int favoritesCount = 0,
    int progressCount = 0,
    int historyCount = 0,
    String? errorMessage,
  });
}

/// Implementación de ProfileSyncGateway mediante RPCs transaccionales seguras de Supabase.
class SupabaseProfileSyncGateway implements ProfileSyncGateway {
  final SupabaseClient? client;

  SupabaseProfileSyncGateway({this.client});

  @override
  Future<List<Map<String, dynamic>>> pushOperations(
    String profileId,
    List<Map<String, dynamic>> operations,
  ) async {
    final client = this.client;
    if (client == null) {
      throw StateError('SupabaseClient no configurado');
    }

    final response = await client.rpc(
      'push_profile_operations',
      params: {
        'p_profile_id': profileId,
        'p_operations': operations,
      },
    );

    if (response is List) {
      return response.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }
    return [];
  }

  @override
  Future<Map<String, dynamic>> pullChanges(
    String profileId, {
    int sinceRevision = 0,
    int limit = 100,
  }) async {
    final client = this.client;
    if (client == null) {
      throw StateError('SupabaseClient no configurado');
    }

    final response = await client.rpc(
      'pull_profile_changes',
      params: {
        'p_profile_id': profileId,
        'p_since_revision': sinceRevision,
        'p_limit': limit,
      },
    );

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    return {};
  }

  @override
  Future<Map<String, dynamic>> getProfileSnapshot(String profileId) async {
    final client = this.client;
    if (client == null) {
      throw StateError('SupabaseClient no configurado');
    }

    final response = await client.rpc(
      'get_profile_snapshot',
      params: {
        'p_profile_id': profileId,
      },
    );

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    return {};
  }

  @override
  Future<void> updateGuestImportAudit({
    required String profileId,
    required String importBatchId,
    required String status,
    int favoritesCount = 0,
    int progressCount = 0,
    int historyCount = 0,
    String? errorMessage,
  }) async {
    final client = this.client;
    if (client == null) return;

    await client.rpc(
      'update_guest_import_audit',
      params: {
        'p_profile_id': profileId,
        'p_import_batch_id': importBatchId,
        'p_status': status,
        'p_favorites_count': favoritesCount,
        'p_progress_count': progressCount,
        'p_history_count': historyCount,
        'p_error_message': errorMessage,
      },
    );
  }
}

