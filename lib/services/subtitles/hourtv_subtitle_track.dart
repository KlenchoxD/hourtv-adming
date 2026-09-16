/// Formato soportado del archivo de subtítulos.
enum SubtitleFormat { vtt, srt, ass, unsupported }

/// Origen o procedencia de la pista de subtítulos.
enum SubtitleProvenance { sidecar, hlsEmbedded, mp4Embedded }

/// Modelo formal de pista de subtítulos para HourTV.
class HourTvSubtitleTrack {
  final String id;
  final String label;
  final String languageCode;
  final String? url;
  final SubtitleFormat format;
  final String? sourceId;
  final SubtitleProvenance provenance;
  final bool isHlsMediaPlaylist;
  final Map<String, String> requiredHeaders;
  final String charset;
  final bool hearingImpaired;
  final bool isForced;
  final bool isDefault;
  final bool isAuto;

  const HourTvSubtitleTrack({
    required this.id,
    required this.label,
    required this.languageCode,
    this.url,
    this.format = SubtitleFormat.vtt,
    this.sourceId,
    this.provenance = SubtitleProvenance.sidecar,
    this.isHlsMediaPlaylist = false,
    this.requiredHeaders = const {},
    this.charset = 'utf-8',
    this.hearingImpaired = false,
    this.isForced = false,
    this.isDefault = false,
    this.isAuto = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'languageCode': languageCode,
    'url': url,
    'format': format.name,
    'sourceId': sourceId,
    'provenance': provenance.name,
    'isHlsMediaPlaylist': isHlsMediaPlaylist,
    'requiredHeaders': requiredHeaders,
    'charset': charset,
    'hearingImpaired': hearingImpaired,
    'isForced': isForced,
    'isDefault': isDefault,
    'isAuto': isAuto,
  };

  factory HourTvSubtitleTrack.fromJson(Map<String, dynamic> json) {
    final formatName = json['format']?.toString().toLowerCase();
    final provenanceName = json['provenance']?.toString();
    return HourTvSubtitleTrack(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? 'Subtítulo',
      languageCode: (json['languageCode'] ?? json['language'] ?? 'und')
          .toString(),
      url: json['url']?.toString(),
      format: SubtitleFormat.values.firstWhere(
        (value) => value.name == formatName,
        orElse: () => formatName == 'webvtt'
            ? SubtitleFormat.vtt
            : SubtitleFormat.unsupported,
      ),
      sourceId: json['sourceId']?.toString(),
      provenance: SubtitleProvenance.values.firstWhere(
        (value) => value.name == provenanceName,
        orElse: () => SubtitleProvenance.sidecar,
      ),
      isHlsMediaPlaylist: json['isHlsMediaPlaylist'] == true,
      requiredHeaders:
          (json['requiredHeaders'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ) ??
          const {},
      charset: json['charset']?.toString() ?? 'utf-8',
      hearingImpaired: json['hearingImpaired'] == true,
      isForced: json['isForced'] == true,
      isDefault: json['isDefault'] == true,
      isAuto: json['isAuto'] == true,
    );
  }

  /// Pista canónica para desactivar subtítulos.
  static const HourTvSubtitleTrack off = HourTvSubtitleTrack(
    id: 'off',
    label: 'Desactivados',
    languageCode: 'off',
  );

  /// Pista canónica para selección automática según perfil.
  static const HourTvSubtitleTrack auto = HourTvSubtitleTrack(
    id: 'auto',
    label: 'Automático',
    languageCode: 'auto',
    isAuto: true,
  );
}
