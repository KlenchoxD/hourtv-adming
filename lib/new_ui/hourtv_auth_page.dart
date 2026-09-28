import 'package:flutter/material.dart';
import '../services/auth/auth_controller.dart';
import '../services/auth/auth_telemetry.dart';
import 'hourtv_auth_ui.dart';

enum _AuthMode { signIn, signUp, forgot }

/// Entrada a HourTV: iniciar sesión, crear cuenta o recuperar la contraseña.
class HourTvAuthPage extends StatefulWidget {
  const HourTvAuthPage({
    super.key,
    required this.controller,
    required this.onContinueAsGuest,
  });

  final AuthController controller;
  final VoidCallback onContinueAsGuest;

  @override
  State<HourTvAuthPage> createState() => _HourTvAuthPageState();
}

class _HourTvAuthPageState extends State<HourTvAuthPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  var _mode = _AuthMode.signIn;
  bool _obscurePassword = true;
  final Stopwatch _renderStopwatch = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _renderStopwatch.stop();
        debugPrint(
          '[PERF_TTI] FIRST_INTERACTIVE_FRAME: time=${DateTime.now().millisecondsSinceEpoch}',
        );
        AuthTelemetry.instance.recordUiRender(
          _renderStopwatch.elapsedMilliseconds,
          metadata: {'is_signup': _mode == _AuthMode.signUp},
        );
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _setMode(_AuthMode mode) {
    widget.controller.clearMessages();
    setState(() => _mode = mode);
  }

  void _handleSubmit() {
    widget.controller.clearMessages();
    final email = _emailController.text;
    final password = _passwordController.text;
    switch (_mode) {
      case _AuthMode.signIn:
        widget.controller.signIn(email: email, password: password);
      case _AuthMode.signUp:
        widget.controller.signUp(email: email, password: password);
      case _AuthMode.forgot:
        widget.controller.resetPassword(email);
    }
  }

  void _toggleObscure() {
    final sw = Stopwatch()..start();
    setState(() => _obscurePassword = !_obscurePassword);
    sw.stop();
    AuthTelemetry.instance.recordKeyboardToggle(
      sw.elapsedMilliseconds,
      metadata: {'obscured': _obscurePassword},
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final isLoading = widget.controller.isLoading;
        final error = widget.controller.errorMessage;
        final success = widget.controller.successMessage;
        final height = MediaQuery.sizeOf(context).height;

        return Scaffold(
          backgroundColor: hourTvAuthBg,
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // El muro de pósters va de borde a borde; el formulario
                // sí se limita a un ancho cómodo.
                HourTvAuthHero(height: (height * .34).clamp(220, 320)),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              switch (_mode) {
                                _AuthMode.signIn => 'Inicia sesión',
                                _AuthMode.signUp => 'Crea tu cuenta',
                                _AuthMode.forgot => 'Recupera tu contraseña',
                              },
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              switch (_mode) {
                                _AuthMode.signIn =>
                                  'Tus perfiles, favoritos y "Continuar viendo" en todos tus equipos.',
                                _AuthMode.signUp =>
                                  'Gratis. Solo necesitas un correo y una contraseña.',
                                _AuthMode.forgot =>
                                  'Te enviaremos un enlace a tu correo. Ábrelo en este teléfono para elegir una contraseña nueva.',
                              },
                              style: const TextStyle(
                                color: hourTvAuthMuted,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 22),
                            if (error != null) ...[
                              HourTvAuthMessage(text: error),
                              const SizedBox(height: 14),
                            ],
                            if (success != null) ...[
                              HourTvAuthMessage(text: success, error: false),
                              const SizedBox(height: 14),
                            ],
                            HourTvAuthField(
                              key: const Key('auth_email_field'),
                              controller: _emailController,
                              label: 'Correo electrónico',
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              textInputAction: _mode == _AuthMode.forgot
                                  ? TextInputAction.done
                                  : TextInputAction.next,
                              onSubmitted: _mode == _AuthMode.forgot
                                  ? (_) => _handleSubmit()
                                  : null,
                            ),
                            if (_mode != _AuthMode.forgot) ...[
                              const SizedBox(height: 12),
                              HourTvAuthField(
                                key: const Key('auth_password_field'),
                                controller: _passwordController,
                                label: _mode == _AuthMode.signUp
                                    ? 'Contraseña (mínimo 8 caracteres)'
                                    : 'Contraseña',
                                icon: Icons.lock_outline_rounded,
                                obscure: _obscurePassword,
                                onToggleObscure: _toggleObscure,
                                toggleKey: const Key(
                                  'auth_password_toggle_button',
                                ),
                                autofillHints: [
                                  _mode == _AuthMode.signUp
                                      ? AutofillHints.newPassword
                                      : AutofillHints.password,
                                ],
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _handleSubmit(),
                              ),
                            ],
                            if (_mode == _AuthMode.signIn)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: isLoading
                                      ? null
                                      : () => _setMode(_AuthMode.forgot),
                                  child: const Text(
                                    '¿Olvidaste tu contraseña?',
                                    style: TextStyle(
                                      color: hourTvAuthEmerald,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                            else
                              const SizedBox(height: 18),
                            HourTvAuthButton(
                              key: const Key('auth_submit_button'),
                              label: switch (_mode) {
                                _AuthMode.signIn => 'Iniciar sesión',
                                _AuthMode.signUp => 'Crear cuenta',
                                _AuthMode.forgot => 'Enviar enlace',
                              },
                              loading: isLoading,
                              onPressed: _handleSubmit,
                            ),
                            if (_mode == _AuthMode.forgot)
                              TextButton(
                                onPressed: isLoading
                                    ? null
                                    : () => _setMode(_AuthMode.signIn),
                                child: const Text(
                                  'Volver a iniciar sesión',
                                  style: TextStyle(color: hourTvAuthMuted),
                                ),
                              )
                            else ...[
                              const SizedBox(height: 18),
                              const _OrDivider(),
                              const SizedBox(height: 18),
                              _GoogleButton(
                                onPressed: isLoading
                                    ? null
                                    : () =>
                                          widget.controller.signInWithGoogle(),
                              ),
                              const SizedBox(height: 22),
                              _SwitchModeLink(
                                signUp: _mode == _AuthMode.signUp,
                                onTap: isLoading
                                    ? null
                                    : () => _setMode(
                                        _mode == _AuthMode.signUp
                                            ? _AuthMode.signIn
                                            : _AuthMode.signUp,
                                      ),
                              ),
                              const SizedBox(height: 6),
                              TextButton(
                                onPressed: isLoading
                                    ? null
                                    : widget.onContinueAsGuest,
                                child: const Text(
                                  'Continuar sin cuenta',
                                  style: TextStyle(
                                    color: hourTvAuthMuted,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
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

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: hourTvAuthLine)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('o', style: TextStyle(color: hourTvAuthMuted)),
        ),
        Expanded(child: Divider(color: hourTvAuthLine)),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        key: const Key('auth_google_button'),
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'G',
              style: TextStyle(
                color: Color(0xFF4285F4),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(width: 12),
            Flexible(
              child: Text(
                'Continuar con Google',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchModeLink extends StatelessWidget {
  const _SwitchModeLink({required this.signUp, required this.onTap});

  final bool signUp;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          signUp ? '¿Ya tienes cuenta?' : '¿No tienes cuenta?',
          style: const TextStyle(color: hourTvAuthMuted, fontSize: 14),
        ),
        TextButton(
          key: Key(signUp ? 'auth_tab_signin' : 'auth_tab_signup'),
          onPressed: onTap,
          child: Text(
            signUp ? 'Inicia sesión' : 'Crea una gratis',
            style: const TextStyle(
              color: hourTvAuthEmerald,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
