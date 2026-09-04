import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/parental_control_service.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/services/storage_service.dart';
import 'package:streamtv/services/xtream_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
  });

  test('stores a hashed PIN and verifies it', () async {
    await ParentalControlService.enable('2468');

    expect(ParentalControlService.isEnabled, isTrue);
    expect(ParentalControlService.verifyPin('2468'), isTrue);
    expect(ParentalControlService.verifyPin('0000'), isFalse);
    expect(
      StorageService.getSetting(ParentalControlService.pinHashKey),
      isNot('2468'),
    );
  });

  test('rejects invalid PIN formats', () {
    expect(() => ParentalControlService.enable('12'), throwsArgumentError);
    expect(() => ParentalControlService.enable('abcd'), throwsArgumentError);
  });

  test(
    'detects explicit adult metadata without treating IMDb score as age',
    () {
      expect(
        ParentalControlService.isAdultChannel(
          Channel(name: 'Adulto', url: 'a', rating: '18+'),
        ),
        isTrue,
      );
      expect(
        ParentalControlService.isAdultChannel(
          Channel(name: 'Madura', url: 'b', categories: const ['TV-MA']),
        ),
        isTrue,
      );
      expect(
        ParentalControlService.isAdultChannel(
          Channel(name: 'Bien valorada', url: 'c', rating: '9.6'),
        ),
        isFalse,
      );
    },
  );

  test(
    'filters channels and series only while restricted mode is enabled',
    () async {
      final safe = Channel(name: 'Familiar', url: 'safe', rating: '7.8');
      final adult = Channel(name: 'Adulto', url: 'adult', genre: '+18');
      final matureSeries = XtreamSeries(
        seriesId: '1',
        name: 'Madura',
        host: 'host',
        username: 'user',
        password: 'pass',
        rating: 'TV-MA',
      );

      expect(
        ParentalControlService.filterChannels([safe, adult]),
        hasLength(2),
      );
      await ParentalControlService.enable('1234');

      expect(ParentalControlService.filterChannels([safe, adult]), [safe]);
      expect(ParentalControlService.filterSeries([matureSeries]), isEmpty);
    },
  );

  test(
    'ContentStore hides mature catalog entries without deleting source data',
    () async {
      final store = ContentStore.instance;
      final previous = store.all;
      addTearDown(() => store.all = previous);
      store.all = [
        Channel(name: 'Familiar', url: 'safe', forcedType: 'movie'),
        Channel(
          name: 'Adulto',
          url: 'adult',
          forcedType: 'movie',
          rating: '18+',
        ),
      ];

      await ParentalControlService.enable('1234');

      expect(store.all, hasLength(2));
      expect(store.visibleAll.map((item) => item.url), ['safe']);
      expect(store.movies.map((item) => item.url), ['safe']);
    },
  );
}
