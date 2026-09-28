import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth/auth_controller.dart';
import '../services/auth/auth_gateway.dart';
import '../services/content_store.dart';
import '../services/storage_service.dart';
import '../services/supabase_bootstrap.dart';
import '../services/sync/profile_sync_engine.dart';
import 'hourtv_auth_ui.dart';

/// Perfil > Cuenta: como "Gestión de cuentas" de Xuper. Muestra con qué
/// cuenta estás conectado y deja cambiar la contraseña, recuperarla, cambiar
/// de cuenta o cerrar sesión.
class HourTvAccountPage extends StatelessWidget {
  const HourTvAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = HourTvAuthScope.maybeOf(context);
    return Scaffold(
      backgroundColor: hourTvAuthBg,
      appBar: AppBar(
        backgroundColor: hourTvAuthBg,
        foregroundColor: Colors.white,
        title: const Text('Cuenta'),
      ),
      body: controller == null || !SupabaseBootstrap.instance.isAvailable
          ? const _Unavailable()
          : AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final user = controller.currentUser;
                if (controller.isGuest || user == null) {
                  return _SignedOut(controller: controller);
                }
                return _SignedIn(controller: controller, user: user);
              },
            ),
    );
  }
}

/// Deja la app en la pantalla de inicio de sesión (cierra todo lo abierto).
Future<void> _backToAuth(BuildContext context) async {
  Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
}

Future<void> _signOut(BuildContext context, AuthController controller) async {
  await ProfileSyncEngine.instance?.flush();
  await controller.signOut();
  await StorageService.clearCloudProfileContext();
  ContentStore.instance.refreshProfileData();
  if (context.mounted) await _backToAuth(context);
}

class _SignedIn extends StatelessWidget {
  const _SignedIn({required this.controller, required this.user});

  final AuthController controller;
  final AuthUser user;

  String get _shortId =>
      user.id.replaceAll('-', '').substring(0, 8).toUpperCase();

  bool get _isGoogle => user.provider == 'google';

  @override
  Widget build(BuildContext context) {
    final created = user.createdAt;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _Header(email: user.email, google: _isGoogle),
        const SizedBox(height: 24),
        if (controller.successMessage != null) ...[
          HourTvAuthMessage(text: controller.successMessage!, error: false),
          const SizedBox(height: 14),
        ],
        if (controller.errorMessage != null) ...[
          HourTvAuthMessage(text: controller.errorMessage!),
          const SizedBox(height: 14),
        ],
        _Section(
          children: [
            _InfoRow(
              label: 'Cuenta',
              value: _shortId,
              trailing: IconButton(
                tooltip: 'Copiar',
                icon: const Icon(
                  Icons.copy_rounded,
                  color: hourTvAuthMuted,
                  size: 19,
                ),
                onPressed: () {
                  unawaited(Clipboard.setData(ClipboardData(text: user.id)));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ID de cuenta copiado')),
                  );
                },
              ),
            ),
            _InfoRow(label: 'Correo', value: user.email),
            _InfoRow(
              label: 'Inicio de sesión',
              value: _isGoogle ? 'Google' : 'Correo y contraseña',
            ),
            if (created != null)
              _InfoRow(
                label: 'Miembro desde',
                value:
                    '${created.day.toString().padLeft(2, '0')}/'
                    '${created.month.toString().padLeft(2, '0')}/${created.year}',
              ),
          ],
        ),
        const SizedBox(height: 20),
        _Section(
          children: [
            _ActionRow(
              icon: Icons.password_rounded,
              label: _isGoogle ? 'Crear contraseña' : 'Cambiar contraseña',
              onTap: () => _showChangePassword(context),
            ),
            if (!_isGoogle)
              _ActionRow(
                icon: Icons.mark_email_read_outlined,
                label: 'Olvidé mi contraseña',
                subtitle: 'Te enviamos un enlace a ${user.email}',
                onTap: () {
                  controller.clearMessages();
                  unawaited(controller.resetPassword(user.email));
                },
              ),
            _ActionRow(
              icon: Icons.swap_horiz_rounded,
              label: 'Cambiar de cuenta',
              onTap: () => unawaited(_confirmSignOut(context, switching: true)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _Section(
          children: [
            _ActionRow(
              icon: Icons.logout_rounded,
              label: 'Cerrar sesión',
              color: hourTvAuthError,
              onTap: () =>
                  unawaited(_confirmSignOut(context, switching: false)),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmSignOut(
    BuildContext context, {
    required bool switching,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: hourTvAuthSurface,
        title: Text(
          switching ? 'Cambiar de cuenta' : 'Cerrar sesión',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          switching
              ? 'Se cerrará la sesión de ${user.email} para que entres con otra cuenta.'
              : 'Se cerrará la sesión de ${user.email} en este teléfono.',
          style: const TextStyle(color: hourTvAuthMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: hourTvAuthError),
            child: Text(switching ? 'Cambiar' : 'Cerrar sesión'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) await _signOut(context, controller);
  }

  void _showChangePassword(BuildContext context) {
    controller.clearMessages();
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: hourTvAuthBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        builder: (_) => _ChangePasswordSheet(controller: controller),
      ),
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet({required this.controller});

  final AuthController controller;

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  var _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    widget.controller.clearMessages();
    final ok = await widget.controller.updatePassword(
      _password.text,
      _confirm.text,
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Contraseña nueva',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Mínimo 8 caracteres.',
              style: TextStyle(color: hourTvAuthMuted),
            ),
            const SizedBox(height: 18),
            if (widget.controller.errorMessage != null) ...[
              HourTvAuthMessage(text: widget.controller.errorMessage!),
              const SizedBox(height: 12),
            ],
            HourTvAuthField(
              controller: _password,
              label: 'Contraseña nueva',
              icon: Icons.lock_outline_rounded,
              obscure: _obscure,
              onToggleObscure: () => setState(() => _obscure = !_obscure),
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            HourTvAuthField(
              controller: _confirm,
              label: 'Repite la contraseña',
              icon: Icons.lock_outline_rounded,
              obscure: _obscure,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => unawaited(_save()),
            ),
            const SizedBox(height: 18),
            HourTvAuthButton(
              label: 'Guardar',
              loading: widget.controller.isLoading,
              onPressed: () => unawaited(_save()),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut({required this.controller});

  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        const Icon(
          Icons.account_circle_outlined,
          color: hourTvAuthMuted,
          size: 64,
        ),
        const SizedBox(height: 14),
        const Text(
          'Estás usando HourTV sin cuenta',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Con una cuenta gratis tus perfiles, favoritos y "Continuar viendo" '
          'se guardan en la nube y los recuperas en cualquier equipo.',
          textAlign: TextAlign.center,
          style: TextStyle(color: hourTvAuthMuted, height: 1.4),
        ),
        const SizedBox(height: 24),
        HourTvAuthButton(
          label: 'Iniciar sesión o crear cuenta',
          onPressed: () {
            controller.exitGuestMode();
            unawaited(_backToAuth(context));
          },
        ),
      ],
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Text(
          'Las cuentas no están disponibles en esta versión de HourTV.',
          textAlign: TextAlign.center,
          style: TextStyle(color: hourTvAuthMuted, fontSize: 15),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.email, required this.google});

  final String email;
  final bool google;

  @override
  Widget build(BuildContext context) {
    final initial = email.isEmpty ? '?' : email[0].toUpperCase();
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hourTvAuthEmerald.withValues(alpha: .14),
            border: Border.all(color: hourTvAuthEmerald, width: 2),
          ),
          child: Text(
            initial,
            style: const TextStyle(
              color: hourTvAuthEmerald,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          email,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: hourTvAuthEmerald.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            google ? 'Conectada con Google' : 'Correo verificado',
            style: const TextStyle(
              color: hourTvAuthEmerald,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: hourTvAuthSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hourTvAuthLine),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: hourTvAuthLine),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.trailing});

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, trailing == null ? 16 : 4, 12),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: hourTvAuthMuted)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: const TextStyle(color: hourTvAuthMuted)),
      trailing: color == Colors.white
          ? const Icon(Icons.chevron_right_rounded, color: hourTvAuthMuted)
          : null,
    );
  }
}
