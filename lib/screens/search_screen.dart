import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../theme/app_theme.dart';
import '../services/device_type.dart';
import '../services/storage_service.dart';
import '../widgets/tv_focusable.dart';

/// Buscador a pantalla completa. Recibe todo el contenido y devuelve
/// (Navigator.pop) el Channel elegido para reproducirlo.
class SearchScreen extends StatefulWidget {
  final List<Channel> all;
  const SearchScreen({super.key, required this.all});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  List<Channel> _results = const [];
  late final List<Channel> _popular;

  List<String> _history = const [];
  @override
  void initState() {
    super.initState();
    _popular = _buildPopular();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !DeviceProfile.isTv(context)) {
        _focus.requestFocus();
      }
    });
    final saved = StorageService.getSetting(
      'searchHistory',
      defaultValue: const [],
    );
    if (saved is List) {
      _history = saved.map((item) => item.toString()).take(8).toList();
    }
  }

  List<Channel> _buildPopular() {
    final unique = <String, Channel>{};
    for (final channel in widget.all) {
      final title = channel.displayName.trim();
      if (title.isEmpty) continue;
      unique.putIfAbsent(title.toLowerCase(), () => channel);
    }
    final items = unique.values.toList()..shuffle(Random());
    return items.take(10).toList();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _search(String q) {
    final query = q.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() => _results = const []);
      return;
    }
    final out = widget.all
        .where((c) => c.displayName.toLowerCase().contains(query))
        .take(120)
        .toList();
    setState(() => _results = out);
  }

  Future<void> _rememberQuery(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    final updated = [
      query,
      ..._history.where((item) => item.toLowerCase() != query.toLowerCase()),
    ].take(8).toList();
    setState(() => _history = updated);
    await StorageService.saveSetting('searchHistory', updated);
  }

  void _showSystemVoiceInput() {
    _focus.requestFocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Usa el micrófono del teclado del sistema o el botón de voz del control.',
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _selectResult(Channel channel) async {
    await _rememberQuery(_ctrl.text);
    if (mounted) Navigator.pop(context, channel);
  }

  void _useHistory(String query) {
    _ctrl.text = query;
    _ctrl.selection = TextSelection.collapsed(offset: query.length);
    _search(query);
    _focus.requestFocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.show');
  }

  String _typeLabel(Channel c) {
    switch (c.type) {
      case MediaType.movie:
        return 'Película';
      case MediaType.series:
        return 'Serie';
      case MediaType.live:
        return c.countryName ?? 'En vivo';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Column(
          children: [
            // Barra de búsqueda
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 16, 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.35),
                          width: 1.4,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search_rounded,
                            color: AppColors.accent,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _ctrl,
                              focusNode: _focus,
                              onChanged: _search,
                              onSubmitted: _rememberQuery,
                              textInputAction: TextInputAction.search,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                              ),
                              cursorColor: AppColors.accent,
                              decoration: const InputDecoration(
                                isCollapsed: true,
                                border: InputBorder.none,
                                hintText:
                                    'Buscar canales, películas o series...',
                                hintStyle: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Entrada de voz del sistema',
                            onPressed: _showSystemVoiceInput,
                            icon: const Icon(
                              Icons.mic_rounded,
                              color: AppColors.accent,
                            ),
                          ),

                          if (_ctrl.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _ctrl.clear();
                                _search('');
                                _focus.requestFocus();
                              },
                              child: const Icon(
                                Icons.close_rounded,
                                color: AppColors.textMuted,
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_ctrl.text.trim().isEmpty) {
      return _historyView();
    }
    if (_results.isEmpty) {
      return _hint(
        'Sin resultados para "${_ctrl.text.trim()}"',
        Icons.sentiment_dissatisfied_rounded,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final c = _results[i];
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _selectResult(c),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 52,
                    height: 52,
                    color: AppColors.surfaceDark,
                    child: c.logo != null && c.logo!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: c.logo!,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => _initial(c),
                          )
                        : _initial(c),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _typeLabel(c),
                              style: const TextStyle(
                                color: AppColors.accentLight,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.play_circle_fill_rounded,
                  color: AppColors.accent,
                  size: 28,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _historyView() {
    if (_history.isEmpty && _popular.isEmpty) {
      return _hint(
        'Escribe o usa la voz del sistema para buscar en todo tu contenido',
        Icons.search_rounded,
      );
    }

    final isTv = DeviceProfile.isTv(context);
    final scale = DeviceProfile.uiScale(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isTv ? 900 : 620),
        child: ListView(
          padding: EdgeInsets.fromLTRB(24, 16 * scale, 24, 32),
          children: [
            if (_history.isNotEmpty) ...[
              Text(
                'Búsquedas recientes',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18 * scale,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 14 * scale),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var index = 0; index < _history.length; index++)
                    TvFocusable(
                      autofocus: isTv && index == 0,
                      onTap: () => _useHistory(_history[index]),
                      borderRadius: BorderRadius.circular(18),
                      child: Chip(
                        avatar: const Icon(Icons.history_rounded, size: 18),
                        label: Text(_history[index]),
                        backgroundColor: AppColors.cardDark,
                        labelStyle: const TextStyle(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 28 * scale),
            ],
            Text(
              'Búsquedas populares',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20 * scale,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 12 * scale),
            for (var index = 0; index < _popular.length; index++)
              Padding(
                padding: EdgeInsets.only(bottom: 8 * scale),
                child: TvFocusable(
                  autofocus: isTv && _history.isEmpty && index == 0,
                  onTap: () => _useHistory(_popular[index].displayName),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14 * scale,
                      vertical: 10 * scale,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.cardElevated),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 42 * scale,
                          child: Text(
                            (index + 1).toString(),
                            style: TextStyle(
                              color: _rankColor(index),
                              fontSize: 27 * scale,
                              height: 1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        SizedBox(width: 8 * scale),
                        Expanded(
                          child: Text(
                            _popular[index].displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15 * scale,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.north_west_rounded,
                          color: AppColors.textMuted,
                          size: 19 * scale,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _rankColor(int index) {
    if (index == 0) return AppColors.accent;
    if (index == 1) return AppColors.warning;
    if (index == 2) return AppColors.success;
    return AppColors.textMuted;
  }

  Widget _initial(Channel c) => Center(
    child: Text(
      c.displayName.isNotEmpty ? c.displayName[0].toUpperCase() : '?',
      style: const TextStyle(
        color: AppColors.accentLight,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  Widget _hint(String text, IconData icon) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.textMuted, size: 54),
        const SizedBox(height: 14),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      ],
    ),
  );
}
