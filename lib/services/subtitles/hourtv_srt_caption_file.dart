import 'package:video_player/video_player.dart';

/// Implementación de ClosedCaptionFile para subtítulos SRT (SubRip).
/// Permite alimentar directamente `VideoPlayerController.setClosedCaptionFile`
/// sin duplicar el overlay existente ni mantener dos motores de reproducción de cues.
class HourTvSrtCaptionFile extends ClosedCaptionFile {
  final List<Caption> _captions;

  HourTvSrtCaptionFile(String srtContent) : _captions = _parseSrt(srtContent);

  @override
  List<Caption> get captions => _captions;

  static List<Caption> _parseSrt(String srt) {
    final trimmed = srt.trim();
    if (trimmed.isEmpty) return const [];

    // Rechazar payloads HTML o JSON
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('<!doctype html') ||
        lower.startsWith('<html') ||
        lower.startsWith('{') ||
        lower.startsWith('[')) {
      throw const FormatException('Contenido no corresponde a formato SRT válido');
    }

    final captions = <Caption>[];
    // Normalizar saltos de línea y separar por bloques vacíos
    final normalized = trimmed.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final blocks = normalized.split(RegExp(r'\n\s*\n'));

    for (final block in blocks) {
      final lines = block.trim().split('\n');
      if (lines.length < 2) continue;

      // Buscar la línea de tiempo con formato 00:00:00,000 --> 00:00:00,000
      int timeLineIdx = -1;
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('-->')) {
          timeLineIdx = i;
          break;
        }
      }

      if (timeLineIdx == -1) continue;

      final timeParts = lines[timeLineIdx].split('-->');
      if (timeParts.length != 2) continue;

      final start = _parseSrtTimestamp(timeParts[0].trim());
      final end = _parseSrtTimestamp(timeParts[1].trim().split(' ')[0]);

      if (start == null || end == null) continue;

      final textLines = lines.sublist(timeLineIdx + 1);
      final text = textLines.join('\n').trim();

      if (text.isNotEmpty) {
        captions.add(
          Caption(
            number: captions.length + 1,
            start: start,
            end: end,
            text: text,
          ),
        );
      }
    }

    if (captions.isEmpty && trimmed.isNotEmpty) {
      throw const FormatException('No se encontraron bloques SRT válidos en el archivo');
    }

    return captions;
  }

  static Duration? _parseSrtTimestamp(String timestamp) {
    // Formato hh:mm:ss,ms o mm:ss,ms
    final regExp = RegExp(r'(?:(\d{1,2}):)?(\d{1,2}):(\d{1,2})[,.](\d{1,3})');
    final match = regExp.firstMatch(timestamp);
    if (match == null) return null;

    final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
    final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;
    var millis = int.tryParse(match.group(4) ?? '0') ?? 0;
    // Pad milisegundos si vienen de 1 o 2 dígitos
    final rawMillis = match.group(4) ?? '';
    if (rawMillis.length == 1) millis *= 100;
    if (rawMillis.length == 2) millis *= 10;

    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: millis,
    );
  }
}
