import 'package:flutter/material.dart';
import '../services/auth/auth_controller.dart';

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
  bool _isSignUp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    widget.controller.clearMessages();
    final email = _emailController.text;
    final password = _passwordController.text;

    if (_isSignUp) {
      widget.controller.signUp(email: email, password: password);
    } else {
      widget.controller.signIn(email: email, password: password);
    }
  }

  void _handleForgotPassword() {
    final email = _emailController.text;
    widget.controller.resetPassword(email);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final isLoading = widget.controller.isLoading;
        final error = widget.controller.errorMessage;
        final success = widget.controller.successMessage;

        return Scaffold(
          backgroundColor: const Color(0xFF0C0C0E),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // HourTV Branding
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E676),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Hour',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'TV',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 24,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Tabs: Iniciar Sesión / Crear Cuenta
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              key: const Key('auth_tab_signin'),
                              onTap: isLoading ? null : () => setState(() => _isSignUp = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: !_isSignUp ? const Color(0xFF1E1E24) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'INICIAR SESIÓN',
                                  style: TextStyle(
                                    color: !_isSignUp ? const Color(0xFF00E676) : Colors.white60,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              key: const Key('auth_tab_signup'),
                              onTap: isLoading ? null : () => setState(() => _isSignUp = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _isSignUp ? const Color(0xFF1E1E24) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'CREAR CUENTA',
                                  style: TextStyle(
                                    color: _isSignUp ? const Color(0xFF00E676) : Colors.white60,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Error & Success Feedback
                    if (error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          error,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (success != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          success,
                          style: const TextStyle(color: Color(0xFF00E676), fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Form Fields
                    TextField(
                      key: const Key('auth_email_field'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Correo electrónico',
                        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                        prefixIcon: const Icon(Icons.email_outlined, color: Colors.white54, size: 20),
                        filled: true,
                        fillColor: const Color(0xFF16161B),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF00E676)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('auth_password_field'),
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Contraseña (mínimo 8 caracteres)',
                        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                        prefixIcon: const Icon(Icons.lock_outline, color: Colors.white54, size: 20),
                        filled: true,
                        fillColor: const Color(0xFF16161B),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF00E676)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Forgot Password (only in sign-in)
                    if (!_isSignUp)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: isLoading ? null : _handleForgotPassword,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          ),
                          child: const Text(
                            '¿Olvidaste tu contraseña?',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Submit Button
                    ElevatedButton(
                      key: const Key('auth_submit_button'),
                      onPressed: isLoading ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: const Color(0xFF00E676).withValues(alpha: 0.3),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Text(
                              _isSignUp ? 'CREAR CUENTA' : 'INICIAR SESIÓN',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),

                    // Divider
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'o',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Continuar como invitado
                    OutlinedButton(
                      onPressed: isLoading ? null : widget.onContinueAsGuest,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Continuar como invitado',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
