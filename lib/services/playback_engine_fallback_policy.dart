/// Failures that can reasonably be recovered by changing the decoding engine.
/// Source availability/authentication failures must continue through the
/// existing server fallback instead of retrying the same URL with mpv.
enum NativeEngineFallbackReason { unsupportedContainer, decoder }

class PlaybackEngineFallbackPolicy {
  const PlaybackEngineFallbackPolicy._();

  static NativeEngineFallbackReason? reasonFor(Object? error) {
    final value = error?.toString().toLowerCase().trim() ?? '';
    if (value.isEmpty || _isSourceFailure(value)) return null;

    if (_decoderMarkers.any(value.contains)) {
      return NativeEngineFallbackReason.decoder;
    }
    if (_containerMarkers.any(value.contains)) {
      return NativeEngineFallbackReason.unsupportedContainer;
    }
    return null;
  }

  static bool shouldTryMpv(Object? error) => reasonFor(error) != null;

  static bool _isSourceFailure(String value) {
    if (_sourceMarkers.any(value.contains)) return true;
    return RegExp(r'\b(401|403|404|408|429|5\d\d)\b').hasMatch(value);
  }

  static const _sourceMarkers = <String>[
    'socketexception',
    'failed host lookup',
    'no address associated',
    'connection refused',
    'connection reset',
    'network is unreachable',
    'timeout',
    'timed out',
    'httpdatasourceexception',
    'httpexception',
    'response code',
    'status code',
    'cleartext',
    'handshake',
    'certificate',
    'sslerror',
  ];

  static const _decoderMarkers = <String>[
    'decoderinitializationexception',
    'decoder init failed',
    'decoder initialization failed',
    'mediacodecrenderer',
    'mediacodec\$codecexception',
    'error_code_decoding',
    'unsupported codec',
  ];

  static const _containerMarkers = <String>[
    'unrecognizedinputformatexception',
    'none of the available extractors',
    'error_code_parsing_container_unsupported',
    'unsupported container format',
    'unsupported input format',
  ];
}
