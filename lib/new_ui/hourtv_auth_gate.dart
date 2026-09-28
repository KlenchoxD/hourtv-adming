import 'package:flutter/material.dart';
import '../services/auth/auth_controller.dart';
import '../services/auth/auth_gateway.dart';
import '../services/supabase_bootstrap.dart';
import 'hourtv_auth_page.dart';
import 'hourtv_auth_ui.dart';
import 'hourtv_new_password_page.dart';
import 'hourtv_verify_email_page.dart';

class HourTvAuthGate extends StatefulWidget {
  const HourTvAuthGate({
    super.key,
    this.controller,
    required this.guestChild,
    required this.authenticatedChild,
  });

  final AuthController? controller;
  final Widget guestChild;
  final Widget authenticatedChild;

  @override
  State<HourTvAuthGate> createState() => _HourTvAuthGateState();
}

class _HourTvAuthGateState extends State<HourTvAuthGate> {
  late final AuthController _controller;
  bool _createdOwnController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = AuthController(gateway: SupabaseBootstrap.instance.authGateway);
      _createdOwnController = true;
    }
    HourTvAuthScope.current = _controller;
  }

  @override
  void dispose() {
    if (identical(HourTvAuthScope.current, _controller)) {
      HourTvAuthScope.current = null;
    }
    if (_createdOwnController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller == null && !SupabaseBootstrap.instance.isAvailable) {
      return widget.guestChild;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final phase = _controller.currentPhase;

        switch (phase) {
          case AuthSessionPhase.guest:
            return HourTvAuthScope(
              controller: _controller,
              child: widget.guestChild,
            );
          case AuthSessionPhase.authenticated:
            return HourTvAuthScope(
              controller: _controller,
              child: widget.authenticatedChild,
            );
          case AuthSessionPhase.passwordRecovery:
            return HourTvNewPasswordPage(controller: _controller);
          case AuthSessionPhase.verificationRequired:
            return HourTvVerifyEmailPage(
              controller: _controller,
              onUseGuestMode: _controller.continueAsGuest,
            );
          case AuthSessionPhase.signedOut:
            return HourTvAuthPage(
              controller: _controller,
              onContinueAsGuest: _controller.continueAsGuest,
            );
        }
      },
    );
  }
}
