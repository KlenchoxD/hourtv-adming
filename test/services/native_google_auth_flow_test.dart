import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/services/auth/native_google_auth.dart';

final class _Selector implements NativeGoogleAccountSelector {
  _Selector({required this.supported, this.credential, this.error});

  final bool supported;
  final NativeGoogleCredential? credential;
  final Object? error;
  int calls = 0;

  @override
  bool get isSupported => supported;

  @override
  Future<NativeGoogleCredential?> selectAccount() async {
    calls++;
    if (error != null) throw error!;
    return credential;
  }
}

void main() {
  test('intercambia el token elegido sin abrir OAuth web', () async {
    final selector = _Selector(
      supported: true,
      credential: const NativeGoogleCredential(idToken: 'id-token'),
    );
    String? exchangedToken;
    var browserCalls = 0;
    final flow = NativeGoogleAuthFlow(
      selector: selector,
      exchangeIdToken: (credential) async {
        exchangedToken = credential.idToken;
      },
      openBrowserFallback: () async {
        browserCalls++;
        return true;
      },
    );

    expect(await flow.signIn(), isTrue);
    expect(exchangedToken, 'id-token');
    expect(browserCalls, 0);
  });

  test('cancelar el selector nativo no abre el navegador', () async {
    final selector = _Selector(supported: true, credential: null);
    var browserCalls = 0;
    final flow = NativeGoogleAuthFlow(
      selector: selector,
      exchangeIdToken: (_) async {},
      openBrowserFallback: () async {
        browserCalls++;
        return true;
      },
    );

    expect(await flow.signIn(), isFalse);
    expect(browserCalls, 0);
  });

  test(
    'usa OAuth web cuando la plataforma no admite selector nativo',
    () async {
      final selector = _Selector(supported: false);
      var browserCalls = 0;
      final flow = NativeGoogleAuthFlow(
        selector: selector,
        exchangeIdToken: (_) async {},
        openBrowserFallback: () async {
          browserCalls++;
          return true;
        },
      );

      expect(await flow.signIn(), isTrue);
      expect(selector.calls, 0);
      expect(browserCalls, 1);
    },
  );

  test('usa OAuth web si Google nativo no está configurado', () async {
    final selector = _Selector(
      supported: true,
      error: const NativeGoogleUnavailableException(),
    );
    var browserCalls = 0;
    final flow = NativeGoogleAuthFlow(
      selector: selector,
      exchangeIdToken: (_) async {},
      openBrowserFallback: () async {
        browserCalls++;
        return true;
      },
    );

    expect(await flow.signIn(), isTrue);
    expect(browserCalls, 1);
  });
}
