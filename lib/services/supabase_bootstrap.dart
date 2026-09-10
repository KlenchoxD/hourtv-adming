import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth/auth_gateway.dart';
import 'auth/supabase_auth_gateway.dart';
import 'auth/unavailable_auth_gateway.dart';
import 'supabase_config.dart';

class SupabaseBootstrap {
  SupabaseBootstrap._({this._authGateway, this._isTest = false});

  static SupabaseBootstrap? _instance;
  static SupabaseBootstrap get instance => _instance ??= SupabaseBootstrap._();

  @visibleForTesting
  static void setInstanceForTest(SupabaseBootstrap bootstrap) {
    _instance = bootstrap;
  }

  factory SupabaseBootstrap.forTest({AuthGateway? authGateway}) =>
      SupabaseBootstrap._(authGateway: authGateway, isTest: true);

  final bool _isTest;
  bool _isAvailable = false;
  AuthGateway? _authGateway;

  bool get isAvailable => _isAvailable;

  AuthGateway get authGateway =>
      _authGateway ?? UnavailableAuthGateway();

  Future<void> initialize(SupabaseConfig config) async {
    if (!config.isConfigured) {
      _isAvailable = false;
      _authGateway ??= UnavailableAuthGateway();
      return;
    }

    if (_isTest) {
      _isAvailable = true;
      _authGateway ??= UnavailableAuthGateway();
      return;
    }

    try {
      await Supabase.initialize(
        url: config.projectUrl,
        publishableKey: config.publishableKey,
      );
      _isAvailable = true;
      _authGateway = SupabaseAuthGateway(Supabase.instance.client);
    } catch (e, st) {
      // Safe logging without leaking credentials
      debugPrint('Error al inicializar Supabase: $e');
      debugPrintStack(stackTrace: st);
      _isAvailable = false;
      _authGateway = UnavailableAuthGateway();
    }
  }
}
