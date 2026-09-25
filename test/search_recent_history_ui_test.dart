import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_shell.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/catalog_presentation_index.dart';

class FakeSearchHistoryStore implements HourTvSearchHistoryStore {
  FakeSearchHistoryStore([List<String>? initial])
      : _items = List<String>.from(initial ?? const []);

  List<String> _items;

  @override
  Future<List<String>> load() async => List<String>.unmodifiable(_items);

  @override
  Future<void> save(List<String> history) async {
    _items = List<String>.from(history);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dummyContent = [
    Channel(name: 'Avatar El Camino del Agua', url: 'http://stream/avatar.mp4', forcedType: 'movie'),
    Channel(name: 'Batman Inicia', url: 'http://stream/batman.mp4', forcedType: 'movie'),
    Channel(name: 'Matrix Revoluciones', url: 'http://stream/matrix.mp4', forcedType: 'movie'),
  ];

  testWidgets(
    'muestra historial como filas compactas con icono, texto y boton Borrar, sin ActionChip',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final historyStore = FakeSearchHistoryStore(['Avatar', 'Batman']);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourTvMobileSearch(
              content: dummyContent,
              presentationIndex: CatalogPresentationIndex.build(dummyContent),
              onOpen: (_) {},
              historyStore: historyStore,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No debe contener ActionChip
      expect(find.byType(ActionChip), findsNothing);

      // Debe mostrar el encabezado o boton Borrar
      expect(find.text('Borrar'), findsOneWidget);

      // Debe mostrar las filas de historial con su icono y texto
      expect(find.text('Avatar'), findsOneWidget);
      expect(find.text('Batman'), findsOneWidget);
      expect(find.byIcon(Icons.history_rounded), findsWidgets);
    },
  );

  testWidgets(
    'oculta el historial cuando el usuario comienza a escribir',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final historyStore = FakeSearchHistoryStore(['Matrix']);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourTvMobileSearch(
              content: dummyContent,
              presentationIndex: CatalogPresentationIndex.build(dummyContent),
              onOpen: (_) {},
              historyStore: historyStore,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Matrix'), findsOneWidget);
      expect(find.text('Borrar'), findsOneWidget);

      // El usuario escribe en el campo de busqueda
      await tester.enterText(find.byKey(const ValueKey('hourtv-mobile-search-field')), 'Mat');
      await tester.pump();

      // El historial se oculta inmediatamente al comenzar a escribir
      expect(find.text('Borrar'), findsNothing);
      expect(find.byKey(const ValueKey('hourtv-search-clear-history')), findsNothing);
    },
  );

  testWidgets(
    'pulsar Borrar vacia el historial y persiste la lista vacia en el store',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final historyStore = FakeSearchHistoryStore(['Avatar', 'Matrix']);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourTvMobileSearch(
              content: dummyContent,
              presentationIndex: CatalogPresentationIndex.build(dummyContent),
              onOpen: (_) {},
              historyStore: historyStore,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Borrar'), findsOneWidget);

      await tester.tap(find.text('Borrar'));
      await tester.pumpAndSettle();

      // El historial y el boton borrar desaparecen
      expect(find.text('Borrar'), findsNothing);
      expect(find.text('Avatar'), findsNothing);
      expect(find.text('Matrix'), findsNothing);

      // Se persistió la lista vacía
      final persisted = await historyStore.load();
      expect(persisted, isEmpty);
    },
  );

  testWidgets(
    'cuando el historial esta vacio no muestra Borrar ni filas de historial',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final historyStore = FakeSearchHistoryStore([]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourTvMobileSearch(
              content: dummyContent,
              presentationIndex: CatalogPresentationIndex.build(dummyContent),
              onOpen: (_) {},
              historyStore: historyStore,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Borrar'), findsNothing);
      expect(find.byIcon(Icons.history_rounded), findsNothing);
    },
  );

  testWidgets(
    'pulsar una fila de historial ejecuta la busqueda con ese texto',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final historyStore = FakeSearchHistoryStore(['Matrix']);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourTvMobileSearch(
              content: dummyContent,
              presentationIndex: CatalogPresentationIndex.build(dummyContent),
              onOpen: (_) {},
              historyStore: historyStore,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Matrix'));
      await tester.pumpAndSettle();

      // El campo de busqueda ahora contiene Matrix
      final field = tester.widget<TextField>(find.byKey(const ValueKey('hourtv-mobile-search-field')));
      expect(field.controller?.text, 'Matrix');
      // Muestra resultados que contienen Matrix
      expect(find.text('Matrix Revoluciones'), findsOneWidget);
    },
  );
}
