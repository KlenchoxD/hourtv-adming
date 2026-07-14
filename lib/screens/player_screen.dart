import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../services/storage_service.dart';
import '../services/archive_service.dart';
import '../services/stalker_service.dart';
import '../services/device_type.dart';
import '../theme/app_theme.dart';
import '../widgets/tv_focusable.dart';

class PlayerScreen extends StatefulWidget {
  final Channel channel;
  final List<Channel> allChannels;
  const PlayerScreen({
    super.key,
    required this.channel,
    required this.allChannels,
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

  @override
  void initState() {
    super.initState();
    _idx = widget.allChannels.indexWhere((c) => c.url == widget.channel.url);
    if (_idx < 0) _idx = 0;
    _init(widget.allChannels[_idx]);
    StorageService.saveRecent(widget.allChannels[_idx]);
    if (StorageService.getSetting('forceLandscape', defaultValue: false) ==
        true) {
      _forcedLandscape = true;
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  Future<void> _init(Channel ch) async {
    setState(() {
      _loading = true;
      _err = null;
    });
    _cc?.dispose();
    _vc?.dispose();
    _cc = null;
    _vc = null;
    try {
      var playUrl = ch.url;
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
      _vc = VideoPlayerController.networkUrl(
        Uri.parse(playUrl),
        httpHeaders: ch.userAgent?.isNotEmpty == true
            ? {'User-Agent': ch.userAgent!}
            : const {},
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

  void _chg(int d) {
    final ni = _idx + d;
    if (ni >= 0 && ni < widget.allChannels.length) {
      setState(() => _idx = ni);
      _init(widget.allChannels[ni]);
      StorageService.saveRecent(widget.allChannels[ni]);
    }
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

  Future<void> _showPlayerOptions() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Opciones de reproducción'),
        children: [
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
        body: GestureDetector(
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
        onPressed: () => _init(widget.allChannels[_idx]),
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
                          _init(ch);
                          StorageService.saveRecent(ch);
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
