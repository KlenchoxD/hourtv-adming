import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Busca, descarga e instala actualizaciones reales desde los Releases de
/// GitHub del repo de HourTV. Sin datos falsos: si no hay conexion, no hay
/// release publicado, o el release no trae un .apk, se informa el motivo
/// real en vez de simular un resultado.
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.notes,
    required this.sizeBytes,
  });

  final String version;
  final String downloadUrl;
  final String notes;
  final int sizeBytes;
}

sealed class UpdateCheckResult {
  const UpdateCheckResult();
}

class UpdateAvailable extends UpdateCheckResult {
  const UpdateAvailable(this.info);
  final UpdateInfo info;
}

class UpToDate extends UpdateCheckResult {
  const UpToDate();
}

class UpdateCheckFailed extends UpdateCheckResult {
  const UpdateCheckFailed(this.reason);
  final String reason;
}

class UpdateService {
  UpdateService._();
  static final instance = UpdateService._();

  static const _owner = 'KlenchoxD';
  static const _repo = 'hourtv-adming';

  /// Punto verde en el icono de "Perfil" de la barra inferior mientras haya
  /// una actualización sin revisar: se apaga en cuanto la persona entra a
  /// la pantalla de Actualizaciones, no cuando termina de instalarla (ya
  /// vio el aviso, la decisión de actualizar ahora es suya).
  final ValueNotifier<bool> hasUpdateAvailable = ValueNotifier<bool>(false);

  Future<UpdateCheckResult> checkForUpdate() async {
    final http.Response response;
    try {
      response = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/$_owner/$_repo/releases/latest',
            ),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      return const UpdateCheckFailed(
        'No se pudo conectar a GitHub. Revisa tu conexión a internet.',
      );
    }
    if (response.statusCode == 404) {
      return const UpdateCheckFailed(
        'Todavía no hay ninguna versión publicada en GitHub Releases.',
      );
    }
    if (response.statusCode != 200) {
      return UpdateCheckFailed(
        'GitHub respondió con un error (${response.statusCode}).',
      );
    }
    // Todo el parseo va dentro del try. Antes los accesos al JSON estaban
    // fuera y cualquier campo ausente o con otro tipo lanzaba una excepcion
    // sin capturar, dejando la pantalla clavada en "Buscando…" para siempre.
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String? ?? '').trim();
      final remoteVersion = tag.startsWith('v') ? tag.substring(1) : tag;
      if (remoteVersion.isEmpty) {
        return const UpdateCheckFailed(
          'El último release no tiene una versión válida.',
        );
      }
      final assets = (json['assets'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      Map<String, dynamic>? apkAsset;
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        final url = asset['browser_download_url'];
        if (name.endsWith('.apk') && url is String && url.isNotEmpty) {
          apkAsset = asset;
          break;
        }
      }
      if (apkAsset == null) {
        return const UpdateCheckFailed(
          'El último release no incluye un archivo .apk descargable.',
        );
      }

      final packageInfo = await PackageInfo.fromPlatform();
      if (!_isNewer(remoteVersion, packageInfo.version)) {
        return const UpToDate();
      }
      return UpdateAvailable(
        UpdateInfo(
          version: remoteVersion,
          downloadUrl: apkAsset['browser_download_url'] as String,
          notes: (json['body'] as String? ?? '').trim(),
          sizeBytes: (apkAsset['size'] as num?)?.toInt() ?? 0,
        ),
      );
    } catch (error) {
      return UpdateCheckFailed(
        'No se pudo leer la información del release: $error',
      );
    }
  }

  /// true si [remote] es una version mayor que [current] (semver simple,
  /// sin sufijos de prerelease).
  bool _isNewer(String remote, String current) {
    List<int> parts(String value) => value
        .split('+')
        .first
        .split('.')
        .map((part) => int.tryParse(part.trim()) ?? 0)
        .toList();
    final remoteParts = parts(remote);
    final currentParts = parts(current);
    final length = remoteParts.length > currentParts.length
        ? remoteParts.length
        : currentParts.length;
    for (var i = 0; i < length; i++) {
      final r = i < remoteParts.length ? remoteParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (r != c) return r > c;
    }
    return false;
  }

  /// Descarga el APK reportando progreso 0.0-1.0. Lanza si falla la red o
  /// la escritura a disco; el llamador decide como mostrar el error.
  ///
  /// Solo emite cuando el progreso avanza al menos 1% (y siempre el 100%
  /// final): antes emitia por cada trozo HTTP (~2400 veces en un APK de
  /// 19 MB), lo que provocaba miles de repintados y trababa la TV justo
  /// mientras descargaba.
  Stream<double> download(UpdateInfo info, String savePath) async* {
    final request = http.Request('GET', Uri.parse(info.downloadUrl));
    final client = http.Client();
    try {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw Exception('Descarga falló (HTTP ${response.statusCode}).');
      }
      final total = response.contentLength ?? info.sizeBytes;
      final file = File(savePath);
      final sink = file.openWrite();
      var received = 0;
      var lastReported = -1;
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total <= 0) continue;
          final percent = (received * 100 ~/ total).clamp(0, 100);
          if (percent != lastReported) {
            lastReported = percent;
            yield percent / 100;
          }
        }
      } finally {
        await sink.close();
      }
    } finally {
      client.close();
    }
  }

  Future<String> preparedDownloadPath(String version) async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/hourtv-$version.apk';
  }

  /// Abre el APK descargado con el instalador del sistema (pide permiso de
  /// "instalar apps desconocidas" si aun no fue concedido).
  Future<OpenResult> install(String filePath) => OpenFilex.open(filePath);
}
