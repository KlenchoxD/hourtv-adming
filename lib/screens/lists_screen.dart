import 'package:flutter/material.dart';
import '../models/m3u_list.dart';
import '../services/storage_service.dart';
import '../services/xtream_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/tv_focusable.dart';

class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key});
  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  List<M3UList> _lists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() {
    _lists = StorageService.loadLists();
    _loading = false;
  });

  Future<void> _save() async {
    await StorageService.saveLists(_lists);
    if (mounted) setState(() {});
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------- Agregar lista M3U ----------------
  Future<void> _addM3u() async {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar lista M3U'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre', hintText: 'ej: Mi lista')),
          const SizedBox(height: 12),
          TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'URL M3U', hintText: 'http://...')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (urlCtrl.text.trim().isEmpty) return;
              _lists.add(M3UList(
                name: nameCtrl.text.trim().isEmpty ? 'Lista ${_lists.length + 1}' : nameCtrl.text.trim(),
                url: urlCtrl.text.trim(),
              ));
              Navigator.pop(ctx, true);
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    urlCtrl.dispose();
    if (added == true) {
      await _save();
      _toast('Lista agregada. Vuelve a Canales para cargarla.');
    }
  }

  // ---------------- Agregar cuenta Xtream ----------------
  Future<void> _addXtream() async {
    final nameCtrl = TextEditingController();
    final hostCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool checking = false;
    String? status;
    bool ok = false;

    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        Future<void> validate() async {
          if (hostCtrl.text.trim().isEmpty || userCtrl.text.trim().isEmpty || passCtrl.text.trim().isEmpty) {
            setLocal(() => status = 'Completa servidor, usuario y contraseña');
            return;
          }
          setLocal(() { checking = true; status = 'Conectando...'; ok = false; });
          final acc = await XtreamService.validate(hostCtrl.text, userCtrl.text, passCtrl.text);
          setLocal(() {
            checking = false;
            ok = acc.authenticated;
            status = acc.authenticated
                ? '✓ ${acc.message}  ·  Vence: ${acc.expDate ?? "-"}'
                : '✗ ${acc.message}';
          });
        }

        return AlertDialog(
          title: const Text('Cuenta Xtream'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre (opcional)', hintText: 'ej: Mi proveedor')),
              const SizedBox(height: 10),
              TextField(controller: hostCtrl, decoration: const InputDecoration(labelText: 'Servidor (con puerto)', hintText: 'http://servidor.com:8080')),
              const SizedBox(height: 4),
              const Align(alignment: Alignment.centerLeft, child: Text('Incluye el puerto si tu proveedor lo usa (ej: :8080, :25461)', style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
              const SizedBox(height: 10),
              TextField(controller: userCtrl, decoration: const InputDecoration(labelText: 'Usuario')),
              const SizedBox(height: 10),
              TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña')),
              const SizedBox(height: 14),
              if (status != null)
                Text(status!, style: TextStyle(color: ok ? AppColors.success : (checking ? AppColors.textSecondary : AppColors.error), fontSize: 12.5)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            OutlinedButton(onPressed: checking ? null : validate, child: const Text('Probar')),
            ElevatedButton(
              onPressed: checking ? null : () {
                if (hostCtrl.text.trim().isEmpty || userCtrl.text.trim().isEmpty || passCtrl.text.trim().isEmpty) {
                  setLocal(() => status = 'Completa todos los campos');
                  return;
                }
                final url = XtreamService.buildM3uUrl(hostCtrl.text, userCtrl.text, passCtrl.text);
                _lists.add(M3UList(
                  name: nameCtrl.text.trim().isEmpty ? 'Xtream ${_lists.length + 1}' : nameCtrl.text.trim(),
                  url: url,
                  description: 'Cuenta Xtream · ${XtreamService.normalizeHost(hostCtrl.text)}',
                  category: 'xtream',
                  host: XtreamService.normalizeHost(hostCtrl.text),
                  username: userCtrl.text.trim(),
                  password: passCtrl.text.trim(),
                ));
                Navigator.pop(ctx, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      }),
    );

    nameCtrl.dispose();
    hostCtrl.dispose();
    userCtrl.dispose();
    passCtrl.dispose();
    if (added == true) {
      await _save();
      _toast('Cuenta agregada. Vuelve a Canales para cargar el contenido.');
    }
  }

  Future<void> _delList(int i) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar'),
        content: Text('¿Eliminar "${_lists[i].name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm == true) {
      _lists.removeAt(i);
      await _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userCount = _lists.where((l) => !l.isDefault).length;
    return SafeArea(
      child: Column(children: [
        _topBar(),
        // Tarjetas para agregar fuente
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Row(children: [
            Expanded(child: _addCard(Icons.dns_rounded, 'Cuenta Xtream', 'Servidor · usuario · clave', _addXtream, primary: true)),
            const SizedBox(width: 12),
            Expanded(child: _addCard(Icons.link_rounded, 'Lista M3U', 'Pega una URL .m3u', _addM3u, primary: false)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
          child: Row(children: [
            const Text('FUENTES', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            const SizedBox(width: 8),
            Text('${_lists.length}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const Spacer(),
            if (userCount > 0)
              Text('$userCount propias', style: const TextStyle(color: AppColors.accentLight, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
        Expanded(
          child: _loading
              ? const LoadingIndicator()
              : _lists.isEmpty
                  ? const EmptyState(icon: Icons.playlist_add, title: 'Sin fuentes', subtitle: 'Agrega tu cuenta Xtream o una lista M3U')
                  : ListView.builder(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), itemCount: _lists.length, itemBuilder: (ctx, i) => _listTile(_lists[i], i)),
        ),
      ]),
    );
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 20, 14),
    child: Row(children: [
      IconButton(icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary), onPressed: () => Navigator.maybePop(context)),
      const SizedBox(width: 2),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: const [
        Text('Mis Fuentes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.3)),
        SizedBox(height: 2),
        Text('Conecta tu proveedor IPTV o listas M3U', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
      ]),
    ]),
  );

  Widget _addCard(IconData icon, String title, String subtitle, VoidCallback onTap, {required bool primary}) => TvFocusable(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: primary ? null : AppColors.cardDark,
        gradient: primary ? AppTheme.accentGradient : null,
        borderRadius: BorderRadius.circular(16),
        border: primary ? null : Border.all(color: AppColors.accent.withValues(alpha: 0.30), width: 1.3),
        boxShadow: primary ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.28), blurRadius: 16, offset: const Offset(0, 6))] : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: primary ? Colors.white : AppColors.accent, size: 22),
          const Spacer(),
          Icon(Icons.add_rounded, color: primary ? Colors.white70 : AppColors.accent, size: 20),
        ]),
        const SizedBox(height: 12),
        Text(title, style: TextStyle(color: primary ? Colors.white : AppColors.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(subtitle, style: TextStyle(color: primary ? Colors.white70 : AppColors.textMuted, fontSize: 11.5)),
      ]),
    ),
  );

  Widget _listTile(M3UList list, int i) {
    final isXtream = list.category == 'xtream';
    final badge = isXtream ? 'XTREAM' : (list.isDefault ? 'INCLUIDA' : 'M3U');
    final badgeColor = isXtream ? AppColors.success : (list.isDefault ? AppColors.textMuted : AppColors.accent);
    return TvFocusable(
      onTap: () {},
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(isXtream ? Icons.dns_rounded : (list.isDefault ? Icons.public_rounded : Icons.playlist_play_rounded), color: badgeColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(list.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w700))),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(6)),
                  child: Text(badge, style: TextStyle(color: badgeColor, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                ),
              ]),
              const SizedBox(height: 3),
              Text(list.description ?? list.url, style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          if (!list.isDefault)
            IconButton(icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textMuted, size: 20), onPressed: () => _delList(i))
          else
            const SizedBox(width: 8),
        ]),
      ),
    );
  }
}
