import 'package:flutter/material.dart';
import '../../models/channel.dart';
import '../../new_ui/hourtv_detail_page.dart';
import '../../new_ui/hourtv_series_detail_page.dart';
import '../content_store.dart';
import 'catalog_repository.dart';

/// Navegador unificado de detalles que realiza hidratación asíncrona determinista
/// de tarjetas provenientes de Drift antes de abrir las pantallas de detalle.
class CatalogDetailNavigator {
  /// Ruta a una ficha sin animación de entrada/salida. La animación estándar
  /// dibuja dos pantallas completas durante 300 ms y el primer frame de la
  /// ficha (el más caro: texto e imágenes nuevas) caía justo al empezarla,
  /// viéndose como un salto. Sin animación ese costo es solo una espera.
  static Route<T> instantRoute<T>(WidgetBuilder builder) => PageRouteBuilder<T>(
    pageBuilder: (context, _, _) => builder(context),
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );

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
    final effectiveRepo =
        repository ??
        (CatalogRepository.hasInstance ? CatalogRepository.instance : null);
    channel = current(channel, effectiveStore.all);

    // El catálogo publicado es la fuente completa actual; Drift puede conservar
    // una tarjeta antigua sin temporadas mientras termina su sincronización.
    final publishedSeries = hourTvResolveSeries(
      channel,
      effectiveStore.visibleSeries,
      allowSynthetic: false,
    );
    if (publishedSeries != null &&
        publishedSeries.episodes?.isNotEmpty == true) {
      Navigator.of(context).push(
        instantRoute<void>(
          (_) => HourTvSeriesDetailPage(series: publishedSeries),
        ),
      );
      return;
    }

    // 1. Si no es del catálogo Drift o no hay repositorio, usar resolución directa tradicional
    if (!channel.isDriftCatalog || effectiveRepo == null) {
      final legacySeries = hourTvResolveSeries(
        channel,
        effectiveStore.visibleSeries,
      );
      if (legacySeries != null) {
        Navigator.of(context).push(
          instantRoute<void>(
            (_) => HourTvSeriesDetailPage(series: legacySeries),
          ),
        );
        return;
      }
      Navigator.of(context).push(
        instantRoute<void>(
          (_) => HourTvDetailPage(
            channel: channel,
            preview: preview,
            fromContinueWatching: fromContinueWatching,
          ),
        ),
      );
      return;
    }

    // 2. Catálogo Drift: la pantalla se abre en el mismo toque con lo que ya
    // trae la tarjeta, y la ficha completa aparece al terminar la hidratación.
    // Antes se esperaba la hidratación ANTES del push y el toque se sentía
    // trabado varios segundos.
    Navigator.of(context).push(
      instantRoute<void>(
        (_) => _HydratingDetailPage(
          card: channel,
          repository: effectiveRepo,
          fromContinueWatching: fromContinueWatching,
          preview: preview,
        ),
      ),
    );
  }
}

/// Versión actual de [saved] en el catálogo cargado. Biblioteca, Historial
/// y Continuar viendo guardan una copia del título con los servidores de ese
/// día; si el catálogo los cambió, esa copia abría un servidor caído (pantalla
/// negra). El progreso no se pierde: se guarda por id del título.
@visibleForTesting
Channel current(Channel saved, List<Channel> catalog) {
  final id = saved.tvgId?.trim();
  if (id == null || id.isEmpty || saved.type == MediaType.live) return saved;
  for (final item in catalog) {
    if (item.tvgId == id && item.type == saved.type) return item;
  }
  return saved;
}

class _HydratingDetailPage extends StatefulWidget {
  const _HydratingDetailPage({
    required this.card,
    required this.repository,
    required this.fromContinueWatching,
    required this.preview,
  });

  final Channel card;
  final CatalogRepository repository;
  final bool fromContinueWatching;
  final bool preview;

  @override
  State<_HydratingDetailPage> createState() => _HydratingDetailPageState();
}

class _HydratingDetailPageState extends State<_HydratingDetailPage> {
  late Future<Widget?> _page = _hydrate();

  Future<Widget?> _hydrate() async {
    final card = widget.card;
    final repo = widget.repository;
    final titleId = card.stableTitleId;
    if (titleId == null || titleId.isEmpty) return null;

    var isSeries =
        card.forcedType == 'series' ||
        card.forcedType == 'anime' ||
        card.forcedType == 'novela';
    if (!isSeries && card.forcedType == null) {
      final localTitle = await repo.dao.getTitleById(titleId);
      isSeries = localTitle?.mediaType == 'series';
    }

    if (isSeries) {
      final series = await repo.hydrateSeries(titleId);
      return series == null ? null : HourTvSeriesDetailPage(series: series);
    }
    final hydrated = await repo.hydrateChannel(titleId);
    return hydrated == null
        ? null
        : HourTvDetailPage(
            channel: hydrated,
            preview: widget.preview,
            fromContinueWatching: widget.fromContinueWatching,
          );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget?>(
      future: _page,
      builder: (context, snapshot) {
        final page = snapshot.data;
        if (page != null) return page;
        final failed = snapshot.connectionState == ConnectionState.done;
        return _DetailPlaceholder(
          card: widget.card,
          failed: failed,
          onRetry: () => setState(() => _page = _hydrate()),
        );
      },
    );
  }
}

class _DetailPlaceholder extends StatelessWidget {
  const _DetailPlaceholder({
    required this.card,
    required this.failed,
    required this.onRetry,
  });

  final Channel card;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final image = card.backdrop ?? card.logo;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      extendBodyBehindAppBar: true,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: image == null || image.isEmpty
                ? const ColoredBox(color: Color(0xFF111111))
                : Image.network(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: Color(0xFF111111)),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 24),
                if (!failed)
                  const Center(child: CircularProgressIndicator(strokeWidth: 2))
                else ...[
                  const Text(
                    'No se pudieron cargar los detalles del título.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: onRetry,
                    child: const Text('Reintentar'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
