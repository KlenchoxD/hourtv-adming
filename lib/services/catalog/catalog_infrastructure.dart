import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../database/catalog_database.dart';
import '../catalog_parser.dart';
import '../supabase_bootstrap.dart';
import 'catalog_repository.dart';
import 'catalog_sync_engine.dart';
import 'supabase_catalog_gateway.dart';
import 'unavailable_catalog_gateway.dart';

/// Contenedor de las dependencias e infraestructura del catálogo local y sincronizado.
class CatalogInfrastructure {
  final CatalogDatabase database;
  final CatalogRepository repository;
  final SupabaseCatalogGateway? gateway;
  final CatalogSyncEngine? syncEngine;

  const CatalogInfrastructure({
    required this.database,
    required this.repository,
    this.gateway,
    this.syncEngine,
  });
}

/// Inicializa de forma resiliente la base de datos local SQLite (Drift) y el
/// repositorio de catálogo, desacoplado de si Supabase está configurado o no.
///
/// Soporta inyección completa de dependencias para testing sin tocar recursos remotos.
Future<CatalogInfrastructure> initializeCatalogInfrastructure({
  Future<Directory> Function()? documentsDirectoryProvider,
  File? databaseFile,
  CatalogDatabase? catalogDatabase,
  SupabaseBootstrap? bootstrap,
  SupabaseClient? supabaseClient,
  SupabaseCatalogGateway? gateway,
  CatalogSyncEngine? syncEngine,
  Future<CatalogPayload> Function()? fallbackPayloadLoader,
  void Function(String message, [Object? error])? logError,
  bool autoInitializeRepository = true,
}) async {
  // 1. Obtener cliente de Supabase de manera segura a través de SupabaseBootstrap
  final effectiveBootstrap = bootstrap ?? SupabaseBootstrap.instance;
  final effectiveClient = supabaseClient ?? effectiveBootstrap.client;

  // 2. Crear o usar base de datos Drift (siempre se crea, incluso sin Supabase)
  CatalogDatabase db;
  if (catalogDatabase != null) {
    db = catalogDatabase;
  } else {
    try {
      final File file;
      if (databaseFile != null) {
        file = databaseFile;
      } else {
        final dirProvider = documentsDirectoryProvider ?? getApplicationDocumentsDirectory;
        final dir = await dirProvider();
        file = File('${dir.path}/hourtv_catalog.db');
      }
      db = CatalogDatabase.inBackground(file);
    } catch (e, st) {
      _logSanitized(logError, 'Error al abrir base de datos de catálogo', e, st);
      rethrow;
    }
  }

  // 3. Configurar Gateway y SyncEngine según la disponibilidad del cliente Supabase
  SupabaseCatalogGateway? effectiveGateway = gateway;
  CatalogSyncEngine? effectiveSyncEngine = syncEngine;

  if (effectiveClient != null || gateway != null || syncEngine != null) {
    if (effectiveClient != null) {
      effectiveGateway ??= SupabaseCatalogGateway(effectiveClient);
    }
    if (effectiveGateway != null && effectiveGateway is! UnavailableCatalogGateway) {
      effectiveSyncEngine ??= CatalogSyncEngine(
        gateway: effectiveGateway,
        dao: db.catalogDao,
      );
    }
  } else {
    // Si no hay Supabase configurado, usar gateway no disponible y omitir sync remota
    effectiveGateway = UnavailableCatalogGateway();
    effectiveSyncEngine = null;
  }

  // 4. Construir y registrar CatalogRepository
  final repo = CatalogRepository(
    dao: db.catalogDao,
    gateway: effectiveGateway,
    syncEngine: effectiveSyncEngine,
    fallbackPayloadLoader: fallbackPayloadLoader ?? () => CatalogRepository.loadAssetSources(),
  );
  CatalogRepository.configureInstance(repo);

  // 5. Inicializar repositorio en segundo plano si está habilitado
  if (autoInitializeRepository) {
    unawaited(
      repo.initialize().catchError((error, stackTrace) {
        _logSanitized(logError, 'Error durante la inicialización del catálogo', error, stackTrace);
        return CatalogRepositoryStatus.failed;
      }),
    );
  }

  return CatalogInfrastructure(
    database: db,
    repository: repo,
    gateway: effectiveGateway,
    syncEngine: effectiveSyncEngine,
  );
}

void _logSanitized(
  void Function(String message, [Object? error])? customLogger,
  String message,
  Object? error,
  StackTrace? stackTrace,
) {
  final sanitized = error != null ? '$message: ${error.runtimeType}' : message;
  if (customLogger != null) {
    customLogger(sanitized, error);
  } else {
    debugPrint(sanitized);
    if (stackTrace != null && kDebugMode) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
