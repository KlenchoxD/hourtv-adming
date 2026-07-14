import 'package:flutter/material.dart';

import '../models/channel.dart';
import '../models/epg_program.dart';
import '../services/content_store.dart';
import '../services/device_type.dart';
import '../services/epg_service.dart';
import '../services/xtream_service.dart';
import '../theme/app_theme.dart';
import '../widgets/tv_focusable.dart';
import 'player_screen.dart';

class EpgScreen extends StatefulWidget {
  final List<Channel> channels;

  const EpgScreen({super.key, required this.channels});

  @override
  State<EpgScreen> createState() => _EpgScreenState();
}

class _EpgScreenState extends State<EpgScreen> {
  static const _pixelsPerMinute = 3.0;
  static const _windowLength = Duration(hours: 6);

  final _horizontal = ScrollController();
  final _store = ContentStore.instance;
  late DateTime _windowStart;
  late List<Channel> _channels;

  @override
  void initState() {
    super.initState();
    _windowStart = _roundToHalfHour(
      DateTime.now().subtract(const Duration(minutes: 30)),
    );
    _channels = widget.channels
        .where((channel) => channel.type == MediaType.live)
        .toList();
    _store.addListener(_onStoreChanged);
  }

  DateTime _roundToHalfHour(DateTime value) => DateTime(
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute < 30 ? 0 : 30,
  );

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    _horizontal.dispose();
    super.dispose();
  }

  void _jumpToNow() {
    if (!_horizontal.hasClients) return;
    final minutes = DateTime.now().difference(_windowStart).inMinutes;
    final target = (minutes * _pixelsPerMinute - 160).clamp(
      0.0,
      _horizontal.position.maxScrollExtent,
    );
    _horizontal.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _play(
    Channel channel, {
    List<Channel>? allChannels,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          channel: channel,
          allChannels: allChannels ?? _channels,
        ),
      ),
    );
  }

  Future<void> _showProgram(Channel channel, EpgProgram program) async {
    final catchupUrl = XtreamService.buildTimeshiftUrl(channel, program);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(program.title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                channel.displayName,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(program.timeRange),
              if (program.description?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(program.description!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
          if (catchupUrl != null)
            OutlinedButton.icon(
              autofocus: true,
              onPressed: () {
                final catchupChannel = channel.copyWith(
                  name: '${channel.displayName} — ${program.title}',
                  url: catchupUrl,
                  hasCatchup: false,
                );
                Navigator.pop(dialogContext);
                _play(catchupChannel, allChannels: [catchupChannel]);
              },
              icon: const Icon(Icons.history_rounded),
              label: const Text('Ver desde el inicio'),
            ),
          FilledButton.icon(
            autofocus: catchupUrl == null,
            onPressed: () {
              Navigator.pop(dialogContext);
              _play(channel);
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Ver canal'),
          ),
        ],
      ),
    );
  }

  List<EpgProgram> _programsFor(Channel channel) {
    final end = _windowStart.add(_windowLength);
    return EpgService.programsFor(channel)
        .where(
          (program) =>
              program.stop.isAfter(_windowStart) && program.start.isBefore(end),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isTv = DeviceProfile.isTv(context);
    final channelWidth = isTv ? 230.0 : 170.0;
    final rowHeight = isTv ? 88.0 : 76.0;
    final timelineWidth = _windowLength.inMinutes * _pixelsPerMinute;

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Guía de programación'),
        actions: [
          if (_store.epgLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          TextButton.icon(
            onPressed: _jumpToNow,
            icon: const Icon(Icons.my_location_rounded),
            label: const Text('Ahora'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _channels.isEmpty
          ? const Center(
              child: Text(
                'No hay canales en vivo para mostrar.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : SingleChildScrollView(
              controller: _horizontal,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: channelWidth + timelineWidth,
                child: Column(
                  children: [
                    _timeHeader(channelWidth, timelineWidth),
                    Expanded(
                      child: ListView.builder(
                        itemExtent: rowHeight,
                        itemCount: _channels.length,
                        itemBuilder: (context, index) => _channelRow(
                          _channels[index],
                          index,
                          channelWidth,
                          timelineWidth,
                          rowHeight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _timeHeader(double channelWidth, double timelineWidth) {
    final slots = _windowLength.inMinutes ~/ 30;
    return Container(
      height: 54,
      color: AppColors.cardDark,
      child: Row(
        children: [
          SizedBox(
            width: channelWidth,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'CANALES',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: timelineWidth,
            child: Row(
              children: [
                for (var slot = 0; slot < slots; slot++)
                  Container(
                    width: 30 * _pixelsPerMinute,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 8),
                    decoration: const BoxDecoration(
                      border: Border(left: BorderSide(color: Colors.white12)),
                    ),
                    child: Text(
                      _formatTime(
                        _windowStart.add(Duration(minutes: slot * 30)),
                      ),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _channelRow(
    Channel channel,
    int rowIndex,
    double channelWidth,
    double timelineWidth,
    double rowHeight,
  ) {
    final programs = _programsFor(channel);
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: channelWidth,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: TvFocusable(
                onTap: () => _play(channel),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.centerLeft,
                  color: AppColors.surfaceDark,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.live_tv_rounded,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          channel.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: timelineWidth,
            height: rowHeight,
            child: Stack(
              children: [
                for (
                  var minute = 0;
                  minute < _windowLength.inMinutes;
                  minute += 30
                )
                  Positioned(
                    left: minute * _pixelsPerMinute,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 1, color: Colors.white10),
                  ),
                if (programs.isEmpty)
                  const Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Sin programación disponible',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    ),
                  ),
                for (final program in programs)
                  _programCard(channel, program, rowIndex, rowHeight),
                _nowMarker(rowHeight),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _programCard(
    Channel channel,
    EpgProgram program,
    int rowIndex,
    double rowHeight,
  ) {
    final visibleStart = program.start.isBefore(_windowStart)
        ? _windowStart
        : program.start;
    final windowEnd = _windowStart.add(_windowLength);
    final visibleStop = program.stop.isAfter(windowEnd)
        ? windowEnd
        : program.stop;
    final left =
        visibleStart.difference(_windowStart).inSeconds / 60 * _pixelsPerMinute;
    final width =
        (visibleStop.difference(visibleStart).inSeconds / 60 * _pixelsPerMinute)
            .clamp(56.0, 720.0);
    final isCurrent = program.isOnAt(DateTime.now());

    return Positioned(
      left: left,
      top: 5,
      width: width,
      height: rowHeight - 10,
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: TvFocusable(
          autofocus: rowIndex == 0 && isCurrent,
          onTap: () => _showProgram(channel, program),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isCurrent
                  ? AppColors.accent.withValues(alpha: 0.28)
                  : AppColors.cardDark,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  program.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  program.timeRange,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _nowMarker(double rowHeight) {
    final minutes = DateTime.now().difference(_windowStart).inSeconds / 60;
    if (minutes < 0 || minutes > _windowLength.inMinutes) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: minutes * _pixelsPerMinute,
      top: 0,
      bottom: 0,
      child: Container(width: 2, color: AppColors.live),
    );
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
