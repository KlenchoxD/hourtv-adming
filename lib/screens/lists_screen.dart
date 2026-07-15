import 'package:flutter/material.dart';
import '../models/m3u_list.dart';
import '../services/content_store.dart';
import '../services/m3u_parser_service.dart';
import '../services/stalker_service.dart';
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
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    if (!mounted) return;
    setState(() {
      _lists = StorageService.loadLists();
      _loading = false;
    });
  }

  String _sourceKey(M3UList source) {
    final category = source.category ?? 'm3u';
    final endpoint = source.host ?? source.url;
    return '$category|$endpoint|${source.username ?? ''}'.toLowerCase();
  }

  Future<void> _addSource(M3UList? source, String label) async {
    if (source == null) return;
    if (_lists.any((item) => _sourceKey(item) == _sourceKey(source))) {
      _toast('Esa fuente ya está guardada.');
      return;
    }
    _lists = [..._lists, source];
    await _saveAndReload('$label agregada y contenido actualizado.');
  }

  Future<void> _saveAndReload(String message) async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      await StorageService.saveLists(_lists);
      await ContentStore.instance.reload();
      if (!mounted) return;
      setState(() => _lists = StorageService.loadLists());
      _toast(message);
    } catch (error) {
      _toast('No se pudo guardar o recargar la fuente: $error');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addM3u() async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    var checking = false;
    var valid = false;
    String? status;

    final source = await showDialog<M3UList>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) {
          void invalidate(String _) {
            if (valid || status != null) {
              setLocal(() {
                valid = false;
                status = null;
              });
            }
          }

          Future<void> validate() async {
            final url = urlController.text.trim();
            final uri = Uri.tryParse(url);
            if (uri == null ||
                !uri.hasAuthority ||
                (uri.scheme != 'http' && uri.scheme != 'https')) {
              setLocal(() {
                valid = false;
                status = 'Escribe una URL http o https válida.';
              });
              return;
            }
            setLocal(() {
              checking = true;
              valid = false;
              status = 'Descargando y comprobando la lista…';
            });
            try {
              final channels = await M3UParserService.fetchAndParse(
                url,
                listName: nameController.text.trim(),
              );
              if (!dialogContext.mounted) return;
              setLocal(() {
                checking = false;
                valid = channels.isNotEmpty;
                status = channels.isEmpty
                    ? 'La lista no contiene canales reproducibles.'
                    : '✓ Lista válida · ${channels.length} elementos';
              });
            } catch (error) {
              if (!dialogContext.mounted) return;
              setLocal(() {
                checking = false;
                valid = false;
                status = 'No se pudo validar: $error';
              });
            }
          }

          return AlertDialog(
            title: const Text('Agregar lista M3U'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      hintText: 'ej: Mi lista',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlController,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    onChanged: invalidate,
                    decoration: const InputDecoration(
                      labelText: 'URL M3U',
                      hintText: 'https://servidor/lista.m3u',
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (status != null)
                    Text(
                      status!,
                      style: TextStyle(
                        color: valid
                            ? AppColors.success
                            : checking
                            ? AppColors.textSecondary
                            : AppColors.error,
                        fontSize: 12.5,
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              OutlinedButton(
                onPressed: checking ? null : validate,
                child: Text(checking ? 'Probando…' : 'Probar'),
              ),
              ElevatedButton(
                onPressed: !valid || checking
                    ? null
                    : () {
                        Navigator.pop(
                          dialogContext,
                          M3UList(
                            name: nameController.text.trim().isEmpty
                                ? 'Lista ${_lists.length + 1}'
                                : nameController.text.trim(),
                            url: urlController.text.trim(),
                          ),
                        );
                      },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
    nameController.dispose();
    urlController.dispose();
    await _addSource(source, 'Lista');
  }

  Future<void> _addXtream() async {
    final nameController = TextEditingController();
    final hostController = TextEditingController();
    final userController = TextEditingController();
    final passController = TextEditingController();
    var checking = false;
    var valid = false;
    String? status;

    final source = await showDialog<M3UList>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) {
          void invalidate(String _) {
            if (valid || status != null) {
              setLocal(() {
                valid = false;
                status = null;
              });
            }
          }

          Future<void> validate() async {
            final host = hostController.text.trim();
            final user = userController.text.trim();
            final password = passController.text.trim();
            if (host.isEmpty || user.isEmpty || password.isEmpty) {
              setLocal(() {
                valid = false;
                status = 'Completa servidor, usuario y contraseña.';
              });
              return;
            }
            setLocal(() {
              checking = true;
              valid = false;
              status = 'Conectando…';
            });
            final account = await XtreamService.validate(host, user, password);
            if (!dialogContext.mounted) return;
            setLocal(() {
              checking = false;
              valid = account.authenticated;
              status = account.authenticated
                  ? '✓ ${account.message} · Vence: ${account.expDate ?? "-"}'
                  : '✕ ${account.message}';
            });
          }

          return AlertDialog(
            title: const Text('Cuenta Xtream'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre (opcional)',
                      hintText: 'ej: Mi proveedor',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: hostController,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    onChanged: invalidate,
                    decoration: const InputDecoration(
                      labelText: 'Servidor (con puerto)',
                      hintText: 'http://servidor.com:8080',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: userController,
                    onChanged: invalidate,
                    decoration: const InputDecoration(labelText: 'Usuario'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passController,
                    obscureText: true,
                    onChanged: invalidate,
                    decoration: const InputDecoration(labelText: 'Contraseña'),
                  ),
                  const SizedBox(height: 14),
                  if (status != null)
                    Text(
                      status!,
                      style: TextStyle(
                        color: valid
                            ? AppColors.success
                            : checking
                            ? AppColors.textSecondary
                            : AppColors.error,
                        fontSize: 12.5,
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              OutlinedButton(
                onPressed: checking ? null : validate,
                child: Text(checking ? 'Probando…' : 'Probar'),
              ),
              ElevatedButton(
                onPressed: !valid || checking
                    ? null
                    : () {
                        final host = XtreamService.normalizeHost(
                          hostController.text,
                        );
                        Navigator.pop(
                          dialogContext,
                          M3UList(
                            name: nameController.text.trim().isEmpty
                                ? 'Xtream ${_lists.length + 1}'
                                : nameController.text.trim(),
                            url: XtreamService.buildM3uUrl(
                              hostController.text,
                              userController.text,
                              passController.text,
                            ),
                            description: 'Cuenta Xtream · $host',
                            category: 'xtream',
                            host: host,
                            username: userController.text.trim(),
                            password: passController.text.trim(),
                          ),
                        );
                      },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );

    nameController.dispose();
    hostController.dispose();
    userController.dispose();
    passController.dispose();
    await _addSource(source, 'Cuenta');
  }

  Future<void> _addStalker() async {
    final nameController = TextEditingController();
    final hostController = TextEditingController();
    final macController = TextEditingController(text: '00:1A:79:');
    var checking = false;
    var valid = false;
    String? status;

    final source = await showDialog<M3UList>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) {
          void invalidate(String _) {
            if (valid || status != null) {
              setLocal(() {
                valid = false;
                status = null;
              });
            }
          }

          Future<void> validate() async {
            final host = hostController.text.trim();
            final mac = macController.text.trim();
            if (host.isEmpty || !StalkerService.isValidMac(mac)) {
              setLocal(() {
                valid = false;
                status = 'Completa una URL y una MAC válidas.';
              });
              return;
            }
            setLocal(() {
              checking = true;
              valid = false;
              status = 'Conectando…';
            });
            final result = await StalkerService.validate(host, mac);
            if (!dialogContext.mounted) return;
            setLocal(() {
              checking = false;
              valid = result.authenticated;
              status = result.authenticated
                  ? '✓ ${result.message}'
                  : '✕ ${result.message}';
            });
          }

          return AlertDialog(
            title: const Text('Portal Stalker / Ministra'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre (opcional)',
                      hintText: 'ej: Portal de casa',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: hostController,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    onChanged: invalidate,
                    decoration: const InputDecoration(
                      labelText: 'URL del portal',
                      hintText: 'http://servidor.com/stalker_portal/c',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: macController,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: invalidate,
                    decoration: const InputDecoration(
                      labelText: 'Dirección MAC',
                      hintText: '00:1A:79:XX:XX:XX',
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (status != null)
                    Text(
                      status!,
                      style: TextStyle(
                        color: valid
                            ? AppColors.success
                            : checking
                            ? AppColors.textSecondary
                            : AppColors.error,
                        fontSize: 12.5,
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              OutlinedButton(
                onPressed: checking ? null : validate,
                child: Text(checking ? 'Probando…' : 'Probar'),
              ),
              ElevatedButton(
                onPressed: !valid || checking
                    ? null
                    : () {
                        final host = StalkerService.normalizePortal(
                          hostController.text,
                        );
                        Navigator.pop(
                          dialogContext,
                          M3UList(
                            name: nameController.text.trim().isEmpty
                                ? 'Stalker ${_lists.length + 1}'
                                : nameController.text.trim(),
                            url: host,
                            description: 'Portal Stalker · $host',
                            category: 'stalker',
                            host: host,
                            username: StalkerService.normalizeMac(
                              macController.text,
                            ),
                            userAgent: StalkerService.magUserAgent,
                          ),
                        );
                      },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );

    nameController.dispose();
    hostController.dispose();
    macController.dispose();
    await _addSource(source, 'Portal');
  }

  Future<void> _deleteList(int index) async {
    final source = _lists[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar fuente'),
        content: Text('¿Eliminar "${source.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    _lists = [..._lists]..removeAt(index);
    await _saveAndReload('Fuente eliminada y contenido actualizado.');
  }

  @override
  Widget build(BuildContext context) {
    final userCount = _lists.where((source) => !source.isDefault).length;
    return SafeArea(
      child: Column(
        children: [
          _topBar(),
          if (_syncing)
            const LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.accent,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 720) {
                  return SizedBox(
                    height: 126,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        SizedBox(
                          width: 190,
                          child: _addCard(
                            Icons.dns_rounded,
                            'Cuenta Xtream',
                            'Servidor · usuario · clave',
                            _addXtream,
                            primary: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 190,
                          child: _addCard(
                            Icons.router_rounded,
                            'Portal Stalker',
                            'URL · dirección MAC',
                            _addStalker,
                            primary: false,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 190,
                          child: _addCard(
                            Icons.link_rounded,
                            'Lista M3U',
                            'Pega una URL .m3u',
                            _addM3u,
                            primary: false,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: _addCard(
                        Icons.dns_rounded,
                        'Cuenta Xtream',
                        'Servidor · usuario · clave',
                        _addXtream,
                        primary: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _addCard(
                        Icons.router_rounded,
                        'Portal Stalker',
                        'URL · dirección MAC',
                        _addStalker,
                        primary: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _addCard(
                        Icons.link_rounded,
                        'Lista M3U',
                        'Pega una URL .m3u',
                        _addM3u,
                        primary: false,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
            child: Row(
              children: [
                const Text(
                  'FUENTES',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _lists.length.toString(),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                if (userCount > 0)
                  Text(
                    '$userCount propias',
                    style: const TextStyle(
                      color: AppColors.accentLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const LoadingIndicator()
                : _lists.isEmpty
                ? const EmptyState(
                    icon: Icons.playlist_add,
                    title: 'Sin fuentes',
                    subtitle: 'Agrega Xtream, Stalker o una lista M3U',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: _lists.length,
                    itemBuilder: (_, index) => _listTile(_lists[index], index),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 14),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textPrimary,
            ),
            onPressed: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 2),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Mis Fuentes',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Conecta tu proveedor IPTV o listas M3U',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _addCard(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    required bool primary,
  }) {
    return TvFocusable(
      onTap: _syncing ? () {} : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 126,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: primary ? null : AppColors.cardDark,
          gradient: primary ? AppTheme.accentGradient : null,
          borderRadius: BorderRadius.circular(16),
          border: primary
              ? null
              : Border.all(
                  color: AppColors.accent.withValues(alpha: 0.30),
                  width: 1.3,
                ),
          boxShadow: primary
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: primary ? Colors.white : AppColors.accent,
                  size: 22,
                ),
                const Spacer(),
                Icon(
                  Icons.add_rounded,
                  color: primary ? Colors.white70 : AppColors.accent,
                  size: 20,
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                color: primary ? Colors.white : AppColors.textPrimary,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: primary ? Colors.white70 : AppColors.textMuted,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listTile(M3UList source, int index) {
    final isXtream = source.category == 'xtream';
    final isStalker = source.category == 'stalker';
    final badge = isStalker
        ? 'STALKER'
        : isXtream
        ? 'XTREAM'
        : source.isDefault
        ? 'INCLUIDA'
        : 'M3U';
    final badgeColor = isXtream || isStalker
        ? AppColors.success
        : source.isDefault
        ? AppColors.textMuted
        : AppColors.accent;

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
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isStalker
                    ? Icons.router_rounded
                    : isXtream
                    ? Icons.dns_rounded
                    : source.isDefault
                    ? Icons.public_rounded
                    : Icons.playlist_play_rounded,
                color: badgeColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          source.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    source.description ?? source.url,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!source.isDefault)
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                onPressed: _syncing ? null : () => _deleteList(index),
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
