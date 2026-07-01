// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ItemsTable extends Items with TableInfo<$ItemsTable, Item> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _streamUrlMeta = const VerificationMeta(
    'streamUrl',
  );
  @override
  late final GeneratedColumn<String> streamUrl = GeneratedColumn<String>(
    'stream_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _logoUrlMeta = const VerificationMeta(
    'logoUrl',
  );
  @override
  late final GeneratedColumn<String> logoUrl = GeneratedColumn<String>(
    'logo_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tvgIdMeta = const VerificationMeta('tvgId');
  @override
  late final GeneratedColumn<String> tvgId = GeneratedColumn<String>(
    'tvg_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _groupTitleMeta = const VerificationMeta(
    'groupTitle',
  );
  @override
  late final GeneratedColumn<String> groupTitle = GeneratedColumn<String>(
    'group_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isHiddenMeta = const VerificationMeta(
    'isHidden',
  );
  @override
  late final GeneratedColumn<bool> isHidden = GeneratedColumn<bool>(
    'is_hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _positionSecondsMeta = const VerificationMeta(
    'positionSeconds',
  );
  @override
  late final GeneratedColumn<int> positionSeconds = GeneratedColumn<int>(
    'position_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastWatchedAtMeta = const VerificationMeta(
    'lastWatchedAt',
  );
  @override
  late final GeneratedColumn<int> lastWatchedAt = GeneratedColumn<int>(
    'last_watched_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    streamUrl,
    logoUrl,
    tvgId,
    groupTitle,
    type,
    isFavorite,
    isHidden,
    isDeleted,
    positionSeconds,
    durationSeconds,
    lastWatchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'items';
  @override
  VerificationContext validateIntegrity(
    Insertable<Item> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('stream_url')) {
      context.handle(
        _streamUrlMeta,
        streamUrl.isAcceptableOrUnknown(data['stream_url']!, _streamUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_streamUrlMeta);
    }
    if (data.containsKey('logo_url')) {
      context.handle(
        _logoUrlMeta,
        logoUrl.isAcceptableOrUnknown(data['logo_url']!, _logoUrlMeta),
      );
    }
    if (data.containsKey('tvg_id')) {
      context.handle(
        _tvgIdMeta,
        tvgId.isAcceptableOrUnknown(data['tvg_id']!, _tvgIdMeta),
      );
    }
    if (data.containsKey('group_title')) {
      context.handle(
        _groupTitleMeta,
        groupTitle.isAcceptableOrUnknown(data['group_title']!, _groupTitleMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('is_hidden')) {
      context.handle(
        _isHiddenMeta,
        isHidden.isAcceptableOrUnknown(data['is_hidden']!, _isHiddenMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('position_seconds')) {
      context.handle(
        _positionSecondsMeta,
        positionSeconds.isAcceptableOrUnknown(
          data['position_seconds']!,
          _positionSecondsMeta,
        ),
      );
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('last_watched_at')) {
      context.handle(
        _lastWatchedAtMeta,
        lastWatchedAt.isAcceptableOrUnknown(
          data['last_watched_at']!,
          _lastWatchedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Item map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Item(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      streamUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stream_url'],
      )!,
      logoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}logo_url'],
      ),
      tvgId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tvg_id'],
      ),
      groupTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_title'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type'],
      )!,
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      isHidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_hidden'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      positionSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_seconds'],
      )!,
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      )!,
      lastWatchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_watched_at'],
      )!,
    );
  }

  @override
  $ItemsTable createAlias(String alias) {
    return $ItemsTable(attachedDatabase, alias);
  }
}

class Item extends DataClass implements Insertable<Item> {
  final String id;
  final String name;
  final String streamUrl;
  final String? logoUrl;
  final String? tvgId;
  final String? groupTitle;
  final int type;
  final bool isFavorite;
  final bool isHidden;
  final bool isDeleted;
  final int positionSeconds;
  final int durationSeconds;
  final int lastWatchedAt;
  const Item({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.logoUrl,
    this.tvgId,
    this.groupTitle,
    required this.type,
    required this.isFavorite,
    required this.isHidden,
    required this.isDeleted,
    required this.positionSeconds,
    required this.durationSeconds,
    required this.lastWatchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['stream_url'] = Variable<String>(streamUrl);
    if (!nullToAbsent || logoUrl != null) {
      map['logo_url'] = Variable<String>(logoUrl);
    }
    if (!nullToAbsent || tvgId != null) {
      map['tvg_id'] = Variable<String>(tvgId);
    }
    if (!nullToAbsent || groupTitle != null) {
      map['group_title'] = Variable<String>(groupTitle);
    }
    map['type'] = Variable<int>(type);
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['is_hidden'] = Variable<bool>(isHidden);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['position_seconds'] = Variable<int>(positionSeconds);
    map['duration_seconds'] = Variable<int>(durationSeconds);
    map['last_watched_at'] = Variable<int>(lastWatchedAt);
    return map;
  }

  ItemsCompanion toCompanion(bool nullToAbsent) {
    return ItemsCompanion(
      id: Value(id),
      name: Value(name),
      streamUrl: Value(streamUrl),
      logoUrl: logoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(logoUrl),
      tvgId: tvgId == null && nullToAbsent
          ? const Value.absent()
          : Value(tvgId),
      groupTitle: groupTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(groupTitle),
      type: Value(type),
      isFavorite: Value(isFavorite),
      isHidden: Value(isHidden),
      isDeleted: Value(isDeleted),
      positionSeconds: Value(positionSeconds),
      durationSeconds: Value(durationSeconds),
      lastWatchedAt: Value(lastWatchedAt),
    );
  }

  factory Item.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Item(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      streamUrl: serializer.fromJson<String>(json['streamUrl']),
      logoUrl: serializer.fromJson<String?>(json['logoUrl']),
      tvgId: serializer.fromJson<String?>(json['tvgId']),
      groupTitle: serializer.fromJson<String?>(json['groupTitle']),
      type: serializer.fromJson<int>(json['type']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      isHidden: serializer.fromJson<bool>(json['isHidden']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      positionSeconds: serializer.fromJson<int>(json['positionSeconds']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
      lastWatchedAt: serializer.fromJson<int>(json['lastWatchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'streamUrl': serializer.toJson<String>(streamUrl),
      'logoUrl': serializer.toJson<String?>(logoUrl),
      'tvgId': serializer.toJson<String?>(tvgId),
      'groupTitle': serializer.toJson<String?>(groupTitle),
      'type': serializer.toJson<int>(type),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'isHidden': serializer.toJson<bool>(isHidden),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'positionSeconds': serializer.toJson<int>(positionSeconds),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
      'lastWatchedAt': serializer.toJson<int>(lastWatchedAt),
    };
  }

  Item copyWith({
    String? id,
    String? name,
    String? streamUrl,
    Value<String?> logoUrl = const Value.absent(),
    Value<String?> tvgId = const Value.absent(),
    Value<String?> groupTitle = const Value.absent(),
    int? type,
    bool? isFavorite,
    bool? isHidden,
    bool? isDeleted,
    int? positionSeconds,
    int? durationSeconds,
    int? lastWatchedAt,
  }) => Item(
    id: id ?? this.id,
    name: name ?? this.name,
    streamUrl: streamUrl ?? this.streamUrl,
    logoUrl: logoUrl.present ? logoUrl.value : this.logoUrl,
    tvgId: tvgId.present ? tvgId.value : this.tvgId,
    groupTitle: groupTitle.present ? groupTitle.value : this.groupTitle,
    type: type ?? this.type,
    isFavorite: isFavorite ?? this.isFavorite,
    isHidden: isHidden ?? this.isHidden,
    isDeleted: isDeleted ?? this.isDeleted,
    positionSeconds: positionSeconds ?? this.positionSeconds,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    lastWatchedAt: lastWatchedAt ?? this.lastWatchedAt,
  );
  Item copyWithCompanion(ItemsCompanion data) {
    return Item(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      streamUrl: data.streamUrl.present ? data.streamUrl.value : this.streamUrl,
      logoUrl: data.logoUrl.present ? data.logoUrl.value : this.logoUrl,
      tvgId: data.tvgId.present ? data.tvgId.value : this.tvgId,
      groupTitle: data.groupTitle.present
          ? data.groupTitle.value
          : this.groupTitle,
      type: data.type.present ? data.type.value : this.type,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      isHidden: data.isHidden.present ? data.isHidden.value : this.isHidden,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      positionSeconds: data.positionSeconds.present
          ? data.positionSeconds.value
          : this.positionSeconds,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      lastWatchedAt: data.lastWatchedAt.present
          ? data.lastWatchedAt.value
          : this.lastWatchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Item(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('streamUrl: $streamUrl, ')
          ..write('logoUrl: $logoUrl, ')
          ..write('tvgId: $tvgId, ')
          ..write('groupTitle: $groupTitle, ')
          ..write('type: $type, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('isHidden: $isHidden, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('positionSeconds: $positionSeconds, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('lastWatchedAt: $lastWatchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    streamUrl,
    logoUrl,
    tvgId,
    groupTitle,
    type,
    isFavorite,
    isHidden,
    isDeleted,
    positionSeconds,
    durationSeconds,
    lastWatchedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Item &&
          other.id == this.id &&
          other.name == this.name &&
          other.streamUrl == this.streamUrl &&
          other.logoUrl == this.logoUrl &&
          other.tvgId == this.tvgId &&
          other.groupTitle == this.groupTitle &&
          other.type == this.type &&
          other.isFavorite == this.isFavorite &&
          other.isHidden == this.isHidden &&
          other.isDeleted == this.isDeleted &&
          other.positionSeconds == this.positionSeconds &&
          other.durationSeconds == this.durationSeconds &&
          other.lastWatchedAt == this.lastWatchedAt);
}

class ItemsCompanion extends UpdateCompanion<Item> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> streamUrl;
  final Value<String?> logoUrl;
  final Value<String?> tvgId;
  final Value<String?> groupTitle;
  final Value<int> type;
  final Value<bool> isFavorite;
  final Value<bool> isHidden;
  final Value<bool> isDeleted;
  final Value<int> positionSeconds;
  final Value<int> durationSeconds;
  final Value<int> lastWatchedAt;
  final Value<int> rowid;
  const ItemsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.streamUrl = const Value.absent(),
    this.logoUrl = const Value.absent(),
    this.tvgId = const Value.absent(),
    this.groupTitle = const Value.absent(),
    this.type = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.isHidden = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.positionSeconds = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.lastWatchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemsCompanion.insert({
    required String id,
    required String name,
    required String streamUrl,
    this.logoUrl = const Value.absent(),
    this.tvgId = const Value.absent(),
    this.groupTitle = const Value.absent(),
    required int type,
    this.isFavorite = const Value.absent(),
    this.isHidden = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.positionSeconds = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.lastWatchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       streamUrl = Value(streamUrl),
       type = Value(type);
  static Insertable<Item> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? streamUrl,
    Expression<String>? logoUrl,
    Expression<String>? tvgId,
    Expression<String>? groupTitle,
    Expression<int>? type,
    Expression<bool>? isFavorite,
    Expression<bool>? isHidden,
    Expression<bool>? isDeleted,
    Expression<int>? positionSeconds,
    Expression<int>? durationSeconds,
    Expression<int>? lastWatchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (streamUrl != null) 'stream_url': streamUrl,
      if (logoUrl != null) 'logo_url': logoUrl,
      if (tvgId != null) 'tvg_id': tvgId,
      if (groupTitle != null) 'group_title': groupTitle,
      if (type != null) 'type': type,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (isHidden != null) 'is_hidden': isHidden,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (positionSeconds != null) 'position_seconds': positionSeconds,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (lastWatchedAt != null) 'last_watched_at': lastWatchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? streamUrl,
    Value<String?>? logoUrl,
    Value<String?>? tvgId,
    Value<String?>? groupTitle,
    Value<int>? type,
    Value<bool>? isFavorite,
    Value<bool>? isHidden,
    Value<bool>? isDeleted,
    Value<int>? positionSeconds,
    Value<int>? durationSeconds,
    Value<int>? lastWatchedAt,
    Value<int>? rowid,
  }) {
    return ItemsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      streamUrl: streamUrl ?? this.streamUrl,
      logoUrl: logoUrl ?? this.logoUrl,
      tvgId: tvgId ?? this.tvgId,
      groupTitle: groupTitle ?? this.groupTitle,
      type: type ?? this.type,
      isFavorite: isFavorite ?? this.isFavorite,
      isHidden: isHidden ?? this.isHidden,
      isDeleted: isDeleted ?? this.isDeleted,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      lastWatchedAt: lastWatchedAt ?? this.lastWatchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (streamUrl.present) {
      map['stream_url'] = Variable<String>(streamUrl.value);
    }
    if (logoUrl.present) {
      map['logo_url'] = Variable<String>(logoUrl.value);
    }
    if (tvgId.present) {
      map['tvg_id'] = Variable<String>(tvgId.value);
    }
    if (groupTitle.present) {
      map['group_title'] = Variable<String>(groupTitle.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (isHidden.present) {
      map['is_hidden'] = Variable<bool>(isHidden.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (positionSeconds.present) {
      map['position_seconds'] = Variable<int>(positionSeconds.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (lastWatchedAt.present) {
      map['last_watched_at'] = Variable<int>(lastWatchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('streamUrl: $streamUrl, ')
          ..write('logoUrl: $logoUrl, ')
          ..write('tvgId: $tvgId, ')
          ..write('groupTitle: $groupTitle, ')
          ..write('type: $type, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('isHidden: $isHidden, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('positionSeconds: $positionSeconds, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('lastWatchedAt: $lastWatchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ItemsTable items = $ItemsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [items];
}

typedef $$ItemsTableCreateCompanionBuilder =
    ItemsCompanion Function({
      required String id,
      required String name,
      required String streamUrl,
      Value<String?> logoUrl,
      Value<String?> tvgId,
      Value<String?> groupTitle,
      required int type,
      Value<bool> isFavorite,
      Value<bool> isHidden,
      Value<bool> isDeleted,
      Value<int> positionSeconds,
      Value<int> durationSeconds,
      Value<int> lastWatchedAt,
      Value<int> rowid,
    });
typedef $$ItemsTableUpdateCompanionBuilder =
    ItemsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> streamUrl,
      Value<String?> logoUrl,
      Value<String?> tvgId,
      Value<String?> groupTitle,
      Value<int> type,
      Value<bool> isFavorite,
      Value<bool> isHidden,
      Value<bool> isDeleted,
      Value<int> positionSeconds,
      Value<int> durationSeconds,
      Value<int> lastWatchedAt,
      Value<int> rowid,
    });

class $$ItemsTableFilterComposer extends Composer<_$AppDatabase, $ItemsTable> {
  $$ItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get streamUrl => $composableBuilder(
    column: $table.streamUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get logoUrl => $composableBuilder(
    column: $table.logoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tvgId => $composableBuilder(
    column: $table.tvgId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupTitle => $composableBuilder(
    column: $table.groupTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isHidden => $composableBuilder(
    column: $table.isHidden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionSeconds => $composableBuilder(
    column: $table.positionSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastWatchedAt => $composableBuilder(
    column: $table.lastWatchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ItemsTable> {
  $$ItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get streamUrl => $composableBuilder(
    column: $table.streamUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get logoUrl => $composableBuilder(
    column: $table.logoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tvgId => $composableBuilder(
    column: $table.tvgId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupTitle => $composableBuilder(
    column: $table.groupTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isHidden => $composableBuilder(
    column: $table.isHidden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionSeconds => $composableBuilder(
    column: $table.positionSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastWatchedAt => $composableBuilder(
    column: $table.lastWatchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItemsTable> {
  $$ItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get streamUrl =>
      $composableBuilder(column: $table.streamUrl, builder: (column) => column);

  GeneratedColumn<String> get logoUrl =>
      $composableBuilder(column: $table.logoUrl, builder: (column) => column);

  GeneratedColumn<String> get tvgId =>
      $composableBuilder(column: $table.tvgId, builder: (column) => column);

  GeneratedColumn<String> get groupTitle => $composableBuilder(
    column: $table.groupTitle,
    builder: (column) => column,
  );

  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isHidden =>
      $composableBuilder(column: $table.isHidden, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<int> get positionSeconds => $composableBuilder(
    column: $table.positionSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastWatchedAt => $composableBuilder(
    column: $table.lastWatchedAt,
    builder: (column) => column,
  );
}

class $$ItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ItemsTable,
          Item,
          $$ItemsTableFilterComposer,
          $$ItemsTableOrderingComposer,
          $$ItemsTableAnnotationComposer,
          $$ItemsTableCreateCompanionBuilder,
          $$ItemsTableUpdateCompanionBuilder,
          (Item, BaseReferences<_$AppDatabase, $ItemsTable, Item>),
          Item,
          PrefetchHooks Function()
        > {
  $$ItemsTableTableManager(_$AppDatabase db, $ItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> streamUrl = const Value.absent(),
                Value<String?> logoUrl = const Value.absent(),
                Value<String?> tvgId = const Value.absent(),
                Value<String?> groupTitle = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<bool> isHidden = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> positionSeconds = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<int> lastWatchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemsCompanion(
                id: id,
                name: name,
                streamUrl: streamUrl,
                logoUrl: logoUrl,
                tvgId: tvgId,
                groupTitle: groupTitle,
                type: type,
                isFavorite: isFavorite,
                isHidden: isHidden,
                isDeleted: isDeleted,
                positionSeconds: positionSeconds,
                durationSeconds: durationSeconds,
                lastWatchedAt: lastWatchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String streamUrl,
                Value<String?> logoUrl = const Value.absent(),
                Value<String?> tvgId = const Value.absent(),
                Value<String?> groupTitle = const Value.absent(),
                required int type,
                Value<bool> isFavorite = const Value.absent(),
                Value<bool> isHidden = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> positionSeconds = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<int> lastWatchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemsCompanion.insert(
                id: id,
                name: name,
                streamUrl: streamUrl,
                logoUrl: logoUrl,
                tvgId: tvgId,
                groupTitle: groupTitle,
                type: type,
                isFavorite: isFavorite,
                isHidden: isHidden,
                isDeleted: isDeleted,
                positionSeconds: positionSeconds,
                durationSeconds: durationSeconds,
                lastWatchedAt: lastWatchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ItemsTable,
      Item,
      $$ItemsTableFilterComposer,
      $$ItemsTableOrderingComposer,
      $$ItemsTableAnnotationComposer,
      $$ItemsTableCreateCompanionBuilder,
      $$ItemsTableUpdateCompanionBuilder,
      (Item, BaseReferences<_$AppDatabase, $ItemsTable, Item>),
      Item,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ItemsTableTableManager get items =>
      $$ItemsTableTableManager(_db, _db.items);
}
