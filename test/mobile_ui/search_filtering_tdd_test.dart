import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_shell.dart';
import 'package:streamtv/services/catalog_presentation_index.dart';
import 'package:streamtv/database/catalog_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<Channel> sampleChannels = [
    Channel(name: 'The Matrix', url: 'https://video/1', genre: 'Ciencia Ficción'),
    Channel(name: 'Matrix Reloaded', url: 'https://video/2', genre: 'Ciencia Ficción'),
    Channel(name: 'Matrix Revolutions', url: 'https://video/3', genre: 'Ciencia Ficción'),
    Channel(name: 'Avatar', url: 'https://video/4', genre: 'Aventura'),
    Channel(name: 'Inception', url: 'https://video/5', genre: 'Acción'),
    Channel(name: 'Zootopia Fin Del Catalogo', url: 'https://video/6', genre: 'Animación'),
  ];

  Widget createSearchWidget({List<Channel>? channels}) {
    final list = channels ?? sampleChannels;
    return MaterialApp(
      home: Scaffold(
        body: HourTvMobileSearch(
          content: list,
          presentationIndex: CatalogPresentationIndex.build(list),
          onOpen: (_) {},
        ),
      ),
    );
  }

  group('HourTvMobileSearch TDD Filtering Tests', () {
    testWidgets('1. La búsqueda "Matrix" solo devuelve coincidencias reales y no el catálogo completo', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createSearchWidget());
      await tester.pumpAndSettle();

      // Estado inicial: Descubre con todos los elementos
      expect(find.text('Descubre'), findsOneWidget);

      // Escribir "Matrix" en el campo de búsqueda
      final searchField = find.byKey(const ValueKey('hourtv-mobile-search-field'));
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'Matrix');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      // Debe mostrar exactamente 3 resultados
      expect(find.text('3 resultados'), findsOneWidget);
      expect(find.text('The Matrix'), findsOneWidget);
      expect(find.text('Matrix Reloaded'), findsOneWidget);
      expect(find.text('Matrix Revolutions'), findsOneWidget);

      // Elementos que no contienen Matrix NO deben estar visibles
      expect(find.text('Avatar'), findsNothing);
      expect(find.text('Inception'), findsNothing);
      expect(find.text('Zootopia Fin Del Catalogo'), findsNothing);
    });

    testWidgets('2. Una búsqueda inexistente devuelve cero coincidencias y muestra estado vacío', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createSearchWidget());
      await tester.pumpAndSettle();

      final searchField = find.byKey(const ValueKey('hourtv-mobile-search-field'));
      await tester.enterText(searchField, 'TerminoQueNoExisteEnElCatalogo12345');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      // Contador en 0 resultados y mensaje de vacío
      expect(find.text('0 resultados'), findsOneWidget);
      expect(find.text('No hay coincidencias con los filtros actuales'), findsOneWidget);
      expect(find.text('The Matrix'), findsNothing);
      expect(find.text('Avatar'), findsNothing);
    });

    testWidgets('3. Borrar la consulta restaura el catálogo completo', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createSearchWidget());
      await tester.pumpAndSettle();

      final searchField = find.byKey(const ValueKey('hourtv-mobile-search-field'));
      await tester.enterText(searchField, 'Matrix');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('3 resultados'), findsOneWidget);

      // Borrar texto de búsqueda
      await tester.enterText(searchField, '');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      // Debe restaurar "Descubre" y mostrar los elementos del catálogo
      expect(find.text('Descubre'), findsOneWidget);
      expect(find.text('The Matrix'), findsOneWidget);
      expect(find.text('Avatar'), findsOneWidget);
      expect(find.text('Inception'), findsOneWidget);
    });

    testWidgets('4. El último resultado del catálogo es localizable', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createSearchWidget());
      await tester.pumpAndSettle();

      final searchField = find.byKey(const ValueKey('hourtv-mobile-search-field'));
      await tester.enterText(searchField, 'Zootopia');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text('1 resultado'), findsOneWidget);
      expect(find.text('Zootopia Fin Del Catalogo'), findsOneWidget);
      expect(find.text('The Matrix'), findsNothing);
    });

    testWidgets('5. Con CatalogPageSource activo, una búsqueda que devuelve 0 resultados NO recurre al catálogo completo', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = CatalogDatabase.inMemory();
      addTearDown(db.close);

      final pageSource = CatalogPageSource(dao: db.catalogDao, pageSize: 20);
      addTearDown(pageSource.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HourTvMobileSearch(
            content: sampleChannels,
            presentationIndex: CatalogPresentationIndex.build(sampleChannels),
            catalogPageSource: pageSource,
            onOpen: (_) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final searchField = find.byKey(const ValueKey('hourtv-mobile-search-field'));
      await tester.enterText(searchField, 'Matrix');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      // Debe reportar 0 resultados y NO los 6 elementos del catálogo estático
      expect(find.text('0 resultados'), findsOneWidget);
      expect(find.text('No hay coincidencias con los filtros actuales'), findsOneWidget);
      expect(find.text('The Matrix'), findsNothing);
      expect(find.text('Avatar'), findsNothing);
    });
  });
}

