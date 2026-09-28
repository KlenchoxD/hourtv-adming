import 'package:flutter/material.dart';

import '../services/auth/auth_controller.dart';
import 'hourtv_auth_ui.dart';

/// Pantalla a la que lleva el enlace de "¿Olvidaste tu contraseña?": antes
/// el enlace abría la app ya dentro de la cuenta sin pedir una contraseña
/// nueva, así que la vieja (olvidada) seguía siendo la única.
class HourTvNewPasswordPage extends StatefulWidget {
  const HourTvNewPasswordPage({super.key, required this.controller});

  final AuthController controller;

  @override
  State<HourTvNewPasswordPage> createState() => _HourTvNewPasswordPageState();
}

class _HourTvNewPasswordPageState extends State<HourTvNewPasswordPage> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  var _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _save() {
    widget.controller.clearMessages();
    widget.controller.updatePassword(_password.text, _confirm.text);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final loading = widget.controller.isLoading;
        final error = widget.controller.errorMessage;
        final email = widget.controller.currentUser?.email ?? '';
        return Scaffold(
          backgroundColor: hourTvAuthBg,
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // El muro de pósters va de borde a borde; el formulario
                // sí se limita a un ancho cómodo.
                const HourTvAuthHero(height: 220, tagline: null),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Elige una contraseña nueva',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              email.isEmpty
                                  ? 'Mínimo 8 caracteres.'
                                  : 'Para $email. Mínimo 8 caracteres.',
                              style: const TextStyle(
                                color: hourTvAuthMuted,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 22),
                            if (error != null) ...[
                              HourTvAuthMessage(text: error),
                              const SizedBox(height: 14),
                            ],
                            HourTvAuthField(
                              key: const Key('new_password_field'),
                              controller: _password,
                              label: 'Contraseña nueva',
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscure,
                              onToggleObscure: () =>
                                  setState(() => _obscure = !_obscure),
                              autofillHints: const [AutofillHints.newPassword],
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 12),
                            HourTvAuthField(
                              key: const Key('new_password_confirm_field'),
                              controller: _confirm,
                              label: 'Repite la contraseña',
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscure,
                              autofillHints: const [AutofillHints.newPassword],
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _save(),
                            ),
                            const SizedBox(height: 22),
                            HourTvAuthButton(
                              key: const Key('new_password_save_button'),
                              label: 'Guardar contraseña',
                              loading: loading,
                              onPressed: _save,
                            ),
                            TextButton(
                              onPressed: loading
                                  ? null
                                  : () => widget.controller.signOut(),
                              child: const Text(
                                'Cancelar',
                                style: TextStyle(color: hourTvAuthMuted),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
