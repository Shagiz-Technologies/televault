enum FileSyncStatus {
  pending,
  uploading,
  synced,
  failed,
  deletedLocal,
  vaultedEncrypted,
}

extension FileSyncStatusDb on FileSyncStatus {
  int get dbValue => switch (this) {
    FileSyncStatus.pending => 0,
    FileSyncStatus.uploading => 1,
    FileSyncStatus.synced => 2,
    FileSyncStatus.failed => 3,
    FileSyncStatus.deletedLocal => 4,
    FileSyncStatus.vaultedEncrypted => 5,
  };
}

FileSyncStatus fileSyncStatusFromDb(int value) {
  return switch (value) {
    0 => FileSyncStatus.pending,
    1 => FileSyncStatus.uploading,
    2 => FileSyncStatus.synced,
    3 => FileSyncStatus.failed,
    4 => FileSyncStatus.deletedLocal,
    5 => FileSyncStatus.vaultedEncrypted,
    _ => FileSyncStatus.pending,
  };
}
