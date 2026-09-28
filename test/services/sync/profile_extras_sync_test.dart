import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/services/storage_service.dart';
import 'package:streamtv/services/sync/profile_extras_sync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _profile = '44444444-4444-4444-8444-444444444444';

/// Imita la tabla y el trigger de la migración: conteo = el mayor; like y
/// setting = el más reciente.
class _FakeStore implements ProfileExtrasStore {
  final rows = <String, Map<String, dynamic>>{};
  bool missing = false;

  @override
  Future<void> upsert(List<Map<String, dynamic>> incoming) async {
    if (missing) throw const PostgrestException(message: 'x', code: 'PGRST205');
    for (final r in incoming) {
      final id = '${r['kind']}|${r['key']}';
      final old = rows[id];
      if (old == null) {
        rows[id] = r;
      } else if (r['kind'] == 'watch_count') {
        if ((r['value'] as num) > (old['value'] as num)) rows[id] = r;
      } else if (DateTime.parse(r['updated_at']).isAfter(
        DateTime.parse(old['updated_at']),
      )) {
        rows[id] = r;
      }
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetch(String profileId) async =>
      rows.values.toList();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    ProfileExtrasSync.resetForTesting();
  });

  test('Me gusta: gana el cambio más reciente entre equipos', () async {
    final store = _FakeStore();
    // Otro equipo quitó el Me gusta de Coco después de que aquí se puso.
    await StorageService.saveLikedUrlsFor(_profile, {'coco'});
    await StorageService.saveLikeStampsFor(_profile, {
      'coco': DateTime.utc(2026, 9, 1),
    });
    store.rows['like|coco'] = {
      'kind': 'like',
      'key': 'coco',
      'value': false,
      'updated_at': DateTime.utc(2026, 9, 20).toIso8601String(),
    };
    // Y le dio Me gusta a Moana, que aquí no estaba.
    store.rows['like|moana'] = {
      'kind': 'like',
      'key': 'moana',
      'value': true,
      'updated_at': DateTime.utc(2026, 9, 21).toIso8601String(),
    };

    final changed = await ProfileExtrasSync.sync(
      _profile,
      includeSettings: false,
      store: store,
    );

    expect(changed, isTrue);
    expect(StorageService.loadLikedUrlsFor(_profile), {'moana'});
  });

  test('conteos: se queda el mayor, sin sumar dos veces', () async {
    final store = _FakeStore();
    await StorageService.saveWatchCountsFor(_profile, {'coco': 3, 'moana': 1});
    store.rows['watch_count|moana'] = {
      'kind': 'watch_count',
      'key': 'moana',
      'value': 5,
      'updated_at': DateTime.utc(2026, 9, 20).toIso8601String(),
    };

    await ProfileExtrasSync.sync(
      _profile,
      includeSettings: false,
      store: store,
    );

    expect(StorageService.loadWatchCountsFor(_profile), {
      'coco': 3,
      'moana': 5,
    });
    expect(store.rows['watch_count|coco']!['value'], 3);
  });

  test('ajustes: el más reciente, solo del perfil en uso', () async {
    final store = _FakeStore();
    await StorageService.saveSetting('subtitleFontScale', 1.0);
    store.rows['setting|subtitleFontScale'] = {
      'kind': 'setting',
      'key': 'subtitleFontScale',
      'value': 1.4,
      'updated_at': DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 1))
          .toIso8601String(),
    };

    await ProfileExtrasSync.sync(
      _profile,
      includeSettings: false,
      store: store,
    );
    expect(StorageService.getSetting('subtitleFontScale'), 1.0);

    await ProfileExtrasSync.sync(
      _profile,
      includeSettings: true,
      store: store,
    );
    expect(StorageService.getSetting('subtitleFontScale'), 1.4);
  });

  test('sin la tabla en Supabase no falla y no insiste', () async {
    final store = _FakeStore()..missing = true;
    await StorageService.saveLikedUrlsFor(_profile, {'coco'});
    expect(
      await ProfileExtrasSync.sync(
        _profile,
        includeSettings: true,
        store: store,
      ),
      isFalse,
    );
    expect(StorageService.loadLikedUrlsFor(_profile), {'coco'});
  });
}
