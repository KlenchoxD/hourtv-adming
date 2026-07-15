import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
      'https://www.effectivecpmnetwork.com/j4c4vxjm?key=02db82eac7ad89e5799436cbc25c9946';

  static bool shouldShowPreroll(Channel channel) {
    return channel.type != MediaType.live;
  }

  static bool get supportsWebView =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static bool allowsContainedNavigation(
    String url, {
    required String? lockedHost,
  }) {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return false;
    }
    if (lockedHost == null || lockedHost.isEmpty) return true;
    return uri.host.toLowerCase() == lockedHost.toLowerCase();
  }

  static Future<void> showPreroll(BuildContext context, Channel channel) async {
    if (!shouldShowPreroll(channel) || !context.mounted) return;
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
  int _secondsLeft = _waitSeconds;
  int _progress = 0;
  String? _loadError;
  String? _lockedHost;

  bool get _canSkip => _secondsLeft == 0;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    if (widget.useWebView) _createWebView();
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

  void _createWebView() {
    try {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) {
              return AdService.allowsContainedNavigation(
                    request.url,
                    lockedHost: _lockedHost,
                  )
                  ? NavigationDecision.navigate
                  : NavigationDecision.prevent;
            },
            onProgress: (progress) {
              if (mounted) setState(() => _progress = progress);
            },
            onPageFinished: (url) {
              final host = Uri.tryParse(url)?.host;
              if (mounted) {
                setState(() {
                  _progress = 100;
                  if (host?.isNotEmpty == true) _lockedHost ??= host;
                });
              }
            },
            onWebResourceError: (error) {
              if (error.isForMainFrame == false || !mounted) return;
              setState(() => _loadError = 'No se pudo cargar la publicidad.');
            },
          ),
        )
        ..loadRequest(Uri.parse(AdService.smartlink));
    } catch (_) {
      _controller = null;
      _loadError = 'Espacio publicitario';
    }
  }

  void _close() {
    if (_canSkip) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _skipFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return PopScope(
      canPop: _canSkip,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (controller != null)
              WebViewWidget(controller: controller)
            else
              _fallback(),
            if (_progress < 100 && controller != null)
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

class InlineAdBanner extends StatefulWidget {
  const InlineAdBanner({super.key});

  @override
  State<InlineAdBanner> createState() => _InlineAdBannerState();
}

class _InlineAdBannerState extends State<InlineAdBanner> {
  WebViewController? _controller;
  int _progress = 0;
  bool _loadError = false;
  String? _lockedHost;

  @override
  void initState() {
    super.initState();
    if (AdService.supportsWebView) _createController();
  }

  void _createController() {
    try {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(AppColors.cardDark)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) {
              return AdService.allowsContainedNavigation(
                    request.url,
                    lockedHost: _lockedHost,
                  )
                  ? NavigationDecision.navigate
                  : NavigationDecision.prevent;
            },
            onProgress: (progress) {
              if (mounted) setState(() => _progress = progress);
            },
            onPageFinished: (url) {
              final host = Uri.tryParse(url)?.host;
              if (mounted) {
                setState(() {
                  _progress = 100;
                  if (host?.isNotEmpty == true) _lockedHost ??= host;
                });
              }
            },
            onWebResourceError: (error) {
              if (error.isForMainFrame == false || !mounted) return;
              setState(() => _loadError = true);
            },
          ),
        )
        ..loadRequest(Uri.parse(AdService.smartlink));
    } catch (_) {
      _controller = null;
      _loadError = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
      child: Semantics(
        label: 'Publicidad',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 96,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: AppColors.cardDark,
                  child: controller != null && !_loadError
                      ? WebViewWidget(controller: controller)
                      : const Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.campaign_rounded,
                                color: AppColors.accent,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Espacio publicitario',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                if (_progress < 100 && controller != null)
                  Align(
                    alignment: Alignment.topCenter,
                    child: LinearProgressIndicator(
                      value: _progress == 0 ? null : _progress / 100,
                      minHeight: 2,
                      color: AppColors.accent,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                const Positioned(
                  top: 7,
                  left: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.all(Radius.circular(5)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      child: Text(
                        'PUBLICIDAD',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
