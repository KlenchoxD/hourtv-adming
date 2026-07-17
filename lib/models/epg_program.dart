class EpgProgram {
  final String channelId;
  final String title;
  final String? description;
  final DateTime start;
  final DateTime stop;

  const EpgProgram({
    required this.channelId,
    required this.title,
    this.description,
    required this.start,
    required this.stop,
  });

  bool isOnAt(DateTime time) => !time.isBefore(start) && time.isBefore(stop);

  String get timeRange {
    String fmt(DateTime d) {
      final local = d.toLocal();
      final h = local.hour.toString().padLeft(2, '0');
      final m = local.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    return '${fmt(start)} - ${fmt(stop)}';
  }
}
