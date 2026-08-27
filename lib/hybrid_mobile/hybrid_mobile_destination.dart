import 'package:flutter/widgets.dart';

enum HybridMobileDestination { home, liveTv, search, library, profile }

extension HybridMobileDestinationPresentation on HybridMobileDestination {
  String get label => switch (this) {
    HybridMobileDestination.home => 'Inicio',
    HybridMobileDestination.liveTv => 'TV',
    HybridMobileDestination.search => 'Buscar',
    HybridMobileDestination.library => 'Mi Biblioteca',
    HybridMobileDestination.profile => 'Perfil',
  };
}

enum HybridMobileRouteLayer { details, player }

@immutable
class HybridMobileRouteEntry {
  const HybridMobileRouteEntry({required this.layer, required this.child});

  final HybridMobileRouteLayer layer;
  final Widget child;
}

class HybridMobileNavigationController extends ChangeNotifier {
  HybridMobileNavigationController({
    HybridMobileDestination initialDestination = HybridMobileDestination.home,
  }) : _destination = initialDestination;

  HybridMobileDestination _destination;
  final List<HybridMobileRouteEntry> _routes = <HybridMobileRouteEntry>[];

  HybridMobileDestination get destination => _destination;
  List<HybridMobileRouteEntry> get routes =>
      List<HybridMobileRouteEntry>.unmodifiable(_routes);
  bool get hasOverlay => _routes.isNotEmpty;
  bool get canHandleBack => hasOverlay || _destination != HybridMobileDestination.home;

  void selectDestination(HybridMobileDestination value) {
    if (value == _destination && _routes.isEmpty) return;
    _routes.clear();
    _destination = value;
    notifyListeners();
  }

  void pushDetails(Widget child) {
    _routes
      ..clear()
      ..add(
        HybridMobileRouteEntry(
          layer: HybridMobileRouteLayer.details,
          child: child,
        ),
      );
    notifyListeners();
  }

  void pushPlayer(Widget child) {
    _routes.add(
      HybridMobileRouteEntry(
        layer: HybridMobileRouteLayer.player,
        child: child,
      ),
    );
    notifyListeners();
  }

  bool pop() {
    if (_routes.isNotEmpty) {
      _routes.removeLast();
      notifyListeners();
      return true;
    }
    if (_destination != HybridMobileDestination.home) {
      _destination = HybridMobileDestination.home;
      notifyListeners();
      return true;
    }
    return false;
  }
}
