/// Estados del ciclo de vida del motor de sincronización.
enum SyncStatus {
  idle,
  checkingMetadata,
  fetchingChanges,
  applyingChanges,
  fullResyncing,
  completed,
  error,
}

/// Resultado devuelto tras ejecutar un ciclo de sincronización incremental o completa.
class SyncResult {
  final int initialRevision;
  final int finalRevision;
  final int appliedChangesCount;
  final bool fullResyncPerformed;
  final String? errorMessage;

  const SyncResult({
    required this.initialRevision,
    required this.finalRevision,
    this.appliedChangesCount = 0,
    this.fullResyncPerformed = false,
    this.errorMessage,
  });

  bool get hasChanges => appliedChangesCount > 0 || fullResyncPerformed;

  @override
  String toString() =>
      'SyncResult(initialRev: $initialRevision, finalRev: $finalRevision, applied: $appliedChangesCount, fullResync: $fullResyncPerformed, error: $errorMessage)';
}
