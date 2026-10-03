import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Tendencia no presenta historial local mientras espera tendencias',
    () async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      final store = ContentStore.instance;
      store.resetForTesting();
      final movie = Channel(
        name: 'El diario de una princesa',
        url: 'vod:princesa',
        forcedType: 'movie',
      );
      store.all = [movie];
      await StorageService.saveRecent(movie);
      expect(store.trending, isEmpty);
      store.resetForTesting();
    },
  );
}
