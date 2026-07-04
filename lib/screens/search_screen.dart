import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
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
    final out = widget.all.where((c) => c.displayName.toLowerCase().contains(query)).take(120).toList();
    setState(() => _results = out);
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
        child: Column(children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 16, 10),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.35), width: 1.4),
                  ),
                  child: Row(children: [
                    const Icon(Icons.search_rounded, color: AppColors.accent, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        focusNode: _focus,
                        onChanged: _search,
                        textInputAction: TextInputAction.search,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                        cursorColor: AppColors.accent,
                        decoration: const InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: 'Buscar canales, películas o series...',
                          hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 15),
                        ),
                      ),
                    ),
                    if (_ctrl.text.isNotEmpty)
                      GestureDetector(
                        onTap: () { _ctrl.clear(); _search(''); _focus.requestFocus(); },
                        child: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
                      ),
                  ]),
                ),
              ),
            ]),
          ),
          Expanded(child: _body()),
        ]),
      ),
    );
  }

  Widget _body() {
    if (_ctrl.text.trim().isEmpty) {
      return _hint('Escribe para buscar en todo tu contenido', Icons.search_rounded);
    }
    if (_results.isEmpty) {
      return _hint('Sin resultados para "${_ctrl.text.trim()}"', Icons.sentiment_dissatisfied_rounded);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final c = _results[i];
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.pop(context, c),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 52, height: 52,
                  color: AppColors.surfaceDark,
                  child: c.logo != null && c.logo!.isNotEmpty
                      ? CachedNetworkImage(imageUrl: c.logo!, fit: BoxFit.cover, errorWidget: (_, _, _) => _initial(c))
                      : _initial(c),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(6)),
                      child: Text(_typeLabel(c), style: const TextStyle(color: AppColors.accentLight, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ]),
              ),
              const Icon(Icons.play_circle_fill_rounded, color: AppColors.accent, size: 28),
            ]),
          ),
        );
      },
    );
  }

  Widget _initial(Channel c) => Center(
        child: Text(c.displayName.isNotEmpty ? c.displayName[0].toUpperCase() : '?',
            style: const TextStyle(color: AppColors.accentLight, fontSize: 20, fontWeight: FontWeight.w800)),
      );

  Widget _hint(String text, IconData icon) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: AppColors.textMuted, size: 54),
          const SizedBox(height: 14),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        ]),
      );
}
