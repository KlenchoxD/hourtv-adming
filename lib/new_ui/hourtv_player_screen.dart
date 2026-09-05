import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../services/storage_service.dart';
import '../services/ad_service.dart';
import '../services/archive_service.dart';
import '../services/stalker_service.dart';
import '../services/device_type.dart';
import '../services/cast_service.dart';
import '../services/content_store.dart';
import '../services/embed_resolver.dart';
import '../services/playback_source_fallback.dart';
import 'hourtv_focusable.dart';
import 'hourtv_cast_controls_screen.dart';
import 'hourtv_cast_sheet.dart';

const _hourRed = Color(0xFF00C781);
const _hourSurface = Color(0xFF101412);
const _hourMuted = Color(0xFFA6A6B0);
const _hourError = Color(0xFFFF5A66);

enum _VideoFitMode { automatic, contain, cover }

String _formatPlaybackTime(Duration time) {
  String two(int number) => number.toString().padLeft(2, '0');
  final hours = time.inHours;
  final base =
      '${two(time.inMinutes.remainder(60))}:${two(time.inSeconds.remainder(60))}';
  return hours > 0 ? '${two(hours)}:$base' : base;
}

class PlayerScreen extends StatefulWidget {
  final Channel channel;
  final List<Channel> allChannels;
  final String? initialUrl;

  /// Fuerza horizontal aunque el ajuste global "forceLandscape" este apagado.
  /// Lo usa el boton Expandir de TV en vivo: expandir en vertical no es
  /// pantalla completa util, el video queda como una franja en medio.
  final bool forceLandscape;
  const PlayerScreen({
    super.key,
    required this.channel,
    required this.allChannels,
    this.initialUrl,
    this.forceLandscape = false,
  });
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _vc;
  ChewieController? _cc;
  bool _loading = true;
  String? _err;
  // Texto crudo del error, para quien administra sus propias fuentes IPTV y
  // necesita el detalle tecnico. Se muestra chico y apagado bajo el mensaje.
  String? _errDetail;
  bool _showList = false;
  int _idx = 0;
  final _screenFocus = FocusNode();
  bool _forcedLandscape = false;
  bool _forcedPortrait = false;
  static const _platform = MethodChannel('hourtv/device');
  Timer? _chromeTimer;
  Timer? _gestureTimer;
  bool _chromeVisible = true;
  double _volume = 1;
  double _screenDim = 0;
  _VideoFitMode _videoFitMode = _VideoFitMode.automatic;
  bool _verticalGestureOnRight = true;
  String? _gestureLabel;
  String? _activeServerUrl;
  String? _resolvedPlaybackUrl;
  // El receptor Chromecast por defecto no puede enviar cabeceras HTTP
  // personalizadas (Referer/User-Agent) al pedir el video: si la
  // reproduccion actual depende de eso (paginas embed resueltas), transmitir
  // siempre va a fallar en el televisor aunque el link sea valido aca.
  bool _resolvedPlaybackNeedsHeaders = false;
  // Orden de mirrors a probar para el canal actual; se reconstruye en cada
  // llamada "fresca" a _init (cambio de canal, seleccion manual de servidor,
  // botón Reintentar) y se recorre sola cuando un mirror falla en caliente.
  PlaybackSourcePlan? _sourcePlan;
  bool _recoveringFromPlaybackError = false;
  // Estilo de subtitulos elegido en Perfil > Idioma y subtitulos. Chewie solo
  // pinta subtitulos dentro de sus controles (y aqui van desactivados), asi
  // que HourTV dibuja la linea de subtitulo con este estilo.
  double _subtitleScale = 1;
  bool _subtitleBold = false;
  StreamSubscription<List<GoogleCastDevice>>? _castDevicesSubscription;
  StreamSubscription<GoogleCastSession?>? _castSessionSubscription;
  // Solo se guarda si hay sesion activa, para pintar el boton. La lista de
  // dispositivos y el estado de conexion los lleva el panel de transmision
  // (`showCastSheet`), que es quien los muestra.
  bool _castConnected = false;

  final ValueNotifier<int?> _nextEpisodeCountdown = ValueNotifier(null);
  final ValueNotifier<bool> _creditsMode = ValueNotifier(false);
  final ValueNotifier<bool> _playbackEnded = ValueNotifier(false);
  bool _autoNextCancelled = false;
  bool _advancingEpisode = false;
  int _lastProgressSecond = -1;

  Channel get _currentChannel => widget.allChannels[_idx];
  bool get _isLive => _currentChannel.type == MediaType.live;
  bool get _isSeriesEpisode => _currentChannel.type == MediaType.series;
  bool get _hasNextEpisode =>
      _isSeriesEpisode && _idx + 1 < widget.allChannels.length;

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform == TargetPlatform.android) {
      unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
      );
    }
    _idx = widget.allChannels.indexWhere((c) => c.url == widget.channel.url);
    if (_idx < 0) _idx = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_startInitialPlayback());
        unawaited(_initializeCast());
      }
    });
    _subtitleScale =
        double.tryParse(
          StorageService.getSetting(
            'subtitleFontScale',
            defaultValue: 1.0,
          ).toString(),
        ) ??
        1.0;
    _subtitleBold =
        StorageService.getSetting('subtitleBold', defaultValue: false) == true;
    if (widget.forceLandscape ||
        StorageService.getSetting('forceLandscape', defaultValue: false) ==
            true) {
      _forcedLandscape = true;
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      // Sin esto, el reproductor se quedaba con la preferencia global de la
      // app (portrait+landscape), asi que giraba solo segun como estuviera
      // sostenido el telefono en vez de abrir siempre vertical. "Forzar
      // horizontal" (arriba) sigue siendo el escape hatch para quien
      // realmente quiera ver todo en horizontal.
      _forcedPortrait = true;
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  Future<void> _startInitialPlayback() async {
    await _playChannel(widget.allChannels[_idx], streamUrl: widget.initialUrl);
  }

  Future<void> _playChannel(Channel channel, {String? streamUrl}) async {
    await AdService.showPreroll(context, channel);
    if (!mounted) return;
    await StorageService.saveRecent(channel);
    if (!mounted) return;
    await _init(channel, streamUrl: streamUrl);
  }

  void _resetEpisodeUi() {
    _autoNextCancelled = false;
    _lastProgressSecond = -1;
    _nextEpisodeCountdown.value = null;
    _creditsMode.value = false;
    _playbackEnded.value = false;
  }

  void _onVideoProgress() {
    final controller = _vc;
    if (controller == null) return;
    if (controller.value.hasError) {
      _handlePlaybackError(controller);
      return;
    }
    if (!controller.value.isInitialized || _isLive) {
      return;
    }
    final value = controller.value;
    final duration = value.duration;
    if (duration <= Duration.zero) return;
    final second = value.position.inSeconds;
    if (second == _lastProgressSecond && !value.isCompleted) return;
    _lastProgressSecond = second;

    final remaining = duration - value.position;
    final completed =
        value.isCompleted || remaining <= const Duration(milliseconds: 450);
    // Progreso real para "Continuar viendo": cada ~10s, y siempre al terminar
    // (asi el titulo sale de la fila en vez de quedar marcado a medias).
    if (completed || second % 10 == 0) {
      final fraction = (value.position.inMilliseconds /
              duration.inMilliseconds)
          .clamp(0.0, 1.0);
      unawaited(
        ContentStore.instance.updatePlaybackProgress(
          _currentChannel,
          fraction,
          notify: false,
        ),
      );
    }
    if (completed) {
      _nextEpisodeCountdown.value = null;
      _creditsMode.value = false;
      if (!_advancingEpisode && !_playbackEnded.value) {
        _playbackEnded.value = true;
        _chromeTimer?.cancel();
        if (mounted && _chromeVisible) {
          setState(() => _chromeVisible = false);
        }
      }
      return;
    }

    if (_hasNextEpisode &&
        !_autoNextCancelled &&
        value.position >= const Duration(seconds: 30) &&
        remaining <= const Duration(seconds: 15)) {
      final seconds = (remaining.inMilliseconds / 1000).ceil().clamp(1, 15);
      _nextEpisodeCountdown.value = seconds;
      _creditsMode.value = true;
      if (remaining <= const Duration(seconds: 1) && !_advancingEpisode) {
        unawaited(_playNextEpisode());
      }
      return;
    }

    if (_nextEpisodeCountdown.value != null) {
      _nextEpisodeCountdown.value = null;
      _creditsMode.value = false;
    }
  }

  Future<void> _playNextEpisode() async {
    if (!_hasNextEpisode || _advancingEpisode) return;
    _advancingEpisode = true;
    _nextEpisodeCountdown.value = null;
    _creditsMode.value = false;
    _playbackEnded.value = false;
    try {
      await _chg(1);
    } finally {
      _advancingEpisode = false;
    }
  }

  void _cancelAutoNext() {
    _autoNextCancelled = true;
    _nextEpisodeCountdown.value = null;
    _creditsMode.value = false;
  }

  Future<void> _replayCurrent() async {
    final controller = _vc;
    if (controller == null || !controller.value.isInitialized) return;
    _resetEpisodeUi();
    await controller.seekTo(Duration.zero);
    await controller.play();
    _showChromeControls();
  }

  Future<void> _skipEstimatedIntro() async {
    final controller = _vc;
    if (controller == null || !controller.value.isInitialized) return;
    const introEnd = Duration(seconds: 85);
    final duration = controller.value.duration;
    final target = duration > introEnd ? introEnd : duration;
    await controller.seekTo(target);
    _showChromeControls();
  }

  Future<void> _init(
    Channel ch, {
    String? streamUrl,
    bool isFallbackAttempt = false,
  }) async {
    final targetUrl = streamUrl ?? ch.url;
    if (!isFallbackAttempt) {
      _sourcePlan = PlaybackSourcePlan.forChannel(ch, preferredUrl: streamUrl);
    }
    _recoveringFromPlaybackError = false;
    _resetEpisodeUi();
    setState(() {
      _loading = true;
      _err = null;
      _errDetail = null;
      _activeServerUrl = targetUrl;
    });
    _vc?.removeListener(_onVideoProgress);
    _cc?.dispose();
    _vc?.dispose();
    _cc = null;
    _vc = null;
    try {
      var playUrl = targetUrl;
      Map<String, String> playHeaders = ch.userAgent?.isNotEmpty == true
          ? {'User-Agent': ch.userAgent!}
          : const {};
      // VOD cuyo servidor es una pagina embed (streamwish, vidhide, dood...):
      // como Xuper, se intenta extraer el .m3u8/.mp4 directo y reproducirlo
      // nativo en ExoPlayer con su Referer. En Vivo nunca entra aqui.
      if (ch.type != MediaType.live && isEmbedStreamUrl(targetUrl)) {
        final resolved = await EmbedResolver.resolve(targetUrl);
        if (!mounted) return;
        if (resolved != null) {
          playUrl = resolved.url;
          playHeaders = resolved.headers;
        } else {
          // Antes esto caia al WebView de la pagina embed: se veia el
          // reproductor y los controles del sitio de terceros en vez de los
          // de HourTV. Ahora se trata como cualquier otro servidor caido:
          // prueba el siguiente mirror, y solo si no queda ninguno se
          // muestra el error nativo. El reproductor propio nunca se
          // reemplaza por el de otra pagina.
          if (await _tryFallback(ch, targetUrl)) return;
          setState(() {
            _err = 'No se pudo obtener el vídeo de esta película.';
            _loading = false;
          });
          return;
        }
      }
      if (playUrl.startsWith('archive:')) {
        final resolved = await ArchiveService.resolveStream(playUrl);
        if (resolved == null) {
          if (!mounted) return;
          if (await _tryFallback(ch, targetUrl)) return;
          setState(() {
            _err = 'No se pudo obtener el vídeo de esta película.';
            _loading = false;
          });
          return;
        }
        playUrl = resolved;
      } else if (playUrl.startsWith('stalker:')) {
        final resolved = await StalkerService.resolveStream(playUrl);
        if (resolved == null) {
          if (!mounted) return;
          if (await _tryFallback(ch, targetUrl)) return;
          setState(() {
            _err = 'No se pudo crear el enlace temporal de este canal.';
            _loading = false;
          });
          return;
        }
        playUrl = resolved;
      }
      _resolvedPlaybackUrl = playUrl;
      _resolvedPlaybackNeedsHeaders = playHeaders.isNotEmpty;
      _vc = VideoPlayerController.networkUrl(
        Uri.parse(playUrl),
        httpHeaders: playHeaders,
      );
      await _vc!.initialize();
      unawaited(_applyPreferredAudioLanguage(_vc!));
      final autoPlay =
          StorageService.getSetting('autoPlay', defaultValue: true) == true;
      _cc = ChewieController(
        videoPlayerController: _vc!,
        autoPlay: autoPlay,
        looping: false,
        aspectRatio: _vc!.value.aspectRatio,
        allowFullScreen: true,
        allowMuting: true,
        // Controles propios (chrome custom) hacen todo: play/pausa, seek,
        // progreso, gestos. Los de Chewie eran redundantes y repintaban una
        // segunda barra sobre la textura de video -> micro-trabas en TV Box.
        showControls: false,
        placeholder: Container(
          color: Colors.black,
          child: Center(child: _lg(ch)),
        ),
        errorBuilder: (_, m) => Center(
          child: Text(m, style: const TextStyle(color: Colors.white)),
        ),
        materialProgressColors: ChewieProgressColors(
          playedColor: _hourRed,
          handleColor: _hourRed,
          backgroundColor: _hourSurface,
          bufferedColor: _hourMuted,
        ),
      );
      final activeController = _vc!;
      activeController.addListener(_onVideoProgress);
      setState(() => _loading = false);
      // En Android la textura externa debe estar montada antes de iniciar el
      // stream. Arrancar desde Chewie durante initialize puede dejar audio
      // activo con una superficie negra en dispositivos que usan Skia.
      if (autoPlay && defaultTargetPlatform == TargetPlatform.android) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && identical(_vc, activeController)) {
            unawaited(activeController.play());
          }
        });
      }
      // Arranca el auto-ocultado: sin esto, la barra de arriba y las flechas
      // laterales se quedaban visibles para siempre al entrar a una peli.
      _showChromeControls();
    } catch (e) {
      if (await _tryFallback(ch, targetUrl)) return;
      setState(() {
        _err = playbackErrorMessage(e.toString());
        _errDetail = e.toString();
        _loading = false;
      });
    }
  }

  /// Si `failedUrl` es la fuente activa del plan y quedan mirrors por probar,
  /// reintenta con el siguiente sin repetir preroll ni volver a contar la
  /// reproduccion (no pasa por `_playChannel`). Devuelve true si se lanzo un
  /// reintento, false si no habia plan/mirrors y el llamador debe mostrar error.
  Future<bool> _tryFallback(Channel ch, String failedUrl) async {
    final plan = _sourcePlan;
    if (!mounted || plan == null || plan.current != failedUrl || !plan.hasNext) {
      return false;
    }
    final nextUrl = plan.advance();
    if (nextUrl == null) return false;
    await _init(ch, streamUrl: nextUrl, isFallbackAttempt: true);
    return true;
  }

  /// Fuente ya reproduciendose que falla en caliente (stream caido, red
  /// interrumpida): intenta el siguiente mirror antes de rendirse.
  void _handlePlaybackError(VideoPlayerController controller) {
    if (_recoveringFromPlaybackError) return;
    final failedUrl = _activeServerUrl;
    if (failedUrl == null) return;
    _recoveringFromPlaybackError = true;
    unawaited(() async {
      final handled = await _tryFallback(_currentChannel, failedUrl);
      if (!handled && mounted) {
        final detail = controller.value.errorDescription;
        setState(() {
          _err = playbackErrorMessage(detail);
          _errDetail = detail;
          _loading = false;
        });
      }
    }());
  }

  Widget _lg(Channel ch) => ch.logo != null
      ? CachedNetworkImage(
          imageUrl: ch.logo!,
          memCacheWidth: 720,
          width: 80,
          height: 80,
          fit: BoxFit.contain,
          errorWidget: (a, b, c) => _in(ch),
        )
      : _in(ch);
  Widget _in(Channel ch) => Text(
    ch.displayName.isNotEmpty ? ch.displayName[0].toUpperCase() : '?',
    style: const TextStyle(
      color: _hourRed,
      fontSize: 40,
      fontWeight: FontWeight.bold,
    ),
  );

  Future<void> _chg(int direction) async {
    final nextIndex = _idx + direction;
    if (nextIndex < 0 || nextIndex >= widget.allChannels.length) return;
    setState(() => _idx = nextIndex);
    await _playChannel(widget.allChannels[nextIndex]);
  }

  void _togglePlayPause() {
    final v = _vc;
    if (v == null || !v.value.isInitialized) return;
    v.value.isPlaying ? v.pause() : v.play();
    setState(() {});
  }

  void _showChromeControls() {
    if (mounted) setState(() => _chromeVisible = true);
    _chromeTimer?.cancel();
    _chromeTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_showList) setState(() => _chromeVisible = false);
    });
  }

  void _toggleChrome() {
    if (_chromeVisible) {
      _chromeTimer?.cancel();
      setState(() => _chromeVisible = false);
    } else {
      _showChromeControls();
    }
  }

  Future<void> _seekBy(Duration amount) async {
    final vc = _vc;
    if (vc == null || !vc.value.isInitialized) return;
    final durationMs = vc.value.duration.inMilliseconds;
    if (durationMs <= 0) return;
    final targetMs = (vc.value.position.inMilliseconds + amount.inMilliseconds)
        .clamp(0, durationMs);
    await vc.seekTo(Duration(milliseconds: targetMs));
    _showGesture(amount.isNegative ? '-10 s' : '+10 s');
    _showChromeControls();
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 120) return;
    unawaited(_seekBy(Duration(seconds: velocity < 0 ? 10 : -10)));
  }

  void _onVerticalDragStart(DragStartDetails details) {
    _verticalGestureOnRight =
        details.localPosition.dx > MediaQuery.sizeOf(context).width / 2;
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    final change = -(details.primaryDelta ?? 0) / 260;
    if (_verticalGestureOnRight) {
      _volume = (_volume + change).clamp(0.0, 1.0);
      _vc?.setVolume(_volume);
      _showGesture('Volumen ${(_volume * 100).round()}%');
    } else {
      _screenDim = (_screenDim - change).clamp(0.0, 0.72);
      _showGesture('Brillo ${((1 - _screenDim) * 100).round()}%');
    }
  }

  void _showGesture(String label) {
    _gestureTimer?.cancel();
    if (mounted) setState(() => _gestureLabel = label);
    _gestureTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _gestureLabel = null);
    });
  }

  Future<void> _enterPictureInPicture() async {
    final size = _vc?.value.size;
    try {
      final entered =
          await _platform.invokeMethod<bool>('enterPictureInPicture', {
            'width': (size?.width.round() ?? 16).clamp(1, 239),
            'height': (size?.height.round() ?? 9).clamp(1, 239),
          }) ??
          false;
      if (!entered && mounted) {
        await _showMessage(
          'Picture-in-Picture',
          'Este dispositivo no permite Picture-in-Picture.',
        );
      } else if (mounted) {
        setState(() => _chromeVisible = false);
      }
    } on PlatformException catch (error) {
      if (mounted) {
        await _showMessage(
          'Picture-in-Picture',
          error.message ?? 'No se pudo activar Picture-in-Picture.',
        );
      }
    }
  }

  Future<void> _openCastSettings() async {
    try {
      final opened =
          await _platform.invokeMethod<bool>('openCastSettings') ?? false;
      if (!opened && mounted) {
        await _showMessage(
          'Transmitir',
          'Este dispositivo no ofrece el panel nativo para compartir pantalla.',
        );
      }
    } on PlatformException catch (error) {
      if (mounted) {
        await _showMessage(
          'Transmitir',
          error.message ?? 'No se pudo abrir el panel para transmitir.',
        );
      }
    }
  }

  Future<void> _initializeCast() async {
    if (widget.allChannels[_idx].type == MediaType.live) return;
    final available = await CastService.instance.initialize();
    if (!mounted || !available) return;
    _castSessionSubscription = CastService.instance.sessionStream.listen(
      _onCastSessionChanged,
    );
    setState(() => _castConnected = CastService.instance.isConnected);
    // El descubrimiento arranca ya, para que al abrir el panel la lista este
    // poblada en vez de tener que esperar desde cero.
    await CastService.instance.startDiscovery();
  }

  void _onCastSessionChanged(GoogleCastSession? session) {
    if (!mounted) return;
    final connected =
        session?.connectionState == GoogleCastConnectState.connected;
    final disconnected = _castConnected && !connected;
    if (connected) unawaited(_vc?.pause());
    setState(() => _castConnected = connected);
    if (disconnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('La transmisión terminó.'),
          action: SnackBarAction(
            label: 'Reanudar aquí',
            onPressed: () => unawaited(_vc?.play()),
          ),
        ),
      );
    }
  }

  /// Boton de transmitir con la identidad de la app: capsula con borde rojo,
  /// icono y etiqueta. Antes era un IconButton suelto que no se distinguia de
  /// los demas y no decia lo que hacia. Cuando hay sesion activa se pinta en
  /// rojo relleno con el estado "Conectado".
  Widget _castButton() {
    final connected = _castConnected;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: connected ? _hourRed : Colors.white.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => unawaited(_openRealCast()),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: connected ? _hourRed : Colors.white24,
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  connected ? Icons.cast_connected_rounded : Icons.cast_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 7),
                Text(
                  connected ? 'Conectado' : 'Transmitir',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Abre el panel de transmision propio de la app.
  ///
  /// Antes, si el descubrimiento aun no habia encontrado nada, este boton
  /// lanzaba `Settings.ACTION_CAST_SETTINGS`: el panel NATIVO de Android, que
  /// saca al usuario de HourTV. Y mientras se buscaba, no parecia hacer nada.
  /// Ahora siempre abre la hoja propia, que ya muestra el estado "buscando".
  Future<void> _openRealCast() async {
    final channel = widget.allChannels[_idx];
    final streamUrl = _resolvedPlaybackUrl ?? _activeServerUrl ?? channel.url;

    // Motivos reales por los que este contenido no se puede enviar. Se pasan
    // al panel para explicarlos ahi en vez de ofrecer dispositivos que van a
    // fallar al cargar el video.
    final blocked =
        (CastService.needsUnsupportedHeaders(channel.userAgent) ||
            _resolvedPlaybackNeedsHeaders)
        ? 'Este servidor exige cabeceras personalizadas (User-Agent o '
              'Referer) y el receptor predeterminado de Chromecast no '
              'permite enviarlas, así que el televisor rechazaría el vídeo.'
        : (!CastService.isNetworkUrl(streamUrl) ||
              CastService.contentTypeFor(streamUrl, mediaType: channel.type) ==
                  null)
        ? 'Este servidor no expone una URL HLS (.m3u8) ni MP4, que son los '
              'únicos formatos que acepta Chromecast.'
        : null;

    final connected = await showCastSheet(
      context,
      title: channel.displayName,
      streamUrl: () => _resolvedPlaybackUrl ?? _activeServerUrl ?? channel.url,
      posterUrl: channel.backdrop ?? channel.logo,
      position: () => _vc?.value.position ?? Duration.zero,
      duration: () => _vc?.value.duration,
      mediaType: channel.type,
      blockedReason: blocked,
    );
    if (!mounted || !connected) return;
    // Con la sesion activa el video local no debe seguir sonando.
    await _vc?.pause();
    if (mounted) await _openCastControls();
  }

  Future<void> _openCastControls() async {
    final video = _vc;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CastControlsScreen(
          title: widget.allChannels[_idx].displayName,
          fallbackDuration: video?.value.duration ?? Duration.zero,
        ),
      ),
    );
    if (mounted) _screenFocus.requestFocus();
  }

  Future<void> _showMessage(String title, String message) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    if (mounted) _screenFocus.requestFocus();
  }

  /// Selecciona la pista de audio segun la preferencia guardada en Perfil >
  /// Idioma y subtitulos, si la fuente ofrece una que coincida. Usa la misma
  /// API real de pistas que el selector manual (getAudioTracks/
  /// selectAudioTrack); si el dispositivo o la fuente no la soportan,
  /// simplemente no hace nada (se queda con la pista por defecto).
  Future<void> _applyPreferredAudioLanguage(
    VideoPlayerController controller,
  ) async {
    final preferred = StorageService.getSetting(
      'preferredAudioLanguage',
      defaultValue: 'auto',
    ).toString();
    if (preferred == 'auto') return;
    try {
      if (!controller.isAudioTrackSupportAvailable()) return;
      final tracks = await controller.getAudioTracks();
      final match = tracks
          .where(
            (track) =>
                (track.language ?? '').toLowerCase().startsWith(preferred),
          )
          .firstOrNull;
      if (match != null && !match.isSelected) {
        await controller.selectAudioTrack(match.id);
      }
    } catch (_) {
      // Sin pista compatible o sin soporte: se mantiene la pista por defecto.
    }
  }

  Future<void> _showAudioSelector() async {
    final vc = _vc;
    if (vc == null || !vc.value.isInitialized) return;
    if (!vc.isAudioTrackSupportAvailable()) {
      await _showMessage(
        'Audio',
        'La selección de audio no está disponible en este dispositivo.',
      );
      return;
    }
    try {
      final tracks = await vc.getAudioTracks();
      if (!mounted) return;
      if (tracks.isEmpty) {
        await _showMessage(
          'Audio',
          'Esta fuente solo ofrece la pista de audio predeterminada.',
        );
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('Pista de audio'),
          children: [
            for (final track in tracks)
              SimpleDialogOption(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await vc.selectAudioTrack(track.id);
                },
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    track.isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(
                    track.label?.trim().isNotEmpty == true
                        ? track.label!
                        : (track.language?.toUpperCase() ?? 'Audio'),
                  ),
                  subtitle: track.codec == null
                      ? null
                      : Text(track.codec!.toUpperCase()),
                ),
              ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) await _showMessage('Audio', error.toString());
    }
    if (mounted) _screenFocus.requestFocus();
  }

  Future<void> _showSubtitleSelector() => _showMessage(
    'Subtítulos',
    'Esta fuente no ofrece subtítulos seleccionables. Se mantienen desactivados.',
  );

  Future<void> _showQualitySelector() async {
    final value = _vc?.value;
    final size = value?.size;
    final resolution = size == null || size.isEmpty
        ? 'Resolución desconocida'
        : '${size.width.round()} × ${size.height.round()}';
    await _showMessage(
      'Calidad',
      'Automática · $resolution\n'
          'El reproductor adapta la calidad a la fuente y a la conexión.',
    );
  }

  Future<void> _showAspectSelector() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Relación de aspecto'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              setState(() => _videoFitMode = _VideoFitMode.automatic);
              Navigator.pop(dialogContext);
            },
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.fit_screen_rounded),
              title: Text('Autom\u00e1tico'),
              subtitle: Text('Elige el mejor encuadre para la pantalla'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              setState(() => _videoFitMode = _VideoFitMode.contain);
              Navigator.pop(dialogContext);
            },
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.fit_screen_rounded),
              title: Text('Ajustar'),
              subtitle: Text('Muestra la imagen completa'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              setState(() => _videoFitMode = _VideoFitMode.cover);
              Navigator.pop(dialogContext);
            },
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.zoom_out_map_rounded),
              title: Text('Llenar (sin deformar)'),
              subtitle: Text('Recorta los bordes para ocupar la pantalla'),
            ),
          ),
        ],
      ),
    );
    if (mounted) _screenFocus.requestFocus();
  }

  Future<void> _showServerSelector() async {
    final channel = widget.allChannels[_idx];
    final servers = channel.servers;
    if (servers.length < 2) return;
    final byLanguage = <String, List<ChannelServer>>{};
    for (final server in servers) {
      final language = server.language?.trim();
      final label = language == null || language.isEmpty
          ? 'Idioma no especificado'
          : language;
      byLanguage.putIfAbsent(label, () => []).add(server);
    }
    final selected = await showDialog<ChannelServer>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Cambiar servidor'),
        children: [
          for (final entry in byLanguage.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
              child: Text(
                entry.key,
                style: const TextStyle(
                  color: _hourRed,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (final server in entry.value)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, server),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _activeServerUrl == server.url
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(
                    server.name.trim().isEmpty
                        ? 'Servidor ${servers.indexOf(server) + 1}'
                        : server.name,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
    if (!mounted || selected == null) return;
    await _init(channel, streamUrl: selected.url);
    if (mounted) _screenFocus.requestFocus();
  }

  Future<void> _showPlayerOptions() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Opciones de reproducción'),
        children: [
          if (widget.allChannels[_idx].type != MediaType.live)
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(dialogContext);
                unawaited(_openCastSettings());
              },
              // Esto NO es transmitir: es el espejo de pantalla del sistema, y
              // no existe forma de hacerlo dentro de la app. Se deja porque es
              // la unica salida para servidores no casteables, pero el texto
              // avisa de que sale a los ajustes de Android.
              child: const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.screen_share_rounded),
                title: Text('Compartir pantalla'),
                subtitle: Text(
                  'Abre los ajustes de Android. Alternativa para servidores '
                  'que no se pueden transmitir',
                ),
              ),
            ),
          if (widget.allChannels[_idx].servers.length > 1)
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(dialogContext);
                unawaited(_showServerSelector());
              },
              child: const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.dns_rounded),
                title: Text('Servidor'),
              ),
            ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(dialogContext);
              unawaited(_showAudioSelector());
            },
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.audiotrack_rounded),
              title: Text('Audio'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(dialogContext);
              unawaited(_showSubtitleSelector());
            },
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.subtitles_rounded),
              title: Text('Subtítulos'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(dialogContext);
              unawaited(_showQualitySelector());
            },
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.high_quality_rounded),
              title: Text('Calidad'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(dialogContext);
              unawaited(_showAspectSelector());
            },
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.aspect_ratio_rounded),
              title: Text('Relación de aspecto'),
            ),
          ),
        ],
      ),
    );
    if (mounted) _screenFocus.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final desktop = DeviceProfile.isDesktop(context);

    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.backspace) {
      if (_showList) {
        setState(() => _showList = false);
      } else if (_cc?.isFullScreen == true) {
        _cc?.exitFullScreen();
      } else if (!desktop && _chromeVisible) {
        _chromeTimer?.cancel();
        setState(() => _chromeVisible = false);
      } else {
        Navigator.maybePop(context);
      }
      return KeyEventResult.handled;
    }

    if (_showList) return KeyEventResult.ignored;

    final playKey =
        key == LogicalKeyboardKey.mediaPlayPause ||
        key == LogicalKeyboardKey.mediaPlay ||
        key == LogicalKeyboardKey.mediaPause ||
        key == LogicalKeyboardKey.space ||
        (desktop && key == LogicalKeyboardKey.keyK) ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter;
    if (playKey) {
      _togglePlayPause();
      _showChromeControls();
      return KeyEventResult.handled;
    }

    if (desktop && key == LogicalKeyboardKey.keyM) {
      _volume = _volume > 0 ? 0 : 1;
      _vc?.setVolume(_volume);
      _showGesture(_volume == 0 ? 'Silencio' : 'Volumen 100%');
      _showChromeControls();
      return KeyEventResult.handled;
    }
    if (desktop && key == LogicalKeyboardKey.keyF) {
      final controller = _cc;
      if (controller != null) {
        controller.isFullScreen
            ? controller.exitFullScreen()
            : controller.enterFullScreen();
      }
      _showChromeControls();
      return KeyEventResult.handled;
    }
    if (desktop && key == LogicalKeyboardKey.arrowUp) {
      _volume = (_volume + .1).clamp(0.0, 1.0);
      _vc?.setVolume(_volume);
      _showGesture('Volumen ${(_volume * 100).round()}%');
      return KeyEventResult.handled;
    }
    if (desktop && key == LogicalKeyboardKey.arrowDown) {
      _volume = (_volume - .1).clamp(0.0, 1.0);
      _vc?.setVolume(_volume);
      _showGesture('Volumen ${(_volume * 100).round()}%');
      return KeyEventResult.handled;
    }

    if (_isLive &&
        (key == LogicalKeyboardKey.channelDown ||
            key == LogicalKeyboardKey.mediaTrackPrevious)) {
      unawaited(_chg(-1));
      _showChromeControls();
      return KeyEventResult.handled;
    }
    if (_isLive &&
        (key == LogicalKeyboardKey.channelUp ||
            key == LogicalKeyboardKey.mediaTrackNext)) {
      unawaited(_chg(1));
      _showChromeControls();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.mediaRewind) {
      unawaited(_seekBy(const Duration(seconds: -10)));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.mediaFastForward) {
      unawaited(_seekBy(const Duration(seconds: 10)));
      return KeyEventResult.handled;
    }
    if (!desktop && key == LogicalKeyboardKey.arrowUp) {
      _showChromeControls();
      unawaited(_showPlayerOptions());
      return KeyEventResult.handled;
    }
    if (!desktop && _isLive && key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _showList = true;
        _chromeVisible = true;
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_showList && !_chromeVisible,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) return;
      if (_showList) {
        setState(() => _showList = false);
      } else if (_chromeVisible) {
        setState(() => _chromeVisible = false);
      }
    },
    child: Focus(
      focusNode: _screenFocus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleChrome,
                onHorizontalDragEnd: _onHorizontalDragEnd,
                onVerticalDragStart: _onVerticalDragStart,
                onVerticalDragUpdate: _onVerticalDragUpdate,
                child: Stack(
                  children: [
                    // El video va FUERA del SafeArea, a sangre: dentro, el
                    // inset del recorte de camara le dejaba franjas negras a
                    // los lados en horizontal. Los controles si respetan el
                    // SafeArea, para no quedar debajo del notch.
                    //
                    // OJO: en Android el video va dentro de un `Center` con
                    // restricciones SUELTAS. Se intento unificarlo con el
                    // resto de plataformas usando Positioned.fill +
                    // SizedBox.expand (restricciones ajustadas) y la pantalla
                    // volvio a quedarse en negro con el audio sonando: el
                    // decodificador seguia entregando fotogramas (logcat:
                    // queueBuffer fps=30) pero la textura externa no se
                    // componia. Verificado en el Infinix. No cambiar sin
                    // probar en dispositivo.
                    if (defaultTargetPlatform == TargetPlatform.android)
                      Positioned.fill(
                        child: Center(
                          child: _loading
                              ? _lw()
                              : _err != null
                              ? _ew()
                              : _cc != null
                              ? _androidVideoStage()
                              : const SizedBox(),
                        ),
                      )
                    else
                      Positioned.fill(
                        child: _loading
                            ? Center(child: _lw())
                            : _err != null
                            ? Center(child: _ew())
                            : _vc != null
                            ? _videoStage()
                            : const SizedBox(),
                      ),
                    // Positioned.fill obligatorio: como hijo sin posicionar,
                    // este SafeArea se dimensionaba a su contenido, y el Stack
                    // de dentro solo tiene hijos Positioned, asi que colapsaba
                    // a 0x0 y arrastraba al Stack exterior. Resultado: pantalla
                    // completamente negra, sin video y sin controles.
                    Positioned.fill(
                      child: SafeArea(
                        minimum: EdgeInsets.symmetric(
                          horizontal: DeviceProfile.isTv(context) ? 12 : 0,
                        ),
                        child: Stack(
                          children: [
                            if (_screenDim > 0)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: ColoredBox(
                                    color: Colors.black.withValues(
                                      alpha: _screenDim,
                                    ),
                                  ),
                                ),
                              ),
                            if (_vc != null) _subtitleOverlay(_vc!),
                            if (_chromeVisible)
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: _tb(),
                              ),
                            if (_chromeVisible &&
                                DeviceProfile.isTv(context) &&
                                !_showList)
                              Positioned(
                                left: 46,
                                right: 46,
                                bottom: 34,
                                child: _tvTransport(),
                              ),
                            if (_chromeVisible &&
                                !DeviceProfile.isDesktop(context) &&
                                !DeviceProfile.isTv(context) &&
                                !_showList)
                              Positioned(
                                left: 16,
                                right: 16,
                                bottom: 12,
                                child: _touchTransport(),
                              ),
                            if (_chromeVisible &&
                                DeviceProfile.isDesktop(context) &&
                                !_showList)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Center(child: _desktopShortcutHint()),
                                ),
                              ),
                            if (_gestureLabel != null)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black87,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _gestureLabel!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (_vc != null) _introPrompt(),
                            _nextEpisodePrompt(),
                            _endOfPlaybackOverlay(),
                            if (_showList && _isLive) _ov(),
                            if (_chromeVisible &&
                                !_showList &&
                                _isLive &&
                                !DeviceProfile.isDesktop(context) &&
                                !DeviceProfile.isTv(context)) ...[
                              Positioned(
                                left: 8,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: _nb(
                                    Icons.chevron_left,
                                    () => _chg(-1),
                                    label: 'Canal anterior',
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 8,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: _nb(
                                    Icons.chevron_right,
                                    () => _chg(1),
                                    label: 'Canal siguiente',
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    ),
  );

  /// Linea de subtitulo con el tamaño/negrita elegidos en Perfil. Usa
  /// ValueListenableBuilder para repintar SOLO esta capa cuando cambia el
  /// caption, sin reconstruir el arbol completo en cada frame (clave para el
  /// TV Box). Aparece unicamente cuando la fuente entrega subtitulos.
  Widget _subtitleOverlay(VideoPlayerController controller) {
    return Positioned(
      left: 24,
      right: 24,
      bottom: DeviceProfile.isTv(context) ? 120 : 88,
      child: IgnorePointer(
        child: ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final text = value.caption.text.trim();
            if (text.isEmpty) return const SizedBox.shrink();
            return Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .66),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18 * _subtitleScale,
                      fontWeight: _subtitleBold
                          ? FontWeight.w900
                          : FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Conserva en Android el arbol de Chewie, estable con Skia. Ajustar y
  /// automatico respetan la relacion original; Llenar usa el Transform.scale
  /// que ya era fiable antes de introducir el render con FittedBox.
  /// Escena de video en Android. Recupera el encogido de creditos --que se
  /// perdio al pasar el render a Chewie-- sin volver a imponer restricciones
  /// ajustadas: se limita el maximo con un ConstrainedBox, asi el hijo sigue
  /// recibiendo restricciones SUELTAS y la textura se sigue componiendo.
  Widget _androidVideoStage() {
    final chewie = _cc;
    if (chewie == null) return const SizedBox();
    return ValueListenableBuilder<bool>(
      valueListenable: _creditsMode,
      builder: (context, credits, _) {
        final surface = _androidChewieSurface(chewie);
        if (!credits) return surface;
        final size = MediaQuery.sizeOf(context);
        return AnimatedSize(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: size.width * .68,
              maxHeight: size.height * .68,
            ),
            child: surface,
          ),
        );
      },
    );
  }

  Widget _androidChewieSurface(ChewieController chewie) {
    final controller = _vc;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    final videoAr = controller.value.aspectRatio > 0
        ? controller.value.aspectRatio
        : 16 / 9;
    // Se mide la caja real que ocupa el video, no la pantalla entera: en modo
    // creditos `_videoStage` reduce esa caja, y con MediaQuery el recorte se
    // calculaba sobre un tamano que ya no era el del video.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final surface = Chewie(controller: chewie);
        if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
          return surface;
        }
        final screenAr = width / height;
        final cover = switch (_videoFitMode) {
          _VideoFitMode.contain => false,
          _VideoFitMode.cover => true,
          _VideoFitMode.automatic => _shouldFill(videoAr, screenAr),
        };
        if (!cover) return surface;
        // OJO: aqui NO se puede usar Transform.scale. Impeller esta
        // desactivado (Skia) y video_player pinta una textura externa: al
        // aplicarle una matriz de escala el decodificador sigue entregando
        // fotogramas (logcat: queueBuffer fps=30) pero la superficie no se
        // compone y la pantalla queda en negro. Se comprobo en el Infinix.
        //
        // En su lugar se agranda la CAJA por layout y se recorta con un
        // ClipRect normal (sin saveLayer): la textura se dibuja a su tamano
        // real, sin transformaciones.
        final boxAr = width / height;
        final target = videoAr > boxAr
            ? Size(height * videoAr, height)
            : Size(width, width / videoAr);
        return ClipRect(
          child: OverflowBox(
            maxWidth: target.width,
            maxHeight: target.height,
            child: SizedBox(
              width: target.width,
              height: target.height,
              child: surface,
            ),
          ),
        );
      },
    );
  }

  Widget _videoStage() {
    return ValueListenableBuilder<bool>(
      valueListenable: _creditsMode,
      builder: (context, credits, _) {
        return LayoutBuilder(
          // OJO: nada de `alignment` aqui. Con alignment el Container pasa
          // restricciones SUELTAS al hijo, y un FittedBox con restricciones
          // sueltas no escala: se queda con el tamaño nativo del video
          // (1920x1080) y se sale de la pantalla -> se oia el audio pero la
          // imagen no aparecia. Solo con padding el hijo recibe
          // restricciones ajustadas y el modo creditos igual encoge.
          builder: (context, constraints) => AnimatedContainer(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            padding: credits
                ? EdgeInsets.fromLTRB(
                    24,
                    28,
                    constraints.maxWidth * .28,
                    constraints.maxHeight * .28,
                  )
                : EdgeInsets.zero,
            decoration: credits
                ? BoxDecoration(
                    border: Border.all(color: Colors.white24, width: 2),
                  )
                : null,
            child: SizedBox.expand(child: _videoSurface()),
          ),
        );
      },
    );
  }

  Widget _videoSurface() {
    final controller = _vc;
    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }
    if (DeviceProfile.isDesktop(context)) {
      final chewie = _cc;
      return chewie == null
          ? const ColoredBox(color: Colors.black)
          : Chewie(controller: chewie);
    }

    // Android no pasa por aqui: usa `_androidVideoStage`, con su propio
    // arbol de Chewie (ver el comentario en build).
    final videoSize = controller.value.size;
    final videoAr = controller.value.aspectRatio > 0
        ? controller.value.aspectRatio
        : 16 / 9;
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenAr = constraints.maxWidth / constraints.maxHeight;
        final fit = switch (_videoFitMode) {
          _VideoFitMode.contain => BoxFit.contain,
          _VideoFitMode.cover => BoxFit.cover,
          _VideoFitMode.automatic =>
            _shouldFill(videoAr, screenAr) ? BoxFit.cover : BoxFit.contain,
        };
        final width = videoSize.width > 0 ? videoSize.width : 16.0;
        final height = videoSize.height > 0 ? videoSize.height : 9.0;
        return ColoredBox(
          color: Colors.black,
          child: Center(
            child: FittedBox(
              fit: fit,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: width,
                height: height,
                child: VideoPlayer(controller),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Decide si en modo automatico se llena la pantalla (recortando) o se
  /// conserva la imagen completa (con franjas).
  ///
  /// Se mide la fraccion de imagen que se perderia al llenar, no una
  /// "diferencia relativa" abstracta. El umbral anterior era .18, y un 16:9 en
  /// un telefono de 2436x1080 da .21: se pasaba por poquisimo, asi que
  /// automatico NUNCA llenaba y siempre salian las franjas laterales.
  ///
  /// Llenar un 2.25:1 con un 16:9 cuesta un 21% de alto, recortado a partes
  /// iguales arriba y abajo. Se acepta hasta un 25%: a cambio desaparecen las
  /// franjas. Por encima de eso (contenido 4:3 o vertical) se conserva la
  /// imagen entera, porque recortar medio cuadro es peor que la franja. Quien
  /// quiera el fotograma completo tiene "Ajustar" en las opciones.
  static bool _shouldFill(double videoAr, double screenAr) {
    if (!videoAr.isFinite || !screenAr.isFinite) return false;
    if (videoAr <= 0 || screenAr <= 0) return false;
    final smaller = videoAr < screenAr ? videoAr : screenAr;
    final larger = videoAr < screenAr ? screenAr : videoAr;
    return 1 - (smaller / larger) <= .25;
  }

  Widget _touchTransport() {
    final controller = _vc;
    if (controller == null) return const SizedBox.shrink();
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final ready = value.isInitialized && value.duration > Duration.zero;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .82),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 12, 10),
            child: Row(
              children: [
                IconButton(
                  tooltip: value.isPlaying ? 'Pausar' : 'Reproducir',
                  onPressed: _togglePlayPause,
                  icon: Icon(
                    value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _formatPlaybackTime(value.position),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ready
                      ? VideoProgressIndicator(
                          controller,
                          allowScrubbing: true,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          colors: const VideoProgressColors(
                            playedColor: _hourRed,
                            bufferedColor: Color(0x99FFFFFF),
                            backgroundColor: Color(0x44FFFFFF),
                          ),
                        )
                      : const LinearProgressIndicator(
                          minHeight: 4,
                          color: _hourRed,
                          backgroundColor: Color(0x44FFFFFF),
                        ),
                ),
                const SizedBox(width: 10),
                Text(
                  _formatPlaybackTime(value.duration),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _introPrompt() {
    final controller = _vc;
    if (controller == null || !_isSeriesEpisode) {
      return const SizedBox.shrink();
    }
    return Positioned(
      right: 24,
      bottom: DeviceProfile.isTv(context) ? 138 : 90,
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final seconds = value.position.inSeconds;
          if (!value.isInitialized ||
              seconds < 5 ||
              seconds > 70 ||
              _playbackEnded.value) {
            return const SizedBox.shrink();
          }
          return _overlayAction(
            icon: Icons.skip_next_rounded,
            label: 'Omitir introducci\u00f3n \u00b7 salto estimado 1:25',
            onTap: () => unawaited(_skipEstimatedIntro()),
          );
        },
      ),
    );
  }

  Widget _nextEpisodePrompt() {
    if (!_hasNextEpisode) return const SizedBox.shrink();
    final next = widget.allChannels[_idx + 1];
    return Positioned(
      right: 24,
      bottom: 24,
      child: ValueListenableBuilder<int?>(
        valueListenable: _nextEpisodeCountdown,
        builder: (context, seconds, _) {
          if (seconds == null) return const SizedBox.shrink();
          final artwork = next.backdrop ?? next.logo;
          return Container(
            width: DeviceProfile.isTv(context) ? 390 : 340,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xF2111113),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xCC000000),
                  blurRadius: 28,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'SIGUIENTE EPISODIO',
                  style: TextStyle(
                    color: _hourRed,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 112,
                        height: 64,
                        child: artwork == null
                            ? const ColoredBox(
                                color: _hourSurface,
                                child: Icon(
                                  Icons.movie_rounded,
                                  color: Colors.white54,
                                ),
                              )
                            : CachedNetworkImage(
                                imageUrl: artwork,
                                memCacheWidth: 320,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) =>
                                    const ColoredBox(color: _hourSurface),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            next.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Reproducci\u00f3n autom\u00e1tica en $seconds s',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _overlayAction(
                        icon: Icons.play_arrow_rounded,
                        label: 'Reproducir ahora',
                        primary: true,
                        onTap: () => unawaited(_playNextEpisode()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _overlayAction(
                        icon: Icons.close_rounded,
                        label: 'Cancelar',
                        onTap: _cancelAutoNext,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _endOfPlaybackOverlay() {
    return Positioned.fill(
      child: ValueListenableBuilder<bool>(
        valueListenable: _playbackEnded,
        builder: (context, ended, _) {
          if (!ended || _isLive) return const SizedBox.shrink();
          return ColoredBox(
            color: const Color(0xF20B0B0B),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: _hourRed,
                        size: 52,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _currentChannel.displayName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: DeviceProfile.isTv(context) ? 32 : 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Has llegado al final.',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 26),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          if (_hasNextEpisode)
                            _overlayAction(
                              icon: Icons.skip_next_rounded,
                              label: 'Siguiente episodio',
                              primary: true,
                              autofocus: true,
                              onTap: () => unawaited(_playNextEpisode()),
                            ),
                          _overlayAction(
                            icon: Icons.replay_rounded,
                            label: 'Reproducir de nuevo',
                            primary: !_hasNextEpisode,
                            autofocus: !_hasNextEpisode,
                            onTap: () => unawaited(_replayCurrent()),
                          ),
                          _overlayAction(
                            icon: Icons.info_outline_rounded,
                            label: 'Ficha y contenido relacionado',
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                          _overlayAction(
                            icon: Icons.home_rounded,
                            label: 'Volver al inicio',
                            onTap: () => Navigator.of(
                              context,
                            ).popUntil((route) => route.isFirst),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _overlayAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool primary = false,
    bool autofocus = false,
  }) {
    final content = Container(
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      decoration: BoxDecoration(
        color: primary ? _hourRed : const Color(0xFF1B1B1E),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: primary ? _hourRed : Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 21),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
    if (DeviceProfile.isTv(context)) {
      return TvFocusable(
        onTap: onTap,
        autofocus: autofocus,
        borderRadius: BorderRadius.circular(11),
        child: content,
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: content,
      ),
    );
  }

  Widget _desktopShortcutHint() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'MÉTODOS ABREVIADOS',
            style: TextStyle(
              color: _hourRed,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Espacio / K  ·  Play o pausa\n'
            '← / →  ·  Retroceder o avanzar 10 s\n'
            '↑ / ↓  ·  Volumen     M  ·  Silencio     F  ·  Pantalla completa',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.7),
          ),
        ],
      ),
    );
  }

  Widget _lw() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const CircularProgressIndicator(color: _hourRed),
      const SizedBox(height: 16),
      const Text('Cargando...', style: TextStyle(color: Colors.white70)),
    ],
  );
  Widget _ew() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.error, color: _hourError, size: 48),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          _err ?? '',
          style: const TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      ),
      if (_errDetail != null && _errDetail!.trim().isNotEmpty) ...[
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _errDetail!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white30, fontSize: 11),
          ),
        ),
      ],
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: () =>
            _init(widget.allChannels[_idx], streamUrl: _activeServerUrl),
        icon: const Icon(Icons.refresh),
        label: const Text('Reintentar'),
      ),
    ],
  );
  Widget _nb(IconData ic, VoidCallback on, {required String label}) =>
      Semantics(
        button: true,
        label: label,
        child: TvFocusable(
          onTap: on,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(ic, color: Colors.white, size: 28),
          ),
        ),
      );

  Widget _tvTransport() {
    final controller = _vc;
    final value = controller?.value;
    final initialized = value?.isInitialized == true;
    final position = value?.position ?? Duration.zero;
    final duration = value?.duration ?? Duration.zero;

    String format(Duration time) {
      String two(int number) => number.toString().padLeft(2, '0');
      final hours = time.inHours;
      final base =
          '${two(time.inMinutes.remainder(60))}:${two(time.inSeconds.remainder(60))}';
      return hours > 0 ? '${two(hours)}:$base' : base;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 30,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _HourPlayerBadge(),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.allChannels[_idx].displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Text(
                  'CONTROL REMOTO ACTIVO',
                  style: TextStyle(
                    color: _hourMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _tvControl(
                  icon: Icons.replay_10_rounded,
                  label: 'Atrás',
                  onTap: () => unawaited(_seekBy(const Duration(seconds: -10))),
                ),
                const SizedBox(width: 12),
                _tvControl(
                  icon: value?.isPlaying == true
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  label: value?.isPlaying == true ? 'Pausa' : 'Reproducir',
                  primary: true,
                  onTap: _togglePlayPause,
                ),
                const SizedBox(width: 12),
                _tvControl(
                  icon: Icons.forward_10_rounded,
                  label: 'Adelante',
                  onTap: () => unawaited(_seekBy(const Duration(seconds: 10))),
                ),
                const SizedBox(width: 12),
                _tvControl(
                  icon: _volume == 0
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  label: 'Volumen',
                  onTap: () {
                    _volume = _volume > 0 ? 0 : 1;
                    _vc?.setVolume(_volume);
                    setState(() {});
                  },
                ),
                const SizedBox(width: 20),
                Text(
                  format(position),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: initialized
                        ? VideoProgressIndicator(
                            controller!,
                            allowScrubbing: true,
                            padding: EdgeInsets.zero,
                            colors: const VideoProgressColors(
                              playedColor: _hourRed,
                              bufferedColor: Color(0x99FFFFFF),
                              backgroundColor: Color(0x44FFFFFF),
                            ),
                          )
                        : const LinearProgressIndicator(
                            minHeight: 6,
                            color: _hourRed,
                            backgroundColor: Color(0x44FFFFFF),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  format(duration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tvControl({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    return TvFocusable(
      onTap: onTap,
      autofocus: primary,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: primary ? 76 : 64,
        height: primary ? 64 : 56,
        decoration: BoxDecoration(
          color: primary ? _hourRed : const Color(0xFF1A1A1D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: primary ? 31 : 25),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tb() {
    final ch = widget.allChannels[_idx];
    if (DeviceProfile.isTv(context)) {
      return SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          child: Row(
            children: [
              const _HourPlayerBadge(),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  ch.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TvFocusable(
                onTap: () => Navigator.maybePop(context),
                autofocus: false,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xDD171719),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.close_rounded, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Salir de reproducción',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
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
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Volver',
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (ch.type == MediaType.live) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _hourRed,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        ch.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (ch.epgLine != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      ch.epgLine!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else if (ch.group != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      ch.group!,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Picture-in-Picture',
            icon: const Icon(
              Icons.picture_in_picture_alt_rounded,
              color: Colors.white,
            ),
            onPressed: () => unawaited(_enterPictureInPicture()),
          ),
          if (DeviceProfile.isDesktop(context))
            IconButton(
              tooltip: 'Pantalla completa',
              icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
              onPressed: () {
                final controller = _cc;
                if (controller == null) return;
                if (controller.isFullScreen) {
                  controller.exitFullScreen();
                } else {
                  controller.enterFullScreen();
                }
              },
            ),
          if (ch.type != MediaType.live && !DeviceProfile.isTv(context))
            _castButton(),
          IconButton(
            tooltip: 'Audio, subtítulos, calidad y aspecto',
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
            onPressed: () => unawaited(_showPlayerOptions()),
          ),

          if (ch.type == MediaType.live)
            IconButton(
              tooltip: 'Todos los canales',
              icon: Icon(
                _showList
                    ? Icons.close_rounded
                    : Icons.format_list_bulleted_rounded,
                color: Colors.white,
              ),
              onPressed: () => setState(() => _showList = !_showList),
            ),
          IconButton(
            tooltip: ch.isFavorite ? 'Quitar de favoritos' : 'Favorito',
            icon: Icon(
              ch.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _hourRed,
            ),
            onPressed: () async {
              final fav = await StorageService.toggleFavorite(ch);
              if (!mounted) return;
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    fav ? 'Aniadido a favoritos' : 'Eliminado de favoritos',
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _ov() => Positioned.fill(
    child: GestureDetector(
      onTap: () => setState(() => _showList = false),
      child: Container(
        color: Colors.black87,
        child: Center(
          child: Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.7,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _hourSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text(
                        'Todos los canales',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        widget.allChannels.length.toString(),
                        style: const TextStyle(color: _hourMuted),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.allChannels.length,
                    itemBuilder: (ctx, i) {
                      final ch = widget.allChannels[i];
                      final cur = i == _idx;
                      return ListTile(
                        autofocus: cur,
                        onTap: () {
                          setState(() {
                            _idx = i;
                            _showList = false;
                          });
                          unawaited(_playChannel(ch));
                        },
                        leading: ch.logo != null
                            ? CachedNetworkImage(
                                imageUrl: ch.logo!,
                                memCacheWidth: 720,
                                width: 40,
                                height: 40,
                                fit: BoxFit.contain,
                                errorWidget: (a, b, c) => _in(ch),
                              )
                            : _in(ch),
                        title: Text(
                          ch.displayName,
                          style: TextStyle(
                            color: cur ? _hourRed : Colors.white,
                            fontSize: 14,
                            fontWeight: cur ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                        subtitle: (ch.epgLine ?? ch.group) != null
                            ? Text(
                                ch.epgLine ?? ch.group!,
                                style: const TextStyle(
                                  color: _hourMuted,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        trailing: cur
                            ? const Icon(
                                Icons.play_arrow,
                                color: _hourRed,
                                size: 20,
                              )
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  /// Guarda la posicion actual al salir del reproductor, para no perder
  /// hasta 10s de avance en "Continuar viendo" si el usuario sale antes del
  /// proximo tick periodico.
  void _persistFinalProgress() {
    final controller = _vc;
    if (controller == null || _isLive || !controller.value.isInitialized) {
      return;
    }
    final duration = controller.value.duration;
    if (duration <= Duration.zero) return;
    final fraction = (controller.value.position.inMilliseconds /
            duration.inMilliseconds)
        .clamp(0.0, 1.0);
    unawaited(
      ContentStore.instance.updatePlaybackProgress(_currentChannel, fraction),
    );
  }

  @override
  void dispose() {
    _persistFinalProgress();
    _chromeTimer?.cancel();
    _gestureTimer?.cancel();
    _castDevicesSubscription?.cancel();
    _castSessionSubscription?.cancel();
    unawaited(CastService.instance.stopDiscovery());
    _vc?.removeListener(_onVideoProgress);
    _cc?.dispose();
    _vc?.dispose();
    _nextEpisodeCountdown.dispose();
    _creditsMode.dispose();
    _playbackEnded.dispose();
    _screenFocus.dispose();
    if (_forcedLandscape || _forcedPortrait) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    super.dispose();
  }
}

/// Traduce el error crudo de ExoPlayer/Dart a algo que el usuario pueda
/// entender y accionar. Antes se pintaba `e.toString()` tal cual, o sea
/// cosas como "PlatformException(VideoError, ... ExoPlaybackException:
/// Source error, null, null)": ni el usuario sabe que hacer ni dice nada
/// sobre la causa real (cuenta vencida, canal caido, formato no soportado).
String playbackErrorMessage(String? raw) {
  final value = (raw ?? '').toLowerCase();
  if (value.isEmpty) {
    return 'No se pudo reproducir este contenido.';
  }
  if (value.contains('403') || value.contains('401')) {
    return 'El servidor rechazó la conexión. La cuenta puede haber vencido '
        'o estar en uso en otro dispositivo.';
  }
  if (value.contains('404')) {
    return 'Este enlace ya no existe en el servidor. Probá con otro '
        'servidor del mismo título.';
  }
  if (value.contains('failed host lookup') ||
      value.contains('no address associated') ||
      value.contains('socketexception') ||
      value.contains('connection refused') ||
      value.contains('network is unreachable')) {
    return 'No se pudo contactar al servidor. Revisá tu conexión a internet '
        'o si la fuente sigue activa.';
  }
  if (value.contains('timeout') || value.contains('timed out')) {
    return 'El servidor tardó demasiado en responder. Probá de nuevo o usá '
        'otro servidor.';
  }
  if (value.contains('cleartext')) {
    return 'El sistema bloqueó este servidor por usar HTTP sin cifrar.';
  }
  if (value.contains('handshake') || value.contains('certificate')) {
    return 'El certificado de seguridad del servidor no es válido.';
  }
  if (value.contains('unrecognizedinputformat') ||
      value.contains('none of the available extractors') ||
      value.contains('src_not_supported') ||
      value.contains('parsererror')) {
    return 'Este formato de video no se puede reproducir en este dispositivo.';
  }
  if (RegExp(r'\b5\d\d\b').hasMatch(value)) {
    return 'El servidor de la fuente está fallando. Probá más tarde o con '
        'otro servidor.';
  }
  return 'No se pudo reproducir este contenido. Probá con otro servidor.';
}

/// Extensiones de stream directo que ExoPlayer reproduce nativamente.
const _directMediaExtensions = <String>[
  '.m3u8',
  '.mpd',
  '.mp4',
  '.m4v',
  '.mov',
  '.webm',
  '.mkv',
  '.ts',
  '.flv',
  '.avi',
  '.mp3',
  '.aac',
  '.ogg',
];

/// True si la URL es una pagina web (embed tipo niramirus/dood/streamtape) en
/// vez de un stream directo. Los esquemas propios (archive:, stalker:) y los
/// enlaces con extension de video conocida NO son embed.
bool isEmbedStreamUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return false;
  }
  final path = uri.path.toLowerCase();
  return !_directMediaExtensions.any(path.endsWith);
}

class _HourPlayerBadge extends StatelessWidget {
  const _HourPlayerBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _hourRed,
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Text(
        'HOURTV TV-OS',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: .9,
        ),
      ),
    );
  }
}
