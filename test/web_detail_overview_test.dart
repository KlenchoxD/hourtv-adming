import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/new_ui/hourtv_web_detail_overview.dart';

void main() {
  testWidgets(
    'limita a seis créditos únicos y coloca reparto bajo la información',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HourTvWebDetailOverview(
                channel: Channel(
                  name: 'Historia',
                  url: 'movie:test',
                  forcedType: 'movie',
                  plot: 'Sinopsis real',
                  cast: 'Ana, Luis, Ana, Sara, Pedro, Eva, Juan, Extra',
                ),
                actions: const Text('Acciones'),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(CircleAvatar), findsNWidgets(6));
      expect(find.text('Extra'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Reparto principal')).dx,
        greaterThan(350),
      );
      expect(
        tester.getTopLeft(find.text('Reparto principal')).dy,
        greaterThan(tester.getBottomRight(find.text('Sinopsis real')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('sinopsis expandible y reparto real sin datos inventados', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HourTvWebDetailOverview(
              channel: Channel(
                name: 'Historia',
                url: 'movie:test',
                forcedType: 'movie',
                plot: List.filled(30, 'Una historia real.').join(' '),
                cast: 'Ana Pérez, Luis Soto, Ana Pérez',
                director: 'Directora Real',
              ),
              actions: const Text('Acciones'),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Sobre la película'), findsOneWidget);
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('Luis Soto'), findsOneWidget);
    expect(find.text('Directora Real'), findsOneWidget);
    expect(find.text('Estreno'), findsNothing);
    await tester.tap(find.text('Ver sinopsis completa'));
    await tester.pump();
    expect(find.text('Ver menos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'serie sin reparto no crea tarjetas vacías y cabe en web estrecha',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HourTvWebDetailOverview(
                channel: Channel(
                  name: 'Serie',
                  url: 'series:test',
                  forcedType: 'series',
                ),
                actions: const Text('Acciones'),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Sobre la serie'), findsOneWidget);
      expect(find.text('Reparto principal'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
