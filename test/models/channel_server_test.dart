import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/channel.dart';

void main() {
  group('ChannelServer JSON Serialization - Phase 2 Scope A', () {
    test('Fuente legacy sin health', () {
      final json = {
        'id': 'legacy-uuid',
        'name': 'Legacy Server',
        'url': 'https://legacy.com',
        'language': 'es',
      };
      final server = ChannelServer.fromJson(json);
      expect(server.name, 'Legacy Server');
      expect(server.id, 'legacy-uuid');
      expect(server.health, isNull);
      expect(server.effectiveHealthStatus, 'pending');

      final out = server.toJson();
      expect(out.containsKey('health'), isFalse);
    });

    test('Rechaza health y contadores con tipos inválidos', () {
      final base = <String, dynamic>{
        'id': 'invalid-types',
        'name': 'Invalid',
        'url': 'https://invalid.test',
      };
      expect(
        () => ChannelServer.fromJson({...base, 'health': 'down'}),
        throwsFormatException,
      );
      expect(
        () => ChannelServer.fromJson({
          ...base,
          'health': {'status': 'pending', 'httpCode': '503'},
        }),
        throwsFormatException,
      );
      expect(
        () => ChannelServer.fromJson({
          ...base,
          'health': {'status': 'pending', 'consecutiveFailures': '1'},
        }),
        throwsFormatException,
      );
    });

    test('Mantiene el contrato legacy de language y subtitles vacíos', () {
      final server = ChannelServer.fromJson({
        'name': 'Legacy',
        'url': 'https://legacy.test',
      });
      expect(server.toJson(), containsPair('language', null));
      expect(server.toJson(), containsPair('subtitles', const []));
    });

    test('Fuente con todos los campos de salud', () {
      final json = {
        'id': 'full-uuid',
        'name': 'Full Server',
        'url': 'https://full.com',
        'health': {
          'status': 'degraded',
          'lastError': 'timeout',
          'httpCode': 503,
          'consecutiveFailures': 2,
          'firstFailureAt': '2026-09-20T10:00:00Z',
          'lastSuccessAt': '2026-09-19T10:00:00Z',
          'lastCheck': '2026-09-20T10:05:00Z',
          'lastCheckRunId': 'run-123',
          'recheckRequestedAt': '2026-09-20T10:10:00Z',
        },
        'replacementForId': 'old-uuid',
        'replacedById': 'new-uuid',
      };
      final server = ChannelServer.fromJson(json);
      expect(server.health?.status, 'degraded');
      expect(server.health?.httpCode, 503);
      expect(server.health?.consecutiveFailures, 2);
      expect(server.replacementForId, 'old-uuid');
      expect(server.replacedById, 'new-uuid');
    });

    test('Rechazo de estado desconocido', () {
      final json = {
        'id': 'bad-status',
        'name': 'Bad Server',
        'url': 'https://bad.com',
        'health': {'status': 'unknown_state', 'consecutiveFailures': 0},
      };
      expect(() => ChannelServer.fromJson(json), throwsFormatException);
    });

    test('Rechazo de httpCode fuera de 100-599', () {
      final json = {
        'id': 'bad-http',
        'name': 'Bad HTTP',
        'url': 'https://badhttp.com',
        'health': {
          'status': 'pending',
          'consecutiveFailures': 0,
          'httpCode': 99,
        },
      };
      expect(() => ChannelServer.fromJson(json), throwsFormatException);

      json['health'] = {
        'status': 'pending',
        'consecutiveFailures': 0,
        'httpCode': 600,
      };
      expect(() => ChannelServer.fromJson(json), throwsFormatException);
    });

    test('Rechazo de consecutiveFailures negativo', () {
      final json = {
        'id': 'bad-failures',
        'name': 'Bad Failures',
        'url': 'https://badf.com',
        'health': {'status': 'pending', 'consecutiveFailures': -1},
      };
      expect(() => ChannelServer.fromJson(json), throwsFormatException);
    });

    test('Round trip que preserve id, salud y campos de reemplazo', () {
      final json = {
        'id': 'round-uuid',
        'name': 'Round',
        'url': 'https://round.com',
        'language': 'en',
        'health': {'status': 'active', 'consecutiveFailures': 0},
        'replacementForId': 'r1',
        'replacedById': 'r2',
      };
      final server = ChannelServer.fromJson(json);
      final out = server.toJson();

      expect(out['id'], 'round-uuid');
      expect(out['health']['status'], 'active');
      expect(out['replacementForId'], 'r1');
      expect(out['replacedById'], 'r2');
      // Aseguramos que la entrada y salida sean equivalentes en los campos parseados
      expect(out['name'], 'Round');
      expect(out['url'], 'https://round.com');
      expect(out['language'], 'en');
    });
  });
}
