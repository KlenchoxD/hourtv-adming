import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/studio_ui/data/studio_catalog_adapter.dart';
import 'package:streamtv/studio_ui/data/studio_media_item.dart';
import 'package:streamtv/studio_ui/foundation/studio_theme.dart';

Future<void> loadStudioTestFonts() async {
  final inter = FontLoader('Inter')
    ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
  final materialIcons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await Future.wait([inter.load(), materialIcons.load()]);
}

abstract final class StudioFixtures {
  static final movieChannel = Channel(
    name: 'El último amanecer',
    url: 'https://example.test/el-ultimo-amanecer.m3u8',
    forcedType: 'movie',
    genre: 'Drama',
    year: '2026',
    rating: '9.6',
    duration: '124 min',
    plot: 'Una ciudad espera el regreso del sol.',
    director: 'Mariana Cordero',
    writer: 'Lucía Fernández',
    isFeatured: true,
  );

  static StudioMediaItem get movie =>
      StudioCatalogAdapter.fromChannel(movieChannel);
}

class StudioTestApp extends StatelessWidget {
  const StudioTestApp({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: StudioTheme.build(),
      home: Scaffold(body: child),
    );
  }
}
