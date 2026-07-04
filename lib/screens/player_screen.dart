import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../services/storage_service.dart';
import '../services/archive_service.dart';
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

  @override
  void initState() {
    super.initState();
    _idx = widget.allChannels.indexWhere((c) => c.url == widget.channel.url);
    if (_idx < 0) _idx = 0;
    _init(widget.allChannels[_idx]);
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
      }
      _vc = VideoPlayerController.networkUrl(Uri.parse(playUrl));
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

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.mediaPlayPause ||
        k == LogicalKeyboardKey.mediaPlay ||
        k == LogicalKeyboardKey.mediaPause) {
      _togglePlayPause();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
      return KeyEventResult.handled;
    }
    if (_showList) return KeyEventResult.ignored;
    if (k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.mediaTrackPrevious) {
      _chg(-1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight ||
        k == LogicalKeyboardKey.mediaTrackNext) {
      _chg(1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter) {
      _togglePlayPause();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _screenFocus,
    autofocus: true,
    onKeyEvent: _onKey,
    child: Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: _loading
                  ? _lw()
                  : _err != null
                  ? _ew()
                  : _cc != null
                  ? Chewie(controller: _cc!)
                  : const SizedBox(),
            ),
            Positioned(top: 0, left: 0, right: 0, child: _tb()),
            if (_showList) _ov(),
            if (!_showList) ...[
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(child: _nb(Icons.chevron_left, () => _chg(-1))),
              ),
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(child: _nb(Icons.chevron_right, () => _chg(1))),
              ),
            ],
          ],
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
