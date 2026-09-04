import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/services/parental_control_service.dart';
import 'package:streamtv/services/storage_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  test('visibleAll se memoriza pero se invalida al cambiar el catálogo o el '
      'modo restringido', () async {
    final store = ContentStore.instance;
    store.all = [
      Channel(name: 'Familiar', url: 'http://a/1.mp4', genre: 'Comedia'),
      Channel(name: 'Prohibida', url: 'http://a/2.mp4', genre: 'Adultos'),
    ];

    final first = store.visibleAll;
    expect(first.length, 2);
    // Misma lista y mismo estado: debe devolver la instancia cacheada.
    expect(identical(store.visibleAll, first), isTrue);

    await ParentalControlService.enable('1234');
    final restricted = store.visibleAll;
    expect(restricted.map((c) => c.name), ['Familiar']);

    store.all.add(Channel(name: 'Nueva', url: 'http://a/3.mp4'));
    expect(store.visibleAll.length, 2);

    await ParentalControlService.disable('1234');
    expect(store.visibleAll.length, 3);
  });
}
