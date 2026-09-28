import 'dart:io' show File;

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

QueryExecutor openMemoryExecutor() =>
    throw UnsupportedError('En el navegador no hay base en memoria');

QueryExecutor openFileExecutor(File file) =>
    throw UnsupportedError('En el navegador no hay archivos');

// SQLite compilado a WebAssembly; guarda en el almacenamiento del navegador
// (OPFS o IndexedDB). sqlite3.wasm y drift_worker.js viven en web/ y deben
// coincidir con las versiones de sqlite3 y drift de pubspec.lock.
QueryExecutor openWebExecutor() => driftDatabase(
  name: 'hourtv_catalog',
  web: DriftWebOptions(
    sqlite3Wasm: Uri.parse('sqlite3.wasm'),
    driftWorker: Uri.parse('drift_worker.js'),
  ),
);
