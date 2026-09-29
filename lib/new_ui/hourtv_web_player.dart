import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../mobile_ui/hourtv_mobile_components.dart';
import '../mobile_ui/hourtv_mobile_theme.dart';
import '../models/channel.dart';
import '../services/content_store.dart';
import '../services/recommendations/related_content_engine.dart';
import '../services/storage_service.dart';
import 'hourtv_detail_parts.dart';
import 'hourtv_player_screen.dart';
import 'hourtv_detail_page.dart';
import 'web_embed/fullscreen.dart';
import 'web_embed/embed_frame.dart';

/// Reproductor en el navegador. Los servidores del catálogo son páginas de
/// reproductor (paulinito, voe, ok.ru...) cuyo video solo se entrega si la
/// petición dice venir de esa misma página, cosa que un navegador no deja
/// fingir. Por eso se muestra su propio reproductor en un iframe, como hacen
/// las webs de películas. La app de Android sigue con su reproductor.
///
/// ponytail: sin reanudar posición ni subtítulos propios; el iframe es de
/// otro dominio y no deja leer el tiempo. Se agrega si algún día hay un
/// servidor intermedio para el video.
class HourTvWebPlayerState extends State<PlayerScreen> {
  // En series se puede cambiar de episodio sin salir del reproductor.
  late Channel _current = widget.channel;
  late List<ChannelServer> _servers = _playableServers(_current);

  late final List<Channel> _episodes = _isSeries(widget.channel)
      ? widget.allChannels
      : const [];

  late final List<Channel> _related = _isSeries(widget.channel)
      ? const []
      : RelatedContentEngine.instance.getRelated(
          target: widget.channel,
          candidates: ContentStore.instance.movies,
          isKidsProfile: StorageService.activeProfileIsKids,
          limit: 9,
        );

  static bool _isSeries(Channel c) =>
      c.type == MediaType.series || c.forcedType == 'series';

  void _playEpisode(Channel episode) => setState(() {
    _current = episode;
    _servers = _playableServers(episode);
    _selected = 0;
    _failed.clear();
  });
  late int _selected = _initialServer();

  /// Un blog (blogdepelis) no es un reproductor: mostrarlo entero dentro de
  /// la página se ve roto. Todas las películas tienen además un reproductor
  /// directo, que es el que se usa.
  static bool _isPlayerPage(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
      return false;
    }
    return !uri.host.toLowerCase().endsWith('blogdepelis.net');
  }

  static List<ChannelServer> _playableServers(Channel channel) {
    final servers = channel.servers.isNotEmpty
        ? channel.servers
        : [ChannelServer(name: 'Servidor 1', url: channel.url)];
    return servers.where((s) => _isPlayerPage(s.url)).toList(growable: false);
  }

  int _initialServer() {
    final wanted = widget.initialUrl;
    final index = wanted == null
        ? -1
        : _servers.indexWhere((s) => s.url == wanted);
    return index < 0 ? 0 : index;
  }

  /// Servidores cuyo video el navegador no pudo abrir (canal caído, http en
  /// una página https, formato no soportado).
  final _failed = <int>{};

  /// Canal en vivo o archivo de video: va en un <video>, no en un iframe.
  bool _isDirectMedia(String url) {
    if (_current.type == MediaType.live) return true;
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    return path.endsWith('.m3u8') ||
        path.endsWith('.mp4') ||
        path.endsWith('.webm') ||
        path.endsWith('.ts');
  }

  void _close() => Navigator.of(context).maybePop();

  // El mismo reproductor en vertical y en horizontal: con la llave global se
  // mueve de lugar sin recrear el iframe (antes al girar se recargaba).
  final _playerKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Vertical (celular): video arriba y la ficha debajo. Horizontal o
    // computador: el video a pantalla completa con controles flotantes.
    final portrait = size.width < 600 || size.height > size.width;
    final player = KeyedSubtree(key: _playerKey, child: _player());
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: HourTvMobileTokens.deepBlack,
          body: portrait ? _portrait(player) : _landscape(player),
        ),
      ),
    );
  }

  Widget _portrait(Widget player) => SafeArea(
    bottom: false,
    child: Column(
      children: [
        Stack(
          children: [
            AspectRatio(aspectRatio: 16 / 9, child: player),
            Positioned(
              left: 8,
              top: 8,
              child: hourTvPointerShield(_roundButton()),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: hourTvPointerShield(_fullscreenButton()),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
            children: [
              Text(
                _current.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: HourTvMobileTokens.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              HourTvDetailMeta(
                rating: _current.rating,
                year: _current.year,
                extra: hourTvPrettyDuration(_current.duration),
              ),
              if (_servers.length > 1) ...[
                const SizedBox(height: 22),
                const _SectionTitle('Servidores'),
                const SizedBox(height: 4),
                const Text(
                  'Si uno no carga, prueba con otro.',
                  style: TextStyle(
                    color: HourTvMobileTokens.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < _servers.length; i++) _serverTile(i),
              ],
              if ((_current.plot ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 22),
                const _SectionTitle('Sinopsis'),
                const SizedBox(height: 8),
                Text(
                  _current.plot!.trim(),
                  style: const TextStyle(
                    color: HourTvMobileTokens.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
              ..._moreSections(),
            ],
          ),
        ),
      ],
    ),
  );

  List<Widget> _moreSections() => [
    if (_episodes.length > 1) ...[
      const SizedBox(height: 22),
      const _SectionTitle('Episodios'),
      const SizedBox(height: 12),
      for (final episode in _episodes) _episodeTile(episode),
    ],
    if (_related.isNotEmpty) ...[
      const SizedBox(height: 22),
      const _SectionTitle('Relacionado'),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 16,
        crossAxisSpacing: 10,
        childAspectRatio: 120 / 218,
        children: [
          for (final item in _related)
            HourTvPosterCard(
              channel: item,
              width: double.infinity,
              onTap: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      HourTvDetailPage(channel: item, preview: false),
                ),
              ),
            ),
        ],
      ),
    ],
  ];

  Widget _fullscreenButton() => Material(
    color: const Color(0xB3000000),
    shape: const CircleBorder(),
    child: IconButton(
      tooltip: 'Pantalla completa',
      onPressed: () {
        hourTvToggleFullscreen();
        // Al entrar o salir cambia el tamaño; se refresca el ícono.
        Future<void>.delayed(
          const Duration(milliseconds: 400),
          () => mounted ? setState(() {}) : null,
        );
      },
      icon: Icon(
        hourTvIsFullscreen()
            ? Icons.fullscreen_exit_rounded
            : Icons.fullscreen_rounded,
        color: HourTvMobileTokens.textPrimary,
      ),
    ),
  );

  Widget _episodeTile(Channel episode) {
    final playing = episode.url == _current.url;
    final duration = hourTvPrettyDuration(episode.duration);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: playing
            ? HourTvMobileTokens.emerald.withValues(alpha: .10)
            : HourTvMobileTokens.surfacePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HourTvMobileTokens.radiusMedium),
          side: BorderSide(
            color: playing
                ? HourTvMobileTokens.emerald
                : HourTvMobileTokens.borderSubtle,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(HourTvMobileTokens.radiusMedium),
          onTap: playing ? null : () => _playEpisode(episode),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(
                  playing ? Icons.equalizer_rounded : Icons.play_arrow_rounded,
                  color: playing
                      ? HourTvMobileTokens.emerald
                      : HourTvMobileTokens.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    episode.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: HourTvMobileTokens.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (duration != null)
                  Text(
                    duration,
                    style: const TextStyle(
                      color: HourTvMobileTokens.textMuted,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _landscape(Widget player) => Stack(
    children: [
      // Recuadro siempre 16:9 y centrado: los reproductores de los servidores
      // se dibujan 16:9 según el ancho, y en ventanas más anchas que eso
      // sobraba video abajo y se podía desplazar dentro del reproductor.
      Positioned.fill(
        child: Center(
          child: AspectRatio(aspectRatio: 16 / 9, child: player),
        ),
      ),
      Positioned(left: 16, top: 16, child: hourTvPointerShield(_roundButton())),
      // Sin botón propio de pantalla completa: aquí el reproductor del
      // servidor ya trae el suyo y salían dos.
      if (_servers.length > 1)
        Positioned(
          right: 16,
          top: 16,
          child: hourTvPointerShield(
            Material(
              color: const Color(0xB3000000),
              shape: const StadiumBorder(
                side: BorderSide(color: HourTvMobileTokens.borderSubtle),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: _openServerSheet,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.dns_rounded,
                        size: 18,
                        color: HourTvMobileTokens.emerald,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _serverLabel(_selected),
                        style: const TextStyle(
                          color: HourTvMobileTokens.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: HourTvMobileTokens.textPrimary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _roundButton() => Material(
    color: const Color(0xB3000000),
    shape: const CircleBorder(),
    child: IconButton(
      tooltip: 'Volver',
      onPressed: _close,
      icon: const Icon(
        Icons.arrow_back_rounded,
        color: HourTvMobileTokens.textPrimary,
      ),
    ),
  );

  Future<void> _openServerSheet() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: HourTvMobileTokens.background,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 520),
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const _SectionTitle('Servidores'),
          const SizedBox(height: 12),
          for (var i = 0; i < _servers.length; i++)
            _serverTile(i, onChosen: () => Navigator.pop(sheetContext)),
        ],
      ),
    ),
  );

  Widget _player() => _servers.isEmpty
      ? const _NoWebServer()
      : _failed.contains(_selected)
      ? _NoWebServer(
          message: _servers.length > 1
              ? 'Este servidor no se puede ver en el navegador. '
                    'Prueba con otro.'
              : null,
        )
      : _isDirectMedia(_servers[_selected].url)
      ? hourTvVideoFrame(
          _servers[_selected].url,
          onError: () => setState(() => _failed.add(_selected)),
        )
      : hourTvEmbedFrame(_servers[_selected].url);

  /// Servidor como tarjeta de la app: el elegido con borde e ícono verdes.
  Widget _serverTile(int i, {VoidCallback? onChosen}) {
    final selected = i == _selected;
    final failed = _failed.contains(i);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? HourTvMobileTokens.emerald.withValues(alpha: .10)
            : HourTvMobileTokens.surfacePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HourTvMobileTokens.radiusMedium),
          side: BorderSide(
            color: selected
                ? HourTvMobileTokens.emerald
                : HourTvMobileTokens.borderSubtle,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(HourTvMobileTokens.radiusMedium),
          onTap: () {
            setState(() => _selected = i);
            onChosen?.call();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.play_circle_fill_rounded
                      : Icons.play_circle_outline_rounded,
                  color: selected
                      ? HourTvMobileTokens.emerald
                      : HourTvMobileTokens.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _serverLabel(i),
                    style: const TextStyle(
                      color: HourTvMobileTokens.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (selected || failed)
                  Text(
                    failed ? 'No carga' : 'Reproduciendo',
                    style: TextStyle(
                      color: failed
                          ? HourTvMobileTokens.error
                          : HourTvMobileTokens.emerald,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _serverLabel(int i) {
    final name = _servers[i].name.trim();
    final language = _servers[i].language?.trim();
    final base = name.isEmpty ? 'Servidor ${i + 1}' : name;
    return language == null || language.isEmpty ? base : '$base · $language';
  }
}

class _NoWebServer extends StatelessWidget {
  const _NoWebServer({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        message ??
            'Esto no se puede ver en el navegador. '
                'Puedes verlo en la app de Android.',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 16,
          height: 1.4,
        ),
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: HourTvMobileTokens.textPrimary,
      fontSize: 16,
      fontWeight: FontWeight.w800,
    ),
  );
}
