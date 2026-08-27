import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/hybrid_mobile/components/hybrid_bottom_navigation.dart';
import 'package:streamtv/hybrid_mobile/data/hybrid_catalog_controller.dart';
import 'package:streamtv/hybrid_mobile/hybrid_mobile_destination.dart';
import 'package:streamtv/hybrid_mobile/hybrid_mobile_shell.dart';
import 'package:streamtv/studio_ui/data/studio_profile.dart';
import 'package:streamtv/studio_ui/screens/studio_profile_gate.dart';

import 'support/hybrid_test_app.dart';

void main() {
  late EmptyHybridCatalogSource source;
  late HybridCatalogController catalog;

  setUp(() {
    source = EmptyHybridCatalogSource();
    catalog = HybridCatalogController(source: source);
  });

  tearDown(() {
    catalog.dispose();
    source.dispose();
  });

  testWidgets('requires profile creation before building destinations', (
    tester,
  ) async {
    var destinationBuilds = 0;
    await tester.pumpWidget(
      HybridTestApp(
        child: HybridMobileShell(
          catalog: catalog,
          profileRepository: InMemoryHybridProfileRepository(),
          destinationBuilder: (context, destination) {
            destinationBuilds++;
            return Text(destination.label);
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(StudioProfileGate), findsOneWidget);
    expect(find.text('Crea tu perfil'), findsOneWidget);
    expect(find.byType(HybridBottomNavigation), findsNothing);
    expect(destinationBuilds, 0);
  });

  testWidgets('selects one destination and preserves indexed child state', (
    tester,
  ) async {
    final profile = _profile();
    final controllers = <HybridMobileDestination, ScrollController>{
      for (final destination in HybridMobileDestination.values)
        destination: ScrollController(),
    };
    addTearDown(() {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    });

    await tester.pumpWidget(
      HybridTestApp(
        child: HybridMobileShell(
          catalog: catalog,
          profileRepository: InMemoryHybridProfileRepository(
            profiles: <StudioProfile>[profile],
          ),
          destinationBuilder: (context, destination) => ListView(
            key: ValueKey<String>('page-${destination.name}'),
            controller: controllers[destination],
            children: <Widget>[
              Text('Pantalla ${destination.label}'),
              const SizedBox(height: 1200),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Renata'));
    await tester.pumpAndSettle();

    controllers[HybridMobileDestination.home]!.jumpTo(180);
    await tester.pump();
    await tester.tap(find.text('TV'));
    await tester.pump();
    expect(find.text('Pantalla TV'), findsOneWidget);
    await tester.tap(find.text('Inicio'));
    await tester.pump();

    expect(controllers[HybridMobileDestination.home]!.offset, 180);
    expect(_selectedSemantics(tester), 1);
  });

  testWidgets('details and player layers hide bottom navigation and pop first', (
    tester,
  ) async {
    final navigation = HybridMobileNavigationController();
    addTearDown(navigation.dispose);
    await tester.pumpWidget(
      HybridTestApp(
        child: HybridMobileShell(
          catalog: catalog,
          navigationController: navigation,
          profileRepository: InMemoryHybridProfileRepository(
            profiles: <StudioProfile>[_profile()],
          ),
          destinationBuilder: (context, destination) => Text(destination.label),
        ),
      ),
    );
    await tester.tap(find.text('Renata'));
    await tester.pumpAndSettle();

    navigation.pushDetails(const ColoredBox(
      key: ValueKey<String>('details-layer'),
      color: Colors.black,
    ));
    await tester.pump();
    expect(find.byType(HybridBottomNavigation), findsNothing);
    expect(find.byKey(const ValueKey<String>('details-layer')), findsOneWidget);

    navigation.pushPlayer(const ColoredBox(
      key: ValueKey<String>('player-layer'),
      color: Colors.black,
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('player-layer')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('player-layer')), findsNothing);
    expect(find.byKey(const ValueKey<String>('details-layer')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('details-layer')), findsNothing);
    expect(find.byType(HybridBottomNavigation), findsOneWidget);
  });

  testWidgets('back from another destination returns to Inicio', (tester) async {
    await tester.pumpWidget(
      HybridTestApp(
        child: HybridMobileShell(
          catalog: catalog,
          profileRepository: InMemoryHybridProfileRepository(
            profiles: <StudioProfile>[_profile()],
          ),
          destinationBuilder: (context, destination) => Text(destination.label),
        ),
      ),
    );
    await tester.tap(find.text('Renata'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buscar'));
    await tester.pump();
    expect(find.text('Buscar'), findsWidgets);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Inicio'), findsWidgets);
    expect(_selectedSemantics(tester), 1);
  });
}

StudioProfile _profile() => const StudioProfile(
  id: 'renata',
  name: 'Renata',
  avatarKey: 'avatar-1',
);

int _selectedSemantics(WidgetTester tester) => tester
    .widgetList<Semantics>(find.byType(Semantics))
    .where((widget) => widget.properties.selected == true)
    .length;
