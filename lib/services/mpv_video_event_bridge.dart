import 'dart:async';

import 'package:flutter/services.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// Buffers native events until video_player subscribes, including errors that
/// occur before metadata exists. Independent of libmpv so lifecycle is testable.
class MpvVideoEventBridge {
  MpvVideoEventBridge({required this.isLive});

  final bool isLive;
  final _events = StreamController<VideoEvent>();
  bool _initialized = false;
  bool _disposed = false;

  Stream<VideoEvent> get stream => _events.stream;

  void emit(VideoEvent event) {
    if (!_disposed) _events.add(event);
  }

  void reportError(Object error) {
    if (!_disposed) {
      _events.addError(
        PlatformException(code: 'VideoError', message: error.toString()),
      );
    }
  }

  void notifyMetadata({
    required Duration duration,
    int? width,
    int? height,
    bool audioOnly = false,
  }) {
    if (_initialized || _disposed) return;
    final hasVideo = (width ?? 0) > 0 && (height ?? 0) > 0;
    if ((!hasVideo && !audioOnly) || (!isLive && duration <= Duration.zero)) {
      return;
    }
    _initialized = true;
    emit(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: duration,
        size: hasVideo
            ? Size(width!.toDouble(), height!.toDouble())
            : Size.zero,
      ),
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final hadListener = _events.hasListener;
    final closed = _events.close();
    // A single-subscription stream with no listener cannot deliver `done`.
    // Disposal must not wait for a controller that was never initialized.
    if (hadListener) await closed;
  }
}
