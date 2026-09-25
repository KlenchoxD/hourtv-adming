import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/mobile_ui/hourtv_genre_service.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_shell.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/catalog_presentation_index.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<Channel> createSampleCatalog(int count) {
    return List.generate(
      count,
      (i) => Channel(
        name: 'Titulo $i',
        url: 'http://test/$i',
        forcedType: i % 2 == 0 ? 'movie' : 'series',
        genre: i % 3 == 0 ? 'Acción' : 'Drama',
        year: '${2000 + (i % 25)}',
      ),
    );
  }

  setUp(() {
    CatalogPresentationIndex.resetBuildCountForTest();
    HourTvGenreService.resetNormalizationCountForTest();
  });

  testWidgets(
    'secuencia de tipeo aplica debounce y reutiliza el indice del catalogo',
    (tester) async {
      final catalog = createSampleCatalog(50);

      expect(CatalogPresentationIndex.buildCountForTest, 0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourTvMobileSearch(
              content: catalog,
              presentationIndex: CatalogPresentationIndex.build(catalog),
              onOpen: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Debe haberse construido exactamente 1 índice para el catálogo
      expect(CatalogPresentationIndex.buildCountForTest, 1);

      final normCountAfterMount =
          HourTvGenreService.normalizationCountForTest;

      // Escribir 5 caracteres rápidamente antes del debounce (250ms)
      final searchField = find.byKey(
        const ValueKey('hourtv-mobile-search-field'),
      );
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 't');
      await tester.pump(const Duration(milliseconds: 50));

      await tester.enterText(searchField, 'ti');
      await tester.pump(const Duration(milliseconds: 50));

      await tester.enterText(searchField, 'tit');
      await tester.pump(const Duration(milliseconds: 50));

      await tester.enterText(searchField, 'titu');
      await tester.pump(const Duration(milliseconds: 50));

      await tester.enterText(searchField, 'titul');
      await tester.pump(const Duration(milliseconds: 50));

      // Pasamos el tiempo de debounce
      await tester.pump(const Duration(milliseconds: 300));

      // El índice no debe haberse reconstruido
      expect(CatalogPresentationIndex.buildCountForTest, 1);

      // La normalización no debe haber recorrido los 50 elementos del catálogo de nuevo
      final normDeltaAfterTyping =
          HourTvGenreService.normalizationCountForTest - normCountAfterMount;
      // Solo el query se normaliza (a lo sumo unas pocas veces), no 50 * número de teclas
      expect(normDeltaAfterTyping, lessThan(30));
    },
  );

  testWidgets(
    'filtros, ordenamiento y scroll reutilizan el indice sin reconstruirlo',
    (tester) async {
      final catalog = createSampleCatalog(60);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourTvMobileSearch(
              content: catalog,
              presentationIndex: CatalogPresentationIndex.build(catalog),
              onOpen: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(CatalogPresentationIndex.buildCountForTest, 1);

      // Cambiar tipo mediante el selector
      final tipoSelector = find.byKey(
        const ValueKey('hourtv-search-type-selector'),
      );
      if (tipoSelector.evaluate().isNotEmpty) {
        await tester.tap(tipoSelector);
        await tester.pump();
        final peliculasOption = find.text('Películas');
        if (peliculasOption.evaluate().isNotEmpty) {
          await tester.tap(peliculasOption.last);
          await tester.pump();
        }
      }

      // El índice sigue siendo exactamente 1
      expect(CatalogPresentationIndex.buildCountForTest, 1);

      // Simular scroll hacia abajo
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -500));
      await tester.pump();

      // El índice no debe reconstruirse en scroll
      expect(CatalogPresentationIndex.buildCountForTest, 1);
    },
  );

  testWidgets(
    'reemplazar la lista de catalogo construye exactamente un nuevo indice',
    (tester) async {
      final catalog1 = createSampleCatalog(30);
      final catalog2 = createSampleCatalog(40);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourTvMobileSearch(
              content: catalog1,
              presentationIndex: CatalogPresentationIndex.build(catalog1),
              onOpen: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(CatalogPresentationIndex.buildCountForTest, 1);

      // Reemplazamos por un nuevo catálogo
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourTvMobileSearch(
              content: catalog2,
              presentationIndex: CatalogPresentationIndex.build(catalog2),
              onOpen: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Debe haber construido exactamente un nuevo índice (total 2)
      expect(CatalogPresentationIndex.buildCountForTest, 2);
    },
  );
}
