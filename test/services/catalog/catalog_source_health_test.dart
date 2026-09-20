import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/services/catalog/catalog_dtos.dart';

void main() {
  test('CatalogSourceDto parses complete source health telemetry', () {
    final source = CatalogSourceDto.fromJson({
      'id': 'source-1',
      'name': 'VOE',
      'url': 'https://example.com/embed/1',
      'health_status': 'degraded',
      'health_last_error': 'timeout',
      'health_http_code': 504,
      'health_consecutive_failures': 2,
      'health_first_failure_at': '2026-09-20T10:00:00Z',
      'health_last_success_at': '2026-09-20T09:00:00Z',
      'health_last_check': '2026-09-20T10:05:00Z',
      'health_last_check_run_id': 'run-1',
    });

    expect(source.healthStatus, 'degraded');
    expect(source.healthLastError, 'timeout');
    expect(source.healthHttpCode, 504);
    expect(source.healthConsecutiveFailures, 2);
    expect(source.healthFirstFailureAt, DateTime.utc(2026, 9, 20, 10));
    expect(source.healthLastSuccessAt, DateTime.utc(2026, 9, 20, 9));
    expect(source.healthLastCheck, DateTime.utc(2026, 9, 20, 10, 5));
    expect(source.healthLastCheckRunId, 'run-1');
  });

  test('CatalogSourceDto gives legacy sources safe pending defaults', () {
    final source = CatalogSourceDto.fromJson({
      'id': 'source-legacy',
      'name': 'Legacy',
      'url': 'https://example.com/legacy',
    });

    expect(source.healthStatus, 'pending');
    expect(source.healthConsecutiveFailures, 0);
    expect(source.healthLastCheck, isNull);
  });
}
