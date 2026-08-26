import 'package:flutter/material.dart';
import 'package:streamtv/studio_ui/components/studio_bottom_nav.dart';
import 'package:streamtv/studio_ui/components/studio_button.dart';
import 'package:streamtv/studio_ui/components/studio_header.dart';
import 'package:streamtv/studio_ui/components/studio_logo.dart';
import 'package:streamtv/studio_ui/components/studio_media_card.dart';
import 'package:streamtv/studio_ui/foundation/studio_tokens.dart';

import '../support/studio_test_fixtures.dart';

class StudioComponentHarness extends StatelessWidget {
  const StudioComponentHarness({super.key, required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return StudioTestApp(
      child: SizedBox(
        width: width,
        height: 760,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            StudioHeader(
              profileName: 'Renata',
              onHome: () {},
              onProfile: () {},
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(StudioSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const StudioLogo(showTagline: true),
                    const SizedBox(height: StudioSpacing.xxl),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: StudioButton(
                            label: 'Reproducir',
                            icon: Icons.play_arrow_rounded,
                            onPressed: () {},
                          ),
                        ),
                        const SizedBox(width: StudioSpacing.sm),
                        Expanded(
                          child: StudioButton(
                            label: 'Mi Lista',
                            icon: Icons.add_rounded,
                            variant: StudioButtonVariant.secondary,
                            onPressed: () {},
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: StudioSpacing.xxl),
                    StudioMediaCard(
                      item: StudioFixtures.movie,
                      width: 135,
                      onTap: () {},
                      onToggleFavorite: () {},
                    ),
                  ],
                ),
              ),
            ),
            StudioBottomNav(selectedIndex: 0, onSelected: (_) {}),
          ],
        ),
      ),
    );
  }
}
