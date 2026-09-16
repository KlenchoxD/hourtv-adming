import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

final class NativeGoogleCredential {
  const NativeGoogleCredential({required this.idToken});

  final String idToken;
}

class NativeGoogleUnavailableException implements Exception {
  const NativeGoogleUnavailableException();
}

abstract interface class NativeGoogleAccountSelector {
  bool get isSupported;
  Future<NativeGoogleCredential?> selectAccount();
}

final class GoogleNativeAccountSelector implements NativeGoogleAccountSelector {
  GoogleNativeAccountSelector({required this.serverClientId});

  final String serverClientId;
  Future<void>? _initialization;

  @override
  bool get isSupported =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      serverClientId.trim().isNotEmpty;

  Future<void> _initialize() => _initialization ??= GoogleSignIn.instance
      .initialize(serverClientId: serverClientId.trim());

  @override
  Future<NativeGoogleCredential?> selectAccount() async {
    if (!isSupported) throw const NativeGoogleUnavailableException();
    try {
      await _initialize();
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw const NativeGoogleUnavailableException();
      }
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const NativeGoogleUnavailableException();
      }
      return NativeGoogleCredential(idToken: idToken);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw const NativeGoogleUnavailableException();
    }
  }
}

final class NativeGoogleAuthFlow {
  NativeGoogleAuthFlow({
    required this.selector,
    required this.exchangeIdToken,
    required this.openBrowserFallback,
  });

  final NativeGoogleAccountSelector selector;
  final Future<void> Function(NativeGoogleCredential credential)
  exchangeIdToken;
  final Future<bool> Function() openBrowserFallback;

  Future<bool> signIn() async {
    if (!selector.isSupported) return openBrowserFallback();
    try {
      final credential = await selector.selectAccount();
      if (credential == null) return false;
      await exchangeIdToken(credential);
      return true;
    } on NativeGoogleUnavailableException {
      return openBrowserFallback();
    }
  }
}
