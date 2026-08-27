import 'package:flutter/widgets.dart';

import 'data/hybrid_catalog_controller.dart';
import 'hybrid_mobile_destination.dart';

class HybridMobileScope extends InheritedNotifier<HybridMobileNavigationController> {
  const HybridMobileScope({
    super.key,
    required this.catalog,
    required HybridMobileNavigationController navigation,
    required super.child,
  }) : super(notifier: navigation);

  final HybridCatalogController catalog;

  HybridMobileNavigationController get navigation => notifier!;

  static HybridMobileScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<HybridMobileScope>();
    assert(scope != null, 'HybridMobileScope is missing above this context.');
    return scope!;
  }
}
