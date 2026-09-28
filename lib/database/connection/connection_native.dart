import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

QueryExecutor openMemoryExecutor() => NativeDatabase.memory();

QueryExecutor openFileExecutor(File file) =>
    NativeDatabase.createInBackground(file);

QueryExecutor openWebExecutor() =>
    throw UnsupportedError('La base web solo existe en el navegador');
