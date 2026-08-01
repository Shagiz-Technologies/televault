// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $BucketsTable extends Buckets with TableInfo<$BucketsTable, Bucket> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BucketsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _chatIdMeta = const VerificationMeta('chatId');
  @override
  late final GeneratedColumn<BigInt> chatId = GeneratedColumn<BigInt>(
    'chat_id',
    aliasedName,
    false,
    type: DriftSqlType.bigInt,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 50,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _allowedMediaTypesMeta = const VerificationMeta(
    'allowedMediaTypes',
  );
  @override
  late final GeneratedColumn<String> allowedMediaTypes =
      GeneratedColumn<String>(
        'allowed_media_types',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('photo,video'),
      );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    chatId,
    name,
    allowedMediaTypes,
    isActive,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'buckets';
  @override
  VerificationContext validateIntegrity(
    Insertable<Bucket> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('chat_id')) {
      context.handle(
        _chatIdMeta,
        chatId.isAcceptableOrUnknown(data['chat_id']!, _chatIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chatIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('allowed_media_types')) {
      context.handle(
        _allowedMediaTypesMeta,
        allowedMediaTypes.isAcceptableOrUnknown(
          data['allowed_media_types']!,
          _allowedMediaTypesMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Bucket map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Bucket(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      chatId: attachedDatabase.typeMapping.read(
        DriftSqlType.bigInt,
        data['${effectivePrefix}chat_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      allowedMediaTypes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}allowed_media_types'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BucketsTable createAlias(String alias) {
    return $BucketsTable(attachedDatabase, alias);
  }
}

class Bucket extends DataClass implements Insertable<Bucket> {
  final int id;
  final BigInt chatId;
  final String name;
  final String allowedMediaTypes;
  final bool isActive;
  final DateTime createdAt;
  const Bucket({
    required this.id,
    required this.chatId,
    required this.name,
    required this.allowedMediaTypes,
    required this.isActive,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['chat_id'] = Variable<BigInt>(chatId);
    map['name'] = Variable<String>(name);
    map['allowed_media_types'] = Variable<String>(allowedMediaTypes);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BucketsCompanion toCompanion(bool nullToAbsent) {
    return BucketsCompanion(
      id: Value(id),
      chatId: Value(chatId),
      name: Value(name),
      allowedMediaTypes: Value(allowedMediaTypes),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
    );
  }

  factory Bucket.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Bucket(
      id: serializer.fromJson<int>(json['id']),
      chatId: serializer.fromJson<BigInt>(json['chatId']),
      name: serializer.fromJson<String>(json['name']),
      allowedMediaTypes: serializer.fromJson<String>(json['allowedMediaTypes']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'chatId': serializer.toJson<BigInt>(chatId),
      'name': serializer.toJson<String>(name),
      'allowedMediaTypes': serializer.toJson<String>(allowedMediaTypes),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Bucket copyWith({
    int? id,
    BigInt? chatId,
    String? name,
    String? allowedMediaTypes,
    bool? isActive,
    DateTime? createdAt,
  }) => Bucket(
    id: id ?? this.id,
    chatId: chatId ?? this.chatId,
    name: name ?? this.name,
    allowedMediaTypes: allowedMediaTypes ?? this.allowedMediaTypes,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
  );
  Bucket copyWithCompanion(BucketsCompanion data) {
    return Bucket(
      id: data.id.present ? data.id.value : this.id,
      chatId: data.chatId.present ? data.chatId.value : this.chatId,
      name: data.name.present ? data.name.value : this.name,
      allowedMediaTypes: data.allowedMediaTypes.present
          ? data.allowedMediaTypes.value
          : this.allowedMediaTypes,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Bucket(')
          ..write('id: $id, ')
          ..write('chatId: $chatId, ')
          ..write('name: $name, ')
          ..write('allowedMediaTypes: $allowedMediaTypes, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, chatId, name, allowedMediaTypes, isActive, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bucket &&
          other.id == this.id &&
          other.chatId == this.chatId &&
          other.name == this.name &&
          other.allowedMediaTypes == this.allowedMediaTypes &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt);
}

class BucketsCompanion extends UpdateCompanion<Bucket> {
  final Value<int> id;
  final Value<BigInt> chatId;
  final Value<String> name;
  final Value<String> allowedMediaTypes;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  const BucketsCompanion({
    this.id = const Value.absent(),
    this.chatId = const Value.absent(),
    this.name = const Value.absent(),
    this.allowedMediaTypes = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  BucketsCompanion.insert({
    this.id = const Value.absent(),
    required BigInt chatId,
    required String name,
    this.allowedMediaTypes = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : chatId = Value(chatId),
       name = Value(name);
  static Insertable<Bucket> custom({
    Expression<int>? id,
    Expression<BigInt>? chatId,
    Expression<String>? name,
    Expression<String>? allowedMediaTypes,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (chatId != null) 'chat_id': chatId,
      if (name != null) 'name': name,
      if (allowedMediaTypes != null) 'allowed_media_types': allowedMediaTypes,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  BucketsCompanion copyWith({
    Value<int>? id,
    Value<BigInt>? chatId,
    Value<String>? name,
    Value<String>? allowedMediaTypes,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
  }) {
    return BucketsCompanion(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      name: name ?? this.name,
      allowedMediaTypes: allowedMediaTypes ?? this.allowedMediaTypes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (chatId.present) {
      map['chat_id'] = Variable<BigInt>(chatId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (allowedMediaTypes.present) {
      map['allowed_media_types'] = Variable<String>(allowedMediaTypes.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BucketsCompanion(')
          ..write('id: $id, ')
          ..write('chatId: $chatId, ')
          ..write('name: $name, ')
          ..write('allowedMediaTypes: $allowedMediaTypes, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $LabelsTable extends Labels with TableInfo<$LabelsTable, Label> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LabelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 11,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorHexMeta = const VerificationMeta(
    'colorHex',
  );
  @override
  late final GeneratedColumn<String> colorHex = GeneratedColumn<String>(
    'color_hex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('#0A84FF'),
  );
  static const VerificationMeta _emojiMeta = const VerificationMeta('emoji');
  @override
  late final GeneratedColumn<String> emoji = GeneratedColumn<String>(
    'emoji',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, colorHex, emoji, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'labels';
  @override
  VerificationContext validateIntegrity(
    Insertable<Label> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_hex')) {
      context.handle(
        _colorHexMeta,
        colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta),
      );
    }
    if (data.containsKey('emoji')) {
      context.handle(
        _emojiMeta,
        emoji.isAcceptableOrUnknown(data['emoji']!, _emojiMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Label map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Label(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_hex'],
      )!,
      emoji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emoji'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LabelsTable createAlias(String alias) {
    return $LabelsTable(attachedDatabase, alias);
  }
}

class Label extends DataClass implements Insertable<Label> {
  final int id;
  final String name;
  final String colorHex;
  final String? emoji;
  final DateTime createdAt;
  const Label({
    required this.id,
    required this.name,
    required this.colorHex,
    this.emoji,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['color_hex'] = Variable<String>(colorHex);
    if (!nullToAbsent || emoji != null) {
      map['emoji'] = Variable<String>(emoji);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LabelsCompanion toCompanion(bool nullToAbsent) {
    return LabelsCompanion(
      id: Value(id),
      name: Value(name),
      colorHex: Value(colorHex),
      emoji: emoji == null && nullToAbsent
          ? const Value.absent()
          : Value(emoji),
      createdAt: Value(createdAt),
    );
  }

  factory Label.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Label(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      colorHex: serializer.fromJson<String>(json['colorHex']),
      emoji: serializer.fromJson<String?>(json['emoji']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'colorHex': serializer.toJson<String>(colorHex),
      'emoji': serializer.toJson<String?>(emoji),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Label copyWith({
    int? id,
    String? name,
    String? colorHex,
    Value<String?> emoji = const Value.absent(),
    DateTime? createdAt,
  }) => Label(
    id: id ?? this.id,
    name: name ?? this.name,
    colorHex: colorHex ?? this.colorHex,
    emoji: emoji.present ? emoji.value : this.emoji,
    createdAt: createdAt ?? this.createdAt,
  );
  Label copyWithCompanion(LabelsCompanion data) {
    return Label(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      emoji: data.emoji.present ? data.emoji.value : this.emoji,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Label(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorHex: $colorHex, ')
          ..write('emoji: $emoji, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, colorHex, emoji, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Label &&
          other.id == this.id &&
          other.name == this.name &&
          other.colorHex == this.colorHex &&
          other.emoji == this.emoji &&
          other.createdAt == this.createdAt);
}

class LabelsCompanion extends UpdateCompanion<Label> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> colorHex;
  final Value<String?> emoji;
  final Value<DateTime> createdAt;
  const LabelsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.emoji = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  LabelsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.colorHex = const Value.absent(),
    this.emoji = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Label> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? colorHex,
    Expression<String>? emoji,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colorHex != null) 'color_hex': colorHex,
      if (emoji != null) 'emoji': emoji,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  LabelsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? colorHex,
    Value<String?>? emoji,
    Value<DateTime>? createdAt,
  }) {
    return LabelsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      emoji: emoji ?? this.emoji,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<String>(colorHex.value);
    }
    if (emoji.present) {
      map['emoji'] = Variable<String>(emoji.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LabelsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorHex: $colorHex, ')
          ..write('emoji: $emoji, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $FilesTable extends Files with TableInfo<$FilesTable, File> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPathResolvedMeta = const VerificationMeta(
    'localPathResolved',
  );
  @override
  late final GeneratedColumn<bool> localPathResolved = GeneratedColumn<bool>(
    'local_path_resolved',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("local_path_resolved" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _localMediaAccessStateMeta =
      const VerificationMeta('localMediaAccessState');
  @override
  late final GeneratedColumn<String> localMediaAccessState =
      GeneratedColumn<String>(
        'local_media_access_state',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('available'),
      );
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _folderNameMeta = const VerificationMeta(
    'folderName',
  );
  @override
  late final GeneratedColumn<String> folderName = GeneratedColumn<String>(
    'folder_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileHashMeta = const VerificationMeta(
    'fileHash',
  );
  @override
  late final GeneratedColumn<String> fileHash = GeneratedColumn<String>(
    'file_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bucketIdMeta = const VerificationMeta(
    'bucketId',
  );
  @override
  late final GeneratedColumn<int> bucketId = GeneratedColumn<int>(
    'bucket_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES buckets (id)',
    ),
  );
  static const VerificationMeta _telegramMessageIdMeta = const VerificationMeta(
    'telegramMessageId',
  );
  @override
  late final GeneratedColumn<int> telegramMessageId = GeneratedColumn<int>(
    'telegram_message_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _telegramFileIdMeta = const VerificationMeta(
    'telegramFileId',
  );
  @override
  late final GeneratedColumn<int> telegramFileId = GeneratedColumn<int>(
    'telegram_file_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _uploadOperationIdMeta = const VerificationMeta(
    'uploadOperationId',
  );
  @override
  late final GeneratedColumn<String> uploadOperationId =
      GeneratedColumn<String>(
        'upload_operation_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _remoteStateVerifiedMeta =
      const VerificationMeta('remoteStateVerified');
  @override
  late final GeneratedColumn<bool> remoteStateVerified = GeneratedColumn<bool>(
    'remote_state_verified',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("remote_state_verified" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextRetryAtMeta = const VerificationMeta(
    'nextRetryAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextRetryAt = GeneratedColumn<DateTime>(
    'next_retry_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>(
        'last_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _telegramErrorCodeMeta = const VerificationMeta(
    'telegramErrorCode',
  );
  @override
  late final GeneratedColumn<int> telegramErrorCode = GeneratedColumn<int>(
    'telegram_error_code',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _telegramErrorCategoryMeta =
      const VerificationMeta('telegramErrorCategory');
  @override
  late final GeneratedColumn<String> telegramErrorCategory =
      GeneratedColumn<String>(
        'telegram_error_category',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _telegramRetryAfterMeta =
      const VerificationMeta('telegramRetryAfter');
  @override
  late final GeneratedColumn<DateTime> telegramRetryAfter =
      GeneratedColumn<DateTime>(
        'telegram_retry_after',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastTelegramOperationMeta =
      const VerificationMeta('lastTelegramOperation');
  @override
  late final GeneratedColumn<String> lastTelegramOperation =
      GeneratedColumn<String>(
        'last_telegram_operation',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _userActionRequiredMeta =
      const VerificationMeta('userActionRequired');
  @override
  late final GeneratedColumn<bool> userActionRequired = GeneratedColumn<bool>(
    'user_action_required',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("user_action_required" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isVaultedMeta = const VerificationMeta(
    'isVaulted',
  );
  @override
  late final GeneratedColumn<bool> isVaulted = GeneratedColumn<bool>(
    'is_vaulted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_vaulted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isEncryptedMeta = const VerificationMeta(
    'isEncrypted',
  );
  @override
  late final GeneratedColumn<bool> isEncrypted = GeneratedColumn<bool>(
    'is_encrypted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_encrypted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _encryptionVersionMeta = const VerificationMeta(
    'encryptionVersion',
  );
  @override
  late final GeneratedColumn<int> encryptionVersion = GeneratedColumn<int>(
    'encryption_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ivB64Meta = const VerificationMeta('ivB64');
  @override
  late final GeneratedColumn<String> ivB64 = GeneratedColumn<String>(
    'iv_b64',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vaultFormatVersionMeta =
      const VerificationMeta('vaultFormatVersion');
  @override
  late final GeneratedColumn<int> vaultFormatVersion = GeneratedColumn<int>(
    'vault_format_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _encryptedObjectIdMeta = const VerificationMeta(
    'encryptedObjectId',
  );
  @override
  late final GeneratedColumn<String> encryptedObjectId =
      GeneratedColumn<String>(
        'encrypted_object_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _encryptedSizeMeta = const VerificationMeta(
    'encryptedSize',
  );
  @override
  late final GeneratedColumn<int> encryptedSize = GeneratedColumn<int>(
    'encrypted_size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originalSizeMeta = const VerificationMeta(
    'originalSize',
  );
  @override
  late final GeneratedColumn<int> originalSize = GeneratedColumn<int>(
    'original_size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vaultIntegrityStatusMeta =
      const VerificationMeta('vaultIntegrityStatus');
  @override
  late final GeneratedColumn<String> vaultIntegrityStatus =
      GeneratedColumn<String>(
        'vault_integrity_status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('unknown'),
      );
  static const VerificationMeta _vaultMigrationStatusMeta =
      const VerificationMeta('vaultMigrationStatus');
  @override
  late final GeneratedColumn<String> vaultMigrationStatus =
      GeneratedColumn<String>(
        'vault_migration_status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('notRequired'),
      );
  static const VerificationMeta _keyWrappingVersionMeta =
      const VerificationMeta('keyWrappingVersion');
  @override
  late final GeneratedColumn<int> keyWrappingVersion = GeneratedColumn<int>(
    'key_wrapping_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastVerifiedAtMeta = const VerificationMeta(
    'lastVerifiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastVerifiedAt =
      GeneratedColumn<DateTime>(
        'last_verified_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _deletedLocallyAtMeta = const VerificationMeta(
    'deletedLocallyAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedLocallyAt =
      GeneratedColumn<DateTime>(
        'deleted_locally_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _labelIdMeta = const VerificationMeta(
    'labelId',
  );
  @override
  late final GeneratedColumn<int> labelId = GeneratedColumn<int>(
    'label_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES labels (id)',
    ),
  );
  static const VerificationMeta _dateAddedMeta = const VerificationMeta(
    'dateAdded',
  );
  @override
  late final GeneratedColumn<DateTime> dateAdded = GeneratedColumn<DateTime>(
    'date_added',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    localPath,
    localPathResolved,
    localMediaAccessState,
    assetId,
    folderName,
    fileHash,
    size,
    bucketId,
    telegramMessageId,
    telegramFileId,
    uploadOperationId,
    remoteStateVerified,
    status,
    retryCount,
    lastError,
    nextRetryAt,
    lastAttemptAt,
    telegramErrorCode,
    telegramErrorCategory,
    telegramRetryAfter,
    lastTelegramOperation,
    userActionRequired,
    isVaulted,
    isEncrypted,
    encryptionVersion,
    ivB64,
    vaultFormatVersion,
    encryptedObjectId,
    encryptedSize,
    originalSize,
    vaultIntegrityStatus,
    vaultMigrationStatus,
    keyWrappingVersion,
    lastVerifiedAt,
    deletedLocallyAt,
    labelId,
    dateAdded,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'files';
  @override
  VerificationContext validateIntegrity(
    Insertable<File> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    } else if (isInserting) {
      context.missing(_localPathMeta);
    }
    if (data.containsKey('local_path_resolved')) {
      context.handle(
        _localPathResolvedMeta,
        localPathResolved.isAcceptableOrUnknown(
          data['local_path_resolved']!,
          _localPathResolvedMeta,
        ),
      );
    }
    if (data.containsKey('local_media_access_state')) {
      context.handle(
        _localMediaAccessStateMeta,
        localMediaAccessState.isAcceptableOrUnknown(
          data['local_media_access_state']!,
          _localMediaAccessStateMeta,
        ),
      );
    }
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    }
    if (data.containsKey('folder_name')) {
      context.handle(
        _folderNameMeta,
        folderName.isAcceptableOrUnknown(data['folder_name']!, _folderNameMeta),
      );
    } else if (isInserting) {
      context.missing(_folderNameMeta);
    }
    if (data.containsKey('file_hash')) {
      context.handle(
        _fileHashMeta,
        fileHash.isAcceptableOrUnknown(data['file_hash']!, _fileHashMeta),
      );
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('bucket_id')) {
      context.handle(
        _bucketIdMeta,
        bucketId.isAcceptableOrUnknown(data['bucket_id']!, _bucketIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bucketIdMeta);
    }
    if (data.containsKey('telegram_message_id')) {
      context.handle(
        _telegramMessageIdMeta,
        telegramMessageId.isAcceptableOrUnknown(
          data['telegram_message_id']!,
          _telegramMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('telegram_file_id')) {
      context.handle(
        _telegramFileIdMeta,
        telegramFileId.isAcceptableOrUnknown(
          data['telegram_file_id']!,
          _telegramFileIdMeta,
        ),
      );
    }
    if (data.containsKey('upload_operation_id')) {
      context.handle(
        _uploadOperationIdMeta,
        uploadOperationId.isAcceptableOrUnknown(
          data['upload_operation_id']!,
          _uploadOperationIdMeta,
        ),
      );
    }
    if (data.containsKey('remote_state_verified')) {
      context.handle(
        _remoteStateVerifiedMeta,
        remoteStateVerified.isAcceptableOrUnknown(
          data['remote_state_verified']!,
          _remoteStateVerifiedMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('next_retry_at')) {
      context.handle(
        _nextRetryAtMeta,
        nextRetryAt.isAcceptableOrUnknown(
          data['next_retry_at']!,
          _nextRetryAtMeta,
        ),
      );
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('telegram_error_code')) {
      context.handle(
        _telegramErrorCodeMeta,
        telegramErrorCode.isAcceptableOrUnknown(
          data['telegram_error_code']!,
          _telegramErrorCodeMeta,
        ),
      );
    }
    if (data.containsKey('telegram_error_category')) {
      context.handle(
        _telegramErrorCategoryMeta,
        telegramErrorCategory.isAcceptableOrUnknown(
          data['telegram_error_category']!,
          _telegramErrorCategoryMeta,
        ),
      );
    }
    if (data.containsKey('telegram_retry_after')) {
      context.handle(
        _telegramRetryAfterMeta,
        telegramRetryAfter.isAcceptableOrUnknown(
          data['telegram_retry_after']!,
          _telegramRetryAfterMeta,
        ),
      );
    }
    if (data.containsKey('last_telegram_operation')) {
      context.handle(
        _lastTelegramOperationMeta,
        lastTelegramOperation.isAcceptableOrUnknown(
          data['last_telegram_operation']!,
          _lastTelegramOperationMeta,
        ),
      );
    }
    if (data.containsKey('user_action_required')) {
      context.handle(
        _userActionRequiredMeta,
        userActionRequired.isAcceptableOrUnknown(
          data['user_action_required']!,
          _userActionRequiredMeta,
        ),
      );
    }
    if (data.containsKey('is_vaulted')) {
      context.handle(
        _isVaultedMeta,
        isVaulted.isAcceptableOrUnknown(data['is_vaulted']!, _isVaultedMeta),
      );
    }
    if (data.containsKey('is_encrypted')) {
      context.handle(
        _isEncryptedMeta,
        isEncrypted.isAcceptableOrUnknown(
          data['is_encrypted']!,
          _isEncryptedMeta,
        ),
      );
    }
    if (data.containsKey('encryption_version')) {
      context.handle(
        _encryptionVersionMeta,
        encryptionVersion.isAcceptableOrUnknown(
          data['encryption_version']!,
          _encryptionVersionMeta,
        ),
      );
    }
    if (data.containsKey('iv_b64')) {
      context.handle(
        _ivB64Meta,
        ivB64.isAcceptableOrUnknown(data['iv_b64']!, _ivB64Meta),
      );
    }
    if (data.containsKey('vault_format_version')) {
      context.handle(
        _vaultFormatVersionMeta,
        vaultFormatVersion.isAcceptableOrUnknown(
          data['vault_format_version']!,
          _vaultFormatVersionMeta,
        ),
      );
    }
    if (data.containsKey('encrypted_object_id')) {
      context.handle(
        _encryptedObjectIdMeta,
        encryptedObjectId.isAcceptableOrUnknown(
          data['encrypted_object_id']!,
          _encryptedObjectIdMeta,
        ),
      );
    }
    if (data.containsKey('encrypted_size')) {
      context.handle(
        _encryptedSizeMeta,
        encryptedSize.isAcceptableOrUnknown(
          data['encrypted_size']!,
          _encryptedSizeMeta,
        ),
      );
    }
    if (data.containsKey('original_size')) {
      context.handle(
        _originalSizeMeta,
        originalSize.isAcceptableOrUnknown(
          data['original_size']!,
          _originalSizeMeta,
        ),
      );
    }
    if (data.containsKey('vault_integrity_status')) {
      context.handle(
        _vaultIntegrityStatusMeta,
        vaultIntegrityStatus.isAcceptableOrUnknown(
          data['vault_integrity_status']!,
          _vaultIntegrityStatusMeta,
        ),
      );
    }
    if (data.containsKey('vault_migration_status')) {
      context.handle(
        _vaultMigrationStatusMeta,
        vaultMigrationStatus.isAcceptableOrUnknown(
          data['vault_migration_status']!,
          _vaultMigrationStatusMeta,
        ),
      );
    }
    if (data.containsKey('key_wrapping_version')) {
      context.handle(
        _keyWrappingVersionMeta,
        keyWrappingVersion.isAcceptableOrUnknown(
          data['key_wrapping_version']!,
          _keyWrappingVersionMeta,
        ),
      );
    }
    if (data.containsKey('last_verified_at')) {
      context.handle(
        _lastVerifiedAtMeta,
        lastVerifiedAt.isAcceptableOrUnknown(
          data['last_verified_at']!,
          _lastVerifiedAtMeta,
        ),
      );
    }
    if (data.containsKey('deleted_locally_at')) {
      context.handle(
        _deletedLocallyAtMeta,
        deletedLocallyAt.isAcceptableOrUnknown(
          data['deleted_locally_at']!,
          _deletedLocallyAtMeta,
        ),
      );
    }
    if (data.containsKey('label_id')) {
      context.handle(
        _labelIdMeta,
        labelId.isAcceptableOrUnknown(data['label_id']!, _labelIdMeta),
      );
    }
    if (data.containsKey('date_added')) {
      context.handle(
        _dateAddedMeta,
        dateAdded.isAcceptableOrUnknown(data['date_added']!, _dateAddedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {localPath, bucketId},
  ];
  @override
  File map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return File(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      )!,
      localPathResolved: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}local_path_resolved'],
      )!,
      localMediaAccessState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_media_access_state'],
      )!,
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      ),
      folderName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_name'],
      )!,
      fileHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_hash'],
      ),
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      bucketId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bucket_id'],
      )!,
      telegramMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}telegram_message_id'],
      ),
      telegramFileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}telegram_file_id'],
      ),
      uploadOperationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}upload_operation_id'],
      ),
      remoteStateVerified: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}remote_state_verified'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      nextRetryAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_retry_at'],
      ),
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt_at'],
      ),
      telegramErrorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}telegram_error_code'],
      ),
      telegramErrorCategory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}telegram_error_category'],
      ),
      telegramRetryAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}telegram_retry_after'],
      ),
      lastTelegramOperation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_telegram_operation'],
      ),
      userActionRequired: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}user_action_required'],
      )!,
      isVaulted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_vaulted'],
      )!,
      isEncrypted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_encrypted'],
      )!,
      encryptionVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}encryption_version'],
      ),
      ivB64: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}iv_b64'],
      ),
      vaultFormatVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}vault_format_version'],
      ),
      encryptedObjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_object_id'],
      ),
      encryptedSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}encrypted_size'],
      ),
      originalSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}original_size'],
      ),
      vaultIntegrityStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vault_integrity_status'],
      )!,
      vaultMigrationStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vault_migration_status'],
      )!,
      keyWrappingVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}key_wrapping_version'],
      ),
      lastVerifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_verified_at'],
      ),
      deletedLocallyAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_locally_at'],
      ),
      labelId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}label_id'],
      ),
      dateAdded: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date_added'],
      )!,
    );
  }

  @override
  $FilesTable createAlias(String alias) {
    return $FilesTable(attachedDatabase, alias);
  }
}

class File extends DataClass implements Insertable<File> {
  final int id;
  final String localPath;
  final bool localPathResolved;
  final String localMediaAccessState;
  final String? assetId;
  final String folderName;
  final String? fileHash;
  final int size;
  final int bucketId;
  final int? telegramMessageId;
  final int? telegramFileId;
  final String? uploadOperationId;
  final bool remoteStateVerified;
  final int status;
  final int retryCount;
  final String? lastError;
  final DateTime? nextRetryAt;
  final DateTime? lastAttemptAt;
  final int? telegramErrorCode;
  final String? telegramErrorCategory;
  final DateTime? telegramRetryAfter;
  final String? lastTelegramOperation;
  final bool userActionRequired;
  final bool isVaulted;
  final bool isEncrypted;
  final int? encryptionVersion;
  final String? ivB64;
  final int? vaultFormatVersion;
  final String? encryptedObjectId;
  final int? encryptedSize;
  final int? originalSize;
  final String vaultIntegrityStatus;
  final String vaultMigrationStatus;
  final int? keyWrappingVersion;
  final DateTime? lastVerifiedAt;
  final DateTime? deletedLocallyAt;
  final int? labelId;
  final DateTime dateAdded;
  const File({
    required this.id,
    required this.localPath,
    required this.localPathResolved,
    required this.localMediaAccessState,
    this.assetId,
    required this.folderName,
    this.fileHash,
    required this.size,
    required this.bucketId,
    this.telegramMessageId,
    this.telegramFileId,
    this.uploadOperationId,
    required this.remoteStateVerified,
    required this.status,
    required this.retryCount,
    this.lastError,
    this.nextRetryAt,
    this.lastAttemptAt,
    this.telegramErrorCode,
    this.telegramErrorCategory,
    this.telegramRetryAfter,
    this.lastTelegramOperation,
    required this.userActionRequired,
    required this.isVaulted,
    required this.isEncrypted,
    this.encryptionVersion,
    this.ivB64,
    this.vaultFormatVersion,
    this.encryptedObjectId,
    this.encryptedSize,
    this.originalSize,
    required this.vaultIntegrityStatus,
    required this.vaultMigrationStatus,
    this.keyWrappingVersion,
    this.lastVerifiedAt,
    this.deletedLocallyAt,
    this.labelId,
    required this.dateAdded,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['local_path'] = Variable<String>(localPath);
    map['local_path_resolved'] = Variable<bool>(localPathResolved);
    map['local_media_access_state'] = Variable<String>(localMediaAccessState);
    if (!nullToAbsent || assetId != null) {
      map['asset_id'] = Variable<String>(assetId);
    }
    map['folder_name'] = Variable<String>(folderName);
    if (!nullToAbsent || fileHash != null) {
      map['file_hash'] = Variable<String>(fileHash);
    }
    map['size'] = Variable<int>(size);
    map['bucket_id'] = Variable<int>(bucketId);
    if (!nullToAbsent || telegramMessageId != null) {
      map['telegram_message_id'] = Variable<int>(telegramMessageId);
    }
    if (!nullToAbsent || telegramFileId != null) {
      map['telegram_file_id'] = Variable<int>(telegramFileId);
    }
    if (!nullToAbsent || uploadOperationId != null) {
      map['upload_operation_id'] = Variable<String>(uploadOperationId);
    }
    map['remote_state_verified'] = Variable<bool>(remoteStateVerified);
    map['status'] = Variable<int>(status);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || nextRetryAt != null) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt);
    }
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    if (!nullToAbsent || telegramErrorCode != null) {
      map['telegram_error_code'] = Variable<int>(telegramErrorCode);
    }
    if (!nullToAbsent || telegramErrorCategory != null) {
      map['telegram_error_category'] = Variable<String>(telegramErrorCategory);
    }
    if (!nullToAbsent || telegramRetryAfter != null) {
      map['telegram_retry_after'] = Variable<DateTime>(telegramRetryAfter);
    }
    if (!nullToAbsent || lastTelegramOperation != null) {
      map['last_telegram_operation'] = Variable<String>(lastTelegramOperation);
    }
    map['user_action_required'] = Variable<bool>(userActionRequired);
    map['is_vaulted'] = Variable<bool>(isVaulted);
    map['is_encrypted'] = Variable<bool>(isEncrypted);
    if (!nullToAbsent || encryptionVersion != null) {
      map['encryption_version'] = Variable<int>(encryptionVersion);
    }
    if (!nullToAbsent || ivB64 != null) {
      map['iv_b64'] = Variable<String>(ivB64);
    }
    if (!nullToAbsent || vaultFormatVersion != null) {
      map['vault_format_version'] = Variable<int>(vaultFormatVersion);
    }
    if (!nullToAbsent || encryptedObjectId != null) {
      map['encrypted_object_id'] = Variable<String>(encryptedObjectId);
    }
    if (!nullToAbsent || encryptedSize != null) {
      map['encrypted_size'] = Variable<int>(encryptedSize);
    }
    if (!nullToAbsent || originalSize != null) {
      map['original_size'] = Variable<int>(originalSize);
    }
    map['vault_integrity_status'] = Variable<String>(vaultIntegrityStatus);
    map['vault_migration_status'] = Variable<String>(vaultMigrationStatus);
    if (!nullToAbsent || keyWrappingVersion != null) {
      map['key_wrapping_version'] = Variable<int>(keyWrappingVersion);
    }
    if (!nullToAbsent || lastVerifiedAt != null) {
      map['last_verified_at'] = Variable<DateTime>(lastVerifiedAt);
    }
    if (!nullToAbsent || deletedLocallyAt != null) {
      map['deleted_locally_at'] = Variable<DateTime>(deletedLocallyAt);
    }
    if (!nullToAbsent || labelId != null) {
      map['label_id'] = Variable<int>(labelId);
    }
    map['date_added'] = Variable<DateTime>(dateAdded);
    return map;
  }

  FilesCompanion toCompanion(bool nullToAbsent) {
    return FilesCompanion(
      id: Value(id),
      localPath: Value(localPath),
      localPathResolved: Value(localPathResolved),
      localMediaAccessState: Value(localMediaAccessState),
      assetId: assetId == null && nullToAbsent
          ? const Value.absent()
          : Value(assetId),
      folderName: Value(folderName),
      fileHash: fileHash == null && nullToAbsent
          ? const Value.absent()
          : Value(fileHash),
      size: Value(size),
      bucketId: Value(bucketId),
      telegramMessageId: telegramMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(telegramMessageId),
      telegramFileId: telegramFileId == null && nullToAbsent
          ? const Value.absent()
          : Value(telegramFileId),
      uploadOperationId: uploadOperationId == null && nullToAbsent
          ? const Value.absent()
          : Value(uploadOperationId),
      remoteStateVerified: Value(remoteStateVerified),
      status: Value(status),
      retryCount: Value(retryCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      nextRetryAt: nextRetryAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextRetryAt),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      telegramErrorCode: telegramErrorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(telegramErrorCode),
      telegramErrorCategory: telegramErrorCategory == null && nullToAbsent
          ? const Value.absent()
          : Value(telegramErrorCategory),
      telegramRetryAfter: telegramRetryAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(telegramRetryAfter),
      lastTelegramOperation: lastTelegramOperation == null && nullToAbsent
          ? const Value.absent()
          : Value(lastTelegramOperation),
      userActionRequired: Value(userActionRequired),
      isVaulted: Value(isVaulted),
      isEncrypted: Value(isEncrypted),
      encryptionVersion: encryptionVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(encryptionVersion),
      ivB64: ivB64 == null && nullToAbsent
          ? const Value.absent()
          : Value(ivB64),
      vaultFormatVersion: vaultFormatVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(vaultFormatVersion),
      encryptedObjectId: encryptedObjectId == null && nullToAbsent
          ? const Value.absent()
          : Value(encryptedObjectId),
      encryptedSize: encryptedSize == null && nullToAbsent
          ? const Value.absent()
          : Value(encryptedSize),
      originalSize: originalSize == null && nullToAbsent
          ? const Value.absent()
          : Value(originalSize),
      vaultIntegrityStatus: Value(vaultIntegrityStatus),
      vaultMigrationStatus: Value(vaultMigrationStatus),
      keyWrappingVersion: keyWrappingVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(keyWrappingVersion),
      lastVerifiedAt: lastVerifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastVerifiedAt),
      deletedLocallyAt: deletedLocallyAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedLocallyAt),
      labelId: labelId == null && nullToAbsent
          ? const Value.absent()
          : Value(labelId),
      dateAdded: Value(dateAdded),
    );
  }

  factory File.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return File(
      id: serializer.fromJson<int>(json['id']),
      localPath: serializer.fromJson<String>(json['localPath']),
      localPathResolved: serializer.fromJson<bool>(json['localPathResolved']),
      localMediaAccessState: serializer.fromJson<String>(
        json['localMediaAccessState'],
      ),
      assetId: serializer.fromJson<String?>(json['assetId']),
      folderName: serializer.fromJson<String>(json['folderName']),
      fileHash: serializer.fromJson<String?>(json['fileHash']),
      size: serializer.fromJson<int>(json['size']),
      bucketId: serializer.fromJson<int>(json['bucketId']),
      telegramMessageId: serializer.fromJson<int?>(json['telegramMessageId']),
      telegramFileId: serializer.fromJson<int?>(json['telegramFileId']),
      uploadOperationId: serializer.fromJson<String?>(
        json['uploadOperationId'],
      ),
      remoteStateVerified: serializer.fromJson<bool>(
        json['remoteStateVerified'],
      ),
      status: serializer.fromJson<int>(json['status']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      nextRetryAt: serializer.fromJson<DateTime?>(json['nextRetryAt']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      telegramErrorCode: serializer.fromJson<int?>(json['telegramErrorCode']),
      telegramErrorCategory: serializer.fromJson<String?>(
        json['telegramErrorCategory'],
      ),
      telegramRetryAfter: serializer.fromJson<DateTime?>(
        json['telegramRetryAfter'],
      ),
      lastTelegramOperation: serializer.fromJson<String?>(
        json['lastTelegramOperation'],
      ),
      userActionRequired: serializer.fromJson<bool>(json['userActionRequired']),
      isVaulted: serializer.fromJson<bool>(json['isVaulted']),
      isEncrypted: serializer.fromJson<bool>(json['isEncrypted']),
      encryptionVersion: serializer.fromJson<int?>(json['encryptionVersion']),
      ivB64: serializer.fromJson<String?>(json['ivB64']),
      vaultFormatVersion: serializer.fromJson<int?>(json['vaultFormatVersion']),
      encryptedObjectId: serializer.fromJson<String?>(
        json['encryptedObjectId'],
      ),
      encryptedSize: serializer.fromJson<int?>(json['encryptedSize']),
      originalSize: serializer.fromJson<int?>(json['originalSize']),
      vaultIntegrityStatus: serializer.fromJson<String>(
        json['vaultIntegrityStatus'],
      ),
      vaultMigrationStatus: serializer.fromJson<String>(
        json['vaultMigrationStatus'],
      ),
      keyWrappingVersion: serializer.fromJson<int?>(json['keyWrappingVersion']),
      lastVerifiedAt: serializer.fromJson<DateTime?>(json['lastVerifiedAt']),
      deletedLocallyAt: serializer.fromJson<DateTime?>(
        json['deletedLocallyAt'],
      ),
      labelId: serializer.fromJson<int?>(json['labelId']),
      dateAdded: serializer.fromJson<DateTime>(json['dateAdded']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'localPath': serializer.toJson<String>(localPath),
      'localPathResolved': serializer.toJson<bool>(localPathResolved),
      'localMediaAccessState': serializer.toJson<String>(localMediaAccessState),
      'assetId': serializer.toJson<String?>(assetId),
      'folderName': serializer.toJson<String>(folderName),
      'fileHash': serializer.toJson<String?>(fileHash),
      'size': serializer.toJson<int>(size),
      'bucketId': serializer.toJson<int>(bucketId),
      'telegramMessageId': serializer.toJson<int?>(telegramMessageId),
      'telegramFileId': serializer.toJson<int?>(telegramFileId),
      'uploadOperationId': serializer.toJson<String?>(uploadOperationId),
      'remoteStateVerified': serializer.toJson<bool>(remoteStateVerified),
      'status': serializer.toJson<int>(status),
      'retryCount': serializer.toJson<int>(retryCount),
      'lastError': serializer.toJson<String?>(lastError),
      'nextRetryAt': serializer.toJson<DateTime?>(nextRetryAt),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'telegramErrorCode': serializer.toJson<int?>(telegramErrorCode),
      'telegramErrorCategory': serializer.toJson<String?>(
        telegramErrorCategory,
      ),
      'telegramRetryAfter': serializer.toJson<DateTime?>(telegramRetryAfter),
      'lastTelegramOperation': serializer.toJson<String?>(
        lastTelegramOperation,
      ),
      'userActionRequired': serializer.toJson<bool>(userActionRequired),
      'isVaulted': serializer.toJson<bool>(isVaulted),
      'isEncrypted': serializer.toJson<bool>(isEncrypted),
      'encryptionVersion': serializer.toJson<int?>(encryptionVersion),
      'ivB64': serializer.toJson<String?>(ivB64),
      'vaultFormatVersion': serializer.toJson<int?>(vaultFormatVersion),
      'encryptedObjectId': serializer.toJson<String?>(encryptedObjectId),
      'encryptedSize': serializer.toJson<int?>(encryptedSize),
      'originalSize': serializer.toJson<int?>(originalSize),
      'vaultIntegrityStatus': serializer.toJson<String>(vaultIntegrityStatus),
      'vaultMigrationStatus': serializer.toJson<String>(vaultMigrationStatus),
      'keyWrappingVersion': serializer.toJson<int?>(keyWrappingVersion),
      'lastVerifiedAt': serializer.toJson<DateTime?>(lastVerifiedAt),
      'deletedLocallyAt': serializer.toJson<DateTime?>(deletedLocallyAt),
      'labelId': serializer.toJson<int?>(labelId),
      'dateAdded': serializer.toJson<DateTime>(dateAdded),
    };
  }

  File copyWith({
    int? id,
    String? localPath,
    bool? localPathResolved,
    String? localMediaAccessState,
    Value<String?> assetId = const Value.absent(),
    String? folderName,
    Value<String?> fileHash = const Value.absent(),
    int? size,
    int? bucketId,
    Value<int?> telegramMessageId = const Value.absent(),
    Value<int?> telegramFileId = const Value.absent(),
    Value<String?> uploadOperationId = const Value.absent(),
    bool? remoteStateVerified,
    int? status,
    int? retryCount,
    Value<String?> lastError = const Value.absent(),
    Value<DateTime?> nextRetryAt = const Value.absent(),
    Value<DateTime?> lastAttemptAt = const Value.absent(),
    Value<int?> telegramErrorCode = const Value.absent(),
    Value<String?> telegramErrorCategory = const Value.absent(),
    Value<DateTime?> telegramRetryAfter = const Value.absent(),
    Value<String?> lastTelegramOperation = const Value.absent(),
    bool? userActionRequired,
    bool? isVaulted,
    bool? isEncrypted,
    Value<int?> encryptionVersion = const Value.absent(),
    Value<String?> ivB64 = const Value.absent(),
    Value<int?> vaultFormatVersion = const Value.absent(),
    Value<String?> encryptedObjectId = const Value.absent(),
    Value<int?> encryptedSize = const Value.absent(),
    Value<int?> originalSize = const Value.absent(),
    String? vaultIntegrityStatus,
    String? vaultMigrationStatus,
    Value<int?> keyWrappingVersion = const Value.absent(),
    Value<DateTime?> lastVerifiedAt = const Value.absent(),
    Value<DateTime?> deletedLocallyAt = const Value.absent(),
    Value<int?> labelId = const Value.absent(),
    DateTime? dateAdded,
  }) => File(
    id: id ?? this.id,
    localPath: localPath ?? this.localPath,
    localPathResolved: localPathResolved ?? this.localPathResolved,
    localMediaAccessState: localMediaAccessState ?? this.localMediaAccessState,
    assetId: assetId.present ? assetId.value : this.assetId,
    folderName: folderName ?? this.folderName,
    fileHash: fileHash.present ? fileHash.value : this.fileHash,
    size: size ?? this.size,
    bucketId: bucketId ?? this.bucketId,
    telegramMessageId: telegramMessageId.present
        ? telegramMessageId.value
        : this.telegramMessageId,
    telegramFileId: telegramFileId.present
        ? telegramFileId.value
        : this.telegramFileId,
    uploadOperationId: uploadOperationId.present
        ? uploadOperationId.value
        : this.uploadOperationId,
    remoteStateVerified: remoteStateVerified ?? this.remoteStateVerified,
    status: status ?? this.status,
    retryCount: retryCount ?? this.retryCount,
    lastError: lastError.present ? lastError.value : this.lastError,
    nextRetryAt: nextRetryAt.present ? nextRetryAt.value : this.nextRetryAt,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
    telegramErrorCode: telegramErrorCode.present
        ? telegramErrorCode.value
        : this.telegramErrorCode,
    telegramErrorCategory: telegramErrorCategory.present
        ? telegramErrorCategory.value
        : this.telegramErrorCategory,
    telegramRetryAfter: telegramRetryAfter.present
        ? telegramRetryAfter.value
        : this.telegramRetryAfter,
    lastTelegramOperation: lastTelegramOperation.present
        ? lastTelegramOperation.value
        : this.lastTelegramOperation,
    userActionRequired: userActionRequired ?? this.userActionRequired,
    isVaulted: isVaulted ?? this.isVaulted,
    isEncrypted: isEncrypted ?? this.isEncrypted,
    encryptionVersion: encryptionVersion.present
        ? encryptionVersion.value
        : this.encryptionVersion,
    ivB64: ivB64.present ? ivB64.value : this.ivB64,
    vaultFormatVersion: vaultFormatVersion.present
        ? vaultFormatVersion.value
        : this.vaultFormatVersion,
    encryptedObjectId: encryptedObjectId.present
        ? encryptedObjectId.value
        : this.encryptedObjectId,
    encryptedSize: encryptedSize.present
        ? encryptedSize.value
        : this.encryptedSize,
    originalSize: originalSize.present ? originalSize.value : this.originalSize,
    vaultIntegrityStatus: vaultIntegrityStatus ?? this.vaultIntegrityStatus,
    vaultMigrationStatus: vaultMigrationStatus ?? this.vaultMigrationStatus,
    keyWrappingVersion: keyWrappingVersion.present
        ? keyWrappingVersion.value
        : this.keyWrappingVersion,
    lastVerifiedAt: lastVerifiedAt.present
        ? lastVerifiedAt.value
        : this.lastVerifiedAt,
    deletedLocallyAt: deletedLocallyAt.present
        ? deletedLocallyAt.value
        : this.deletedLocallyAt,
    labelId: labelId.present ? labelId.value : this.labelId,
    dateAdded: dateAdded ?? this.dateAdded,
  );
  File copyWithCompanion(FilesCompanion data) {
    return File(
      id: data.id.present ? data.id.value : this.id,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      localPathResolved: data.localPathResolved.present
          ? data.localPathResolved.value
          : this.localPathResolved,
      localMediaAccessState: data.localMediaAccessState.present
          ? data.localMediaAccessState.value
          : this.localMediaAccessState,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      folderName: data.folderName.present
          ? data.folderName.value
          : this.folderName,
      fileHash: data.fileHash.present ? data.fileHash.value : this.fileHash,
      size: data.size.present ? data.size.value : this.size,
      bucketId: data.bucketId.present ? data.bucketId.value : this.bucketId,
      telegramMessageId: data.telegramMessageId.present
          ? data.telegramMessageId.value
          : this.telegramMessageId,
      telegramFileId: data.telegramFileId.present
          ? data.telegramFileId.value
          : this.telegramFileId,
      uploadOperationId: data.uploadOperationId.present
          ? data.uploadOperationId.value
          : this.uploadOperationId,
      remoteStateVerified: data.remoteStateVerified.present
          ? data.remoteStateVerified.value
          : this.remoteStateVerified,
      status: data.status.present ? data.status.value : this.status,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      nextRetryAt: data.nextRetryAt.present
          ? data.nextRetryAt.value
          : this.nextRetryAt,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      telegramErrorCode: data.telegramErrorCode.present
          ? data.telegramErrorCode.value
          : this.telegramErrorCode,
      telegramErrorCategory: data.telegramErrorCategory.present
          ? data.telegramErrorCategory.value
          : this.telegramErrorCategory,
      telegramRetryAfter: data.telegramRetryAfter.present
          ? data.telegramRetryAfter.value
          : this.telegramRetryAfter,
      lastTelegramOperation: data.lastTelegramOperation.present
          ? data.lastTelegramOperation.value
          : this.lastTelegramOperation,
      userActionRequired: data.userActionRequired.present
          ? data.userActionRequired.value
          : this.userActionRequired,
      isVaulted: data.isVaulted.present ? data.isVaulted.value : this.isVaulted,
      isEncrypted: data.isEncrypted.present
          ? data.isEncrypted.value
          : this.isEncrypted,
      encryptionVersion: data.encryptionVersion.present
          ? data.encryptionVersion.value
          : this.encryptionVersion,
      ivB64: data.ivB64.present ? data.ivB64.value : this.ivB64,
      vaultFormatVersion: data.vaultFormatVersion.present
          ? data.vaultFormatVersion.value
          : this.vaultFormatVersion,
      encryptedObjectId: data.encryptedObjectId.present
          ? data.encryptedObjectId.value
          : this.encryptedObjectId,
      encryptedSize: data.encryptedSize.present
          ? data.encryptedSize.value
          : this.encryptedSize,
      originalSize: data.originalSize.present
          ? data.originalSize.value
          : this.originalSize,
      vaultIntegrityStatus: data.vaultIntegrityStatus.present
          ? data.vaultIntegrityStatus.value
          : this.vaultIntegrityStatus,
      vaultMigrationStatus: data.vaultMigrationStatus.present
          ? data.vaultMigrationStatus.value
          : this.vaultMigrationStatus,
      keyWrappingVersion: data.keyWrappingVersion.present
          ? data.keyWrappingVersion.value
          : this.keyWrappingVersion,
      lastVerifiedAt: data.lastVerifiedAt.present
          ? data.lastVerifiedAt.value
          : this.lastVerifiedAt,
      deletedLocallyAt: data.deletedLocallyAt.present
          ? data.deletedLocallyAt.value
          : this.deletedLocallyAt,
      labelId: data.labelId.present ? data.labelId.value : this.labelId,
      dateAdded: data.dateAdded.present ? data.dateAdded.value : this.dateAdded,
    );
  }

  @override
  String toString() {
    return (StringBuffer('File(')
          ..write('id: $id, ')
          ..write('localPath: $localPath, ')
          ..write('localPathResolved: $localPathResolved, ')
          ..write('localMediaAccessState: $localMediaAccessState, ')
          ..write('assetId: $assetId, ')
          ..write('folderName: $folderName, ')
          ..write('fileHash: $fileHash, ')
          ..write('size: $size, ')
          ..write('bucketId: $bucketId, ')
          ..write('telegramMessageId: $telegramMessageId, ')
          ..write('telegramFileId: $telegramFileId, ')
          ..write('uploadOperationId: $uploadOperationId, ')
          ..write('remoteStateVerified: $remoteStateVerified, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('telegramErrorCode: $telegramErrorCode, ')
          ..write('telegramErrorCategory: $telegramErrorCategory, ')
          ..write('telegramRetryAfter: $telegramRetryAfter, ')
          ..write('lastTelegramOperation: $lastTelegramOperation, ')
          ..write('userActionRequired: $userActionRequired, ')
          ..write('isVaulted: $isVaulted, ')
          ..write('isEncrypted: $isEncrypted, ')
          ..write('encryptionVersion: $encryptionVersion, ')
          ..write('ivB64: $ivB64, ')
          ..write('vaultFormatVersion: $vaultFormatVersion, ')
          ..write('encryptedObjectId: $encryptedObjectId, ')
          ..write('encryptedSize: $encryptedSize, ')
          ..write('originalSize: $originalSize, ')
          ..write('vaultIntegrityStatus: $vaultIntegrityStatus, ')
          ..write('vaultMigrationStatus: $vaultMigrationStatus, ')
          ..write('keyWrappingVersion: $keyWrappingVersion, ')
          ..write('lastVerifiedAt: $lastVerifiedAt, ')
          ..write('deletedLocallyAt: $deletedLocallyAt, ')
          ..write('labelId: $labelId, ')
          ..write('dateAdded: $dateAdded')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    localPath,
    localPathResolved,
    localMediaAccessState,
    assetId,
    folderName,
    fileHash,
    size,
    bucketId,
    telegramMessageId,
    telegramFileId,
    uploadOperationId,
    remoteStateVerified,
    status,
    retryCount,
    lastError,
    nextRetryAt,
    lastAttemptAt,
    telegramErrorCode,
    telegramErrorCategory,
    telegramRetryAfter,
    lastTelegramOperation,
    userActionRequired,
    isVaulted,
    isEncrypted,
    encryptionVersion,
    ivB64,
    vaultFormatVersion,
    encryptedObjectId,
    encryptedSize,
    originalSize,
    vaultIntegrityStatus,
    vaultMigrationStatus,
    keyWrappingVersion,
    lastVerifiedAt,
    deletedLocallyAt,
    labelId,
    dateAdded,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is File &&
          other.id == this.id &&
          other.localPath == this.localPath &&
          other.localPathResolved == this.localPathResolved &&
          other.localMediaAccessState == this.localMediaAccessState &&
          other.assetId == this.assetId &&
          other.folderName == this.folderName &&
          other.fileHash == this.fileHash &&
          other.size == this.size &&
          other.bucketId == this.bucketId &&
          other.telegramMessageId == this.telegramMessageId &&
          other.telegramFileId == this.telegramFileId &&
          other.uploadOperationId == this.uploadOperationId &&
          other.remoteStateVerified == this.remoteStateVerified &&
          other.status == this.status &&
          other.retryCount == this.retryCount &&
          other.lastError == this.lastError &&
          other.nextRetryAt == this.nextRetryAt &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.telegramErrorCode == this.telegramErrorCode &&
          other.telegramErrorCategory == this.telegramErrorCategory &&
          other.telegramRetryAfter == this.telegramRetryAfter &&
          other.lastTelegramOperation == this.lastTelegramOperation &&
          other.userActionRequired == this.userActionRequired &&
          other.isVaulted == this.isVaulted &&
          other.isEncrypted == this.isEncrypted &&
          other.encryptionVersion == this.encryptionVersion &&
          other.ivB64 == this.ivB64 &&
          other.vaultFormatVersion == this.vaultFormatVersion &&
          other.encryptedObjectId == this.encryptedObjectId &&
          other.encryptedSize == this.encryptedSize &&
          other.originalSize == this.originalSize &&
          other.vaultIntegrityStatus == this.vaultIntegrityStatus &&
          other.vaultMigrationStatus == this.vaultMigrationStatus &&
          other.keyWrappingVersion == this.keyWrappingVersion &&
          other.lastVerifiedAt == this.lastVerifiedAt &&
          other.deletedLocallyAt == this.deletedLocallyAt &&
          other.labelId == this.labelId &&
          other.dateAdded == this.dateAdded);
}

class FilesCompanion extends UpdateCompanion<File> {
  final Value<int> id;
  final Value<String> localPath;
  final Value<bool> localPathResolved;
  final Value<String> localMediaAccessState;
  final Value<String?> assetId;
  final Value<String> folderName;
  final Value<String?> fileHash;
  final Value<int> size;
  final Value<int> bucketId;
  final Value<int?> telegramMessageId;
  final Value<int?> telegramFileId;
  final Value<String?> uploadOperationId;
  final Value<bool> remoteStateVerified;
  final Value<int> status;
  final Value<int> retryCount;
  final Value<String?> lastError;
  final Value<DateTime?> nextRetryAt;
  final Value<DateTime?> lastAttemptAt;
  final Value<int?> telegramErrorCode;
  final Value<String?> telegramErrorCategory;
  final Value<DateTime?> telegramRetryAfter;
  final Value<String?> lastTelegramOperation;
  final Value<bool> userActionRequired;
  final Value<bool> isVaulted;
  final Value<bool> isEncrypted;
  final Value<int?> encryptionVersion;
  final Value<String?> ivB64;
  final Value<int?> vaultFormatVersion;
  final Value<String?> encryptedObjectId;
  final Value<int?> encryptedSize;
  final Value<int?> originalSize;
  final Value<String> vaultIntegrityStatus;
  final Value<String> vaultMigrationStatus;
  final Value<int?> keyWrappingVersion;
  final Value<DateTime?> lastVerifiedAt;
  final Value<DateTime?> deletedLocallyAt;
  final Value<int?> labelId;
  final Value<DateTime> dateAdded;
  const FilesCompanion({
    this.id = const Value.absent(),
    this.localPath = const Value.absent(),
    this.localPathResolved = const Value.absent(),
    this.localMediaAccessState = const Value.absent(),
    this.assetId = const Value.absent(),
    this.folderName = const Value.absent(),
    this.fileHash = const Value.absent(),
    this.size = const Value.absent(),
    this.bucketId = const Value.absent(),
    this.telegramMessageId = const Value.absent(),
    this.telegramFileId = const Value.absent(),
    this.uploadOperationId = const Value.absent(),
    this.remoteStateVerified = const Value.absent(),
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.telegramErrorCode = const Value.absent(),
    this.telegramErrorCategory = const Value.absent(),
    this.telegramRetryAfter = const Value.absent(),
    this.lastTelegramOperation = const Value.absent(),
    this.userActionRequired = const Value.absent(),
    this.isVaulted = const Value.absent(),
    this.isEncrypted = const Value.absent(),
    this.encryptionVersion = const Value.absent(),
    this.ivB64 = const Value.absent(),
    this.vaultFormatVersion = const Value.absent(),
    this.encryptedObjectId = const Value.absent(),
    this.encryptedSize = const Value.absent(),
    this.originalSize = const Value.absent(),
    this.vaultIntegrityStatus = const Value.absent(),
    this.vaultMigrationStatus = const Value.absent(),
    this.keyWrappingVersion = const Value.absent(),
    this.lastVerifiedAt = const Value.absent(),
    this.deletedLocallyAt = const Value.absent(),
    this.labelId = const Value.absent(),
    this.dateAdded = const Value.absent(),
  });
  FilesCompanion.insert({
    this.id = const Value.absent(),
    required String localPath,
    this.localPathResolved = const Value.absent(),
    this.localMediaAccessState = const Value.absent(),
    this.assetId = const Value.absent(),
    required String folderName,
    this.fileHash = const Value.absent(),
    required int size,
    required int bucketId,
    this.telegramMessageId = const Value.absent(),
    this.telegramFileId = const Value.absent(),
    this.uploadOperationId = const Value.absent(),
    this.remoteStateVerified = const Value.absent(),
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.telegramErrorCode = const Value.absent(),
    this.telegramErrorCategory = const Value.absent(),
    this.telegramRetryAfter = const Value.absent(),
    this.lastTelegramOperation = const Value.absent(),
    this.userActionRequired = const Value.absent(),
    this.isVaulted = const Value.absent(),
    this.isEncrypted = const Value.absent(),
    this.encryptionVersion = const Value.absent(),
    this.ivB64 = const Value.absent(),
    this.vaultFormatVersion = const Value.absent(),
    this.encryptedObjectId = const Value.absent(),
    this.encryptedSize = const Value.absent(),
    this.originalSize = const Value.absent(),
    this.vaultIntegrityStatus = const Value.absent(),
    this.vaultMigrationStatus = const Value.absent(),
    this.keyWrappingVersion = const Value.absent(),
    this.lastVerifiedAt = const Value.absent(),
    this.deletedLocallyAt = const Value.absent(),
    this.labelId = const Value.absent(),
    this.dateAdded = const Value.absent(),
  }) : localPath = Value(localPath),
       folderName = Value(folderName),
       size = Value(size),
       bucketId = Value(bucketId);
  static Insertable<File> custom({
    Expression<int>? id,
    Expression<String>? localPath,
    Expression<bool>? localPathResolved,
    Expression<String>? localMediaAccessState,
    Expression<String>? assetId,
    Expression<String>? folderName,
    Expression<String>? fileHash,
    Expression<int>? size,
    Expression<int>? bucketId,
    Expression<int>? telegramMessageId,
    Expression<int>? telegramFileId,
    Expression<String>? uploadOperationId,
    Expression<bool>? remoteStateVerified,
    Expression<int>? status,
    Expression<int>? retryCount,
    Expression<String>? lastError,
    Expression<DateTime>? nextRetryAt,
    Expression<DateTime>? lastAttemptAt,
    Expression<int>? telegramErrorCode,
    Expression<String>? telegramErrorCategory,
    Expression<DateTime>? telegramRetryAfter,
    Expression<String>? lastTelegramOperation,
    Expression<bool>? userActionRequired,
    Expression<bool>? isVaulted,
    Expression<bool>? isEncrypted,
    Expression<int>? encryptionVersion,
    Expression<String>? ivB64,
    Expression<int>? vaultFormatVersion,
    Expression<String>? encryptedObjectId,
    Expression<int>? encryptedSize,
    Expression<int>? originalSize,
    Expression<String>? vaultIntegrityStatus,
    Expression<String>? vaultMigrationStatus,
    Expression<int>? keyWrappingVersion,
    Expression<DateTime>? lastVerifiedAt,
    Expression<DateTime>? deletedLocallyAt,
    Expression<int>? labelId,
    Expression<DateTime>? dateAdded,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (localPath != null) 'local_path': localPath,
      if (localPathResolved != null) 'local_path_resolved': localPathResolved,
      if (localMediaAccessState != null)
        'local_media_access_state': localMediaAccessState,
      if (assetId != null) 'asset_id': assetId,
      if (folderName != null) 'folder_name': folderName,
      if (fileHash != null) 'file_hash': fileHash,
      if (size != null) 'size': size,
      if (bucketId != null) 'bucket_id': bucketId,
      if (telegramMessageId != null) 'telegram_message_id': telegramMessageId,
      if (telegramFileId != null) 'telegram_file_id': telegramFileId,
      if (uploadOperationId != null) 'upload_operation_id': uploadOperationId,
      if (remoteStateVerified != null)
        'remote_state_verified': remoteStateVerified,
      if (status != null) 'status': status,
      if (retryCount != null) 'retry_count': retryCount,
      if (lastError != null) 'last_error': lastError,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (telegramErrorCode != null) 'telegram_error_code': telegramErrorCode,
      if (telegramErrorCategory != null)
        'telegram_error_category': telegramErrorCategory,
      if (telegramRetryAfter != null)
        'telegram_retry_after': telegramRetryAfter,
      if (lastTelegramOperation != null)
        'last_telegram_operation': lastTelegramOperation,
      if (userActionRequired != null)
        'user_action_required': userActionRequired,
      if (isVaulted != null) 'is_vaulted': isVaulted,
      if (isEncrypted != null) 'is_encrypted': isEncrypted,
      if (encryptionVersion != null) 'encryption_version': encryptionVersion,
      if (ivB64 != null) 'iv_b64': ivB64,
      if (vaultFormatVersion != null)
        'vault_format_version': vaultFormatVersion,
      if (encryptedObjectId != null) 'encrypted_object_id': encryptedObjectId,
      if (encryptedSize != null) 'encrypted_size': encryptedSize,
      if (originalSize != null) 'original_size': originalSize,
      if (vaultIntegrityStatus != null)
        'vault_integrity_status': vaultIntegrityStatus,
      if (vaultMigrationStatus != null)
        'vault_migration_status': vaultMigrationStatus,
      if (keyWrappingVersion != null)
        'key_wrapping_version': keyWrappingVersion,
      if (lastVerifiedAt != null) 'last_verified_at': lastVerifiedAt,
      if (deletedLocallyAt != null) 'deleted_locally_at': deletedLocallyAt,
      if (labelId != null) 'label_id': labelId,
      if (dateAdded != null) 'date_added': dateAdded,
    });
  }

  FilesCompanion copyWith({
    Value<int>? id,
    Value<String>? localPath,
    Value<bool>? localPathResolved,
    Value<String>? localMediaAccessState,
    Value<String?>? assetId,
    Value<String>? folderName,
    Value<String?>? fileHash,
    Value<int>? size,
    Value<int>? bucketId,
    Value<int?>? telegramMessageId,
    Value<int?>? telegramFileId,
    Value<String?>? uploadOperationId,
    Value<bool>? remoteStateVerified,
    Value<int>? status,
    Value<int>? retryCount,
    Value<String?>? lastError,
    Value<DateTime?>? nextRetryAt,
    Value<DateTime?>? lastAttemptAt,
    Value<int?>? telegramErrorCode,
    Value<String?>? telegramErrorCategory,
    Value<DateTime?>? telegramRetryAfter,
    Value<String?>? lastTelegramOperation,
    Value<bool>? userActionRequired,
    Value<bool>? isVaulted,
    Value<bool>? isEncrypted,
    Value<int?>? encryptionVersion,
    Value<String?>? ivB64,
    Value<int?>? vaultFormatVersion,
    Value<String?>? encryptedObjectId,
    Value<int?>? encryptedSize,
    Value<int?>? originalSize,
    Value<String>? vaultIntegrityStatus,
    Value<String>? vaultMigrationStatus,
    Value<int?>? keyWrappingVersion,
    Value<DateTime?>? lastVerifiedAt,
    Value<DateTime?>? deletedLocallyAt,
    Value<int?>? labelId,
    Value<DateTime>? dateAdded,
  }) {
    return FilesCompanion(
      id: id ?? this.id,
      localPath: localPath ?? this.localPath,
      localPathResolved: localPathResolved ?? this.localPathResolved,
      localMediaAccessState:
          localMediaAccessState ?? this.localMediaAccessState,
      assetId: assetId ?? this.assetId,
      folderName: folderName ?? this.folderName,
      fileHash: fileHash ?? this.fileHash,
      size: size ?? this.size,
      bucketId: bucketId ?? this.bucketId,
      telegramMessageId: telegramMessageId ?? this.telegramMessageId,
      telegramFileId: telegramFileId ?? this.telegramFileId,
      uploadOperationId: uploadOperationId ?? this.uploadOperationId,
      remoteStateVerified: remoteStateVerified ?? this.remoteStateVerified,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      telegramErrorCode: telegramErrorCode ?? this.telegramErrorCode,
      telegramErrorCategory:
          telegramErrorCategory ?? this.telegramErrorCategory,
      telegramRetryAfter: telegramRetryAfter ?? this.telegramRetryAfter,
      lastTelegramOperation:
          lastTelegramOperation ?? this.lastTelegramOperation,
      userActionRequired: userActionRequired ?? this.userActionRequired,
      isVaulted: isVaulted ?? this.isVaulted,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      encryptionVersion: encryptionVersion ?? this.encryptionVersion,
      ivB64: ivB64 ?? this.ivB64,
      vaultFormatVersion: vaultFormatVersion ?? this.vaultFormatVersion,
      encryptedObjectId: encryptedObjectId ?? this.encryptedObjectId,
      encryptedSize: encryptedSize ?? this.encryptedSize,
      originalSize: originalSize ?? this.originalSize,
      vaultIntegrityStatus: vaultIntegrityStatus ?? this.vaultIntegrityStatus,
      vaultMigrationStatus: vaultMigrationStatus ?? this.vaultMigrationStatus,
      keyWrappingVersion: keyWrappingVersion ?? this.keyWrappingVersion,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      deletedLocallyAt: deletedLocallyAt ?? this.deletedLocallyAt,
      labelId: labelId ?? this.labelId,
      dateAdded: dateAdded ?? this.dateAdded,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (localPathResolved.present) {
      map['local_path_resolved'] = Variable<bool>(localPathResolved.value);
    }
    if (localMediaAccessState.present) {
      map['local_media_access_state'] = Variable<String>(
        localMediaAccessState.value,
      );
    }
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (folderName.present) {
      map['folder_name'] = Variable<String>(folderName.value);
    }
    if (fileHash.present) {
      map['file_hash'] = Variable<String>(fileHash.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (bucketId.present) {
      map['bucket_id'] = Variable<int>(bucketId.value);
    }
    if (telegramMessageId.present) {
      map['telegram_message_id'] = Variable<int>(telegramMessageId.value);
    }
    if (telegramFileId.present) {
      map['telegram_file_id'] = Variable<int>(telegramFileId.value);
    }
    if (uploadOperationId.present) {
      map['upload_operation_id'] = Variable<String>(uploadOperationId.value);
    }
    if (remoteStateVerified.present) {
      map['remote_state_verified'] = Variable<bool>(remoteStateVerified.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (nextRetryAt.present) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (telegramErrorCode.present) {
      map['telegram_error_code'] = Variable<int>(telegramErrorCode.value);
    }
    if (telegramErrorCategory.present) {
      map['telegram_error_category'] = Variable<String>(
        telegramErrorCategory.value,
      );
    }
    if (telegramRetryAfter.present) {
      map['telegram_retry_after'] = Variable<DateTime>(
        telegramRetryAfter.value,
      );
    }
    if (lastTelegramOperation.present) {
      map['last_telegram_operation'] = Variable<String>(
        lastTelegramOperation.value,
      );
    }
    if (userActionRequired.present) {
      map['user_action_required'] = Variable<bool>(userActionRequired.value);
    }
    if (isVaulted.present) {
      map['is_vaulted'] = Variable<bool>(isVaulted.value);
    }
    if (isEncrypted.present) {
      map['is_encrypted'] = Variable<bool>(isEncrypted.value);
    }
    if (encryptionVersion.present) {
      map['encryption_version'] = Variable<int>(encryptionVersion.value);
    }
    if (ivB64.present) {
      map['iv_b64'] = Variable<String>(ivB64.value);
    }
    if (vaultFormatVersion.present) {
      map['vault_format_version'] = Variable<int>(vaultFormatVersion.value);
    }
    if (encryptedObjectId.present) {
      map['encrypted_object_id'] = Variable<String>(encryptedObjectId.value);
    }
    if (encryptedSize.present) {
      map['encrypted_size'] = Variable<int>(encryptedSize.value);
    }
    if (originalSize.present) {
      map['original_size'] = Variable<int>(originalSize.value);
    }
    if (vaultIntegrityStatus.present) {
      map['vault_integrity_status'] = Variable<String>(
        vaultIntegrityStatus.value,
      );
    }
    if (vaultMigrationStatus.present) {
      map['vault_migration_status'] = Variable<String>(
        vaultMigrationStatus.value,
      );
    }
    if (keyWrappingVersion.present) {
      map['key_wrapping_version'] = Variable<int>(keyWrappingVersion.value);
    }
    if (lastVerifiedAt.present) {
      map['last_verified_at'] = Variable<DateTime>(lastVerifiedAt.value);
    }
    if (deletedLocallyAt.present) {
      map['deleted_locally_at'] = Variable<DateTime>(deletedLocallyAt.value);
    }
    if (labelId.present) {
      map['label_id'] = Variable<int>(labelId.value);
    }
    if (dateAdded.present) {
      map['date_added'] = Variable<DateTime>(dateAdded.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FilesCompanion(')
          ..write('id: $id, ')
          ..write('localPath: $localPath, ')
          ..write('localPathResolved: $localPathResolved, ')
          ..write('localMediaAccessState: $localMediaAccessState, ')
          ..write('assetId: $assetId, ')
          ..write('folderName: $folderName, ')
          ..write('fileHash: $fileHash, ')
          ..write('size: $size, ')
          ..write('bucketId: $bucketId, ')
          ..write('telegramMessageId: $telegramMessageId, ')
          ..write('telegramFileId: $telegramFileId, ')
          ..write('uploadOperationId: $uploadOperationId, ')
          ..write('remoteStateVerified: $remoteStateVerified, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('telegramErrorCode: $telegramErrorCode, ')
          ..write('telegramErrorCategory: $telegramErrorCategory, ')
          ..write('telegramRetryAfter: $telegramRetryAfter, ')
          ..write('lastTelegramOperation: $lastTelegramOperation, ')
          ..write('userActionRequired: $userActionRequired, ')
          ..write('isVaulted: $isVaulted, ')
          ..write('isEncrypted: $isEncrypted, ')
          ..write('encryptionVersion: $encryptionVersion, ')
          ..write('ivB64: $ivB64, ')
          ..write('vaultFormatVersion: $vaultFormatVersion, ')
          ..write('encryptedObjectId: $encryptedObjectId, ')
          ..write('encryptedSize: $encryptedSize, ')
          ..write('originalSize: $originalSize, ')
          ..write('vaultIntegrityStatus: $vaultIntegrityStatus, ')
          ..write('vaultMigrationStatus: $vaultMigrationStatus, ')
          ..write('keyWrappingVersion: $keyWrappingVersion, ')
          ..write('lastVerifiedAt: $lastVerifiedAt, ')
          ..write('deletedLocallyAt: $deletedLocallyAt, ')
          ..write('labelId: $labelId, ')
          ..write('dateAdded: $dateAdded')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  const AppSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSetting copyWith({String? key, String? value}) =>
      AppSetting(key: key ?? this.key, value: value ?? this.value);
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TelegramAccountStatesTable extends TelegramAccountStates
    with TableInfo<$TelegramAccountStatesTable, TelegramAccountState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TelegramAccountStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<BigInt> accountId = GeneratedColumn<BigInt>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.bigInt,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPremiumMeta = const VerificationMeta(
    'isPremium',
  );
  @override
  late final GeneratedColumn<bool> isPremium = GeneratedColumn<bool>(
    'is_premium',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_premium" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _premiumUpdatedAtMeta = const VerificationMeta(
    'premiumUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> premiumUpdatedAt =
      GeneratedColumn<DateTime>(
        'premium_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _serverRetryUntilMeta = const VerificationMeta(
    'serverRetryUntil',
  );
  @override
  late final GeneratedColumn<DateTime> serverRetryUntil =
      GeneratedColumn<DateTime>(
        'server_retry_until',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _writeBlockedUntilMeta = const VerificationMeta(
    'writeBlockedUntil',
  );
  @override
  late final GeneratedColumn<DateTime> writeBlockedUntil =
      GeneratedColumn<DateTime>(
        'write_blocked_until',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _pauseReasonMeta = const VerificationMeta(
    'pauseReason',
  );
  @override
  late final GeneratedColumn<String> pauseReason = GeneratedColumn<String>(
    'pause_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPremiumFloodWaitMeta =
      const VerificationMeta('isPremiumFloodWait');
  @override
  late final GeneratedColumn<bool> isPremiumFloodWait = GeneratedColumn<bool>(
    'is_premium_flood_wait',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_premium_flood_wait" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    accountId,
    isPremium,
    premiumUpdatedAt,
    serverRetryUntil,
    writeBlockedUntil,
    pauseReason,
    isPremiumFloodWait,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'telegram_account_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<TelegramAccountState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    }
    if (data.containsKey('is_premium')) {
      context.handle(
        _isPremiumMeta,
        isPremium.isAcceptableOrUnknown(data['is_premium']!, _isPremiumMeta),
      );
    }
    if (data.containsKey('premium_updated_at')) {
      context.handle(
        _premiumUpdatedAtMeta,
        premiumUpdatedAt.isAcceptableOrUnknown(
          data['premium_updated_at']!,
          _premiumUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('server_retry_until')) {
      context.handle(
        _serverRetryUntilMeta,
        serverRetryUntil.isAcceptableOrUnknown(
          data['server_retry_until']!,
          _serverRetryUntilMeta,
        ),
      );
    }
    if (data.containsKey('write_blocked_until')) {
      context.handle(
        _writeBlockedUntilMeta,
        writeBlockedUntil.isAcceptableOrUnknown(
          data['write_blocked_until']!,
          _writeBlockedUntilMeta,
        ),
      );
    }
    if (data.containsKey('pause_reason')) {
      context.handle(
        _pauseReasonMeta,
        pauseReason.isAcceptableOrUnknown(
          data['pause_reason']!,
          _pauseReasonMeta,
        ),
      );
    }
    if (data.containsKey('is_premium_flood_wait')) {
      context.handle(
        _isPremiumFloodWaitMeta,
        isPremiumFloodWait.isAcceptableOrUnknown(
          data['is_premium_flood_wait']!,
          _isPremiumFloodWaitMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId};
  @override
  TelegramAccountState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TelegramAccountState(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.bigInt,
        data['${effectivePrefix}account_id'],
      )!,
      isPremium: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_premium'],
      )!,
      premiumUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}premium_updated_at'],
      ),
      serverRetryUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}server_retry_until'],
      ),
      writeBlockedUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}write_blocked_until'],
      ),
      pauseReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pause_reason'],
      ),
      isPremiumFloodWait: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_premium_flood_wait'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TelegramAccountStatesTable createAlias(String alias) {
    return $TelegramAccountStatesTable(attachedDatabase, alias);
  }
}

class TelegramAccountState extends DataClass
    implements Insertable<TelegramAccountState> {
  final BigInt accountId;
  final bool isPremium;
  final DateTime? premiumUpdatedAt;
  final DateTime? serverRetryUntil;
  final DateTime? writeBlockedUntil;
  final String? pauseReason;
  final bool isPremiumFloodWait;
  final DateTime updatedAt;
  const TelegramAccountState({
    required this.accountId,
    required this.isPremium,
    this.premiumUpdatedAt,
    this.serverRetryUntil,
    this.writeBlockedUntil,
    this.pauseReason,
    required this.isPremiumFloodWait,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<BigInt>(accountId);
    map['is_premium'] = Variable<bool>(isPremium);
    if (!nullToAbsent || premiumUpdatedAt != null) {
      map['premium_updated_at'] = Variable<DateTime>(premiumUpdatedAt);
    }
    if (!nullToAbsent || serverRetryUntil != null) {
      map['server_retry_until'] = Variable<DateTime>(serverRetryUntil);
    }
    if (!nullToAbsent || writeBlockedUntil != null) {
      map['write_blocked_until'] = Variable<DateTime>(writeBlockedUntil);
    }
    if (!nullToAbsent || pauseReason != null) {
      map['pause_reason'] = Variable<String>(pauseReason);
    }
    map['is_premium_flood_wait'] = Variable<bool>(isPremiumFloodWait);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TelegramAccountStatesCompanion toCompanion(bool nullToAbsent) {
    return TelegramAccountStatesCompanion(
      accountId: Value(accountId),
      isPremium: Value(isPremium),
      premiumUpdatedAt: premiumUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(premiumUpdatedAt),
      serverRetryUntil: serverRetryUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(serverRetryUntil),
      writeBlockedUntil: writeBlockedUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(writeBlockedUntil),
      pauseReason: pauseReason == null && nullToAbsent
          ? const Value.absent()
          : Value(pauseReason),
      isPremiumFloodWait: Value(isPremiumFloodWait),
      updatedAt: Value(updatedAt),
    );
  }

  factory TelegramAccountState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TelegramAccountState(
      accountId: serializer.fromJson<BigInt>(json['accountId']),
      isPremium: serializer.fromJson<bool>(json['isPremium']),
      premiumUpdatedAt: serializer.fromJson<DateTime?>(
        json['premiumUpdatedAt'],
      ),
      serverRetryUntil: serializer.fromJson<DateTime?>(
        json['serverRetryUntil'],
      ),
      writeBlockedUntil: serializer.fromJson<DateTime?>(
        json['writeBlockedUntil'],
      ),
      pauseReason: serializer.fromJson<String?>(json['pauseReason']),
      isPremiumFloodWait: serializer.fromJson<bool>(json['isPremiumFloodWait']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<BigInt>(accountId),
      'isPremium': serializer.toJson<bool>(isPremium),
      'premiumUpdatedAt': serializer.toJson<DateTime?>(premiumUpdatedAt),
      'serverRetryUntil': serializer.toJson<DateTime?>(serverRetryUntil),
      'writeBlockedUntil': serializer.toJson<DateTime?>(writeBlockedUntil),
      'pauseReason': serializer.toJson<String?>(pauseReason),
      'isPremiumFloodWait': serializer.toJson<bool>(isPremiumFloodWait),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TelegramAccountState copyWith({
    BigInt? accountId,
    bool? isPremium,
    Value<DateTime?> premiumUpdatedAt = const Value.absent(),
    Value<DateTime?> serverRetryUntil = const Value.absent(),
    Value<DateTime?> writeBlockedUntil = const Value.absent(),
    Value<String?> pauseReason = const Value.absent(),
    bool? isPremiumFloodWait,
    DateTime? updatedAt,
  }) => TelegramAccountState(
    accountId: accountId ?? this.accountId,
    isPremium: isPremium ?? this.isPremium,
    premiumUpdatedAt: premiumUpdatedAt.present
        ? premiumUpdatedAt.value
        : this.premiumUpdatedAt,
    serverRetryUntil: serverRetryUntil.present
        ? serverRetryUntil.value
        : this.serverRetryUntil,
    writeBlockedUntil: writeBlockedUntil.present
        ? writeBlockedUntil.value
        : this.writeBlockedUntil,
    pauseReason: pauseReason.present ? pauseReason.value : this.pauseReason,
    isPremiumFloodWait: isPremiumFloodWait ?? this.isPremiumFloodWait,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TelegramAccountState copyWithCompanion(TelegramAccountStatesCompanion data) {
    return TelegramAccountState(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      isPremium: data.isPremium.present ? data.isPremium.value : this.isPremium,
      premiumUpdatedAt: data.premiumUpdatedAt.present
          ? data.premiumUpdatedAt.value
          : this.premiumUpdatedAt,
      serverRetryUntil: data.serverRetryUntil.present
          ? data.serverRetryUntil.value
          : this.serverRetryUntil,
      writeBlockedUntil: data.writeBlockedUntil.present
          ? data.writeBlockedUntil.value
          : this.writeBlockedUntil,
      pauseReason: data.pauseReason.present
          ? data.pauseReason.value
          : this.pauseReason,
      isPremiumFloodWait: data.isPremiumFloodWait.present
          ? data.isPremiumFloodWait.value
          : this.isPremiumFloodWait,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TelegramAccountState(')
          ..write('accountId: $accountId, ')
          ..write('isPremium: $isPremium, ')
          ..write('premiumUpdatedAt: $premiumUpdatedAt, ')
          ..write('serverRetryUntil: $serverRetryUntil, ')
          ..write('writeBlockedUntil: $writeBlockedUntil, ')
          ..write('pauseReason: $pauseReason, ')
          ..write('isPremiumFloodWait: $isPremiumFloodWait, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    accountId,
    isPremium,
    premiumUpdatedAt,
    serverRetryUntil,
    writeBlockedUntil,
    pauseReason,
    isPremiumFloodWait,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TelegramAccountState &&
          other.accountId == this.accountId &&
          other.isPremium == this.isPremium &&
          other.premiumUpdatedAt == this.premiumUpdatedAt &&
          other.serverRetryUntil == this.serverRetryUntil &&
          other.writeBlockedUntil == this.writeBlockedUntil &&
          other.pauseReason == this.pauseReason &&
          other.isPremiumFloodWait == this.isPremiumFloodWait &&
          other.updatedAt == this.updatedAt);
}

class TelegramAccountStatesCompanion
    extends UpdateCompanion<TelegramAccountState> {
  final Value<BigInt> accountId;
  final Value<bool> isPremium;
  final Value<DateTime?> premiumUpdatedAt;
  final Value<DateTime?> serverRetryUntil;
  final Value<DateTime?> writeBlockedUntil;
  final Value<String?> pauseReason;
  final Value<bool> isPremiumFloodWait;
  final Value<DateTime> updatedAt;
  const TelegramAccountStatesCompanion({
    this.accountId = const Value.absent(),
    this.isPremium = const Value.absent(),
    this.premiumUpdatedAt = const Value.absent(),
    this.serverRetryUntil = const Value.absent(),
    this.writeBlockedUntil = const Value.absent(),
    this.pauseReason = const Value.absent(),
    this.isPremiumFloodWait = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  TelegramAccountStatesCompanion.insert({
    this.accountId = const Value.absent(),
    this.isPremium = const Value.absent(),
    this.premiumUpdatedAt = const Value.absent(),
    this.serverRetryUntil = const Value.absent(),
    this.writeBlockedUntil = const Value.absent(),
    this.pauseReason = const Value.absent(),
    this.isPremiumFloodWait = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  static Insertable<TelegramAccountState> custom({
    Expression<BigInt>? accountId,
    Expression<bool>? isPremium,
    Expression<DateTime>? premiumUpdatedAt,
    Expression<DateTime>? serverRetryUntil,
    Expression<DateTime>? writeBlockedUntil,
    Expression<String>? pauseReason,
    Expression<bool>? isPremiumFloodWait,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (isPremium != null) 'is_premium': isPremium,
      if (premiumUpdatedAt != null) 'premium_updated_at': premiumUpdatedAt,
      if (serverRetryUntil != null) 'server_retry_until': serverRetryUntil,
      if (writeBlockedUntil != null) 'write_blocked_until': writeBlockedUntil,
      if (pauseReason != null) 'pause_reason': pauseReason,
      if (isPremiumFloodWait != null)
        'is_premium_flood_wait': isPremiumFloodWait,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  TelegramAccountStatesCompanion copyWith({
    Value<BigInt>? accountId,
    Value<bool>? isPremium,
    Value<DateTime?>? premiumUpdatedAt,
    Value<DateTime?>? serverRetryUntil,
    Value<DateTime?>? writeBlockedUntil,
    Value<String?>? pauseReason,
    Value<bool>? isPremiumFloodWait,
    Value<DateTime>? updatedAt,
  }) {
    return TelegramAccountStatesCompanion(
      accountId: accountId ?? this.accountId,
      isPremium: isPremium ?? this.isPremium,
      premiumUpdatedAt: premiumUpdatedAt ?? this.premiumUpdatedAt,
      serverRetryUntil: serverRetryUntil ?? this.serverRetryUntil,
      writeBlockedUntil: writeBlockedUntil ?? this.writeBlockedUntil,
      pauseReason: pauseReason ?? this.pauseReason,
      isPremiumFloodWait: isPremiumFloodWait ?? this.isPremiumFloodWait,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<BigInt>(accountId.value);
    }
    if (isPremium.present) {
      map['is_premium'] = Variable<bool>(isPremium.value);
    }
    if (premiumUpdatedAt.present) {
      map['premium_updated_at'] = Variable<DateTime>(premiumUpdatedAt.value);
    }
    if (serverRetryUntil.present) {
      map['server_retry_until'] = Variable<DateTime>(serverRetryUntil.value);
    }
    if (writeBlockedUntil.present) {
      map['write_blocked_until'] = Variable<DateTime>(writeBlockedUntil.value);
    }
    if (pauseReason.present) {
      map['pause_reason'] = Variable<String>(pauseReason.value);
    }
    if (isPremiumFloodWait.present) {
      map['is_premium_flood_wait'] = Variable<bool>(isPremiumFloodWait.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TelegramAccountStatesCompanion(')
          ..write('accountId: $accountId, ')
          ..write('isPremium: $isPremium, ')
          ..write('premiumUpdatedAt: $premiumUpdatedAt, ')
          ..write('serverRetryUntil: $serverRetryUntil, ')
          ..write('writeBlockedUntil: $writeBlockedUntil, ')
          ..write('pauseReason: $pauseReason, ')
          ..write('isPremiumFloodWait: $isPremiumFloodWait, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BucketsTable buckets = $BucketsTable(this);
  late final $LabelsTable labels = $LabelsTable(this);
  late final $FilesTable files = $FilesTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $TelegramAccountStatesTable telegramAccountStates =
      $TelegramAccountStatesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    buckets,
    labels,
    files,
    appSettings,
    telegramAccountStates,
  ];
}

typedef $$BucketsTableCreateCompanionBuilder =
    BucketsCompanion Function({
      Value<int> id,
      required BigInt chatId,
      required String name,
      Value<String> allowedMediaTypes,
      Value<bool> isActive,
      Value<DateTime> createdAt,
    });
typedef $$BucketsTableUpdateCompanionBuilder =
    BucketsCompanion Function({
      Value<int> id,
      Value<BigInt> chatId,
      Value<String> name,
      Value<String> allowedMediaTypes,
      Value<bool> isActive,
      Value<DateTime> createdAt,
    });

final class $$BucketsTableReferences
    extends BaseReferences<_$AppDatabase, $BucketsTable, Bucket> {
  $$BucketsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$FilesTable, List<File>> _filesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.files,
    aliasName: $_aliasNameGenerator(db.buckets.id, db.files.bucketId),
  );

  $$FilesTableProcessedTableManager get filesRefs {
    final manager = $$FilesTableTableManager(
      $_db,
      $_db.files,
    ).filter((f) => f.bucketId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_filesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BucketsTableFilterComposer
    extends Composer<_$AppDatabase, $BucketsTable> {
  $$BucketsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<BigInt> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get allowedMediaTypes => $composableBuilder(
    column: $table.allowedMediaTypes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> filesRefs(
    Expression<bool> Function($$FilesTableFilterComposer f) f,
  ) {
    final $$FilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.files,
      getReferencedColumn: (t) => t.bucketId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilesTableFilterComposer(
            $db: $db,
            $table: $db.files,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BucketsTableOrderingComposer
    extends Composer<_$AppDatabase, $BucketsTable> {
  $$BucketsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<BigInt> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get allowedMediaTypes => $composableBuilder(
    column: $table.allowedMediaTypes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BucketsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BucketsTable> {
  $$BucketsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<BigInt> get chatId =>
      $composableBuilder(column: $table.chatId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get allowedMediaTypes => $composableBuilder(
    column: $table.allowedMediaTypes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> filesRefs<T extends Object>(
    Expression<T> Function($$FilesTableAnnotationComposer a) f,
  ) {
    final $$FilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.files,
      getReferencedColumn: (t) => t.bucketId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilesTableAnnotationComposer(
            $db: $db,
            $table: $db.files,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BucketsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BucketsTable,
          Bucket,
          $$BucketsTableFilterComposer,
          $$BucketsTableOrderingComposer,
          $$BucketsTableAnnotationComposer,
          $$BucketsTableCreateCompanionBuilder,
          $$BucketsTableUpdateCompanionBuilder,
          (Bucket, $$BucketsTableReferences),
          Bucket,
          PrefetchHooks Function({bool filesRefs})
        > {
  $$BucketsTableTableManager(_$AppDatabase db, $BucketsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BucketsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BucketsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BucketsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<BigInt> chatId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> allowedMediaTypes = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => BucketsCompanion(
                id: id,
                chatId: chatId,
                name: name,
                allowedMediaTypes: allowedMediaTypes,
                isActive: isActive,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required BigInt chatId,
                required String name,
                Value<String> allowedMediaTypes = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => BucketsCompanion.insert(
                id: id,
                chatId: chatId,
                name: name,
                allowedMediaTypes: allowedMediaTypes,
                isActive: isActive,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BucketsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({filesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (filesRefs) db.files],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (filesRefs)
                    await $_getPrefetchedData<Bucket, $BucketsTable, File>(
                      currentTable: table,
                      referencedTable: $$BucketsTableReferences._filesRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$BucketsTableReferences(db, table, p0).filesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.bucketId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$BucketsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BucketsTable,
      Bucket,
      $$BucketsTableFilterComposer,
      $$BucketsTableOrderingComposer,
      $$BucketsTableAnnotationComposer,
      $$BucketsTableCreateCompanionBuilder,
      $$BucketsTableUpdateCompanionBuilder,
      (Bucket, $$BucketsTableReferences),
      Bucket,
      PrefetchHooks Function({bool filesRefs})
    >;
typedef $$LabelsTableCreateCompanionBuilder =
    LabelsCompanion Function({
      Value<int> id,
      required String name,
      Value<String> colorHex,
      Value<String?> emoji,
      Value<DateTime> createdAt,
    });
typedef $$LabelsTableUpdateCompanionBuilder =
    LabelsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> colorHex,
      Value<String?> emoji,
      Value<DateTime> createdAt,
    });

final class $$LabelsTableReferences
    extends BaseReferences<_$AppDatabase, $LabelsTable, Label> {
  $$LabelsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$FilesTable, List<File>> _filesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.files,
    aliasName: $_aliasNameGenerator(db.labels.id, db.files.labelId),
  );

  $$FilesTableProcessedTableManager get filesRefs {
    final manager = $$FilesTableTableManager(
      $_db,
      $_db.files,
    ).filter((f) => f.labelId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_filesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LabelsTableFilterComposer
    extends Composer<_$AppDatabase, $LabelsTable> {
  $$LabelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> filesRefs(
    Expression<bool> Function($$FilesTableFilterComposer f) f,
  ) {
    final $$FilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.files,
      getReferencedColumn: (t) => t.labelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilesTableFilterComposer(
            $db: $db,
            $table: $db.files,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LabelsTableOrderingComposer
    extends Composer<_$AppDatabase, $LabelsTable> {
  $$LabelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LabelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LabelsTable> {
  $$LabelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<String> get emoji =>
      $composableBuilder(column: $table.emoji, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> filesRefs<T extends Object>(
    Expression<T> Function($$FilesTableAnnotationComposer a) f,
  ) {
    final $$FilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.files,
      getReferencedColumn: (t) => t.labelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilesTableAnnotationComposer(
            $db: $db,
            $table: $db.files,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LabelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LabelsTable,
          Label,
          $$LabelsTableFilterComposer,
          $$LabelsTableOrderingComposer,
          $$LabelsTableAnnotationComposer,
          $$LabelsTableCreateCompanionBuilder,
          $$LabelsTableUpdateCompanionBuilder,
          (Label, $$LabelsTableReferences),
          Label,
          PrefetchHooks Function({bool filesRefs})
        > {
  $$LabelsTableTableManager(_$AppDatabase db, $LabelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LabelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LabelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LabelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> colorHex = const Value.absent(),
                Value<String?> emoji = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => LabelsCompanion(
                id: id,
                name: name,
                colorHex: colorHex,
                emoji: emoji,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> colorHex = const Value.absent(),
                Value<String?> emoji = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => LabelsCompanion.insert(
                id: id,
                name: name,
                colorHex: colorHex,
                emoji: emoji,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$LabelsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({filesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (filesRefs) db.files],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (filesRefs)
                    await $_getPrefetchedData<Label, $LabelsTable, File>(
                      currentTable: table,
                      referencedTable: $$LabelsTableReferences._filesRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$LabelsTableReferences(db, table, p0).filesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.labelId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LabelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LabelsTable,
      Label,
      $$LabelsTableFilterComposer,
      $$LabelsTableOrderingComposer,
      $$LabelsTableAnnotationComposer,
      $$LabelsTableCreateCompanionBuilder,
      $$LabelsTableUpdateCompanionBuilder,
      (Label, $$LabelsTableReferences),
      Label,
      PrefetchHooks Function({bool filesRefs})
    >;
typedef $$FilesTableCreateCompanionBuilder =
    FilesCompanion Function({
      Value<int> id,
      required String localPath,
      Value<bool> localPathResolved,
      Value<String> localMediaAccessState,
      Value<String?> assetId,
      required String folderName,
      Value<String?> fileHash,
      required int size,
      required int bucketId,
      Value<int?> telegramMessageId,
      Value<int?> telegramFileId,
      Value<String?> uploadOperationId,
      Value<bool> remoteStateVerified,
      Value<int> status,
      Value<int> retryCount,
      Value<String?> lastError,
      Value<DateTime?> nextRetryAt,
      Value<DateTime?> lastAttemptAt,
      Value<int?> telegramErrorCode,
      Value<String?> telegramErrorCategory,
      Value<DateTime?> telegramRetryAfter,
      Value<String?> lastTelegramOperation,
      Value<bool> userActionRequired,
      Value<bool> isVaulted,
      Value<bool> isEncrypted,
      Value<int?> encryptionVersion,
      Value<String?> ivB64,
      Value<int?> vaultFormatVersion,
      Value<String?> encryptedObjectId,
      Value<int?> encryptedSize,
      Value<int?> originalSize,
      Value<String> vaultIntegrityStatus,
      Value<String> vaultMigrationStatus,
      Value<int?> keyWrappingVersion,
      Value<DateTime?> lastVerifiedAt,
      Value<DateTime?> deletedLocallyAt,
      Value<int?> labelId,
      Value<DateTime> dateAdded,
    });
typedef $$FilesTableUpdateCompanionBuilder =
    FilesCompanion Function({
      Value<int> id,
      Value<String> localPath,
      Value<bool> localPathResolved,
      Value<String> localMediaAccessState,
      Value<String?> assetId,
      Value<String> folderName,
      Value<String?> fileHash,
      Value<int> size,
      Value<int> bucketId,
      Value<int?> telegramMessageId,
      Value<int?> telegramFileId,
      Value<String?> uploadOperationId,
      Value<bool> remoteStateVerified,
      Value<int> status,
      Value<int> retryCount,
      Value<String?> lastError,
      Value<DateTime?> nextRetryAt,
      Value<DateTime?> lastAttemptAt,
      Value<int?> telegramErrorCode,
      Value<String?> telegramErrorCategory,
      Value<DateTime?> telegramRetryAfter,
      Value<String?> lastTelegramOperation,
      Value<bool> userActionRequired,
      Value<bool> isVaulted,
      Value<bool> isEncrypted,
      Value<int?> encryptionVersion,
      Value<String?> ivB64,
      Value<int?> vaultFormatVersion,
      Value<String?> encryptedObjectId,
      Value<int?> encryptedSize,
      Value<int?> originalSize,
      Value<String> vaultIntegrityStatus,
      Value<String> vaultMigrationStatus,
      Value<int?> keyWrappingVersion,
      Value<DateTime?> lastVerifiedAt,
      Value<DateTime?> deletedLocallyAt,
      Value<int?> labelId,
      Value<DateTime> dateAdded,
    });

final class $$FilesTableReferences
    extends BaseReferences<_$AppDatabase, $FilesTable, File> {
  $$FilesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BucketsTable _bucketIdTable(_$AppDatabase db) => db.buckets
      .createAlias($_aliasNameGenerator(db.files.bucketId, db.buckets.id));

  $$BucketsTableProcessedTableManager get bucketId {
    final $_column = $_itemColumn<int>('bucket_id')!;

    final manager = $$BucketsTableTableManager(
      $_db,
      $_db.buckets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bucketIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $LabelsTable _labelIdTable(_$AppDatabase db) => db.labels.createAlias(
    $_aliasNameGenerator(db.files.labelId, db.labels.id),
  );

  $$LabelsTableProcessedTableManager? get labelId {
    final $_column = $_itemColumn<int>('label_id');
    if ($_column == null) return null;
    final manager = $$LabelsTableTableManager(
      $_db,
      $_db.labels,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_labelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FilesTableFilterComposer extends Composer<_$AppDatabase, $FilesTable> {
  $$FilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get localPathResolved => $composableBuilder(
    column: $table.localPathResolved,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localMediaAccessState => $composableBuilder(
    column: $table.localMediaAccessState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderName => $composableBuilder(
    column: $table.folderName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileHash => $composableBuilder(
    column: $table.fileHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get telegramMessageId => $composableBuilder(
    column: $table.telegramMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get telegramFileId => $composableBuilder(
    column: $table.telegramFileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uploadOperationId => $composableBuilder(
    column: $table.uploadOperationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get remoteStateVerified => $composableBuilder(
    column: $table.remoteStateVerified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get telegramErrorCode => $composableBuilder(
    column: $table.telegramErrorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get telegramErrorCategory => $composableBuilder(
    column: $table.telegramErrorCategory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get telegramRetryAfter => $composableBuilder(
    column: $table.telegramRetryAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastTelegramOperation => $composableBuilder(
    column: $table.lastTelegramOperation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get userActionRequired => $composableBuilder(
    column: $table.userActionRequired,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isVaulted => $composableBuilder(
    column: $table.isVaulted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEncrypted => $composableBuilder(
    column: $table.isEncrypted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get encryptionVersion => $composableBuilder(
    column: $table.encryptionVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ivB64 => $composableBuilder(
    column: $table.ivB64,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get vaultFormatVersion => $composableBuilder(
    column: $table.vaultFormatVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedObjectId => $composableBuilder(
    column: $table.encryptedObjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get encryptedSize => $composableBuilder(
    column: $table.encryptedSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get originalSize => $composableBuilder(
    column: $table.originalSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vaultIntegrityStatus => $composableBuilder(
    column: $table.vaultIntegrityStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vaultMigrationStatus => $composableBuilder(
    column: $table.vaultMigrationStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get keyWrappingVersion => $composableBuilder(
    column: $table.keyWrappingVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastVerifiedAt => $composableBuilder(
    column: $table.lastVerifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedLocallyAt => $composableBuilder(
    column: $table.deletedLocallyAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dateAdded => $composableBuilder(
    column: $table.dateAdded,
    builder: (column) => ColumnFilters(column),
  );

  $$BucketsTableFilterComposer get bucketId {
    final $$BucketsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bucketId,
      referencedTable: $db.buckets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BucketsTableFilterComposer(
            $db: $db,
            $table: $db.buckets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LabelsTableFilterComposer get labelId {
    final $$LabelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.labelId,
      referencedTable: $db.labels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LabelsTableFilterComposer(
            $db: $db,
            $table: $db.labels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FilesTableOrderingComposer
    extends Composer<_$AppDatabase, $FilesTable> {
  $$FilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get localPathResolved => $composableBuilder(
    column: $table.localPathResolved,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localMediaAccessState => $composableBuilder(
    column: $table.localMediaAccessState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderName => $composableBuilder(
    column: $table.folderName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileHash => $composableBuilder(
    column: $table.fileHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get telegramMessageId => $composableBuilder(
    column: $table.telegramMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get telegramFileId => $composableBuilder(
    column: $table.telegramFileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uploadOperationId => $composableBuilder(
    column: $table.uploadOperationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get remoteStateVerified => $composableBuilder(
    column: $table.remoteStateVerified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get telegramErrorCode => $composableBuilder(
    column: $table.telegramErrorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get telegramErrorCategory => $composableBuilder(
    column: $table.telegramErrorCategory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get telegramRetryAfter => $composableBuilder(
    column: $table.telegramRetryAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastTelegramOperation => $composableBuilder(
    column: $table.lastTelegramOperation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get userActionRequired => $composableBuilder(
    column: $table.userActionRequired,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isVaulted => $composableBuilder(
    column: $table.isVaulted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEncrypted => $composableBuilder(
    column: $table.isEncrypted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get encryptionVersion => $composableBuilder(
    column: $table.encryptionVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ivB64 => $composableBuilder(
    column: $table.ivB64,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get vaultFormatVersion => $composableBuilder(
    column: $table.vaultFormatVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedObjectId => $composableBuilder(
    column: $table.encryptedObjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get encryptedSize => $composableBuilder(
    column: $table.encryptedSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get originalSize => $composableBuilder(
    column: $table.originalSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vaultIntegrityStatus => $composableBuilder(
    column: $table.vaultIntegrityStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vaultMigrationStatus => $composableBuilder(
    column: $table.vaultMigrationStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get keyWrappingVersion => $composableBuilder(
    column: $table.keyWrappingVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastVerifiedAt => $composableBuilder(
    column: $table.lastVerifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedLocallyAt => $composableBuilder(
    column: $table.deletedLocallyAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dateAdded => $composableBuilder(
    column: $table.dateAdded,
    builder: (column) => ColumnOrderings(column),
  );

  $$BucketsTableOrderingComposer get bucketId {
    final $$BucketsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bucketId,
      referencedTable: $db.buckets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BucketsTableOrderingComposer(
            $db: $db,
            $table: $db.buckets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LabelsTableOrderingComposer get labelId {
    final $$LabelsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.labelId,
      referencedTable: $db.labels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LabelsTableOrderingComposer(
            $db: $db,
            $table: $db.labels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FilesTable> {
  $$FilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<bool> get localPathResolved => $composableBuilder(
    column: $table.localPathResolved,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localMediaAccessState => $composableBuilder(
    column: $table.localMediaAccessState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<String> get folderName => $composableBuilder(
    column: $table.folderName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fileHash =>
      $composableBuilder(column: $table.fileHash, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<int> get telegramMessageId => $composableBuilder(
    column: $table.telegramMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get telegramFileId => $composableBuilder(
    column: $table.telegramFileId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get uploadOperationId => $composableBuilder(
    column: $table.uploadOperationId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get remoteStateVerified => $composableBuilder(
    column: $table.remoteStateVerified,
    builder: (column) => column,
  );

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get telegramErrorCode => $composableBuilder(
    column: $table.telegramErrorCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get telegramErrorCategory => $composableBuilder(
    column: $table.telegramErrorCategory,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get telegramRetryAfter => $composableBuilder(
    column: $table.telegramRetryAfter,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastTelegramOperation => $composableBuilder(
    column: $table.lastTelegramOperation,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get userActionRequired => $composableBuilder(
    column: $table.userActionRequired,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isVaulted =>
      $composableBuilder(column: $table.isVaulted, builder: (column) => column);

  GeneratedColumn<bool> get isEncrypted => $composableBuilder(
    column: $table.isEncrypted,
    builder: (column) => column,
  );

  GeneratedColumn<int> get encryptionVersion => $composableBuilder(
    column: $table.encryptionVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ivB64 =>
      $composableBuilder(column: $table.ivB64, builder: (column) => column);

  GeneratedColumn<int> get vaultFormatVersion => $composableBuilder(
    column: $table.vaultFormatVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get encryptedObjectId => $composableBuilder(
    column: $table.encryptedObjectId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get encryptedSize => $composableBuilder(
    column: $table.encryptedSize,
    builder: (column) => column,
  );

  GeneratedColumn<int> get originalSize => $composableBuilder(
    column: $table.originalSize,
    builder: (column) => column,
  );

  GeneratedColumn<String> get vaultIntegrityStatus => $composableBuilder(
    column: $table.vaultIntegrityStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get vaultMigrationStatus => $composableBuilder(
    column: $table.vaultMigrationStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get keyWrappingVersion => $composableBuilder(
    column: $table.keyWrappingVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastVerifiedAt => $composableBuilder(
    column: $table.lastVerifiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedLocallyAt => $composableBuilder(
    column: $table.deletedLocallyAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dateAdded =>
      $composableBuilder(column: $table.dateAdded, builder: (column) => column);

  $$BucketsTableAnnotationComposer get bucketId {
    final $$BucketsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bucketId,
      referencedTable: $db.buckets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BucketsTableAnnotationComposer(
            $db: $db,
            $table: $db.buckets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LabelsTableAnnotationComposer get labelId {
    final $$LabelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.labelId,
      referencedTable: $db.labels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LabelsTableAnnotationComposer(
            $db: $db,
            $table: $db.labels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FilesTable,
          File,
          $$FilesTableFilterComposer,
          $$FilesTableOrderingComposer,
          $$FilesTableAnnotationComposer,
          $$FilesTableCreateCompanionBuilder,
          $$FilesTableUpdateCompanionBuilder,
          (File, $$FilesTableReferences),
          File,
          PrefetchHooks Function({bool bucketId, bool labelId})
        > {
  $$FilesTableTableManager(_$AppDatabase db, $FilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> localPath = const Value.absent(),
                Value<bool> localPathResolved = const Value.absent(),
                Value<String> localMediaAccessState = const Value.absent(),
                Value<String?> assetId = const Value.absent(),
                Value<String> folderName = const Value.absent(),
                Value<String?> fileHash = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<int> bucketId = const Value.absent(),
                Value<int?> telegramMessageId = const Value.absent(),
                Value<int?> telegramFileId = const Value.absent(),
                Value<String?> uploadOperationId = const Value.absent(),
                Value<bool> remoteStateVerified = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<int?> telegramErrorCode = const Value.absent(),
                Value<String?> telegramErrorCategory = const Value.absent(),
                Value<DateTime?> telegramRetryAfter = const Value.absent(),
                Value<String?> lastTelegramOperation = const Value.absent(),
                Value<bool> userActionRequired = const Value.absent(),
                Value<bool> isVaulted = const Value.absent(),
                Value<bool> isEncrypted = const Value.absent(),
                Value<int?> encryptionVersion = const Value.absent(),
                Value<String?> ivB64 = const Value.absent(),
                Value<int?> vaultFormatVersion = const Value.absent(),
                Value<String?> encryptedObjectId = const Value.absent(),
                Value<int?> encryptedSize = const Value.absent(),
                Value<int?> originalSize = const Value.absent(),
                Value<String> vaultIntegrityStatus = const Value.absent(),
                Value<String> vaultMigrationStatus = const Value.absent(),
                Value<int?> keyWrappingVersion = const Value.absent(),
                Value<DateTime?> lastVerifiedAt = const Value.absent(),
                Value<DateTime?> deletedLocallyAt = const Value.absent(),
                Value<int?> labelId = const Value.absent(),
                Value<DateTime> dateAdded = const Value.absent(),
              }) => FilesCompanion(
                id: id,
                localPath: localPath,
                localPathResolved: localPathResolved,
                localMediaAccessState: localMediaAccessState,
                assetId: assetId,
                folderName: folderName,
                fileHash: fileHash,
                size: size,
                bucketId: bucketId,
                telegramMessageId: telegramMessageId,
                telegramFileId: telegramFileId,
                uploadOperationId: uploadOperationId,
                remoteStateVerified: remoteStateVerified,
                status: status,
                retryCount: retryCount,
                lastError: lastError,
                nextRetryAt: nextRetryAt,
                lastAttemptAt: lastAttemptAt,
                telegramErrorCode: telegramErrorCode,
                telegramErrorCategory: telegramErrorCategory,
                telegramRetryAfter: telegramRetryAfter,
                lastTelegramOperation: lastTelegramOperation,
                userActionRequired: userActionRequired,
                isVaulted: isVaulted,
                isEncrypted: isEncrypted,
                encryptionVersion: encryptionVersion,
                ivB64: ivB64,
                vaultFormatVersion: vaultFormatVersion,
                encryptedObjectId: encryptedObjectId,
                encryptedSize: encryptedSize,
                originalSize: originalSize,
                vaultIntegrityStatus: vaultIntegrityStatus,
                vaultMigrationStatus: vaultMigrationStatus,
                keyWrappingVersion: keyWrappingVersion,
                lastVerifiedAt: lastVerifiedAt,
                deletedLocallyAt: deletedLocallyAt,
                labelId: labelId,
                dateAdded: dateAdded,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String localPath,
                Value<bool> localPathResolved = const Value.absent(),
                Value<String> localMediaAccessState = const Value.absent(),
                Value<String?> assetId = const Value.absent(),
                required String folderName,
                Value<String?> fileHash = const Value.absent(),
                required int size,
                required int bucketId,
                Value<int?> telegramMessageId = const Value.absent(),
                Value<int?> telegramFileId = const Value.absent(),
                Value<String?> uploadOperationId = const Value.absent(),
                Value<bool> remoteStateVerified = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<int?> telegramErrorCode = const Value.absent(),
                Value<String?> telegramErrorCategory = const Value.absent(),
                Value<DateTime?> telegramRetryAfter = const Value.absent(),
                Value<String?> lastTelegramOperation = const Value.absent(),
                Value<bool> userActionRequired = const Value.absent(),
                Value<bool> isVaulted = const Value.absent(),
                Value<bool> isEncrypted = const Value.absent(),
                Value<int?> encryptionVersion = const Value.absent(),
                Value<String?> ivB64 = const Value.absent(),
                Value<int?> vaultFormatVersion = const Value.absent(),
                Value<String?> encryptedObjectId = const Value.absent(),
                Value<int?> encryptedSize = const Value.absent(),
                Value<int?> originalSize = const Value.absent(),
                Value<String> vaultIntegrityStatus = const Value.absent(),
                Value<String> vaultMigrationStatus = const Value.absent(),
                Value<int?> keyWrappingVersion = const Value.absent(),
                Value<DateTime?> lastVerifiedAt = const Value.absent(),
                Value<DateTime?> deletedLocallyAt = const Value.absent(),
                Value<int?> labelId = const Value.absent(),
                Value<DateTime> dateAdded = const Value.absent(),
              }) => FilesCompanion.insert(
                id: id,
                localPath: localPath,
                localPathResolved: localPathResolved,
                localMediaAccessState: localMediaAccessState,
                assetId: assetId,
                folderName: folderName,
                fileHash: fileHash,
                size: size,
                bucketId: bucketId,
                telegramMessageId: telegramMessageId,
                telegramFileId: telegramFileId,
                uploadOperationId: uploadOperationId,
                remoteStateVerified: remoteStateVerified,
                status: status,
                retryCount: retryCount,
                lastError: lastError,
                nextRetryAt: nextRetryAt,
                lastAttemptAt: lastAttemptAt,
                telegramErrorCode: telegramErrorCode,
                telegramErrorCategory: telegramErrorCategory,
                telegramRetryAfter: telegramRetryAfter,
                lastTelegramOperation: lastTelegramOperation,
                userActionRequired: userActionRequired,
                isVaulted: isVaulted,
                isEncrypted: isEncrypted,
                encryptionVersion: encryptionVersion,
                ivB64: ivB64,
                vaultFormatVersion: vaultFormatVersion,
                encryptedObjectId: encryptedObjectId,
                encryptedSize: encryptedSize,
                originalSize: originalSize,
                vaultIntegrityStatus: vaultIntegrityStatus,
                vaultMigrationStatus: vaultMigrationStatus,
                keyWrappingVersion: keyWrappingVersion,
                lastVerifiedAt: lastVerifiedAt,
                deletedLocallyAt: deletedLocallyAt,
                labelId: labelId,
                dateAdded: dateAdded,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$FilesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({bucketId = false, labelId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (bucketId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.bucketId,
                                referencedTable: $$FilesTableReferences
                                    ._bucketIdTable(db),
                                referencedColumn: $$FilesTableReferences
                                    ._bucketIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (labelId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.labelId,
                                referencedTable: $$FilesTableReferences
                                    ._labelIdTable(db),
                                referencedColumn: $$FilesTableReferences
                                    ._labelIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FilesTable,
      File,
      $$FilesTableFilterComposer,
      $$FilesTableOrderingComposer,
      $$FilesTableAnnotationComposer,
      $$FilesTableCreateCompanionBuilder,
      $$FilesTableUpdateCompanionBuilder,
      (File, $$FilesTableReferences),
      File,
      PrefetchHooks Function({bool bucketId, bool labelId})
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;
typedef $$TelegramAccountStatesTableCreateCompanionBuilder =
    TelegramAccountStatesCompanion Function({
      Value<BigInt> accountId,
      Value<bool> isPremium,
      Value<DateTime?> premiumUpdatedAt,
      Value<DateTime?> serverRetryUntil,
      Value<DateTime?> writeBlockedUntil,
      Value<String?> pauseReason,
      Value<bool> isPremiumFloodWait,
      Value<DateTime> updatedAt,
    });
typedef $$TelegramAccountStatesTableUpdateCompanionBuilder =
    TelegramAccountStatesCompanion Function({
      Value<BigInt> accountId,
      Value<bool> isPremium,
      Value<DateTime?> premiumUpdatedAt,
      Value<DateTime?> serverRetryUntil,
      Value<DateTime?> writeBlockedUntil,
      Value<String?> pauseReason,
      Value<bool> isPremiumFloodWait,
      Value<DateTime> updatedAt,
    });

class $$TelegramAccountStatesTableFilterComposer
    extends Composer<_$AppDatabase, $TelegramAccountStatesTable> {
  $$TelegramAccountStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<BigInt> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPremium => $composableBuilder(
    column: $table.isPremium,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get premiumUpdatedAt => $composableBuilder(
    column: $table.premiumUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get serverRetryUntil => $composableBuilder(
    column: $table.serverRetryUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get writeBlockedUntil => $composableBuilder(
    column: $table.writeBlockedUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pauseReason => $composableBuilder(
    column: $table.pauseReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPremiumFloodWait => $composableBuilder(
    column: $table.isPremiumFloodWait,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TelegramAccountStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $TelegramAccountStatesTable> {
  $$TelegramAccountStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<BigInt> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPremium => $composableBuilder(
    column: $table.isPremium,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get premiumUpdatedAt => $composableBuilder(
    column: $table.premiumUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get serverRetryUntil => $composableBuilder(
    column: $table.serverRetryUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get writeBlockedUntil => $composableBuilder(
    column: $table.writeBlockedUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pauseReason => $composableBuilder(
    column: $table.pauseReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPremiumFloodWait => $composableBuilder(
    column: $table.isPremiumFloodWait,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TelegramAccountStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TelegramAccountStatesTable> {
  $$TelegramAccountStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<BigInt> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<bool> get isPremium =>
      $composableBuilder(column: $table.isPremium, builder: (column) => column);

  GeneratedColumn<DateTime> get premiumUpdatedAt => $composableBuilder(
    column: $table.premiumUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get serverRetryUntil => $composableBuilder(
    column: $table.serverRetryUntil,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get writeBlockedUntil => $composableBuilder(
    column: $table.writeBlockedUntil,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pauseReason => $composableBuilder(
    column: $table.pauseReason,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPremiumFloodWait => $composableBuilder(
    column: $table.isPremiumFloodWait,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TelegramAccountStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TelegramAccountStatesTable,
          TelegramAccountState,
          $$TelegramAccountStatesTableFilterComposer,
          $$TelegramAccountStatesTableOrderingComposer,
          $$TelegramAccountStatesTableAnnotationComposer,
          $$TelegramAccountStatesTableCreateCompanionBuilder,
          $$TelegramAccountStatesTableUpdateCompanionBuilder,
          (
            TelegramAccountState,
            BaseReferences<
              _$AppDatabase,
              $TelegramAccountStatesTable,
              TelegramAccountState
            >,
          ),
          TelegramAccountState,
          PrefetchHooks Function()
        > {
  $$TelegramAccountStatesTableTableManager(
    _$AppDatabase db,
    $TelegramAccountStatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TelegramAccountStatesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$TelegramAccountStatesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$TelegramAccountStatesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<BigInt> accountId = const Value.absent(),
                Value<bool> isPremium = const Value.absent(),
                Value<DateTime?> premiumUpdatedAt = const Value.absent(),
                Value<DateTime?> serverRetryUntil = const Value.absent(),
                Value<DateTime?> writeBlockedUntil = const Value.absent(),
                Value<String?> pauseReason = const Value.absent(),
                Value<bool> isPremiumFloodWait = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TelegramAccountStatesCompanion(
                accountId: accountId,
                isPremium: isPremium,
                premiumUpdatedAt: premiumUpdatedAt,
                serverRetryUntil: serverRetryUntil,
                writeBlockedUntil: writeBlockedUntil,
                pauseReason: pauseReason,
                isPremiumFloodWait: isPremiumFloodWait,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<BigInt> accountId = const Value.absent(),
                Value<bool> isPremium = const Value.absent(),
                Value<DateTime?> premiumUpdatedAt = const Value.absent(),
                Value<DateTime?> serverRetryUntil = const Value.absent(),
                Value<DateTime?> writeBlockedUntil = const Value.absent(),
                Value<String?> pauseReason = const Value.absent(),
                Value<bool> isPremiumFloodWait = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TelegramAccountStatesCompanion.insert(
                accountId: accountId,
                isPremium: isPremium,
                premiumUpdatedAt: premiumUpdatedAt,
                serverRetryUntil: serverRetryUntil,
                writeBlockedUntil: writeBlockedUntil,
                pauseReason: pauseReason,
                isPremiumFloodWait: isPremiumFloodWait,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TelegramAccountStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TelegramAccountStatesTable,
      TelegramAccountState,
      $$TelegramAccountStatesTableFilterComposer,
      $$TelegramAccountStatesTableOrderingComposer,
      $$TelegramAccountStatesTableAnnotationComposer,
      $$TelegramAccountStatesTableCreateCompanionBuilder,
      $$TelegramAccountStatesTableUpdateCompanionBuilder,
      (
        TelegramAccountState,
        BaseReferences<
          _$AppDatabase,
          $TelegramAccountStatesTable,
          TelegramAccountState
        >,
      ),
      TelegramAccountState,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BucketsTableTableManager get buckets =>
      $$BucketsTableTableManager(_db, _db.buckets);
  $$LabelsTableTableManager get labels =>
      $$LabelsTableTableManager(_db, _db.labels);
  $$FilesTableTableManager get files =>
      $$FilesTableTableManager(_db, _db.files);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$TelegramAccountStatesTableTableManager get telegramAccountStates =>
      $$TelegramAccountStatesTableTableManager(_db, _db.telegramAccountStates);
}
