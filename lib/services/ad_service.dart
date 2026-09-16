import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/channel.dart';
import '../theme/app_theme.dart';

/// Punto único para los anuncios previos a contenido bajo demanda.
///
/// En vivo nunca pasa por el preroll. El proveedor puede sustituirse aquí sin
/// repartir lógica publicitaria por las distintas pantallas de la aplicación.
class AdService {
  AdService._();

  static const smartlink =
      'https://www.profitableratecpmnetwork.com/j4c4vxjm?key=02db82eac7ad89e5799436cbc25c9946';

  static bool shouldShowPreroll(Channel channel) {
    return channel.type != MediaType.live;
  }

  static bool get supportsWebView =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static bool isSmartlinkProvider(String? host) {
    if (host == null || host.isEmpty) return false;
    final h = host.toLowerCase();
    final smartHost = Uri.parse(smartlink).host.toLowerCase();
    return h == smartHost || h.endsWith('.profitableratecpmnetwork.com');
  }

  static bool allowsContainedNavigation(
    String url, {
    required String? lockedHost,
  }) {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return false;
    }
    if (lockedHost == null || lockedHost.isEmpty) return true;
    final host = uri.host.toLowerCase();
    final locked = lockedHost.toLowerCase();
    if (host == locked) return true;
    if (isSmartlinkProvider(locked)) return true;
    return false;
  }

  static String sanitizeHost(String url) {
    return Uri.tryParse(url)?.host.toLowerCase() ?? 'unknown';
  }

  static Future<void> showPreroll(BuildContext context, Channel channel) async {
    if (!shouldShowPreroll(channel) || !context.mounted) return;
    debugPrint('[ADS] preroll_requested');
    await Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 140),
        pageBuilder: (_, _, _) => _PrerollScreen(useWebView: supportsWebView),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }
}

/// Controla la frecuencia del preroll durante una sola instancia del
/// reproductor. Cambiar episodio, servidor o mirror no crea otra sesión.
class PrerollSession {
  bool _shown = false;

  bool takeIfNeeded(Channel channel) {
    if (_shown || !AdService.shouldShowPreroll(channel)) return false;
    _shown = true;
    return true;
  }
}

class _PrerollScreen extends StatefulWidget {
  final bool useWebView;

  const _PrerollScreen({required this.useWebView});

  @override
  State<_PrerollScreen> createState() => _PrerollScreenState();
}

class _PrerollScreenState extends State<_PrerollScreen> {
  static const _waitSeconds = 5;

  final _skipFocus = FocusNode();
  WebViewController? _controller;
  Timer? _timer;
  Timer? _loadTimeout;
  int _secondsLeft = _waitSeconds;
  int _progress = 0;
  String? _loadError;
  String? _lockedHost;
  bool _adReady = false;

  bool get _canSkip => _secondsLeft == 0;

  @override
  void initState() {
    super.initState();
    if (widget.useWebView) {
      _createWebView();
      // Timeout tolerante de 10s: permite la cadena de redirecciones del
      // Smartlink en conexiones móviles sin desmontar prematuramente el WebView.
      _loadTimeout = Timer(const Duration(seconds: 10), () {
        if (mounted && _progress < 100 && _loadError == null) {
          debugPrint('[ADS] timeout');
          setState(() => _loadError = 'Espacio publicitario');
          _beginSkipCountdown();
        }
      });
    } else {
      // En plataformas sin WebView se muestra el fallback; el contador empieza
      // aquí porque no existe una carga publicitaria que esperar.
      _beginSkipCountdown();
    }
  }

  // OK / Enter / centro del D-pad saltan el anuncio cuando ya se puede.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !_canSkip) return KeyEventResult.ignored;
    final skipKeys = {
      LogicalKeyboardKey.select,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
      LogicalKeyboardKey.gameButtonA,
      LogicalKeyboardKey.space,
    };
    if (skipKeys.contains(event.logicalKey)) {
      _close();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _skipFocus.requestFocus();
        });
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _beginSkipCountdown() {
    if (_adReady || !mounted) return;
    _adReady = true;
    _startCountdown();
  }

  void _createWebView() {
    try {
      debugPrint('[ADS] webview_created');
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) {
              final allowed = AdService.allowsContainedNavigation(
                request.url,
                lockedHost: _lockedHost,
              );
              if (!allowed) {
                debugPrint(
                  '[ADS] navigation_blocked host=${AdService.sanitizeHost(request.url)}',
                );
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
            onPageStarted: (url) {
              debugPrint(
                '[ADS] navigation_started host=${AdService.sanitizeHost(url)}',
              );
            },
            onProgress: (progress) {
              if (mounted) setState(() => _progress = progress);
            },
            onPageFinished: (url) {
              final host = Uri.tryParse(url)?.host;
              debugPrint(
                '[ADS] page_finished host=${AdService.sanitizeHost(url)}',
              );
              if (mounted) {
                setState(() {
                  _progress = 100;
                  // No fijar lockedHost al intermediario de redirecciones
                  // del Smartlink; permitir que llegue a la landing final.
                  if (host != null &&
                      host.isNotEmpty &&
                      !AdService.isSmartlinkProvider(host)) {
                    _lockedHost ??= host;
                  }
                });
                _beginSkipCountdown();
              }
            },
            onWebResourceError: (error) {
              debugPrint('[ADS] webview_error code=${error.errorCode}');
              if (error.isForMainFrame == false || !mounted) return;
              setState(() => _loadError = 'No se pudo cargar la publicidad.');
            },
          ),
        )
        ..loadRequest(Uri.parse(AdService.smartlink));
    } catch (_) {
      _controller = null;
      _loadError = 'Espacio publicitario';
      _beginSkipCountdown();
    }
  }

  void _close() {
    if (_canSkip) {
      debugPrint('[ADS] preroll_closed');
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _loadTimeout?.cancel();
    _skipFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: PopScope(
        canPop: _canSkip,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (controller != null && _loadError == null)
                WebViewWidget(controller: controller)
              else
                _fallback(),
              if (_progress < 100 && controller != null && _loadError == null)
                Align(
                  alignment: Alignment.topCenter,
                  child: LinearProgressIndicator(
                    value: _progress == 0 ? null : _progress / 100,
                    minHeight: 2,
                    color: AppColors.accent,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Focus(
                      focusNode: _skipFocus,
                      child: ElevatedButton.icon(
                        onPressed: _canSkip ? _close : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.black.withValues(
                            alpha: 0.72,
                          ),
                          disabledForegroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 11,
                          ),
                        ),
                        icon: Icon(
                          _canSkip
                              ? Icons.skip_next_rounded
                              : Icons.hourglass_top_rounded,
                          size: 19,
                        ),
                        label: Text(
                          _canSkip ? 'Saltar' : 'Saltar en $_secondsLeft s',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 150, 0),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.66),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        child: Text(
                          'PUBLICIDAD',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallback() {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign_rounded, color: AppColors.accent, size: 58),
            const SizedBox(height: 14),
            Text(
              _loadError ?? 'Espacio publicitario',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'La reproducción continuará en unos segundos.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
