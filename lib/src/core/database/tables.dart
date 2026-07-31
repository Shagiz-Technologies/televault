import 'package:drift/drift.dart';

// 1. The Buckets Table (Your Private Channels)
class Buckets extends Table {
  IntColumn get id => integer().autoIncrement()();
  Int64Column get chatId => int64()(); // Telegram Chat IDs are huge
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get allowedMediaTypes =>
      text().withDefault(const Constant('photo,video'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// 2. The Files Table (The Virtual File System)
class Files extends Table {
  IntColumn get id => integer().autoIncrement()();

  // Local Metadata
  TextColumn get localPath => text()(); // /storage/emulated/0/DCIM/...
  TextColumn get assetId => text().nullable()(); // ID from PhotoManager
  TextColumn get folderName => text()(); // "Camera", "Vacation"
  TextColumn get fileHash => text().nullable()(); // SHA-256 for deduplication
  IntColumn get size => integer()(); // In bytes

  // Telegram Metadata
  IntColumn get bucketId => integer().references(Buckets, #id)();
  IntColumn get telegramMessageId =>
      integer().nullable()(); // Null = not uploaded yet
  IntColumn get telegramFileId => integer().nullable()();

  // Status tracking
  // 0 = Pending, 1 = Uploading, 2 = Synced, 3 = Failed,
  // 4 = Deleted Local, 5 = Vaulted Encrypted
  IntColumn get status => integer().withDefault(const Constant(0))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  IntColumn get telegramErrorCode => integer().nullable()();
  TextColumn get telegramErrorCategory => text().nullable()();
  DateTimeColumn get telegramRetryAfter => dateTime().nullable()();
  TextColumn get lastTelegramOperation => text().nullable()();
  BoolColumn get userActionRequired =>
      boolean().withDefault(const Constant(false))();

  // Security
  BoolColumn get isVaulted => boolean().withDefault(const Constant(false))();
  BoolColumn get isEncrypted => boolean().withDefault(const Constant(false))();
  IntColumn get encryptionVersion => integer().nullable()();
  TextColumn get ivB64 => text().nullable()();
  DateTimeColumn get deletedLocallyAt => dateTime().nullable()();
  IntColumn get labelId => integer().nullable().references(Labels, #id)();

  DateTimeColumn get dateAdded => dateTime().withDefault(currentDateAndTime)();

  // Enforce unique paths per bucket to avoid duplicates
  @override
  List<Set<Column>> get uniqueKeys => [
    {localPath, bucketId},
  ];
}

class Labels extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 11)();
  TextColumn get colorHex => text().withDefault(const Constant('#0A84FF'))();
  TextColumn get emoji => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// 3. Settings (Key-Value Store for simple preferences)
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

class TelegramAccountStates extends Table {
  Int64Column get accountId => int64()();
  BoolColumn get isPremium => boolean().withDefault(const Constant(false))();
  DateTimeColumn get premiumUpdatedAt => dateTime().nullable()();
  DateTimeColumn get serverRetryUntil => dateTime().nullable()();
  DateTimeColumn get writeBlockedUntil => dateTime().nullable()();
  TextColumn get pauseReason => text().nullable()();
  BoolColumn get isPremiumFloodWait =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {accountId};
}
