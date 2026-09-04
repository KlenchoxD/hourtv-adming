import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_components.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_shell.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/services/storage_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  testWidgets(
    'mientras el catálogo real todavía carga, el Inicio muestra un '
    'indicador de carga en vez del contenido de muestra (evita el salto '
    'de "sale lo de prototipo y después lo real")',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final store = ContentStore.instance;
      store.all = [];
      store.loading = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: HourTvMobileHome(
              movies: const [],
              allContent: const [],
              store: store,
              onOpen: (_) {},
              onSearch: () {},
              onProfile: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(HourTvBootLoading), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Cargando catálogo'), findsOneWidget);
      // Nada del catalogo de muestra debe aparecer mientras carga.
      expect(find.textContaining('Project Nova'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
