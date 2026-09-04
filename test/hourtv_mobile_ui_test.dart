import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/main.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_components.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_shell.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_theme.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/storage_service.dart';
import 'package:streamtv/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // El selector de perfil obligatorio no es lo que estas pruebas verifican:
  // se marca como ya elegido para que HourTVApp entre directo a la app.
  StorageService.hasChosenProfile.value = true;

  testWidgets('phone app uses the approved HourTV emerald theme', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HourTVApp());
    // _LaunchSplash deja un Future.delayed pendiente si el test termina
    // antes de que dispare: se agota para no dejar timers colgados.
    await tester.pump(const Duration(milliseconds: 950));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.colorScheme.primary, const Color(0xFF00C781));
    expect(app.theme?.scaffoldBackgroundColor, const Color(0xFF050505));
    expect(AppColors.accent, const Color(0xFF00C781));
  });

  testWidgets(
    'el escalado de texto del sistema queda acotado para no romper la UI',
    (WidgetTester tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 3.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(const HourTVApp());
      // _LaunchSplash deja un Future.delayed pendiente si el test termina
      // antes de que dispare: se agota para no dejar timers colgados.
      await tester.pump(const Duration(milliseconds: 950));

      final context = tester.element(find.byType(Scaffold).first);
      final scaler = MediaQuery.textScalerOf(context);
      expect(scaler.scale(100), 130);
    },
  );

  testWidgets('phone navigation exposes the five approved destinations', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const HourTVApp());
    // Pasa la pausa de marca de _LaunchSplash (900ms) antes de que aparezca
    // la app de verdad.
    await tester.pump(const Duration(milliseconds: 950));

    final nav = find.byType(HourTvBottomNavigation);
    expect(find.text('INICIO'), findsOneWidget);
    // "TV" tambien aparece dentro de la pastilla verde del logo HourTV en el
    // header: se busca solo dentro de la barra de navegacion inferior.
    expect(
      find.descendant(of: nav, matching: find.text('TV')),
      findsOneWidget,
    );
    expect(find.text('BUSCAR'), findsOneWidget);
    expect(find.text('MI BIBLIOTECA'), findsOneWidget);
    expect(find.text('PERFIL'), findsOneWidget);
  });

  testWidgets('mobile search ignores accents and persists submitted history', (
    WidgetTester tester,
  ) async {
    final history = _MemorySearchHistoryStore();
    Channel? opened;
    await tester.pumpWidget(
      MaterialApp(
        theme: HourTvMobileTheme.build(),
        home: Scaffold(
          body: HourTvMobileSearch(
            content: <Channel>[
              Channel(
                name: 'Álma de cristal',
                url: 'movie://alma',
                forcedType: 'movie',
                year: '2023',
              ),
              Channel(
                name: 'Frontera Roja',
                url: 'series://frontera',
                forcedType: 'series',
                year: '2026',
              ),
            ],
            historyStore: history,
            onOpen: (channel) => opened = channel,
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('hourtv-mobile-search-field')),
      'alma de cristal',
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('1 resultado'), findsOneWidget);
    expect(find.text('Álma de cristal'), findsOneWidget);
    expect(history.values, isEmpty);

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(history.values, <String>['alma de cristal']);
    await tester.ensureVisible(find.text('Álma de cristal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Álma de cristal'));
    expect(opened?.url, 'movie://alma');
  });

  testWidgets('mobile search reveals the real catalog progressively', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final content = <Channel>[
      for (var index = 0; index < 42; index++)
        Channel(
          name: 'Título ${index.toString().padLeft(2, '0')}',
          url: 'movie://$index',
          forcedType: 'movie',
          year: '${2000 + index}',
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: HourTvMobileTheme.build(),
        home: Scaffold(
          body: HourTvMobileSearch(
            content: content,
            historyStore: _MemorySearchHistoryStore(),
            onOpen: (_) {},
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('hourtv-mobile-search-field')),
      'titulo',
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('42 resultados'), findsOneWidget);
    expect(_mobileSearchGridCount(tester), 18);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2200));
    await tester.pumpAndSettle();
    expect(_mobileSearchGridCount(tester), greaterThan(18));
  });
}

int _mobileSearchGridCount(WidgetTester tester) => tester
    .widget<SliverGrid>(
      find.byKey(const ValueKey('hourtv-mobile-search-results-grid')),
    )
    .delegate
    .estimatedChildCount!;

class _MemorySearchHistoryStore implements HourTvSearchHistoryStore {
  List<String> values = <String>[];

  @override
  Future<List<String>> load() async => <String>[...values];

  @override
  Future<void> save(List<String> history) async {
    values = <String>[...history];
  }
}
