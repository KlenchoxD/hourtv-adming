import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/models/epg_program.dart';
import 'package:streamtv/services/stalker_service.dart';
import 'package:streamtv/services/xtream_service.dart';

void main() {
  group('StalkerService', () {
    test('normaliza URLs habituales del portal', () {
      expect(
        StalkerService.normalizePortal('portal.example/stalker_portal/c/'),
        'http://portal.example/stalker_portal/server/load.php',
      );
      expect(
        StalkerService.normalizePortal(
          'https://portal.example/server/load.php',
        ),
        'https://portal.example/server/load.php',
      );
    });

    test('valida y normaliza la MAC', () {
      expect(StalkerService.isValidMac('00:1a:79:ab:cd:ef'), isTrue);
      expect(
        StalkerService.normalizeMac('00:1a:79:ab:cd:ef'),
        '00:1A:79:AB:CD:EF',
      );
      expect(StalkerService.isValidMac('00-1A-79-AB-CD-EF'), isFalse);
    });
  });

  group('Xtream catch-up', () {
    test('crea la URL timeshift para un programa emitido', () {
      final channel = Channel(
        name: 'Canal',
        url: 'http://provider.test:8080/live/user/pass/42.ts',
        hasCatchup: true,
      );
      final program = EpgProgram(
        channelId: '42',
        title: 'Programa',
        start: DateTime.utc(2020, 1, 2, 3, 4),
        stop: DateTime.utc(2020, 1, 2, 4, 34),
      );

      expect(
        XtreamService.buildTimeshiftUrl(channel, program),
        'http://provider.test:8080/timeshift/user/pass/90/'
        '2020-01-02:03-04/42.ts',
      );
    });

    test('no ofrece timeshift si el canal no tiene archivo', () {
      final channel = Channel(
        name: 'Canal',
        url: 'http://provider.test/live/user/pass/42.ts',
      );
      final program = EpgProgram(
        channelId: '42',
        title: 'Programa',
        start: DateTime.utc(2020),
        stop: DateTime.utc(2020, 1, 1, 1),
      );

      expect(XtreamService.buildTimeshiftUrl(channel, program), isNull);
    });
  });
}
