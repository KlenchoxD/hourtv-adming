import 'package:flutter/material.dart';
import '../services/anime_schedule_service.dart';
import '../services/content_store.dart';
import '../services/parental_control_service.dart';
import '../services/xtream_service.dart';
import 'hourtv_mobile_components.dart';
import 'hourtv_mobile_theme.dart';

class HourTvAnimeCalendarPage extends StatefulWidget {
  const HourTvAnimeCalendarPage({
    super.key,
    required this.store,
    required this.onOpenAnime,
    this.service,
    this.now,
  });
  final ContentStore store;
  final ValueChanged<XtreamSeries> onOpenAnime;
  final AnimeScheduleService? service;
  final DateTime Function()? now;
  @override
  State<HourTvAnimeCalendarPage> createState() =>
      _HourTvAnimeCalendarPageState();
}

class _HourTvAnimeCalendarPageState extends State<HourTvAnimeCalendarPage> {
  static const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  late DateTime _selected;
  late Future<AnimeScheduleResult> _future;
  bool _recent = false;
  bool _catalogOnly = false;
  DateTime get now => (widget.now?.call() ?? DateTime.now()).toLocal();
  AnimeScheduleService get service =>
      widget.service ?? AnimeScheduleService.instance;
  DateTime get week => AnimeScheduleService.weekStart(_selected);
  @override
  void initState() {
    super.initState();
    _selected = now;
    _future = service.loadWeek(_selected);
  }

  void _move(int count) {
    setState(() {
      _selected = DateTime(
        _selected.year,
        _selected.month,
        _selected.day + 7 * count,
      );
      _future = service.loadWeek(_selected);
    });
  }

  Future<void> _refresh() async {
    final request = service.loadWeek(_selected, refresh: true);
    setState(() => _future = request);
    try {
      await request;
    } catch (_) {
      /* The body renders the retry state. */
    }
  }

  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  String dateLabel(DateTime value) =>
      '${value.day} de ${months[value.month - 1]}';
  String timeLabel(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: HourTvMobileTokens.deepBlack,
    appBar: AppBar(
      title: const Text('Calendario de anime'),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (MediaQuery.sizeOf(context).height >= 500) ...[
                  const Text(
                    'Tus estrenos, día a día',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Horarios de emisión en tu zona local. La disponibilidad en HourTV puede variar.',
                    style: TextStyle(
                      color: HourTvMobileTokens.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ChoiceChip(
                      label: const Text('Esta semana'),
                      selected: !_recent,
                      onSelected: (_) => setState(() => _recent = false),
                    ),
                    ChoiceChip(
                      label: const Text('Últimos estrenos'),
                      selected: _recent,
                      onSelected: (_) => setState(() => _recent = true),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Semana anterior',
                      onPressed: () => _move(-1),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Text(
                        '${dateLabel(week)} – ${dateLabel(DateTime(week.year, week.month, week.day + 6))}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Semana siguiente',
                      onPressed: () => _move(1),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selected = now;
                          _future = service.loadWeek(_selected);
                        });
                      },
                      child: const Text('Hoy'),
                    ),
                  ],
                ),
                if (!_recent)
                  SizedBox(
                    height: 62,
                    child: Row(
                      children: [
                        for (var index = 0; index < 7; index++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: _day(index),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                FilterChip(
                  label: const Text('En HourTV'),
                  selected: _catalogOnly,
                  onSelected: (value) => setState(() => _catalogOnly = value),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: widget.store,
              builder: (context, _) => FutureBuilder<AnimeScheduleResult>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || snapshot.data == null) {
                    return _message(
                      Icons.cloud_off_rounded,
                      'No se pudo actualizar el calendario',
                      'Inténtalo nuevamente en unos momentos.',
                      retry: true,
                    );
                  }
                  final result = snapshot.data!;
                  final index = AnimeCatalogIndex(widget.store.visibleSeries);
                  final entries = result.entries.where((entry) {
                    final match = index.match(entry.media);
                    if ((ParentalControlService.kidsOnly ||
                            ParentalControlService.isEnabled ||
                            _catalogOnly) &&
                        match == null) {
                      return false;
                    }
                    final date = entry.airingAt.toLocal();
                    return _recent
                        ? !entry.airingAt.isAfter(now)
                        : sameDay(date, _selected);
                  }).toList();
                  if (_recent) {
                    entries.sort((a, b) => b.airingAt.compareTo(a.airingAt));
                  }
                  return Column(
                    children: [
                      if (result.stale)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Text(
                            'Mostrando el último calendario guardado. No se pudo actualizar.',
                            style: TextStyle(
                              color: HourTvMobileTokens.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      Expanded(
                        child: entries.isEmpty
                            ? _message(
                                Icons.event_available_rounded,
                                _catalogOnly
                                    ? 'No hay emisiones de tu catálogo'
                                    : 'No hay emisiones para este día',
                                _catalogOnly
                                    ? 'Desactiva «En HourTV» para ver otros estrenos.'
                                    : 'Prueba otro día o consulta los últimos estrenos.',
                              )
                            : RefreshIndicator(
                                onRefresh: _refresh,
                                child: ListView.separated(
                                  key: ValueKey(
                                    '$_recent|$_selected|$_catalogOnly',
                                  ),
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    24,
                                  ),
                                  itemCount: entries.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (_, i) => _card(
                                    entries[i],
                                    index.match(entries[i].media),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Calendario y metadatos: AniList',
              style: TextStyle(
                fontSize: 11,
                color: HourTvMobileTokens.textMuted,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _day(int index) {
    final date = DateTime(week.year, week.month, week.day + index);
    final selected = sameDay(date, _selected);
    return Material(
      color: selected
          ? HourTvMobileTokens.emerald
          : HourTvMobileTokens.surfaceControl,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selected = date),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                days[index],
                style: TextStyle(
                  fontSize: 11,
                  color: selected
                      ? Colors.black
                      : HourTvMobileTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.black : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _message(
    IconData icon,
    String title,
    String subtitle, {
    bool retry = false,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: HourTvMobileTokens.emerald),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: HourTvMobileTokens.textSecondary),
            ),
            if (retry)
              TextButton(onPressed: _refresh, child: const Text('Reintentar')),
          ],
        ),
      ),
    ),
  );

  Widget _card(AnimeAiringEntry entry, XtreamSeries? series) {
    final date = entry.airingAt.toLocal();
    final upcoming = entry.airingAt.isAfter(now);
    return Material(
      color: HourTvMobileTokens.surfacePrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: HourTvMobileTokens.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: series == null ? null : () => widget.onOpenAnime(series),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 72,
                height: 104,
                child: HourTvArtwork(
                  url: series?.cover ?? entry.media.poster,
                  borderRadius: BorderRadius.circular(8),
                  memCacheWidth: 216,
                  memCacheHeight: 312,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_recent ? '${dateLabel(date)} · ' : ''}${timeLabel(date)}',
                      style: const TextStyle(
                        color: HourTvMobileTokens.emerald,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      series?.name ?? entry.media.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Episodio ${entry.episode} · ${upcoming ? 'Próximamente' : 'Emitido'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: HourTvMobileTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      series == null
                          ? 'Aún no está en HourTV'
                          : 'Ver episodios en HourTV',
                      style: TextStyle(
                        fontSize: 12,
                        color: series == null
                            ? HourTvMobileTokens.textMuted
                            : HourTvMobileTokens.emerald,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
