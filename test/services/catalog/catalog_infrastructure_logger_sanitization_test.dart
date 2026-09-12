import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/database/daos/catalog_dao.dart';
import 'package:streamtv/services/catalog/catalog_dtos.dart';
import 'package:streamtv/services/catalog/catalog_infrastructure.dart';
import 'package:streamtv/services/supabase_bootstrap.dart';

class _SensitiveSecretException implements Exception {
  final String secretUrl = 'https://my-project.supabase.co/rest/v1?apikey=sbp_secret_999&token=eyJhbGciOi';
  final String connectionString = 'postgresql://postgres:secret_pass_123@db.supabase.co:5432/postgres';

  @override
  String toString() => 'SensitiveException(url: $secretUrl, conn: $connectionString)';
}

class _FailingCatalogDao extends CatalogDao {
  _FailingCatalogDao(super.db);

  @override
  Future<List<LocalTitle>> getPage({
    int limit = 20,
    DateTime? cursorCreatedAt,
    String? cursorId,
    String? mediaType,
    int? year,
    String? genreSlug,
    CatalogSortOrder sort = CatalogSortOrder.recent,
  }) {
    throw _SensitiveSecretException();
  }
}

class _FailingDatabase extends CatalogDatabase {
  _FailingDatabase() : super(NativeDatabase.memory());

  @override
  CatalogDao get catalogDao => _FailingCatalogDao(this);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P2 Security: Logger de inicialización de catálogo sanitizado', () {
    test('El callback logError recibe únicamente String? para errorType y jamás el objeto de error crudo al inicializar repositorio', () async {
      final List<String> capturedMessages = [];
      final List<dynamic> capturedErrorArgs = [];

      final bootstrap = SupabaseBootstrap.forTest();
      final failingDb = _FailingDatabase();

      await initializeCatalogInfrastructure(
        catalogDatabase: failingDb,
        bootstrap: bootstrap,
        logError: (String message, [String? errorType]) {
          capturedMessages.add(message);
          capturedErrorArgs.add(errorType);
        },
        autoInitializeRepository: true,
      );

      await pumpEventQueue();

      expect(capturedMessages, isNotEmpty);
      expect(capturedErrorArgs, isNotEmpty);

      for (final rawArg in capturedErrorArgs) {
        expect(rawArg, isA<String?>());
        expect(rawArg, isNot(isA<Exception>()));
        expect(rawArg, equals('_SensitiveSecretException'));
      }

      for (final msg in capturedMessages) {
        expect(msg, contains('Error durante la inicialización del catálogo: _SensitiveSecretException'));
        expect(msg, isNot(contains('https://')));
        expect(msg, isNot(contains('apikey=')));
        expect(msg, isNot(contains('token=')));
        expect(msg, isNot(contains('secret_pass_123')));
        expect(msg, isNot(contains('postgresql://')));
      }

      await failingDb.close();
    });

    test('Error al abrir la base de datos tampoco entrega el objeto crudo al logger', () async {
      final List<dynamic> capturedErrorArgs = [];
      final List<String> capturedMessages = [];

      expect(
        () async => initializeCatalogInfrastructure(
          documentsDirectoryProvider: () async {
            throw _SensitiveSecretException();
          },
          bootstrap: SupabaseBootstrap.forTest(),
          logError: (String message, [String? errorType]) {
            capturedMessages.add(message);
            capturedErrorArgs.add(errorType);
          },
          autoInitializeRepository: false,
        ),
        throwsA(isA<_SensitiveSecretException>()),
      );

      await pumpEventQueue();

      expect(capturedMessages, isNotEmpty);
      expect(capturedErrorArgs, isNotEmpty);
      for (final rawArg in capturedErrorArgs) {
        expect(rawArg, isA<String?>());
        expect(rawArg, isNot(isA<Exception>()));
        expect(rawArg, equals('_SensitiveSecretException'));
      }
    });
  });
}
