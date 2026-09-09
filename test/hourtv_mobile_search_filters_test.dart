import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_components.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_shell.dart';
import 'package:streamtv/models/channel.dart';

class _MemorySearchHistoryStore implements HourTvSearchHistoryStore {
  List<String> values = [];
  @override
  Future<List<String>> load() async => values;
  @override
  Future<void> save(List<String> history) async => values = List.of(history);
}

void main() {
  final sampleContent = <Channel>[
    Channel(
      name: 'Matrix Resurrections',
      url: 'movie://matrix',
      forcedType: 'movie',
      genre: 'Ciencia Ficción, Acción',
      year: '2021',
    ),
    Channel(
      name: 'El Padrino',
      url: 'movie://padrino',
      forcedType: 'movie',
      genre: 'Drama / Crimen',
      year: '1972',
    ),
    Channel(
      name: 'Breaking Bad',
      url: 'series://bb',
      forcedType: 'series',
      genre: 'drama',
      categories: const ['Crimen | Suspenso'],
      year: '2008',
    ),
    Channel(
      name: 'Attack on Titan',
      url: 'series://aot',
      forcedType: 'series',
      genre: 'Animación',
      group: 'Series Anime',
      categories: const ['Acción', 'Fantasía'],
      year: '2013',
    ),
    Channel(
      name: 'Betty la Fea',
      url: 'series://betty',
      forcedType: 'series',
      genre: 'Comedia',
      group: 'Telenovelas RCN',
      year: '1999',
    ),
    Channel(
      name: 'Contenido Sin Género',
      url: 'movie://sin-genero',
      forcedType: 'movie',
      year: '2020',
    ),
    Channel(
      name: 'Junk Metadata Item',
      url: 'movie://junk',
      forcedType: 'movie',
      genre: '4K, 1080p, Latino',
      categories: const ['Películas', 'VOD', 'Estrenos'],
      year: '2024',
    ),
  ];

  Widget buildTestWidget(
    WidgetTester tester, {
    List<Channel>? content,
    HourTvSearchHistoryStore? historyStore,
  }) {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    return MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: HourTvMobileSearch(
          content: content ?? sampleContent,
          historyStore: historyStore ?? _MemorySearchHistoryStore(),
          onOpen: (_) {},
        ),
      ),
    );
  }

  testWidgets('renderiza los selectores compactos TIPO y GÉNERO', (tester) async {
    await tester.pumpWidget(buildTestWidget(tester));
    await tester.pumpAndSettle();

    expect(find.text('TIPO'), findsOneWidget);
    expect(find.text('GÉNERO'), findsOneWidget);
  });

  testWidgets('ya no aparece la fila rígida HourTvEvenTabs en el buscador', (tester) async {
    await tester.pumpWidget(buildTestWidget(tester));
    await tester.pumpAndSettle();

    expect(find.byType(HourTvEvenTabs), findsNothing);
  });

  testWidgets('el selector de tipo abre la hoja inferior y muestra sus 5 opciones', (tester) async {
    await tester.pumpWidget(buildTestWidget(tester));
    await tester.pumpAndSettle();

    // Toca el selector de tipo
    await tester.tap(find.text('TIPO'));
    await tester.pumpAndSettle();

    expect(find.text('Tipo de contenido'), findsOneWidget);
    expect(find.text('Todo'), findsWidgets);
    expect(find.text('Películas'), findsOneWidget);
    expect(find.text('Series'), findsOneWidget);
    expect(find.text('Anime'), findsOneWidget);
    expect(find.text('Novelas'), findsOneWidget);
  });

  testWidgets('filtro tipo Películas muestra solamente películas', (tester) async {
    await tester.pumpWidget(buildTestWidget(tester));
    await tester.pumpAndSettle();

    await tester.tap(find.text('TIPO'));
    await tester.pumpAndSettle();

    final pelisOption = find.text('Películas');
    await tester.ensureVisible(pelisOption);
    await tester.tap(pelisOption);
    await tester.pumpAndSettle();

    expect(find.text('Matrix Resurrections'), findsOneWidget);
    expect(find.text('El Padrino'), findsOneWidget);
    expect(find.text('Contenido Sin Género'), findsOneWidget);
    expect(find.text('Junk Metadata Item'), findsOneWidget);
    expect(find.text('Breaking Bad'), findsNothing);
    expect(find.text('Attack on Titan'), findsNothing);
    expect(find.text('Betty la Fea'), findsNothing);
  });

  testWidgets('filtro tipo Series muestra solamente series', (tester) async {
    await tester.pumpWidget(buildTestWidget(tester));
    await tester.pumpAndSettle();

    await tester.tap(find.text('TIPO'));
    await tester.pumpAndSettle();

    final seriesOption = find.text('Series');
    await tester.ensureVisible(seriesOption);
    await tester.tap(seriesOption);
    await tester.pumpAndSettle();

    expect(find.text('Breaking Bad'), findsOneWidget);
    expect(find.text('Attack on Titan'), findsOneWidget);
    expect(find.text('Betty la Fea'), findsOneWidget);
    expect(find.text('Matrix Resurrections'), findsNothing);
    expect(find.text('El Padrino'), findsNothing);
  });

  testWidgets('filtro tipo Anime y Novelas conservan la detección de metadatos', (tester) async {
    await tester.pumpWidget(buildTestWidget(tester));
    await tester.pumpAndSettle();

    // Anime
    await tester.tap(find.text('TIPO'));
    await tester.pumpAndSettle();
    final animeOption = find.text('Anime');
    await tester.ensureVisible(animeOption);
    await tester.tap(animeOption);
    await tester.pumpAndSettle();

    expect(find.text('Attack on Titan'), findsOneWidget);
    expect(find.text('Matrix Resurrections'), findsNothing);

    // Novelas
    await tester.tap(find.text('TIPO'));
    await tester.pumpAndSettle();
    final novelasOption = find.text('Novelas');
    await tester.ensureVisible(novelasOption);
    await tester.tap(novelasOption);
    await tester.pumpAndSettle();

    expect(find.text('Betty la Fea'), findsOneWidget);
    expect(find.text('Attack on Titan'), findsNothing);
  });

  testWidgets('el selector de género extrae y divide valores delimitados ignorando basura técnica', (tester) async {
    await tester.pumpWidget(buildTestWidget(tester));
    await tester.pumpAndSettle();

    await tester.tap(find.text('GÉNERO'));
    await tester.pumpAndSettle();

    expect(find.text('Géneros'), findsOneWidget);
    expect(find.text('Todos los géneros'), findsWidgets);
    expect(find.text('Acción'), findsOneWidget);
    expect(find.text('Drama'), findsOneWidget);
    expect(find.text('Ciencia Ficción'), findsOneWidget);
    expect(find.text('Crimen'), findsOneWidget);
    expect(find.text('Suspenso'), findsOneWidget);

    // Basura técnica excluida
    expect(find.text('4K'), findsNothing);
    expect(find.text('1080p'), findsNothing);
    expect(find.text('Latino'), findsNothing);
    expect(find.text('VOD'), findsNothing);
    expect(find.text('Estrenos'), findsNothing);
  });

  testWidgets('seleccionar Drama filtra películas y series que contienen Drama', (tester) async {
    await tester.pumpWidget(buildTestWidget(tester));
    await tester.pumpAndSettle();

    await tester.tap(find.text('GÉNERO'));
    await tester.pumpAndSettle();

    final dramaOption = find.text('Drama');
    await tester.ensureVisible(dramaOption);
    await tester.tap(dramaOption);
    await tester.pumpAndSettle();

    expect(find.text('El Padrino'), findsOneWidget);
    expect(find.text('Breaking Bad'), findsOneWidget);
    expect(find.text('Matrix Resurrections'), findsNothing);
    expect(find.text('Attack on Titan'), findsNothing);
    expect(find.text('Betty la Fea'), findsNothing);
  });

  testWidgets('texto + tipo + género funcionan conjuntamente', (tester) async {
    await tester.pumpWidget(buildTestWidget(tester));
    await tester.pumpAndSettle();

    // Tipo: Series
    await tester.tap(find.text('TIPO'));
    await tester.pumpAndSettle();
    final seriesOption = find.text('Series');
    await tester.ensureVisible(seriesOption);
    await tester.tap(seriesOption);
    await tester.pumpAndSettle();

    // Género: Drama
    await tester.tap(find.text('GÉNERO'));
    await tester.pumpAndSettle();
    final dramaOption = find.text('Drama');
    await tester.ensureVisible(dramaOption);
    await tester.tap(dramaOption);
    await tester.pumpAndSettle();

    // Solo Breaking Bad (serie con drama)
    expect(find.text('Breaking Bad'), findsOneWidget);
    expect(find.text('El Padrino'), findsNothing); // Padrino es película

    // Escribir texto que no coincide
    await tester.enterText(
      find.byKey(const ValueKey('hourtv-mobile-search-field')),
      'Inexistente',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Breaking Bad'), findsNothing);
    expect(find.text('No hay coincidencias con los filtros actuales'), findsOneWidget);
  });

  testWidgets('cambiar tipo resetea a Todos los géneros si el género ya no existe en el subconjunto', (tester) async {
    await tester.pumpWidget(buildTestWidget(tester));
    await tester.pumpAndSettle();

    // Tipo: Películas
    await tester.tap(find.text('TIPO'));
    await tester.pumpAndSettle();
    final pelisOption = find.text('Películas');
    await tester.ensureVisible(pelisOption);
    await tester.tap(pelisOption);
    await tester.pumpAndSettle();

    // Género: Ciencia Ficción (solo existe en Películas Matrix)
    await tester.tap(find.text('GÉNERO'));
    await tester.pumpAndSettle();
    final scifiOption = find.text('Ciencia Ficción');
    await tester.ensureVisible(scifiOption);
    await tester.tap(scifiOption);
    await tester.pumpAndSettle();

    expect(find.text('Matrix Resurrections'), findsOneWidget);

    // Cambiar tipo a Novelas (Betty la Fea no tiene Ciencia Ficción)
    await tester.tap(find.text('TIPO'));
    await tester.pumpAndSettle();
    final novelasOption = find.text('Novelas');
    await tester.ensureVisible(novelasOption);
    await tester.tap(novelasOption);
    await tester.pumpAndSettle();

    // Debe mostrar Betty y el selector de género debe haber vuelto a "Todos los géneros"
    expect(find.text('Betty la Fea'), findsOneWidget);
    expect(find.text('Todos los géneros'), findsOneWidget);
  });

  testWidgets('canal sin género se muestra en Todos los géneros y no provoca errores', (tester) async {
    await tester.pumpWidget(buildTestWidget(tester));
    await tester.pumpAndSettle();

    expect(find.text('Contenido Sin Género'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ordenamiento funciona correctamente con filtros activos', (tester) async {
    await tester.pumpWidget(buildTestWidget(tester));
    await tester.pumpAndSettle();

    // Filtrar Drama (Padrino 1972, Breaking Bad 2008)
    await tester.tap(find.text('GÉNERO'));
    await tester.pumpAndSettle();
    final dramaOption = find.text('Drama');
    await tester.ensureVisible(dramaOption);
    await tester.tap(dramaOption);
    await tester.pumpAndSettle();

    expect(find.text('2 resultados'), findsOneWidget);

    // Abrir menú de orden y elegir Más antiguos
    await tester.tap(find.text('Más recientes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Más antiguos'));
    await tester.pumpAndSettle();

    expect(find.text('Más antiguos'), findsOneWidget);
    expect(find.text('El Padrino'), findsOneWidget);
    expect(find.text('Breaking Bad'), findsOneWidget);
  });

  testWidgets('reconcilia genero al actualizar catalogo via pumpWidget restableciendo a Todos los generos si desaparece', (tester) async {
    final initialList = <Channel>[
      Channel(
        name: 'Item Drama',
        url: 'movie://1',
        forcedType: 'movie',
        genre: 'Drama',
      ),
      Channel(
        name: 'Item SciFi',
        url: 'movie://2',
        forcedType: 'movie',
        genre: 'Ciencia Ficción',
      ),
    ];

    await tester.pumpWidget(buildTestWidget(tester, content: initialList));
    await tester.pumpAndSettle();

    // Seleccionar Ciencia Ficción
    await tester.tap(find.text('GÉNERO'));
    await tester.pumpAndSettle();

    final scifiOption = find.descendant(
      of: find.byType(GridView),
      matching: find.text('Ciencia Ficción'),
    );
    await tester.ensureVisible(scifiOption);
    await tester.tap(scifiOption);
    await tester.pumpAndSettle();

    expect(find.text('Item SciFi'), findsOneWidget);
    expect(find.text('Item Drama'), findsNothing);

    // Ahora actualizar el catalogo mediante pumpWidget removiendo los items de Ciencia Ficción
    final updatedList = <Channel>[
      Channel(
        name: 'Item Drama',
        url: 'movie://1',
        forcedType: 'movie',
        genre: 'Drama',
        year: '2020',
      ),
      Channel(
        name: 'Item Comedia Nuevo',
        url: 'movie://3',
        forcedType: 'movie',
        genre: 'Comedia',
        year: '2023',
      ),
    ];

    await tester.pumpWidget(buildTestWidget(tester, content: updatedList));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // El género desaparecido debe haberse restablecido a Todos los géneros
    expect(find.text('Todos los géneros'), findsOneWidget);
    expect(find.text('Item Drama'), findsOneWidget);
    expect(find.text('Item Comedia Nuevo'), findsOneWidget);
  });

  testWidgets('reconcilia genero al actualizar catalogo conservando el genero si continua disponible', (tester) async {
    final initialList = <Channel>[
      Channel(
        name: 'Item Drama 1',
        url: 'movie://1',
        forcedType: 'movie',
        genre: 'Drama',
        year: '2020',
      ),
      Channel(
        name: 'Item Comedia',
        url: 'movie://2',
        forcedType: 'movie',
        genre: 'Comedia',
        year: '2021',
      ),
    ];

    await tester.pumpWidget(buildTestWidget(tester, content: initialList));
    await tester.pumpAndSettle();

    // Seleccionar Drama
    await tester.tap(find.text('GÉNERO'));
    await tester.pumpAndSettle();

    final dramaOption = find.descendant(
      of: find.byType(GridView),
      matching: find.text('Drama'),
    );
    await tester.ensureVisible(dramaOption);
    await tester.tap(dramaOption);
    await tester.pumpAndSettle();

    expect(find.text('Item Drama 1'), findsOneWidget);

    // Actualizar catalogo agregando otro Drama
    final updatedList = <Channel>[
      Channel(
        name: 'Item Drama 1',
        url: 'movie://1',
        forcedType: 'movie',
        genre: 'Drama',
        year: '2020',
      ),
      Channel(
        name: 'Item Drama 2',
        url: 'movie://3',
        forcedType: 'movie',
        genre: 'Drama',
        year: '2022',
      ),
    ];

    await tester.pumpWidget(buildTestWidget(tester, content: updatedList));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Drama debe conservarse
    expect(find.text('Drama'), findsOneWidget);
    expect(find.text('Item Drama 1'), findsOneWidget);
    expect(find.text('Item Drama 2'), findsOneWidget);
  });
}
