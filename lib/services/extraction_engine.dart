import 'dart:async';

typedef ExtractionCancellationHandler = FutureOr<void> Function();

/// Signals that an adapter does not implement this provider, as distinct from
/// a supported provider that failed to resolve the requested media.
class UnsupportedExtractionException implements Exception {
  const UnsupportedExtractionException();
}

/// An adapter owns its host rules; the coordinator never guesses a provider.
class ExtractorAdapter<T> {
  final String id;
  final bool Function(Uri) supports;
  final Future<T?> Function(Uri) extract;
  final ExtractionCancellationHandler? cancel;
  final Duration timeout;

  const ExtractorAdapter({
    required this.id,
    required this.supports,
    required this.extract,
    this.cancel,
    this.timeout = const Duration(seconds: 20),
  });
}

/// Request-scoped cancellation for the current adapter and late results.
class ExtractionRequest {
  bool _cancelled = false;
  final _cancelledSignal = Completer<void>();
  final Set<ExtractionCancellationHandler> _cancellationHandlers = {};

  bool get isCancelled => _cancelled;
  Future<void> get whenCancelled => _cancelledSignal.future;

  void addCancellationHandler(ExtractionCancellationHandler handler) {
    if (_cancelled) {
      _invokeCancellationHandler(handler);
      return;
    }
    _cancellationHandlers.add(handler);
  }

  void removeCancellationHandler(ExtractionCancellationHandler handler) {
    _cancellationHandlers.remove(handler);
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _cancelledSignal.complete();
    final handlers = List<ExtractionCancellationHandler>.of(
      _cancellationHandlers,
    );
    _cancellationHandlers.clear();
    for (final handler in handlers) {
      _invokeCancellationHandler(handler);
    }
  }

  static void _invokeCancellationHandler(
    ExtractionCancellationHandler handler,
  ) {
    unawaited(Future<void>.sync(handler).catchError((Object _) {}));
  }
}

enum ExtractionStatus { resolved, unsupported, failed, timedOut, cancelled }

class ExtractionResult<T> {
  final ExtractionStatus status;
  final T? value;
  final String? extractorId;
  const ExtractionResult(this.status, {this.value, this.extractorId});
}

/// Ordered, extensible extraction. No UI, media playback or persisted URL cache.
class ExtractionEngine<T> {
  final List<ExtractorAdapter<T>> adapters;
  ExtractionEngine(Iterable<ExtractorAdapter<T>> adapters)
    : adapters = List.unmodifiable(adapters) {
    if (this.adapters.map((a) => a.id).toSet().length != this.adapters.length) {
      throw ArgumentError('Extractor IDs must be unique');
    }
  }

  Future<ExtractionResult<T>> resolve(
    String url, {
    ExtractionRequest? request,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return const ExtractionResult(ExtractionStatus.unsupported);
    }
    var status = ExtractionStatus.unsupported;
    String? last;
    for (final adapter in adapters) {
      if (request?.isCancelled == true) {
        return const ExtractionResult(ExtractionStatus.cancelled);
      }
      if (!adapter.supports(uri)) continue;
      final outcome = await _runAdapter(adapter, uri, request);
      switch (outcome.kind) {
        case _AdapterAttemptKind.cancelled:
          return const ExtractionResult(ExtractionStatus.cancelled);
        case _AdapterAttemptKind.unsupported:
          // Do not report a provider miss as the last failed extractor.
          break;
        case _AdapterAttemptKind.timedOut:
          last = adapter.id;
          status = ExtractionStatus.timedOut;
          break;
        case _AdapterAttemptKind.failed:
          last = adapter.id;
          status = ExtractionStatus.failed;
          break;
        case _AdapterAttemptKind.completed:
          if (request?.isCancelled == true) {
            return const ExtractionResult(ExtractionStatus.cancelled);
          }
          final value = outcome.value;
          if (value != null) {
            return ExtractionResult(
              ExtractionStatus.resolved,
              value: value,
              extractorId: adapter.id,
            );
          }
          last = adapter.id;
          status = ExtractionStatus.failed;
          break;
      }
    }
    if (request?.isCancelled == true) {
      return const ExtractionResult(ExtractionStatus.cancelled);
    }
    return ExtractionResult(status, extractorId: last);
  }

  Future<_AdapterAttempt<T>> _runAdapter(
    ExtractorAdapter<T> adapter,
    Uri uri,
    ExtractionRequest? request,
  ) async {
    if (request?.isCancelled == true) {
      return const _AdapterAttempt.cancelled();
    }

    final completer = Completer<_AdapterAttempt<T>>();
    void complete(_AdapterAttempt<T> outcome) {
      if (!completer.isCompleted) completer.complete(outcome);
    }

    final cancel = adapter.cancel;
    var cancelInvoked = false;
    void cancelAdapter() {
      if (cancel == null || cancelInvoked) return;
      cancelInvoked = true;
      ExtractionRequest._invokeCancellationHandler(cancel);
    }

    if (cancel != null) request?.addCancellationHandler(cancelAdapter);
    final cancellationSubscription = request?.whenCancelled.then((_) {
      complete(const _AdapterAttempt.cancelled());
    });
    final timeout = Timer(adapter.timeout, () {
      complete(const _AdapterAttempt.timedOut());
    });

    try {
      if (request?.isCancelled == true) {
        cancelAdapter();
        return const _AdapterAttempt.cancelled();
      }
      Future<T?>.sync(() => adapter.extract(uri)).then<void>(
        (value) => complete(_AdapterAttempt.completed(value)),
        onError: (Object error, StackTrace _) {
          complete(
            error is UnsupportedExtractionException
                ? const _AdapterAttempt.unsupported()
                : const _AdapterAttempt.failed(),
          );
        },
      );
      final outcome = await completer.future;
      if (outcome.kind == _AdapterAttemptKind.timedOut) cancelAdapter();
      return outcome;
    } finally {
      timeout.cancel();
      if (cancel != null) request?.removeCancellationHandler(cancelAdapter);
      // Keep the cancellation future observed without retaining the request.
      unawaited(cancellationSubscription);
    }
  }
}

enum _AdapterAttemptKind { completed, failed, timedOut, cancelled, unsupported }

class _AdapterAttempt<T> {
  final _AdapterAttemptKind kind;
  final T? value;

  const _AdapterAttempt._(this.kind, [this.value]);
  const _AdapterAttempt.completed(T? value)
    : this._(_AdapterAttemptKind.completed, value);
  const _AdapterAttempt.failed() : this._(_AdapterAttemptKind.failed);
  const _AdapterAttempt.unsupported() : this._(_AdapterAttemptKind.unsupported);
  const _AdapterAttempt.timedOut() : this._(_AdapterAttemptKind.timedOut);
  const _AdapterAttempt.cancelled() : this._(_AdapterAttemptKind.cancelled);
}
