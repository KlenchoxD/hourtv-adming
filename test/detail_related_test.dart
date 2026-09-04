import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/new_ui/hourtv_detail_page.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/services/storage_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  testWidgets(
    '"Relacionado" aparece aunque el genero de la ficha sea una lista '
    'compuesta que no coincide letra por letra con otro titulo, y las '
    'acciones de abajo no desbordan en una pantalla angosta',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final target = Channel(
        name: 'Black Widow',
        url: 'http://a/black-widow.mp4',
        forcedType: 'movie',
        genre: 'Acción, Aventura, Ciencia ficción, Superhéroes, Espionaje',
      );
      ContentStore.instance.all = [
        target,
        Channel(
          name: 'Otra película',
          url: 'http://a/otra.mp4',
          forcedType: 'movie',
          genre: 'Comedia',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: HourTvDetailPage(channel: target, preview: false),
        ),
      );
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;

      expect(find.text('RELACIONADO'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
