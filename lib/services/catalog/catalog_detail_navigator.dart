import 'package:flutter/material.dart';
import '../../models/channel.dart';
import '../../new_ui/hourtv_detail_page.dart';
import '../../new_ui/hourtv_series_detail_page.dart';
import '../content_store.dart';
import '../xtream_service.dart';
import 'catalog_repository.dart';

/// Navegador unificado de detalles que realiza hidratación asíncrona determinista
/// de tarjetas provenientes de Drift antes de abrir las pantallas de detalle.
class CatalogDetailNavigator {
  /// Abre la vista de detalle correspondiente hidratando previamente la entidad
  /// desde la base de datos local SQLite (Drift) si proviene del catálogo indexado.
  static Future<void> openDetails(
    BuildContext context,
    Channel channel, {
    CatalogRepository? repository,
    ContentStore? store,
    bool fromContinueWatching = false,
    bool preview = false,
  }) async {
    final effectiveStore = store ?? ContentStore.instance;
    final effectiveRepo = repository ?? (CatalogRepository.hasInstance ? CatalogRepository.instance : null);

    // 1. Si no es del catálogo Drift o no hay repositorio, usar resolución directa tradicional
    if (!channel.isDriftCatalog || effectiveRepo == null) {
      final legacySeries = hourTvResolveSeries(channel, effectiveStore.visibleSeries);
      if (legacySeries != null) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => HourTvSeriesDetailPage(series: legacySeries),
          ),
        );
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => HourTvDetailPage(
            channel: channel,
            preview: preview,
            fromContinueWatching: fromContinueWatching,
          ),
        ),
      );
      return;
    }

    // 2. Si es del catálogo Drift, hidratar asíncronamente con indicador no bloqueante
    final titleId = channel.stableTitleId;
    if (titleId == null || titleId.isEmpty) {
      _showError(context, channel, repository: effectiveRepo, store: effectiveStore, fromContinueWatching: fromContinueWatching, preview: preview);
      return;
    }

    // Mostrar indicador de carga no bloqueante
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Cargando detalles...'),
          ],
        ),
        duration: Duration(seconds: 4),
      ),
    );

    try {
      // Determinar si es serie o película
      var isSeries = channel.forcedType == 'series' ||
          channel.forcedType == 'anime' ||
          channel.forcedType == 'novela';

      if (!isSeries && channel.forcedType == null) {
        final localTitle = await effectiveRepo.dao.getTitleById(titleId);
        if (localTitle != null && localTitle.mediaType == 'series') {
          isSeries = true;
        }
      }

      if (isSeries) {
        final series = await effectiveRepo.hydrateSeries(titleId);
        if (!context.mounted) return;
        messenger?.hideCurrentSnackBar();

        if (series == null) {
          _showError(context, channel, repository: effectiveRepo, store: effectiveStore, fromContinueWatching: fromContinueWatching, preview: preview);
          return;
        }

        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => HourTvSeriesDetailPage(series: series),
          ),
        );
      } else {
        final hydratedChannel = await effectiveRepo.hydrateChannel(titleId);
        if (!context.mounted) return;
        messenger?.hideCurrentSnackBar();

        if (hydratedChannel == null) {
          _showError(context, channel, repository: effectiveRepo, store: effectiveStore, fromContinueWatching: fromContinueWatching, preview: preview);
          return;
        }

        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => HourTvDetailPage(
              channel: hydratedChannel,
              preview: preview,
              fromContinueWatching: fromContinueWatching,
            ),
          ),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      messenger?.hideCurrentSnackBar();
      _showError(context, channel, repository: effectiveRepo, store: effectiveStore, fromContinueWatching: fromContinueWatching, preview: preview);
    }
  }

  static void _showError(
    BuildContext context,
    Channel channel, {
    CatalogRepository? repository,
    ContentStore? store,
    bool fromContinueWatching = false,
    bool preview = false,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: const Text('No se pudieron cargar los detalles del título.'),
        action: SnackBarAction(
          label: 'Reintentar',
          onPressed: () {
            openDetails(
              context,
              channel,
              repository: repository,
              store: store,
              fromContinueWatching: fromContinueWatching,
              preview: preview,
            );
          },
        ),
      ),
    );
  }
}
