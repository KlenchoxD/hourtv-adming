import 'package:flutter/material.dart';

import '../models/m3u_list.dart';
import '../services/content_store.dart';
import '../services/m3u_parser_service.dart';
import '../services/stalker_service.dart';
import '../services/storage_service.dart';
import '../services/xtream_service.dart';

const _red = Color(0xFFF20A1A);
const _black = Color(0xFF050505);
const _surface = Color(0xFF101012);
const _line = Color(0xFF25252A);
const _muted = Color(0xFFA6A6B0);

class HourTvSourcesPage extends StatefulWidget {
  const HourTvSourcesPage({super.key});

  @override
  State<HourTvSourcesPage> createState() => _HourTvSourcesPageState();
}

class _HourTvSourcesPageState extends State<HourTvSourcesPage> {
  List<M3UList> sources = [];
  bool syncing = false;

  @override
  void initState() {
    super.initState();
    sources = StorageService.loadLists();
  }

  Future<void> _save(M3UList? source) async {
    if (source == null) return;
    setState(() {
      sources = [...sources, source];
      syncing = true;
    });
    await StorageService.saveLists(sources);
    await ContentStore.instance.reload();
    if (!mounted) return;
    setState(() => syncing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${source.name} agregada y catálogo actualizado.'),
      ),
    );
  }

  Future<void> _delete(int index) async {
    final source = sources[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('Eliminar fuente'),
        content: Text('¿Eliminar “${source.name}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() {
      sources = [...sources]..removeAt(index);
      syncing = true;
    });
    await StorageService.saveLists(sources);
    await ContentStore.instance.reload();
    if (mounted) setState(() => syncing = false);
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 720;
    return Scaffold(
      backgroundColor: _black,
      appBar: AppBar(
        backgroundColor: _black,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Fuentes IPTV',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        bottom: syncing
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: _red,
                  backgroundColor: Colors.transparent,
                ),
              )
            : null,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          narrow ? 14 : 28,
          16,
          narrow ? 14 : 28,
          40,
        ),
        children: [
          const Text(
            'Conecta tu contenido',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'HourTV conserva tus proveedores y actualiza automáticamente el catálogo.',
            style: TextStyle(color: _muted, height: 1.4),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: narrow ? 1 : 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: narrow ? 3.25 : 1.55,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _SourceAction(
                icon: Icons.link_rounded,
                title: 'Lista M3U',
                subtitle: 'URL http o https',
                onTap: () async => _save(await _m3uDialog()),
              ),
              _SourceAction(
                icon: Icons.dns_rounded,
                title: 'Cuenta Xtream',
                subtitle: 'Servidor, usuario y contraseña',
                onTap: () async => _save(await _xtreamDialog()),
              ),
              _SourceAction(
                icon: Icons.router_rounded,
                title: 'Stalker / Ministra',
                subtitle: 'Portal y dirección MAC',
                onTap: () async => _save(await _stalkerDialog()),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Fuentes guardadas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text('${sources.length}', style: const TextStyle(color: _muted)),
            ],
          ),
          const SizedBox(height: 12),
          if (sources.isEmpty)
            const _EmptySources()
          else
            for (var index = 0; index < sources.length; index++) ...[
              _SavedSource(
                source: sources[index],
                onDelete: sources[index].isDefault
                    ? null
                    : () => _delete(index),
              ),
              const SizedBox(height: 9),
            ],
        ],
      ),
    );
  }

  Future<M3UList?> _m3uDialog() async {
    final name = TextEditingController();
    final url = TextEditingController();
    var loading = false;
    String? status;
    M3UList? result;
    result = await showDialog<M3UList>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          backgroundColor: _surface,
          title: const Text('Nueva lista M3U'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(name, 'Nombre', 'Mi lista'),
                const SizedBox(height: 12),
                _field(url, 'URL M3U', 'https://servidor/lista.m3u', url: true),
                if (status != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    status!,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _red),
              onPressed: loading
                  ? null
                  : () async {
                      final target = url.text.trim();
                      final uri = Uri.tryParse(target);
                      if (uri == null ||
                          !uri.hasAuthority ||
                          !{'http', 'https'}.contains(uri.scheme)) {
                        setLocal(
                          () => status = 'Escribe una URL http o https válida.',
                        );
                        return;
                      }
                      setLocal(() {
                        loading = true;
                        status = 'Comprobando la lista…';
                      });
                      try {
                        final channels = await M3UParserService.fetchAndParse(
                          target,
                          listName: name.text.trim(),
                        );
                        if (!dialogContext.mounted) return;
                        if (channels.isEmpty) {
                          setLocal(() {
                            loading = false;
                            status =
                                'La lista no contiene elementos reproducibles.';
                          });
                          return;
                        }
                        Navigator.pop(
                          dialogContext,
                          M3UList(
                            name: name.text.trim().isEmpty
                                ? 'Lista ${sources.length + 1}'
                                : name.text.trim(),
                            url: target,
                          ),
                        );
                      } catch (error) {
                        if (dialogContext.mounted) {
                          setLocal(() {
                            loading = false;
                            status = 'No se pudo validar la lista.';
                          });
                        }
                      }
                    },
              child: Text(loading ? 'Probando…' : 'Probar y guardar'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    url.dispose();
    return result;
  }

  Future<M3UList?> _xtreamDialog() async {
    final name = TextEditingController();
    final host = TextEditingController();
    final user = TextEditingController();
    final password = TextEditingController();
    var loading = false;
    String? status;
    final result = await showDialog<M3UList>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          backgroundColor: _surface,
          title: const Text('Nueva cuenta Xtream'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(name, 'Nombre', 'Mi proveedor'),
                const SizedBox(height: 12),
                _field(host, 'Servidor', 'http://servidor:8080', url: true),
                const SizedBox(height: 12),
                _field(user, 'Usuario', ''),
                const SizedBox(height: 12),
                _field(password, 'Contraseña', '', secret: true),
                if (status != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    status!,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _red),
              onPressed: loading
                  ? null
                  : () async {
                      if (host.text.trim().isEmpty ||
                          user.text.trim().isEmpty ||
                          password.text.isEmpty) {
                        setLocal(
                          () => status =
                              'Completa servidor, usuario y contraseña.',
                        );
                        return;
                      }
                      setLocal(() {
                        loading = true;
                        status = 'Conectando…';
                      });
                      final account = await XtreamService.validate(
                        host.text,
                        user.text,
                        password.text,
                      );
                      if (!dialogContext.mounted) return;
                      if (!account.authenticated) {
                        setLocal(() {
                          loading = false;
                          status = account.message;
                        });
                        return;
                      }
                      final normalized = XtreamService.normalizeHost(host.text);
                      Navigator.pop(
                        dialogContext,
                        M3UList(
                          name: name.text.trim().isEmpty
                              ? 'Xtream ${sources.length + 1}'
                              : name.text.trim(),
                          url: XtreamService.buildM3uUrl(
                            host.text,
                            user.text,
                            password.text,
                          ),
                          description: 'Cuenta Xtream · $normalized',
                          category: 'xtream',
                          host: normalized,
                          username: user.text.trim(),
                          password: password.text,
                        ),
                      );
                    },
              child: Text(loading ? 'Probando…' : 'Probar y guardar'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    host.dispose();
    user.dispose();
    password.dispose();
    return result;
  }

  Future<M3UList?> _stalkerDialog() async {
    final name = TextEditingController();
    final host = TextEditingController();
    final mac = TextEditingController(text: '00:1A:79:');
    var loading = false;
    String? status;
    final result = await showDialog<M3UList>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          backgroundColor: _surface,
          title: const Text('Nuevo portal Stalker'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(name, 'Nombre', 'Portal de casa'),
                const SizedBox(height: 12),
                _field(
                  host,
                  'URL del portal',
                  'http://servidor/stalker_portal/c',
                  url: true,
                ),
                const SizedBox(height: 12),
                _field(mac, 'Dirección MAC', '00:1A:79:XX:XX:XX'),
                if (status != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    status!,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _red),
              onPressed: loading
                  ? null
                  : () async {
                      if (host.text.trim().isEmpty ||
                          !StalkerService.isValidMac(mac.text)) {
                        setLocal(
                          () => status = 'Completa una URL y una MAC válidas.',
                        );
                        return;
                      }
                      setLocal(() {
                        loading = true;
                        status = 'Conectando…';
                      });
                      final account = await StalkerService.validate(
                        host.text,
                        mac.text,
                      );
                      if (!dialogContext.mounted) return;
                      if (!account.authenticated) {
                        setLocal(() {
                          loading = false;
                          status = account.message;
                        });
                        return;
                      }
                      final normalized = StalkerService.normalizePortal(
                        host.text,
                      );
                      Navigator.pop(
                        dialogContext,
                        M3UList(
                          name: name.text.trim().isEmpty
                              ? 'Stalker ${sources.length + 1}'
                              : name.text.trim(),
                          url: normalized,
                          description: 'Portal Stalker · $normalized',
                          category: 'stalker',
                          host: normalized,
                          username: StalkerService.normalizeMac(mac.text),
                          userAgent: StalkerService.magUserAgent,
                        ),
                      );
                    },
              child: Text(loading ? 'Probando…' : 'Probar y guardar'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    host.dispose();
    mac.dispose();
    return result;
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint, {
    bool url = false,
    bool secret = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: secret,
      autocorrect: false,
      keyboardType: url ? TextInputType.url : TextInputType.text,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}

class _SourceAction extends StatelessWidget {
  const _SourceAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _line),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.add_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedSource extends StatelessWidget {
  const _SavedSource({required this.source, this.onDelete});
  final M3UList source;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final type = source.isXtream
        ? 'Xtream'
        : (source.isStalker ? 'Stalker' : 'M3U');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF00D6A0)),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$type · ${source.isDefault ? "HourTV" : "Personal"}',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, color: _muted),
            ),
        ],
      ),
    );
  }
}

class _EmptySources extends StatelessWidget {
  const _EmptySources();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: const Column(
        children: [
          Icon(Icons.playlist_add_rounded, color: _muted, size: 40),
          SizedBox(height: 10),
          Text(
            'Aún no agregaste fuentes personales.',
            style: TextStyle(color: _muted),
          ),
        ],
      ),
    );
  }
}
