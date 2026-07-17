import os

base = r"C:\Users\Kleiner\proyectos\mi_app\lib"

player = """import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class PlayerScreen extends StatefulWidget {
  final Channel channel;
  final List<Channel> allChannels;
  const PlayerScreen({super.key, required this.channel, required this.allChannels});
  @override State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _vc;
  ChewieController? _cc;
  bool _loading = true;
  String? _err;
  bool _showList = false;
  int _idx = 0;

  @override void initState() {
    super.initState();
    _idx = widget.allChannels.indexWhere((c) => c.url == widget.channel.url);
    if (_idx < 0) _idx = 0;
    _init(widget.allChannels[_idx]);
  }

  Future<void> _init(Channel ch) async {
    setState(() { _loading = true; _err = null; });
    _cc?.dispose();
    _vc?.dispose();
    _cc = null; _vc = null;
    try {
      _vc = VideoPlayerController.networkUrl(Uri.parse(ch.url));
      await _vc!.initialize();
      _cc = ChewieController(
        videoPlayerController: _vc!,
        autoPlay: true, looping: false,
        aspectRatio: _vc!.value.aspectRatio,
        allowFullScreen: true, allowMuting: true, showControls: true,
        placeholder: Container(color: Colors.black, child: Center(child: _lg(ch))),
        errorBuilder: (_, m) => Center(child: Text(m, style: const TextStyle(color: Colors.white))),
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.accent, handleColor: AppColors.accent,
          backgroundColor: AppColors.cardDark, bufferedColor: AppColors.textMuted,
        ),
      );
      setState(() => _loading = false);
    } catch (e) { setState(() { _err = e.toString(); _loading = false; }); }
  }

  Widget _lg(Channel ch) => ch.logo != null
      ? CachedNetworkImage(imageUrl: ch.logo!, width: 80, height: 80, fit: BoxFit.contain, errorWidget: (a, b, c) => _in(ch))
      : _in(ch);
  Widget _in(Channel ch) => Text(ch.displayName.isNotEmpty ? ch.displayName[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.accent, fontSize: 40, fontWeight: FontWeight.bold));

  void _chg(int d) {
    final ni = _idx + d;
    if (ni >= 0 && ni < widget.allChannels.length) {
      setState(() => _idx = ni);
      _init(widget.allChannels[ni]);
      StorageService.saveRecent(widget.allChannels[ni]);
    }
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(child: Stack(children: [
      Center(child: _loading ? _lw() : _err != null ? _ew() : _cc != null ? Chewie(controller: _cc!) : const SizedBox()),
      Positioned(top: 0, left: 0, right: 0, child: _tb()),
      if (_showList) _ov(),
      if (!_showList) ...[
        Positioned(left: 8, top: 0, bottom: 0, child: Center(child: _nb(Icons.chevron_left, () => _chg(-1)))),
        Positioned(right: 8, top: 0, bottom: 0, child: Center(child: _nb(Icons.chevron_right, () => _chg(1)))),
      ],
    ])),
  );

  Widget _lw() => Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(color: AppColors.accent), const SizedBox(height: 16), const Text('Cargando...', style: TextStyle(color: Colors.white70))]);
  Widget _ew() => Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error, color: AppColors.error, size: 48), const SizedBox(height: 16), Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: Text(_err ?? '', style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center)), const SizedBox(height: 24), ElevatedButton.icon(onPressed: () => _init(widget.allChannels[_idx]), icon: const Icon(Icons.refresh), label: const Text('Reintentar'))]);
  Widget _nb(IconData ic, VoidCallback on) => GestureDetector(onTap: on, child: Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(22)), child: Icon(ic, color: Colors.white, size: 28)));
"""

with open(os.path.join(base, 'screens', 'player_screen.dart'), 'w', encoding='utf-8') as f:
    f.write(player)
print("player part1 written")
