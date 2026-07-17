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

  Future<void> _clearHistory() async {
    setState(() => _history = const []);
    await StorageService.saveSetting('searchHistory', const <String>[]);
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
    if (DeviceProfile.isTv(context)) return _buildTv();
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
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search_rounded,
                            color: AppColors.textSecondary,
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
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                hintText: 'Buscar título o reparto...',
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
                              color: AppColors.textSecondary,
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

  Widget _buildTv() {
    final horizontal = (MediaQuery.sizeOf(context).width * 0.05).clamp(
      44.0,
      96.0,
    );
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(horizontal, 36, horizontal, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TvFocusable(
                    onTap: () => Navigator.maybePop(context),
                    borderRadius: BorderRadius.circular(24),
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  const Text(
                    'Buscar',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  if (_ctrl.text.isNotEmpty)
                    Text(
                      _ctrl.text,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 22,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 26),
              _tvKeyboard(),
              const SizedBox(height: 32),
              Expanded(child: _tvResults()),
            ],
          ),
        ),
      ),
    );
  }

  void _setTvQuery(String value) {
    _ctrl.text = value;
    _ctrl.selection = TextSelection.collapsed(offset: value.length);
    _search(value);
  }

  Widget _tvKeyboard() {
    const rows = ['ABCDEFGHIJKLM', 'NOPQRSTUVWXYZ', '0123456789'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in rows) ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final letter in row.split(''))
                _tvKey(letter, () => _setTvQuery('${_ctrl.text}$letter')),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 10,
          children: [
            _tvKey('Espacio', () => _setTvQuery('${_ctrl.text} '), wide: true),
            _tvKey(
              'Borrar',
              () {
                if (_ctrl.text.isNotEmpty) {
                  _setTvQuery(_ctrl.text.substring(0, _ctrl.text.length - 1));
                }
              },
              icon: Icons.backspace_outlined,
              wide: true,
            ),
            _tvKey(
              'Limpiar',
              () => _setTvQuery(''),
              icon: Icons.clear_rounded,
              wide: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _tvKey(
    String label,
    VoidCallback onTap, {
    IconData? icon,
    bool wide = false,
  }) => TvFocusable(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      width: wide ? 118 : 52,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: icon == null
          ? Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppColors.textPrimary, size: 20),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
    ),
  );

  Widget _tvResults() {
    if (_ctrl.text.trim().isEmpty) return _historyView();
    if (_results.isEmpty) {
      return _hint(
        'Sin resultados para "${_ctrl.text.trim()}"',
        Icons.search_off_rounded,
      );
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 190,
        childAspectRatio: 0.62,
        crossAxisSpacing: 18,
        mainAxisSpacing: 22,
      ),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final item = _results[index];
        return TvFocusable(
          onTap: () => _selectResult(item),
          borderRadius: BorderRadius.circular(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: double.infinity,
                    child: item.logo?.isNotEmpty == true
                        ? CachedNetworkImage(
                            imageUrl: item.logo!,
                            fit: BoxFit.cover,
                            memCacheWidth: 420,
                            errorWidget: (_, _, _) => _initial(item),
                          )
                        : _initial(item),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
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
                            memCacheWidth: 300,
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Búsquedas recientes',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18 * scale,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Borrar historial',
                    onPressed: _clearHistory,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.textMuted,
                      size: 21 * scale,
                    ),
                  ),
                ],
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
    if (index == 2) return const Color(0xFFFFD54F);
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
