import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/channel.dart';
import 'hourtv_player_screen.dart';
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
  late final List<ChannelServer> _servers = _playableServers(widget.channel);
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
    if (widget.channel.type == MediaType.live) return true;
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    return path.endsWith('.m3u8') ||
        path.endsWith('.mp4') ||
        path.endsWith('.webm') ||
        path.endsWith('.ts');
  }

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final title = widget.channel.displayName;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Column(
            children: [
              _topBar(title),
              Expanded(
                child: _servers.isEmpty
                    ? const _NoWebServer()
                    : _failed.contains(_selected)
                    ? _NoWebServer(
                        message: _servers.length > 1
                            ? 'Este servidor no se puede ver en el navegador. '
                                  'Prueba con otro de arriba.'
                            : null,
                      )
                    : _isDirectMedia(_servers[_selected].url)
                    ? hourTvVideoFrame(
                        _servers[_selected].url,
                        onError: () => setState(() => _failed.add(_selected)),
                      )
                    : hourTvEmbedFrame(_servers[_selected].url),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(String title) => Container(
    color: Colors.black,
    padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
    child: SafeArea(
      bottom: false,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Volver',
            onPressed: _close,
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          // Si un servidor no carga, se prueba otro sin salir.
          if (_servers.length > 1)
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  children: [
                    for (var i = 0; i < _servers.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          label: Text(_serverLabel(i)),
                          selected: i == _selected,
                          onSelected: (_) => setState(() => _selected = i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );

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
