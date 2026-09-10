import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_shell.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    ContentStore.instance.resetForTesting();
  });

  testWidgets(
    'hero prioriza destacados editoriales reales y no las primeras peliculas',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // No destacados al inicio
      final nonFeatured = List.generate(
        5,
        (i) => Channel(
          name: 'Regular $i',
          url: 'http://stream/regular$i.mp4',
          forcedType: 'movie',
          backdrop: 'http://img/regular$i.jpg',
          isFeatured: false,
        ),
      );

      // Destacados reales ubicados después
      final realFeatured = [
        Channel(
          name: 'Destacado Real Alpha',
          url: 'http://stream/alpha.mp4',
          forcedType: 'movie',
          backdrop: 'http://img/alpha.jpg',
          year: '2024',
          isFeatured: true,
        ),
        Channel(
          name: 'Destacado Real Beta',
          url: 'http://stream/beta.mp4',
          forcedType: 'movie',
          backdrop: 'http://img/beta.jpg',
          year: '2025',
          isFeatured: true,
        ),
      ];

      final allChannels = [...nonFeatured, ...realFeatured];
      ContentStore.instance.all = allChannels;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: HourTvMobileHome(
              movies: allChannels,
              allContent: allChannels,
              store: ContentStore.instance,
              onOpen: (_) {},
              onSearch: () {},
              onProfile: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      // El hero debe contener los destacados reales y NO los primeros regulares
      final heroCarousel = find.byKey(const ValueKey('hourtv-hero-carousel'));
      expect(
        find.descendant(
          of: heroCarousel,
          matching: find.text('Destacado Real Beta'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: heroCarousel,
          matching: find.text('Regular 0'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'destacado sin backdrop o sin fuente reproducible no califica para hero',
    (tester) async {
      final invalidFeatured = [
        Channel(
          name: 'Destacado Sin Imagen',
          url: 'http://stream/valid.mp4',
          forcedType: 'movie',
          backdrop: null,
          isFeatured: true,
        ),
        Channel(
          name: 'Destacado Sin Url',
          url: '',
          forcedType: 'movie',
          backdrop: 'http://img/valid.jpg',
          isFeatured: true,
        ),
        Channel(
          name: 'Destacado Valido',
          url: 'http://stream/valid2.mp4',
          forcedType: 'movie',
          backdrop: 'http://img/valid2.jpg',
          isFeatured: true,
        ),
      ];
      ContentStore.instance.all = invalidFeatured;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: HourTvMobileHome(
              movies: invalidFeatured,
              allContent: invalidFeatured,
              store: ContentStore.instance,
              onOpen: (_) {},
              onSearch: () {},
              onProfile: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final heroCarousel = find.byKey(const ValueKey('hourtv-hero-carousel'));
      expect(
        find.descendant(
          of: heroCarousel,
          matching: find.text('Destacado Valido'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: heroCarousel,
          matching: find.text('Destacado Sin Imagen'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: heroCarousel,
          matching: find.text('Destacado Sin Url'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'actualizacion de catalogo que acorta el carrusel en pagina avanzada no crashea',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final initialFeatured = [
        Channel(
          name: 'Hero 1',
          url: 'http://s/1.mp4',
          forcedType: 'movie',
          backdrop: 'http://img/1.jpg',
          year: '2025',
          isFeatured: true,
        ),
        Channel(
          name: 'Hero 2',
          url: 'http://s/2.mp4',
          forcedType: 'movie',
          backdrop: 'http://img/2.jpg',
          year: '2024',
          isFeatured: true,
        ),
        Channel(
          name: 'Hero 3',
          url: 'http://s/3.mp4',
          forcedType: 'movie',
          backdrop: 'http://img/3.jpg',
          year: '2023',
          isFeatured: true,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: HourTvMobileHome(
              movies: initialFeatured,
              allContent: initialFeatured,
              featured: initialFeatured,
              store: ContentStore.instance,
              onOpen: (_) {},
              onSearch: () {},
              onProfile: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Desplazamos a la página 2 del carrusel (Hero 3)
      final pageViewFinder = find.byType(PageView);
      expect(pageViewFinder, findsOneWidget);

      await tester.drag(pageViewFinder, const Offset(-450, 0));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.drag(pageViewFinder, const Offset(-450, 0));
      await tester.pump(const Duration(milliseconds: 500));

      // Ahora el catálogo se actualiza y solo tiene 1 elemento
      final shortenedFeatured = [
        Channel(
          name: 'Solo Hero',
          url: 'http://s/solo.mp4',
          forcedType: 'movie',
          backdrop: 'http://img/solo.jpg',
          year: '2025',
          isFeatured: true,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: HourTvMobileHome(
              movies: shortenedFeatured,
              allContent: shortenedFeatured,
              featured: shortenedFeatured,
              store: ContentStore.instance,
              onOpen: (_) {},
              onSearch: () {},
              onProfile: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      // No debe lanzar excepciones y debe mostrar el único elemento
      expect(tester.takeException(), isNull);
      expect(find.text('Solo Hero'), findsOneWidget);
    },
  );
}
