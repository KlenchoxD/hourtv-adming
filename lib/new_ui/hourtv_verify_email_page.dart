import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth/auth_controller.dart';

class HourTvVerifyEmailPage extends StatefulWidget {
  const HourTvVerifyEmailPage({
    super.key,
    required this.controller,
    required this.onUseGuestMode,
  });

  final AuthController controller;
  final VoidCallback onUseGuestMode;

  @override
  State<HourTvVerifyEmailPage> createState() => _HourTvVerifyEmailPageState();
}

class _HourTvVerifyEmailPageState extends State<HourTvVerifyEmailPage> {
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _cooldownSeconds = 0);
      } else {
        if (mounted) setState(() => _cooldownSeconds--);
      }
    });
  }

  Future<void> _handleResend() async {
    final ok = await widget.controller.resendVerification();
    if (ok) {
      _startCooldown();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final email = widget.controller.currentUser?.email ?? '';
        final isLoading = widget.controller.isLoading;
        final error = widget.controller.errorMessage;
        final success = widget.controller.successMessage;

        return Scaffold(
          backgroundColor: const Color(0xFF0C0C0E),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Icon
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3)),
                        ),
                        child: const Icon(
                          Icons.mark_email_unread_outlined,
                          color: Color(0xFF00E676),
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    const Text(
                      'VERIFICA TU CORREO',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Instructions
                    Text(
                      'Hemos enviado un enlace de confirmación a:',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF00E676),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Haz clic en el enlace para activar tu cuenta y acceder a tus perfiles sincronizados.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
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

                    // Action 1: Ya verifiqué mi correo
                    ElevatedButton(
                      onPressed: isLoading ? null : () => widget.controller.refreshSession(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
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
                          : const Text(
                              'Ya verifiqué mi correo',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                    ),
                    const SizedBox(height: 12),

                    // Action 2: Reenviar correo
                    OutlinedButton(
                      onPressed: (isLoading || _cooldownSeconds > 0) ? null : _handleResend,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        _cooldownSeconds > 0
                            ? 'Reenviar en ${_cooldownSeconds}s'
                            : 'Reenviar correo',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Action 3: Usar modo invitado
                    TextButton(
                      onPressed: isLoading ? null : widget.onUseGuestMode,
                      child: const Text(
                        'Usar modo invitado',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    // Action 4: Cerrar sesión
                    TextButton(
                      onPressed: isLoading ? null : () => widget.controller.signOut(),
                      child: Text(
                        'Iniciar sesión con otra cuenta',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 12,
                        ),
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
