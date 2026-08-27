import 'dart:async';

import 'package:flutter/material.dart';

import '../studio_ui/data/studio_profile_repository.dart';
import '../studio_ui/screens/studio_profile_gate.dart';
import 'components/hybrid_bottom_navigation.dart';
import 'data/hybrid_catalog_controller.dart';
import 'hybrid_mobile_destination.dart';
import 'hybrid_mobile_scope.dart';
import 'theme/hybrid_mobile_tokens.dart';

typedef HybridMobileDestinationBuilder =
    Widget Function(BuildContext context, HybridMobileDestination destination);

class HybridMobileShell extends StatefulWidget {
  const HybridMobileShell({
    super.key,
    required this.catalog,
    required this.profileRepository,
    required this.destinationBuilder,
    this.navigationController,
    this.initialDestination = HybridMobileDestination.home,
  });

  final HybridCatalogController catalog;
  final StudioProfileStore profileRepository;
  final HybridMobileDestinationBuilder destinationBuilder;
  final HybridMobileNavigationController? navigationController;
  final HybridMobileDestination initialDestination;

  @override
  State<HybridMobileShell> createState() => _HybridMobileShellState();
}

class _HybridMobileShellState extends State<HybridMobileShell> {
  late final HybridMobileNavigationController _navigation;
  late final bool _ownsNavigation;
  bool _profileChosenThisSession = false;

  @override
  void initState() {
    super.initState();
    _ownsNavigation = widget.navigationController == null;
    _navigation =
        widget.navigationController ??
        HybridMobileNavigationController(
          initialDestination: widget.initialDestination,
        );
    unawaited(widget.catalog.load());
  }

  void _selectProfile(_) {
    setState(() {
      _profileChosenThisSession = true;
      _navigation.selectDestination(HybridMobileDestination.home);
    });
  }

  @override
  void dispose() {
    if (_ownsNavigation) _navigation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_profileChosenThisSession) {
      return Material(
        color: HybridMobileTokens.background,
        child: StudioProfileGate(
          repository: widget.profileRepository,
          onSelected: _selectProfile,
        ),
      );
    }

    return HybridMobileScope(
      catalog: widget.catalog,
      navigation: _navigation,
      child: ListenableBuilder(
        listenable: _navigation,
        builder: (context, _) {
          final destination = _navigation.destination;
          return PopScope(
            canPop: !_navigation.canHandleBack,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _navigation.pop();
            },
            child: Scaffold(
              backgroundColor: HybridMobileTokens.background,
              body: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  SafeArea(
                    bottom: false,
                    child: IndexedStack(
                      index: destination.index,
                      children: <Widget>[
                        for (final value in HybridMobileDestination.values)
                          KeyedSubtree(
                            key: PageStorageKey<String>(
                              'hybrid-destination-${value.name}',
                            ),
                            child: widget.destinationBuilder(context, value),
                          ),
                      ],
                    ),
                  ),
                  for (final route in _navigation.routes)
                    Positioned.fill(
                      child: ColoredBox(
                        color: HybridMobileTokens.background,
                        child: route.child,
                      ),
                    ),
                ],
              ),
              bottomNavigationBar: _navigation.hasOverlay
                  ? null
                  : HybridBottomNavigation(
                      selectedIndex: destination.index,
                      onSelected: (index) {
                        FocusManager.instance.primaryFocus?.unfocus();
                        _navigation.selectDestination(
                          HybridMobileDestination.values[index],
                        );
                      },
                    ),
            ),
          );
        },
      ),
    );
  }
}
