import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/channel.dart';
import '../services/storage_service.dart';
import '../services/ad_service.dart';
import '../services/archive_service.dart';
import '../services/stalker_service.dart';
import '../services/device_type.dart';
import '../services/cast_service.dart';
import '../services/embed_resolver.dart';
import '../theme/app_theme.dart';
import '../widgets/tv_focusable.dart';
import 'cast_controls_screen.dart';

class PlayerScreen extends StatefulWidget {
  final Channel channel;
  final List<Channel> allChannels;
  final String? initialUrl;
  const PlayerScreen({
    super.key,
    required this.channel,
    required this.allChannels,
    this.initialUrl,
  });
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _vc;
  ChewieController? _cc;
  bool _loading = true;
  String? _err;
  bool _showList = false;
  int _idx = 0;
  final _screenFocus = FocusNode();
  bool _forcedLandscape = false;
  static const _platform = MethodChannel('hourtv/device');
  Timer? _chromeTimer;
  Timer? _gestureTimer;
  bool _chromeVisible = true;
  double _volume = 1;
  double _screenDim = 0;
  double _videoScale = 1;
  bool _verticalGestureOnRight = true;
  String? _gestureLabel;
  String? _activeServerUrl;
  String? _resolvedPlaybackUrl;
  // VOD servido como pagina embed (niramirus, dood, streamtape...). No es un
  // stream directo: se reproduce dentro de un WebView contenido.
  String? _embedUrl;
  WebViewController? _embedController;
  StreamSubscription<List<GoogleCastDevice>>? _castDevicesSubscription;
  StreamSubscription<GoogleCastSession?>? _castSessionSubscription;
  List<GoogleCastDevice> _castDevices = const [];
  bool _castSdkAvailable = false;
  bool _castConnected = false;
  bool _castConnecting = false;

  @override
  void initState() {
    super.initState();
    _idx = widget.allChannels.indexWhere((c) => c.url == widget.channel.url);
    if (_idx < 0) _idx = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_startInitialPlayback());
        unawaited(_initializeCast());
      }
    });
    if (StorageService.getSetting('forceLandscape', defaultValue: false) ==
        true) {
      _forcedLandscape = true;
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
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

  Future<void> _init(Channel ch, {String? streamUrl}) async {
    final targetUrl = streamUrl ?? ch.url;
    setState(() {
      _loading = true;
      _err = null;
      _activeServerUrl = targetUrl;
      _embedUrl = null;
    });
    _cc?.dispose();
    _vc?.dispose();
    _cc = null;
    _vc = null;
    _embedController = null;
    try {
      var playUrl = targetUrl;
      Map<String, String> playHeaders = ch.userAgent?.isNotEmpty == true
          ? {'User-Agent': ch.userAgent!}
          : const {};
      // VOD cuyo servidor es una pagina embed (streamwish, vidhide, dood...):
      // como Xuper, se intenta extraer el .m3u8/.mp4 directo y reproducirlo
      // nativo en ExoPlayer con su Referer. Si no se puede resolver, cae al
      // WebView contenido. En Vivo nunca entra aqui.
      if (ch.type != MediaType.live && isEmbedStreamUrl(targetUrl)) {
        final resolved = await EmbedResolver.resolve(targetUrl);
        if (!mounted) return;
        if (resolved != null) {
          playUrl = resolved.url;
          playHeaders = resolved.headers;
        } else {
          _resolvedPlaybackUrl = targetUrl;
          _createEmbedController(targetUrl);
          setState(() => _loading = false);
          return;
        }
      }
      if (playUrl.startsWith('archive:')) {
        final resolved = await ArchiveService.resolveStream(playUrl);
        if (resolved == null) {
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
          setState(() {
            _err = 'No se pudo crear el enlace temporal de este canal.';
            _loading = false;
          });
          return;
        }
        playUrl = resolved;
      }
      _resolvedPlaybackUrl = playUrl;
      _vc = VideoPlayerController.networkUrl(
        Uri.parse(playUrl),
        httpHeaders: playHeaders,
      );
      await _vc!.initialize();
      final autoPlay =
          StorageService.getSetting('autoPlay', defaultValue: true) == true;
      _cc = ChewieController(
        videoPlayerController: _vc!,
        autoPlay: autoPlay,
        looping: false,
        aspectRatio: _vc!.value.aspectRatio,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        placeholder: Container(
          color: Colors.black,
          child: Center(child: _lg(ch)),
        ),
        errorBuilder: (_, m) => Center(
          child: Text(m, style: const TextStyle(color: Colors.white)),
        ),
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.accent,
          handleColor: AppColors.accent,
          backgroundColor: AppColors.cardDark,
          bufferedColor: AppColors.textMuted,
        ),
      );
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _err = e.toString();
        _loading = false;
      });
    }
  }

  Widget _lg(Channel ch) => ch.logo != null
      ? CachedNetworkImage(
          imageUrl: ch.logo!,
          width: 80,
          height: 80,
          fit: BoxFit.contain,
          errorWidget: (a, b, c) => _in(ch),
        )
      : _in(ch);
  Widget _in(Channel ch) => Text(
    ch.displayName.isNotEmpty ? ch.displayName[0].toUpperCase() : '?',
    style: const TextStyle(
      color: AppColors.accent,
      fontSize: 40,
      fontWeight: FontWeight.bold,
    ),
  );

  void _createEmbedController(String url) {
    final host = Uri.tryParse(url)?.host;
    _embedController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          // Permite el host del embed; bloquea saltos a otros dominios
          // (popups de publicidad y redirecciones). Los iframes del video son
          // subrecursos, no navegaciones, y siguen cargando.
          onNavigationRequest: (request) =>
              AdService.allowsContainedNavigation(
                request.url,
                lockedHost: host,
              )
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
        ),
      )
      ..loadRequest(Uri.parse(url));
    _embedUrl = url;
  }

  /// Cuerpo del reproductor cuando el servidor es una pagina embed: el WebView
  /// ocupa la pantalla y una barra minima permite volver o cambiar de servidor.
  Widget _embedBody() {
    final ch = widget.allChannels[_idx];
    return Stack(
      children: [
        Positioned.fill(child: WebViewWidget(controller: _embedController!)),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Text(
                      ch.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (ch.servers.length > 1)
                    IconButton(
                      tooltip: 'Cambiar servidor',
                      icon: const Icon(
                        Icons.playlist_play_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => unawaited(_showServerSelector()),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

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
    _castDevicesSubscription = CastService.instance.devicesStream.listen((
      devices,
    ) {
      if (mounted) setState(() => _castDevices = devices);
    });
    _castSessionSubscription = CastService.instance.sessionStream.listen(
      _onCastSessionChanged,
    );
    setState(() {
      _castSdkAvailable = true;
      _castDevices = CastService.instance.devices;
      _castConnected = CastService.instance.isConnected;
    });
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

  Future<void> _openRealCast() async {
    final channel = widget.allChannels[_idx];
    if (_castConnected) {
      await _openCastControls();
      return;
    }
    if (CastService.needsUnsupportedHeaders(channel.userAgent)) {
      await _showCastFallback(
        'Este servidor exige un User-Agent personalizado. El receptor '
        'predeterminado de Chromecast no permite enviar esa cabecera, por lo '
        'que el video podría ser rechazado.',
      );
      return;
    }
    final streamUrl = _resolvedPlaybackUrl ?? _activeServerUrl ?? channel.url;
    if (!CastService.isNetworkUrl(streamUrl) ||
        CastService.contentTypeFor(streamUrl) == null) {
      await _showCastFallback(
        'Este servidor no expone una URL HLS o MP4 compatible con Chromecast.',
      );
      return;
    }

    await CastService.instance.startDiscovery();
    if (!mounted) return;
    final selected = await showDialog<Object>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Transmitir a'),
        children: [
          for (final device in _castDevices)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, device),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cast_rounded),
                title: Text(device.friendlyName),
                subtitle: device.modelName == null
                    ? null
                    : Text(device.modelName!),
              ),
            ),
          const Divider(),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 'mirror'),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.screen_share_rounded),
              title: Text('Compartir pantalla'),
              subtitle: Text('Usar el espejo nativo como alternativa'),
            ),
          ),
        ],
      ),
    );
    if (!mounted || selected == null) return;
    if (selected == 'mirror') {
      await _openCastSettings();
      return;
    }
    await _connectToCast(selected as GoogleCastDevice, streamUrl, channel);
  }

  Future<void> _connectToCast(
    GoogleCastDevice device,
    String streamUrl,
    Channel channel,
  ) async {
    setState(() => _castConnecting = true);
    try {
      final video = _vc;
      await CastService.instance.connectAndLoad(
        device: device,
        url: streamUrl,
        title: channel.displayName,
        posterUrl: channel.backdrop ?? channel.logo,
        position: video?.value.position ?? Duration.zero,
        duration: video?.value.duration,
      );
      await video?.pause();
      if (!mounted) return;
      await _openCastControls();
    } on TimeoutException {
      if (mounted) {
        await _showCastFallback(
          'El Chromecast no respondió a tiempo. Comprueba que ambos dispositivos '
          'estén en la misma red Wi-Fi.',
        );
      }
    } catch (error) {
      if (mounted) {
        await _showCastFallback('No se pudo transmitir: $error');
      }
    } finally {
      if (mounted) setState(() => _castConnecting = false);
    }
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

  Future<void> _showCastFallback(String reason) async {
    final useMirror = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('No se puede usar Cast directo'),
        content: Text('$reason\n\n¿Quieres compartir la pantalla en su lugar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.screen_share_rounded),
            label: const Text('Compartir pantalla'),
          ),
        ],
      ),
    );
    if (useMirror == true && mounted) await _openCastSettings();
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
              setState(() => _videoScale = 1);
              Navigator.pop(dialogContext);
            },
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.fit_screen_rounded),
              title: Text('Original'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              setState(() => _videoScale = 1.16);
              Navigator.pop(dialogContext);
            },
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.zoom_out_map_rounded),
              title: Text('Zoom / llenar pantalla'),
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
                  color: AppColors.accent,
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
              child: const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.screen_share_rounded),
                title: Text('Compartir pantalla'),
                subtitle: Text('Alternativa para servidores no casteables'),
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
    final k = event.logicalKey;

    if (k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.goBack) {
      if (_showList) {
        setState(() => _showList = false);
      } else if (_chromeVisible) {
        _chromeTimer?.cancel();
        setState(() => _chromeVisible = false);
      } else {
        Navigator.maybePop(context);
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.mediaPlayPause ||
        k == LogicalKeyboardKey.mediaPlay ||
        k == LogicalKeyboardKey.mediaPause) {
      _togglePlayPause();
      _showChromeControls();
      return KeyEventResult.handled;
    }
    if (_showList) return KeyEventResult.ignored;
    if (k == LogicalKeyboardKey.channelDown ||
        k == LogicalKeyboardKey.mediaTrackPrevious) {
      _chg(-1);
      _showChromeControls();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.channelUp ||
        k == LogicalKeyboardKey.mediaTrackNext) {
      _chg(1);
      _showChromeControls();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.mediaRewind) {
      unawaited(_seekBy(const Duration(seconds: -10)));
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight ||
        k == LogicalKeyboardKey.mediaFastForward) {
      unawaited(_seekBy(const Duration(seconds: 10)));
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp) {
      _showChromeControls();
      unawaited(_showPlayerOptions());
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _showList = true;
        _chromeVisible = true;
      });
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter ||
        k == LogicalKeyboardKey.space) {
      _togglePlayPause();
      _showChromeControls();
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
        body: (!_loading && _embedUrl != null && _embedController != null)
            ? _embedBody()
            : GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleChrome,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          onVerticalDragStart: _onVerticalDragStart,
          onVerticalDragUpdate: _onVerticalDragUpdate,
          child: SafeArea(
            minimum: EdgeInsets.symmetric(
              horizontal: DeviceProfile.isTv(context) ? 12 : 0,
            ),
            child: Stack(
              children: [
                Center(
                  child: _loading
                      ? _lw()
                      : _err != null
                      ? _ew()
                      : _cc != null
                      ? Transform.scale(
                          scale: _videoScale,
                          child: Chewie(controller: _cc!),
                        )
                      : const SizedBox(),
                ),
                if (_screenDim > 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: _screenDim),
                      ),
                    ),
                  ),
                if (_chromeVisible)
                  Positioned(top: 0, left: 0, right: 0, child: _tb()),
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
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_showList) _ov(),
                if (_chromeVisible && !_showList) ...[
                  Positioned(
                    left: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _nb(Icons.chevron_left, () => _chg(-1)),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _nb(Icons.chevron_right, () => _chg(1)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _lw() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const CircularProgressIndicator(color: AppColors.accent),
      const SizedBox(height: 16),
      const Text('Cargando...', style: TextStyle(color: Colors.white70)),
    ],
  );
  Widget _ew() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.error, color: AppColors.error, size: 48),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          _err ?? '',
          style: const TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      ),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: () =>
            _init(widget.allChannels[_idx], streamUrl: _activeServerUrl),
        icon: const Icon(Icons.refresh),
        label: const Text('Reintentar'),
      ),
    ],
  );
  Widget _nb(IconData ic, VoidCallback on) => TvFocusable(
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
  );

  Widget _tb() {
    final ch = widget.allChannels[_idx];
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
                          color: AppColors.live,
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
          if (ch.type != MediaType.live &&
              _castSdkAvailable &&
              (_castDevices.isNotEmpty || _castConnected))
            IconButton(
              tooltip: _castConnected
                  ? 'Controles de transmisión'
                  : 'Transmitir a Chromecast',
              icon: _castConnecting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _castConnected
                          ? Icons.cast_connected_rounded
                          : Icons.cast_rounded,
                      color: Colors.white,
                    ),
              onPressed: _castConnecting
                  ? null
                  : () => unawaited(_openRealCast()),
            ),
          IconButton(
            tooltip: 'Audio, subtítulos, calidad y aspecto',
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
            onPressed: () => unawaited(_showPlayerOptions()),
          ),

          IconButton(
            icon: Icon(
              _showList
                  ? Icons.close_rounded
                  : Icons.format_list_bulleted_rounded,
              color: Colors.white,
            ),
            onPressed: () => setState(() => _showList = !_showList),
          ),
          IconButton(
            icon: Icon(
              ch.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: AppColors.accent,
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
              color: AppColors.surfaceDark,
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
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        widget.allChannels.length.toString(),
                        style: const TextStyle(color: AppColors.textMuted),
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
                                width: 40,
                                height: 40,
                                fit: BoxFit.contain,
                                errorWidget: (a, b, c) => _in(ch),
                              )
                            : _in(ch),
                        title: Text(
                          ch.displayName,
                          style: TextStyle(
                            color: cur
                                ? AppColors.accent
                                : AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: cur ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                        subtitle: (ch.epgLine ?? ch.group) != null
                            ? Text(
                                ch.epgLine ?? ch.group!,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        trailing: cur
                            ? const Icon(
                                Icons.play_arrow,
                                color: AppColors.accent,
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

  @override
  void dispose() {
    _chromeTimer?.cancel();
    _gestureTimer?.cancel();
    _castDevicesSubscription?.cancel();
    _castSessionSubscription?.cancel();
    unawaited(CastService.instance.stopDiscovery());
    _cc?.dispose();
    _vc?.dispose();
    _screenFocus.dispose();
    if (_forcedLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    super.dispose();
  }
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
