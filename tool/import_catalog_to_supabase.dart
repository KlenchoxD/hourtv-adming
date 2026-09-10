// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:postgres/postgres.dart';

/// Importador administrativo directo a PostgreSQL local para Supabase.
/// Diseñado con defensa en profundidad: valida host/puerto antes de conectar,
/// opera en modo --dry-run por defecto y maneja transacciones atómicas.
class CatalogDirectImporter {
  /// Valida de forma estricta que el host y puerto apunten exclusivamente
  /// a la instancia de Supabase local de desarrollo.
  static void validateTargetHost(String host, int port) {
    final normalizedHost = host.trim().toLowerCase();
    if (normalizedHost != '127.0.0.1' && normalizedHost != 'localhost') {
      throw ArgumentError(
        'ACCESO DENEGADO: El importador solo puede ejecutarse contra Supabase local (127.0.0.1 o localhost). '
        'Se rechazó el intento de conexión a: $host',
      );
    }
    if (port != 54322) {
      throw ArgumentError(
        'ACCESO DENEGADO: Puerto PostgreSQL inválido ($port). Supabase local utiliza exclusivamente el puerto 54322.',
      );
    }
  }
}

Future<void> main(List<String> args) async {
  final isApply = args.contains('--apply');
  final isDryRun = !isApply || args.contains('--dry-run');

  final host = Platform.environment['LOCAL_SUPABASE_DB_HOST'] ?? '127.0.0.1';
  final port = int.tryParse(Platform.environment['LOCAL_SUPABASE_DB_PORT'] ?? '54322') ?? 54322;
  final user = Platform.environment['LOCAL_SUPABASE_DB_USER'] ?? 'postgres';
  final password = Platform.environment['LOCAL_SUPABASE_DB_PASSWORD'] ?? 'postgres';
  final database = 'postgres';

  print('=== HourTV Importador Administrativo Supabase Local ===');
  print('Modo: ${isDryRun ? "DRY-RUN (Simulación sin escritura)" : "APPLY (Escritura real)"}');

  // 1. Validación estricta de seguridad pre-conexión
  CatalogDirectImporter.validateTargetHost(host, port);
  print('Seguridad: Destino verificado como Supabase local ($host:$port).');

  // 2. Verificar existencia de fuentes o catálogo a importar
  final sourcesFile = File('assets/data/sources.json');
  if (!sourcesFile.existsSync()) {
    print('Aviso: No se encontró assets/data/sources.json para importar.');
    return;
  }

  print('Leyendo archivo de fuentes: ${sourcesFile.path} (${sourcesFile.lengthSync()} bytes)...');
  final content = jsonDecode(await sourcesFile.readAsString());
  final items = content is List ? content : (content['channels'] as List? ?? []);
  print('Total de elementos detectados: ${items.length}');

  if (isDryRun) {
    print('Simulación completada con éxito. Para aplicar los cambios en la base local, ejecute con --apply.');
    return;
  }

  // 3. Conexión segura a PostgreSQL local
  print('Conectando a PostgreSQL local...');
  final connection = await Connection.open(
    Endpoint(
      host: host,
      port: port,
      database: database,
      username: user,
      password: password,
    ),
    settings: const ConnectionSettings(sslMode: SslMode.disable),
  );

  try {
    print('Iniciando transacción de importación...');
    await connection.runTx((session) async {
      var importedTitles = 0;
      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;
        final name = item['name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;

        final titleId = item['tvgId']?.toString().trim().isNotEmpty == true
            ? item['tvgId'].toString().trim()
            : name;
        final normalized = name.toLowerCase().trim();
        final isMovie = item['forcedType'] == 'movie' ||
            item['url']?.toString().endsWith('.mp4') == true ||
            item['url']?.toString().endsWith('.mkv') == true;

        await session.execute(
          Sql.named('''
            INSERT INTO public.titles (id, media_type, title, normalized_title, is_published)
            VALUES (@id, @mediaType, @title, @normalized, true)
            ON CONFLICT (id) DO NOTHING;
          '''),
          parameters: {
            'id': titleId,
            'mediaType': isMovie ? 'movie' : 'series',
            'title': name,
            'normalized': normalized,
          },
        );
        importedTitles++;
      }
      print('Títulos importados en transacción: $importedTitles');
    });
    print('Transacción completada y confirmada (COMMIT).');
  } catch (e) {
    print('Error durante la importación: $e. Se aplicó ROLLBACK.');
    rethrow;
  } finally {
    await connection.close();
    print('Conexión cerrada.');
  }
}
