import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../services/storage_service.dart';
import '../services/content_store.dart';
import '../theme/app_theme.dart';
import '../widgets/tv_focusable.dart';
import 'search_screen.dart';
import 'player_screen.dart';

/// Pestaña EN VIVO: solo canales. El canal se reproduce a pantalla completa de
/// fondo y por encima van el menú de categorías (izquierda), la lista de
/// canales (derecha) y la barra de estado (arriba). Operable con control
/// remoto, teclado y táctil. Los datos vienen del almacén compartido.
class LiveTvScreen extends StatefulWidget {
  final bool active;
  const LiveTvScreen({super.key, this.active = true});
  @override
  State<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _NavCat {
  final String label;
  final IconData icon;
  final String mode; // 'live' | 'fav' | 'genre'
  final String? genre; // id de genero cuando mode == 'genre'
  const _NavCat(this.label, this.icon, this.mode, [this.genre]);
}

const List<_NavCat> _categories = [
  _NavCat('EN VIVO', Icons.live_tv_rounded, 'live'),
  _NavCat('ANIME', Icons.animation_rounded, 'genre', 'anime'),
  _NavCat('DEPORTES', Icons.sports_soccer_rounded, 'genre', 'deportes'),
  _NavCat('NOTICIAS', Icons.newspaper_rounded, 'genre', 'noticias'),
  _NavCat('INFANTILES', Icons.child_care_rounded, 'genre', 'infantiles'),
  _NavCat('DOCUMENTALES', Icons.video_library_rounded, 'genre', 'documentales'),
  _NavCat('COMEDIA', Icons.theater_comedy_rounded, 'genre', 'comedia'),
  _NavCat('MÚSICA', Icons.music_note_rounded, 'genre', 'musica'),
  _NavCat('FAVORITOS', Icons.favorite_rounded, 'fav'),
];

class _LiveTvScreenState extends State<LiveTvScreen> {
  final _store = ContentStore.instance;

  List<Channel> _list = []; // canales de la categoria/pais actual
  bool _autoPlayed = false;

  // Reproductor
  VideoPlayerController? _vc;
  Channel? _current;
  bool _videoLoading = false;
  bool _videoError = false;

  // Navegacion / foco (0 = menu categorias, 1 = lista canales)
  int _zone = 1;
  int _catIdx = 0;
  int _chIdx = 0;
  final FocusNode _root = FocusNode();
  final ScrollController _chScroll = ScrollController();

  // EN VIVO: país seleccionado
  String _country = 'all';

  // Overlays (se ocultan solos para ver el video a pantalla completa)
  bool _overlaysVisible = true;
  Timer? _hideTimer;

  // Reloj
  late Timer _clock;
  DateTime _now = DateTime.now();

  static const double _chItemH = 76;

  List<Channel> get _all => _store.all;
  bool get _loading => _store.loading;
  String? get _error => _store.error;
  List<CountryBucket> get _countries => _store.countries;
  bool get _liveMode => _categories[_catIdx].mode == 'live';

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _store.addListener(_onStore);
    _store.ensureLoaded();
    _applyFilter();
  }

  @override
  void didUpdateWidget(covariant LiveTvScreen old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) {
      if (!widget.active) {
        _vc?.pause();
      } else {
        _maybeAutoPlay();
        _vc?.play();
        _showOverlays();
      }
    }
  }

  void _onStore() {
    if (!mounted) return;
    _applyFilter();
    _maybeAutoPlay();
  }

  void _maybeAutoPlay() {
    if (_autoPlayed || !widget.active) return;
    if (_list.isNotEmpty) {
      _autoPlayed = true;
      _play(_list.first);
      _showOverlays();
    }
  }

  @override
  void dispose() {
    _clock.cancel();
    _hideTimer?.cancel();
    _store.removeListener(_onStore);
    _vc?.dispose();
    _root.dispose();
    _chScroll.dispose();
    super.dispose();
  }

  bool _matches(Channel ch, _NavCat cat) {
    switch (cat.mode) {
      case 'fav':
        return ch.isFavorite;
      case 'genre':
        return ch.type == MediaType.live && ch.genre == cat.genre;
      case 'live':
        if (ch.type != MediaType.live) return false;
        if (_country != 'all') return (ch.countryCode ?? 'zz') == _country;
        return true;
    }
    return false;
  }

  void _applyFilter({bool resetSelection = false}) {
    final cat = _categories[_catIdx];
    _list = _all.where((ch) => _matches(ch, cat)).toList();
    if (resetSelection) _chIdx = 0;
    if (_chIdx >= _list.length) _chIdx = _list.isEmpty ? 0 : _list.length - 1;
    if (mounted) setState(() {});
  }

  Future<void> _play(Channel ch) async {
    setState(() {
      _current = ch;
      _videoLoading = true;
      _videoError = false;
    });
    final old = _vc;
    final vc = VideoPlayerController.networkUrl(Uri.parse(ch.url));
    _vc = vc;
    await old?.dispose();
    try {
      await vc.initialize();
      await vc.setLooping(false);
      if (widget.active) await vc.play();
      if (mounted) setState(() => _videoLoading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _videoError = true;
          _videoLoading = false;
        });
      }
    }
    StorageService.saveRecent(ch);
  }

  Future<void> _toggleFav(Channel ch) async {
    await _store.toggleFavorite(ch);
    if (_categories[_catIdx].mode == 'fav') _applyFilter();
    if (mounted) setState(() {});
  }

  void _selectCategory(int i) {
    setState(() {
      _catIdx = i;
      _zone = 0;
      _country = 'all';
    });
    _applyFilter(resetSelection: true);
    _showOverlays();
  }

  void _selectCountry(String code) {
    setState(() => _country = code);
    _applyFilter(resetSelection: true);
    _showOverlays();
  }

  // ---------- Auto-ocultar overlays ----------
  void _showOverlays() {
    _hideTimer?.cancel();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (!_overlaysVisible) setState(() => _overlaysVisible = true);
    _hideTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _overlaysVisible = false);
    });
  }

  void _toggleOverlays() {
    if (_overlaysVisible) {
      _hideTimer?.cancel();
      setState(() => _overlaysVisible = false);
    } else {
      _showOverlays();
    }
  }

  void _hideForPlayback() {
    _hideTimer?.cancel();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    setState(() => _overlaysVisible = false);
  }

  void _goFullscreen() => _hideForPlayback();

  void _focusChannel(int i) {
    if (_list.isEmpty) return;
    setState(() {
      _chIdx = i.clamp(0, _list.length - 1);
      _zone = 1;
    });
    final target = (_chIdx * _chItemH) - _chItemH;
    if (_chScroll.hasClients) {
      _chScroll.animateTo(
        target.clamp(0.0, _chScroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  // ---------- Teclado / control remoto ----------
  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;

    if (!_overlaysVisible) {
      if (k == LogicalKeyboardKey.escape) {
        Navigator.maybePop(context);
        return KeyEventResult.handled;
      }
      _showOverlays();
      return KeyEventResult.handled;
    }
    _showOverlays();

    if (k == LogicalKeyboardKey.arrowLeft) {
      if (_zone == 1) {
        setState(() => _zone = 0);
        return KeyEventResult.handled;
      }
    } else if (k == LogicalKeyboardKey.arrowRight) {
      if (_zone == 0) {
        setState(() => _zone = 1);
        return KeyEventResult.handled;
      }
    } else if (k == LogicalKeyboardKey.arrowUp) {
      if (_zone == 0) {
        setState(
          () => _catIdx = (_catIdx - 1).clamp(0, _categories.length - 1),
        );
        _applyFilter(resetSelection: true);
      } else {
        _focusChannel(_chIdx - 1);
      }
      return KeyEventResult.handled;
    } else if (k == LogicalKeyboardKey.arrowDown) {
      if (_zone == 0) {
        setState(
          () => _catIdx = (_catIdx + 1).clamp(0, _categories.length - 1),
        );
        _applyFilter(resetSelection: true);
      } else {
        _focusChannel(_chIdx + 1);
      }
      return KeyEventResult.handled;
    } else if (k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter ||
        k == LogicalKeyboardKey.space) {
      if (_zone == 0) {
        _selectCategory(_catIdx);
      } else if (_list.isNotEmpty) {
        _play(_list[_chIdx]);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String get _clockText {
    final h = _now.hour % 12 == 0 ? 12 : _now.hour % 12;
    final m = _now.minute.toString().padLeft(2, '0');
    final ap = _now.hour < 12 ? 'AM' : 'PM';
    return '${h.toString().padLeft(2, '0')}:$m $ap';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final portrait = size.height >= size.width;
    return Focus(
      focusNode: _root,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            portrait ? _portraitBody() : _immersiveBody(size.width),
            if (_loading && _all.isEmpty)
              Positioned.fill(
                child: Container(color: Colors.black, child: _bootLoading()),
              ),
            if (_error != null && !_loading && _all.isEmpty)
              Positioned.fill(
                child: Container(color: Colors.black, child: _errorState()),
              ),
          ],
        ),
      ),
    );
  }

  // ---------- Layout horizontal / TV ----------
  Widget _immersiveBody(double w) {
    final catW = (w * 0.24).clamp(150.0, 230.0);
    final chW = (w * 0.30).clamp(240.0, 360.0);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleOverlays,
            child: _video(),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_overlaysVisible,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _overlaysVisible ? 1 : 0,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.black.withValues(alpha: 0.55),
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.55),
                            ],
                            stops: const [0.0, 0.28, 0.7, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: 0,
                    width: catW,
                    child: _categoryRail(),
                  ),
                  Positioned(
                    top: 56,
                    bottom: 0,
                    right: 0,
                    width: chW,
                    child: _channelRail(),
                  ),
                  Positioned(top: 0, left: 0, right: 0, child: _statusBar()),
                ],
              ),
            ),
          ),
        ),
        if (!_overlaysVisible && !_loading)
          Positioned(
            top: 16,
            right: 16,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.touch_app_rounded,
                      color: Colors.white70,
                      size: 14,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Toca para el menú',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ---------- Layout vertical / telefono ----------
  Widget _portraitBody() {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _statusBar(),
          GestureDetector(
            onTap: _goFullscreen,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                  Positioned.fill(child: _video()),
                  const Positioned(
                    right: 10,
                    bottom: 10,
                    child: Icon(
                      Icons.fullscreen_rounded,
                      color: Colors.white70,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _categoryChipsRow(),
          Expanded(child: _channelRail()),
        ],
      ),
    );
  }

  Widget _categoryChipsRow() {
    return Container(
      height: 46,
      color: Colors.black.withValues(alpha: 0.3),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        itemCount: _categories.length,
        itemBuilder: (ctx, i) {
          final c = _categories[i];
          final sel = i == _catIdx;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TvFocusable(
              onTap: () => _selectCategory(i),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: sel ? AppTheme.accentGradient : null,
                  color: sel ? null : AppColors.cardDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: sel
                        ? Colors.transparent
                        : Colors.white.withValues(alpha: 0.07),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      c.icon,
                      size: 15,
                      color: sel ? Colors.white : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      c.label,
                      style: TextStyle(
                        color: sel ? Colors.white : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------- Video ----------
  Widget _video() {
    final vc = _vc;
    if (vc != null && vc.value.isInitialized && !_videoError) {
      return ColoredBox(
        color: Colors.black,
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: vc.value.size.width,
            height: vc.value.size.height,
            child: VideoPlayer(vc),
          ),
        ),
      );
    }
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B1730), Colors.black],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_current?.logo != null)
              SizedBox(
                width: 130,
                height: 90,
                child: CachedNetworkImage(
                  imageUrl: _current!.logo!,
                  fit: BoxFit.contain,
                  errorWidget: (_, _, _) => const Icon(
                    Icons.tv_rounded,
                    color: AppColors.textMuted,
                    size: 64,
                  ),
                ),
              )
            else
              const Icon(
                Icons.tv_rounded,
                color: AppColors.textMuted,
                size: 64,
              ),
            const SizedBox(height: 18),
            if (_videoLoading)
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.accent,
                ),
              )
            else if (_videoError)
              Column(
                children: [
                  Text(
                    _current?.displayName ?? '',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'No se pudo reproducir este canal',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              )
            else if (_current != null)
              Text(
                _current!.displayName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------- Barra de estado superior ----------
  Widget _statusBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.live_tv_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'EN VIVO',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          _barIcon(Icons.search_rounded, _openSearch),
          _barIcon(Icons.refresh_rounded, () => _store.reload()),
          const SizedBox(width: 8),
          const Icon(
            Icons.wifi_rounded,
            color: AppColors.textSecondary,
            size: 18,
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 18, color: Colors.white24),
          const SizedBox(width: 12),
          Text(
            _clockText,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _barIcon(IconData ic, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: IconButton(
      icon: Icon(ic, color: AppColors.textSecondary, size: 20),
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
    ),
  );

  Future<void> _openSearch() async {
    _hideTimer?.cancel();
    final picked = await Navigator.push<Channel>(
      context,
      MaterialPageRoute(builder: (_) => SearchScreen(all: _all)),
    );
    if (!mounted) return;
    _root.requestFocus();
    if (picked != null) {
      if (picked.type == MediaType.live) {
        _play(picked);
      } else {
        // Película/serie: reproductor a pantalla completa (resuelve VOD/archive).
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PlayerScreen(channel: picked, allChannels: [picked]),
          ),
        );
      }
    }
    _showOverlays();
  }

  // ---------- Menu de categorias (izquierda) ----------
  Widget _categoryRail() {
    return Container(
      padding: const EdgeInsets.only(top: 64, left: 6, bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.black.withValues(alpha: 0.75), Colors.transparent],
        ),
      ),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: _categories.length,
        itemBuilder: (ctx, i) {
          final c = _categories[i];
          final selected = i == _catIdx;
          final focused = _zone == 0 && i == _catIdx;
          return GestureDetector(
            onTap: () => _selectCategory(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: focused
                    ? AppColors.accent.withValues(alpha: 0.22)
                    : (selected
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.transparent),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: focused ? AppColors.accent : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    c.icon,
                    size: 22,
                    color: selected ? AppColors.accent : Colors.white70,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      c.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontSize: 14,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------- Selector de país (EN VIVO) ----------
  Widget _countryBar() {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _countries.length,
        itemBuilder: (ctx, i) {
          final b = _countries[i];
          final sel = b.code == _country;
          final flag = b.code == 'all'
              ? '🌎'
              : (b.code == 'zz' ? '📺' : countryFlag(b.code));
          return Padding(
            padding: const EdgeInsets.only(right: 7, top: 4, bottom: 4),
            child: TvFocusable(
              onTap: () => _selectCountry(b.code),
              borderRadius: BorderRadius.circular(18),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.accent
                      : AppColors.cardElevated.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: sel
                        ? AppColors.accentLight
                        : Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(flag, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(
                      b.name,
                      style: TextStyle(
                        color: sel ? Colors.white : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${b.count}',
                      style: TextStyle(
                        color: sel ? Colors.white70 : AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------- Lista de canales (derecha) ----------
  Widget _channelRail() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Icon(
                  _categories[_catIdx].icon,
                  color: AppColors.accent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _categories[_catIdx].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Text(
                  '${_list.length}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_liveMode && _countries.length > 1) _countryBar(),
          Expanded(
            child: _list.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        _loading
                            ? 'Cargando canales...'
                            : (_categories[_catIdx].mode == 'fav'
                                  ? 'Sin favoritos todavía'
                                  : 'Sin contenido en esta sección'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _chScroll,
                    padding: const EdgeInsets.fromLTRB(8, 0, 12, 16),
                    itemExtent: _chItemH,
                    itemCount: _list.length,
                    itemBuilder: (ctx, i) {
                      final ch = _list[i];
                      final playing = _current?.url == ch.url;
                      final focused = _zone == 1 && i == _chIdx;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: GestureDetector(
                          onTap: () {
                            _focusChannel(i);
                            _play(ch);
                            _showOverlays();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: playing
                                  ? AppColors.accent.withValues(alpha: 0.18)
                                  : (focused
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.transparent),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: focused
                                    ? AppColors.accent
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                _channelLogo(ch),
                                const SizedBox(width: 12),
                                if (playing) ...[
                                  const Icon(
                                    Icons.play_arrow_rounded,
                                    color: AppColors.accent,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 2),
                                ] else if (_liveMode &&
                                    _country == 'all' &&
                                    ch.countryCode != null) ...[
                                  Text(
                                    ch.countryFlagEmoji,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        ch.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: playing
                                              ? AppColors.accentLight
                                              : AppColors.textPrimary,
                                          fontSize: 13,
                                          fontWeight: playing
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                      if (ch.epgLine != null) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          ch.epgLine!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 10.5,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _toggleFav(ch),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      ch.isFavorite
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      size: 16,
                                      color: ch.isFavorite
                                          ? AppColors.accent
                                          : Colors.white38,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _channelLogo(Channel ch) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: ch.logo != null && ch.logo!.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.all(4),
              child: CachedNetworkImage(
                imageUrl: ch.logo!,
                fit: BoxFit.contain,
                placeholder: (_, _) => _logoInitial(ch),
                errorWidget: (_, _, _) => _logoInitial(ch),
              ),
            )
          : _logoInitial(ch),
    );
  }

  Widget _logoInitial(Channel ch) => Center(
    child: Text(
      ch.displayName.isNotEmpty ? ch.displayName[0].toUpperCase() : '?',
      style: const TextStyle(
        color: AppColors.accentLight,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  // ---------- Estados globales ----------
  Widget _bootLoading() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: AppTheme.accentGradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.45),
                blurRadius: 36,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.play_circle_fill_rounded,
            color: Colors.white,
            size: 46,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Cargando canales...',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 20),
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: AppColors.accent,
          ),
        ),
      ],
    ),
  );

  Widget _errorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.error, size: 56),
          const SizedBox(height: 16),
          Text(
            _error ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _store.reload(),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );
}
