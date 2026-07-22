import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../services/content_store.dart';
import '../services/ad_service.dart';
import '../services/device_type.dart';
import '../services/storage_service.dart';
import '../services/tmdb_service.dart';
import '../services/xtream_service.dart';
import '../theme/app_theme.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/hourtv_brand.dart';
import 'movie_detail_screen.dart';
import 'player_screen.dart';
import 'search_screen.dart';
import 'series_detail_screen.dart';

part 'catalog_base.dart';
part 'catalog_tv_screen.dart';
part 'catalog_touch_screen.dart';

/// Pestaña INICIO: catálogo de VIDEO BAJO DEMANDA (películas y series). El
/// backend/datos son únicos (ContentStore); lo que cambia es la FORMA de
/// mostrarlo según el dispositivo (diseño adaptativo por plataforma):
///   - TV (10 pies, control remoto) -> [CatalogTvScreen]
///   - teléfono/tablet (táctil)     -> [CatalogTouchScreen]
/// NO muestra canales en vivo (eso vive en la pestaña En Vivo).
class CatalogScreen extends StatelessWidget {
  /// Categoría con la que arranca (para que el rail de TV abra directo en
  /// Películas o Series). 'all' = Recomendado.
  final String initialCategory;
  const CatalogScreen({super.key, this.initialCategory = 'all'});

  @override
  Widget build(BuildContext context) {
    return DeviceProfile.isTv(context)
        ? CatalogTvScreen(initialCategory: initialCategory)
        : CatalogTouchScreen(initialCategory: initialCategory);
  }
}
