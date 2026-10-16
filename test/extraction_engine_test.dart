import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/services/extraction_engine.dart';

void main() {
  ExtractorAdapter<String> adapter(
    String id,
    Future<String?> Function(Uri) run, {
    Duration timeout = const Duration(seconds: 1),
    ExtractionCancellationHandler? cancel,
  }) => ExtractorAdapter(
    id: id,
    supports: (_) => true,
    extract: run,
    cancel: cancel,
    timeout: timeout,
  );

  test('tries adapters in order and stops on success', () async {
    final calls = <String>[];
    final engine = ExtractionEngine<String>([
      adapter('one', (_) async {
        calls.add('one');
        return null;
      }),
      adapter('two', (_) async {
        calls.add('two');
        return 'stream';
      }),
      adapter('three', (_) async {
        calls.add('three');
        return 'wrong';
      }),
    ]);
    final result = await engine.resolve('https://example.test/e/1');
    expect(result.value, 'stream');
    expect(result.extractorId, 'two');
    expect(calls, ['one', 'two']);
  });

  test('failed adapter cannot prevent the next adapter', () async {
    final result = await ExtractionEngine<String>([
      adapter('broken', (_) async => throw StateError('failure')),
      adapter('working', (_) async => 'stream'),
    ]).resolve('https://example.test/');
    expect(result.value, 'stream');
  });

  test(
    'unsupported adapter miss stays unsupported and has no false owner',
    () async {
      final result = await ExtractionEngine<String>([
        adapter(
          'unrecognized-provider',
          (_) async => throw const UnsupportedExtractionException(),
        ),
      ]).resolve('https://example.test/');

      expect(result.status, ExtractionStatus.unsupported);
      expect(result.extractorId, isNull);
    },
  );

  test('unsupported adapter continues to a later provider', () async {
    final result = await ExtractionEngine<String>([
      adapter(
        'unrecognized-provider',
        (_) async => throw const UnsupportedExtractionException(),
      ),
      adapter('supported-provider', (_) async => 'stream'),
    ]).resolve('https://example.test/');

    expect(result.status, ExtractionStatus.resolved);
    expect(result.extractorId, 'supported-provider');
    expect(result.value, 'stream');
  });

  test('timeout advances to next adapter', () async {
    final pending = Completer<String?>();
    var cancelled = 0;
    final result = await ExtractionEngine<String>([
      adapter(
        'slow',
        (_) => pending.future,
        timeout: const Duration(milliseconds: 1),
        cancel: () {
          cancelled++;
        },
      ),
      adapter('working', (_) async => 'stream'),
    ]).resolve('https://example.test/');
    expect(result.value, 'stream');
    expect(cancelled, 1);
    pending.complete('late');
  });

  test('late results after cancellation are discarded', () async {
    final pending = Completer<String?>();
    final request = ExtractionRequest();
    final future = ExtractionEngine<String>([
      adapter('pending', (_) => pending.future),
    ]).resolve('https://example.test/', request: request);
    request.cancel();
    pending.complete('stale');
    expect((await future).status, ExtractionStatus.cancelled);
  });

  test('request cancellation interrupts the active adapter', () async {
    final pending = Completer<String?>();
    final request = ExtractionRequest();
    var cancelled = 0;
    final future = ExtractionEngine<String>([
      adapter(
        'pending',
        (_) => pending.future,
        cancel: () {
          cancelled++;
        },
      ),
    ]).resolve('https://example.test/', request: request);

    request.cancel();
    final result = await future.timeout(const Duration(milliseconds: 100));

    expect(result.status, ExtractionStatus.cancelled);
    expect(cancelled, 1);
    pending.complete('stale');
  });

  test('duplicate adapter IDs are rejected', () {
    expect(
      () => ExtractionEngine<String>([
        adapter('same', (_) async => null),
        adapter('same', (_) async => null),
      ]),
      throwsArgumentError,
    );
  });

  for (final url in [
    'blob:https://example.test/id',
    'file:///tmp/a',
    'https://user:secret@example.test/',
    'invalid',
  ]) {
    test('rejects invalid input $url', () async {
      final engine = ExtractionEngine<String>([
        adapter('never', (_) async => fail('must not execute')),
      ]);
      expect((await engine.resolve(url)).status, ExtractionStatus.unsupported);
    });
  }
}
