// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LibraryFoldersTable extends LibraryFolders
    with TableInfo<$LibraryFoldersTable, LibraryFolder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryFoldersTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryFolder> instance, {
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
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LibraryFolder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryFolder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LibraryFoldersTable createAlias(String alias) {
    return $LibraryFoldersTable(attachedDatabase, alias);
  }
}

class LibraryFolder extends DataClass implements Insertable<LibraryFolder> {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  const LibraryFolder({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LibraryFoldersCompanion toCompanion(bool nullToAbsent) {
    return LibraryFoldersCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LibraryFolder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryFolder(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LibraryFolder copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => LibraryFolder(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LibraryFolder copyWithCompanion(LibraryFoldersCompanion data) {
    return LibraryFolder(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryFolder(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryFolder &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LibraryFoldersCompanion extends UpdateCompanion<LibraryFolder> {
  final Value<String> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LibraryFoldersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LibraryFoldersCompanion.insert({
    required String id,
    required String name,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LibraryFolder> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LibraryFoldersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LibraryFoldersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryFoldersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DocumentsTable extends Documents
    with TableInfo<$DocumentsTable, Document> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceFilenameMeta = const VerificationMeta(
    'sourceFilename',
  );
  @override
  late final GeneratedColumn<String> sourceFilename = GeneratedColumn<String>(
    'source_filename',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPdfPathMeta = const VerificationMeta(
    'localPdfPath',
  );
  @override
  late final GeneratedColumn<String> localPdfPath = GeneratedColumn<String>(
    'local_pdf_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _packagePathMeta = const VerificationMeta(
    'packagePath',
  );
  @override
  late final GeneratedColumn<String> packagePath = GeneratedColumn<String>(
    'package_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES library_folders (id)',
    ),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastReadBlockIdMeta = const VerificationMeta(
    'lastReadBlockId',
  );
  @override
  late final GeneratedColumn<String> lastReadBlockId = GeneratedColumn<String>(
    'last_read_block_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastReadOffsetMeta = const VerificationMeta(
    'lastReadOffset',
  );
  @override
  late final GeneratedColumn<int> lastReadOffset = GeneratedColumn<int>(
    'last_read_offset',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
    requiredDuringInsert: true,
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    sourceFilename,
    localPdfPath,
    packagePath,
    folderId,
    status,
    lastReadBlockId,
    lastReadOffset,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<Document> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('source_filename')) {
      context.handle(
        _sourceFilenameMeta,
        sourceFilename.isAcceptableOrUnknown(
          data['source_filename']!,
          _sourceFilenameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceFilenameMeta);
    }
    if (data.containsKey('local_pdf_path')) {
      context.handle(
        _localPdfPathMeta,
        localPdfPath.isAcceptableOrUnknown(
          data['local_pdf_path']!,
          _localPdfPathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localPdfPathMeta);
    }
    if (data.containsKey('package_path')) {
      context.handle(
        _packagePathMeta,
        packagePath.isAcceptableOrUnknown(
          data['package_path']!,
          _packagePathMeta,
        ),
      );
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('last_read_block_id')) {
      context.handle(
        _lastReadBlockIdMeta,
        lastReadBlockId.isAcceptableOrUnknown(
          data['last_read_block_id']!,
          _lastReadBlockIdMeta,
        ),
      );
    }
    if (data.containsKey('last_read_offset')) {
      context.handle(
        _lastReadOffsetMeta,
        lastReadOffset.isAcceptableOrUnknown(
          data['last_read_offset']!,
          _lastReadOffsetMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Document map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Document(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      sourceFilename: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_filename'],
      )!,
      localPdfPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_pdf_path'],
      )!,
      packagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}package_path'],
      ),
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      lastReadBlockId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_read_block_id'],
      ),
      lastReadOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_read_offset'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DocumentsTable createAlias(String alias) {
    return $DocumentsTable(attachedDatabase, alias);
  }
}

class Document extends DataClass implements Insertable<Document> {
  final String id;
  final String title;
  final String sourceFilename;
  final String localPdfPath;
  final String? packagePath;
  final String? folderId;
  final String status;
  final String? lastReadBlockId;
  final int? lastReadOffset;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Document({
    required this.id,
    required this.title,
    required this.sourceFilename,
    required this.localPdfPath,
    this.packagePath,
    this.folderId,
    required this.status,
    this.lastReadBlockId,
    this.lastReadOffset,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['source_filename'] = Variable<String>(sourceFilename);
    map['local_pdf_path'] = Variable<String>(localPdfPath);
    if (!nullToAbsent || packagePath != null) {
      map['package_path'] = Variable<String>(packagePath);
    }
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<String>(folderId);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || lastReadBlockId != null) {
      map['last_read_block_id'] = Variable<String>(lastReadBlockId);
    }
    if (!nullToAbsent || lastReadOffset != null) {
      map['last_read_offset'] = Variable<int>(lastReadOffset);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DocumentsCompanion toCompanion(bool nullToAbsent) {
    return DocumentsCompanion(
      id: Value(id),
      title: Value(title),
      sourceFilename: Value(sourceFilename),
      localPdfPath: Value(localPdfPath),
      packagePath: packagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(packagePath),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      status: Value(status),
      lastReadBlockId: lastReadBlockId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReadBlockId),
      lastReadOffset: lastReadOffset == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReadOffset),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Document.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Document(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      sourceFilename: serializer.fromJson<String>(json['sourceFilename']),
      localPdfPath: serializer.fromJson<String>(json['localPdfPath']),
      packagePath: serializer.fromJson<String?>(json['packagePath']),
      folderId: serializer.fromJson<String?>(json['folderId']),
      status: serializer.fromJson<String>(json['status']),
      lastReadBlockId: serializer.fromJson<String?>(json['lastReadBlockId']),
      lastReadOffset: serializer.fromJson<int?>(json['lastReadOffset']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'sourceFilename': serializer.toJson<String>(sourceFilename),
      'localPdfPath': serializer.toJson<String>(localPdfPath),
      'packagePath': serializer.toJson<String?>(packagePath),
      'folderId': serializer.toJson<String?>(folderId),
      'status': serializer.toJson<String>(status),
      'lastReadBlockId': serializer.toJson<String?>(lastReadBlockId),
      'lastReadOffset': serializer.toJson<int?>(lastReadOffset),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Document copyWith({
    String? id,
    String? title,
    String? sourceFilename,
    String? localPdfPath,
    Value<String?> packagePath = const Value.absent(),
    Value<String?> folderId = const Value.absent(),
    String? status,
    Value<String?> lastReadBlockId = const Value.absent(),
    Value<int?> lastReadOffset = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Document(
    id: id ?? this.id,
    title: title ?? this.title,
    sourceFilename: sourceFilename ?? this.sourceFilename,
    localPdfPath: localPdfPath ?? this.localPdfPath,
    packagePath: packagePath.present ? packagePath.value : this.packagePath,
    folderId: folderId.present ? folderId.value : this.folderId,
    status: status ?? this.status,
    lastReadBlockId: lastReadBlockId.present
        ? lastReadBlockId.value
        : this.lastReadBlockId,
    lastReadOffset: lastReadOffset.present
        ? lastReadOffset.value
        : this.lastReadOffset,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Document copyWithCompanion(DocumentsCompanion data) {
    return Document(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      sourceFilename: data.sourceFilename.present
          ? data.sourceFilename.value
          : this.sourceFilename,
      localPdfPath: data.localPdfPath.present
          ? data.localPdfPath.value
          : this.localPdfPath,
      packagePath: data.packagePath.present
          ? data.packagePath.value
          : this.packagePath,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      status: data.status.present ? data.status.value : this.status,
      lastReadBlockId: data.lastReadBlockId.present
          ? data.lastReadBlockId.value
          : this.lastReadBlockId,
      lastReadOffset: data.lastReadOffset.present
          ? data.lastReadOffset.value
          : this.lastReadOffset,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Document(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('sourceFilename: $sourceFilename, ')
          ..write('localPdfPath: $localPdfPath, ')
          ..write('packagePath: $packagePath, ')
          ..write('folderId: $folderId, ')
          ..write('status: $status, ')
          ..write('lastReadBlockId: $lastReadBlockId, ')
          ..write('lastReadOffset: $lastReadOffset, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    sourceFilename,
    localPdfPath,
    packagePath,
    folderId,
    status,
    lastReadBlockId,
    lastReadOffset,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Document &&
          other.id == this.id &&
          other.title == this.title &&
          other.sourceFilename == this.sourceFilename &&
          other.localPdfPath == this.localPdfPath &&
          other.packagePath == this.packagePath &&
          other.folderId == this.folderId &&
          other.status == this.status &&
          other.lastReadBlockId == this.lastReadBlockId &&
          other.lastReadOffset == this.lastReadOffset &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DocumentsCompanion extends UpdateCompanion<Document> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> sourceFilename;
  final Value<String> localPdfPath;
  final Value<String?> packagePath;
  final Value<String?> folderId;
  final Value<String> status;
  final Value<String?> lastReadBlockId;
  final Value<int?> lastReadOffset;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DocumentsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.sourceFilename = const Value.absent(),
    this.localPdfPath = const Value.absent(),
    this.packagePath = const Value.absent(),
    this.folderId = const Value.absent(),
    this.status = const Value.absent(),
    this.lastReadBlockId = const Value.absent(),
    this.lastReadOffset = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocumentsCompanion.insert({
    required String id,
    required String title,
    required String sourceFilename,
    required String localPdfPath,
    this.packagePath = const Value.absent(),
    this.folderId = const Value.absent(),
    required String status,
    this.lastReadBlockId = const Value.absent(),
    this.lastReadOffset = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       sourceFilename = Value(sourceFilename),
       localPdfPath = Value(localPdfPath),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Document> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? sourceFilename,
    Expression<String>? localPdfPath,
    Expression<String>? packagePath,
    Expression<String>? folderId,
    Expression<String>? status,
    Expression<String>? lastReadBlockId,
    Expression<int>? lastReadOffset,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (sourceFilename != null) 'source_filename': sourceFilename,
      if (localPdfPath != null) 'local_pdf_path': localPdfPath,
      if (packagePath != null) 'package_path': packagePath,
      if (folderId != null) 'folder_id': folderId,
      if (status != null) 'status': status,
      if (lastReadBlockId != null) 'last_read_block_id': lastReadBlockId,
      if (lastReadOffset != null) 'last_read_offset': lastReadOffset,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocumentsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? sourceFilename,
    Value<String>? localPdfPath,
    Value<String?>? packagePath,
    Value<String?>? folderId,
    Value<String>? status,
    Value<String?>? lastReadBlockId,
    Value<int?>? lastReadOffset,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return DocumentsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      sourceFilename: sourceFilename ?? this.sourceFilename,
      localPdfPath: localPdfPath ?? this.localPdfPath,
      packagePath: packagePath ?? this.packagePath,
      folderId: folderId ?? this.folderId,
      status: status ?? this.status,
      lastReadBlockId: lastReadBlockId ?? this.lastReadBlockId,
      lastReadOffset: lastReadOffset ?? this.lastReadOffset,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (sourceFilename.present) {
      map['source_filename'] = Variable<String>(sourceFilename.value);
    }
    if (localPdfPath.present) {
      map['local_pdf_path'] = Variable<String>(localPdfPath.value);
    }
    if (packagePath.present) {
      map['package_path'] = Variable<String>(packagePath.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (lastReadBlockId.present) {
      map['last_read_block_id'] = Variable<String>(lastReadBlockId.value);
    }
    if (lastReadOffset.present) {
      map['last_read_offset'] = Variable<int>(lastReadOffset.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('sourceFilename: $sourceFilename, ')
          ..write('localPdfPath: $localPdfPath, ')
          ..write('packagePath: $packagePath, ')
          ..write('folderId: $folderId, ')
          ..write('status: $status, ')
          ..write('lastReadBlockId: $lastReadBlockId, ')
          ..write('lastReadOffset: $lastReadOffset, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VocabularyEntriesTable extends VocabularyEntries
    with TableInfo<$VocabularyEntriesTable, VocabularyEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VocabularyEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES documents (id)',
    ),
  );
  static const VerificationMeta _expressionKeyMeta = const VerificationMeta(
    'expressionKey',
  );
  @override
  late final GeneratedColumn<String> expressionKey = GeneratedColumn<String>(
    'expression_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expressionMeta = const VerificationMeta(
    'expression',
  );
  @override
  late final GeneratedColumn<String> expression = GeneratedColumn<String>(
    'expression',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _meaningKoMeta = const VerificationMeta(
    'meaningKo',
  );
  @override
  late final GeneratedColumn<String> meaningKo = GeneratedColumn<String>(
    'meaning_ko',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceSentenceMeta = const VerificationMeta(
    'sourceSentence',
  );
  @override
  late final GeneratedColumn<String> sourceSentence = GeneratedColumn<String>(
    'source_sentence',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contextBeforeMeta = const VerificationMeta(
    'contextBefore',
  );
  @override
  late final GeneratedColumn<String> contextBefore = GeneratedColumn<String>(
    'context_before',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contextAfterMeta = const VerificationMeta(
    'contextAfter',
  );
  @override
  late final GeneratedColumn<String> contextAfter = GeneratedColumn<String>(
    'context_after',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _blockIdMeta = const VerificationMeta(
    'blockId',
  );
  @override
  late final GeneratedColumn<String> blockId = GeneratedColumn<String>(
    'block_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _textOffsetMeta = const VerificationMeta(
    'textOffset',
  );
  @override
  late final GeneratedColumn<int> textOffset = GeneratedColumn<int>(
    'text_offset',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userMeaningMeta = const VerificationMeta(
    'userMeaning',
  );
  @override
  late final GeneratedColumn<String> userMeaning = GeneratedColumn<String>(
    'user_meaning',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userMemoMeta = const VerificationMeta(
    'userMemo',
  );
  @override
  late final GeneratedColumn<String> userMemo = GeneratedColumn<String>(
    'user_memo',
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
    requiredDuringInsert: true,
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    documentId,
    expressionKey,
    expression,
    meaningKo,
    sourceSentence,
    contextBefore,
    contextAfter,
    blockId,
    textOffset,
    userMeaning,
    userMemo,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vocabulary_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<VocabularyEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('expression_key')) {
      context.handle(
        _expressionKeyMeta,
        expressionKey.isAcceptableOrUnknown(
          data['expression_key']!,
          _expressionKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_expressionKeyMeta);
    }
    if (data.containsKey('expression')) {
      context.handle(
        _expressionMeta,
        expression.isAcceptableOrUnknown(data['expression']!, _expressionMeta),
      );
    } else if (isInserting) {
      context.missing(_expressionMeta);
    }
    if (data.containsKey('meaning_ko')) {
      context.handle(
        _meaningKoMeta,
        meaningKo.isAcceptableOrUnknown(data['meaning_ko']!, _meaningKoMeta),
      );
    }
    if (data.containsKey('source_sentence')) {
      context.handle(
        _sourceSentenceMeta,
        sourceSentence.isAcceptableOrUnknown(
          data['source_sentence']!,
          _sourceSentenceMeta,
        ),
      );
    }
    if (data.containsKey('context_before')) {
      context.handle(
        _contextBeforeMeta,
        contextBefore.isAcceptableOrUnknown(
          data['context_before']!,
          _contextBeforeMeta,
        ),
      );
    }
    if (data.containsKey('context_after')) {
      context.handle(
        _contextAfterMeta,
        contextAfter.isAcceptableOrUnknown(
          data['context_after']!,
          _contextAfterMeta,
        ),
      );
    }
    if (data.containsKey('block_id')) {
      context.handle(
        _blockIdMeta,
        blockId.isAcceptableOrUnknown(data['block_id']!, _blockIdMeta),
      );
    }
    if (data.containsKey('text_offset')) {
      context.handle(
        _textOffsetMeta,
        textOffset.isAcceptableOrUnknown(data['text_offset']!, _textOffsetMeta),
      );
    }
    if (data.containsKey('user_meaning')) {
      context.handle(
        _userMeaningMeta,
        userMeaning.isAcceptableOrUnknown(
          data['user_meaning']!,
          _userMeaningMeta,
        ),
      );
    }
    if (data.containsKey('user_memo')) {
      context.handle(
        _userMemoMeta,
        userMemo.isAcceptableOrUnknown(data['user_memo']!, _userMemoMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {documentId, expressionKey},
  ];
  @override
  VocabularyEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VocabularyEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      expressionKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expression_key'],
      )!,
      expression: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expression'],
      )!,
      meaningKo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meaning_ko'],
      ),
      sourceSentence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_sentence'],
      ),
      contextBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}context_before'],
      ),
      contextAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}context_after'],
      ),
      blockId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}block_id'],
      ),
      textOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}text_offset'],
      ),
      userMeaning: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_meaning'],
      ),
      userMemo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_memo'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $VocabularyEntriesTable createAlias(String alias) {
    return $VocabularyEntriesTable(attachedDatabase, alias);
  }
}

class VocabularyEntry extends DataClass implements Insertable<VocabularyEntry> {
  final String id;
  final String documentId;
  final String expressionKey;
  final String expression;
  final String? meaningKo;
  final String? sourceSentence;
  final String? contextBefore;
  final String? contextAfter;
  final String? blockId;
  final int? textOffset;
  final String? userMeaning;
  final String? userMemo;
  final DateTime createdAt;
  final DateTime updatedAt;
  const VocabularyEntry({
    required this.id,
    required this.documentId,
    required this.expressionKey,
    required this.expression,
    this.meaningKo,
    this.sourceSentence,
    this.contextBefore,
    this.contextAfter,
    this.blockId,
    this.textOffset,
    this.userMeaning,
    this.userMemo,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['document_id'] = Variable<String>(documentId);
    map['expression_key'] = Variable<String>(expressionKey);
    map['expression'] = Variable<String>(expression);
    if (!nullToAbsent || meaningKo != null) {
      map['meaning_ko'] = Variable<String>(meaningKo);
    }
    if (!nullToAbsent || sourceSentence != null) {
      map['source_sentence'] = Variable<String>(sourceSentence);
    }
    if (!nullToAbsent || contextBefore != null) {
      map['context_before'] = Variable<String>(contextBefore);
    }
    if (!nullToAbsent || contextAfter != null) {
      map['context_after'] = Variable<String>(contextAfter);
    }
    if (!nullToAbsent || blockId != null) {
      map['block_id'] = Variable<String>(blockId);
    }
    if (!nullToAbsent || textOffset != null) {
      map['text_offset'] = Variable<int>(textOffset);
    }
    if (!nullToAbsent || userMeaning != null) {
      map['user_meaning'] = Variable<String>(userMeaning);
    }
    if (!nullToAbsent || userMemo != null) {
      map['user_memo'] = Variable<String>(userMemo);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  VocabularyEntriesCompanion toCompanion(bool nullToAbsent) {
    return VocabularyEntriesCompanion(
      id: Value(id),
      documentId: Value(documentId),
      expressionKey: Value(expressionKey),
      expression: Value(expression),
      meaningKo: meaningKo == null && nullToAbsent
          ? const Value.absent()
          : Value(meaningKo),
      sourceSentence: sourceSentence == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceSentence),
      contextBefore: contextBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(contextBefore),
      contextAfter: contextAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(contextAfter),
      blockId: blockId == null && nullToAbsent
          ? const Value.absent()
          : Value(blockId),
      textOffset: textOffset == null && nullToAbsent
          ? const Value.absent()
          : Value(textOffset),
      userMeaning: userMeaning == null && nullToAbsent
          ? const Value.absent()
          : Value(userMeaning),
      userMemo: userMemo == null && nullToAbsent
          ? const Value.absent()
          : Value(userMemo),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory VocabularyEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VocabularyEntry(
      id: serializer.fromJson<String>(json['id']),
      documentId: serializer.fromJson<String>(json['documentId']),
      expressionKey: serializer.fromJson<String>(json['expressionKey']),
      expression: serializer.fromJson<String>(json['expression']),
      meaningKo: serializer.fromJson<String?>(json['meaningKo']),
      sourceSentence: serializer.fromJson<String?>(json['sourceSentence']),
      contextBefore: serializer.fromJson<String?>(json['contextBefore']),
      contextAfter: serializer.fromJson<String?>(json['contextAfter']),
      blockId: serializer.fromJson<String?>(json['blockId']),
      textOffset: serializer.fromJson<int?>(json['textOffset']),
      userMeaning: serializer.fromJson<String?>(json['userMeaning']),
      userMemo: serializer.fromJson<String?>(json['userMemo']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'documentId': serializer.toJson<String>(documentId),
      'expressionKey': serializer.toJson<String>(expressionKey),
      'expression': serializer.toJson<String>(expression),
      'meaningKo': serializer.toJson<String?>(meaningKo),
      'sourceSentence': serializer.toJson<String?>(sourceSentence),
      'contextBefore': serializer.toJson<String?>(contextBefore),
      'contextAfter': serializer.toJson<String?>(contextAfter),
      'blockId': serializer.toJson<String?>(blockId),
      'textOffset': serializer.toJson<int?>(textOffset),
      'userMeaning': serializer.toJson<String?>(userMeaning),
      'userMemo': serializer.toJson<String?>(userMemo),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  VocabularyEntry copyWith({
    String? id,
    String? documentId,
    String? expressionKey,
    String? expression,
    Value<String?> meaningKo = const Value.absent(),
    Value<String?> sourceSentence = const Value.absent(),
    Value<String?> contextBefore = const Value.absent(),
    Value<String?> contextAfter = const Value.absent(),
    Value<String?> blockId = const Value.absent(),
    Value<int?> textOffset = const Value.absent(),
    Value<String?> userMeaning = const Value.absent(),
    Value<String?> userMemo = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => VocabularyEntry(
    id: id ?? this.id,
    documentId: documentId ?? this.documentId,
    expressionKey: expressionKey ?? this.expressionKey,
    expression: expression ?? this.expression,
    meaningKo: meaningKo.present ? meaningKo.value : this.meaningKo,
    sourceSentence: sourceSentence.present
        ? sourceSentence.value
        : this.sourceSentence,
    contextBefore: contextBefore.present
        ? contextBefore.value
        : this.contextBefore,
    contextAfter: contextAfter.present ? contextAfter.value : this.contextAfter,
    blockId: blockId.present ? blockId.value : this.blockId,
    textOffset: textOffset.present ? textOffset.value : this.textOffset,
    userMeaning: userMeaning.present ? userMeaning.value : this.userMeaning,
    userMemo: userMemo.present ? userMemo.value : this.userMemo,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  VocabularyEntry copyWithCompanion(VocabularyEntriesCompanion data) {
    return VocabularyEntry(
      id: data.id.present ? data.id.value : this.id,
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      expressionKey: data.expressionKey.present
          ? data.expressionKey.value
          : this.expressionKey,
      expression: data.expression.present
          ? data.expression.value
          : this.expression,
      meaningKo: data.meaningKo.present ? data.meaningKo.value : this.meaningKo,
      sourceSentence: data.sourceSentence.present
          ? data.sourceSentence.value
          : this.sourceSentence,
      contextBefore: data.contextBefore.present
          ? data.contextBefore.value
          : this.contextBefore,
      contextAfter: data.contextAfter.present
          ? data.contextAfter.value
          : this.contextAfter,
      blockId: data.blockId.present ? data.blockId.value : this.blockId,
      textOffset: data.textOffset.present
          ? data.textOffset.value
          : this.textOffset,
      userMeaning: data.userMeaning.present
          ? data.userMeaning.value
          : this.userMeaning,
      userMemo: data.userMemo.present ? data.userMemo.value : this.userMemo,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VocabularyEntry(')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('expressionKey: $expressionKey, ')
          ..write('expression: $expression, ')
          ..write('meaningKo: $meaningKo, ')
          ..write('sourceSentence: $sourceSentence, ')
          ..write('contextBefore: $contextBefore, ')
          ..write('contextAfter: $contextAfter, ')
          ..write('blockId: $blockId, ')
          ..write('textOffset: $textOffset, ')
          ..write('userMeaning: $userMeaning, ')
          ..write('userMemo: $userMemo, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    documentId,
    expressionKey,
    expression,
    meaningKo,
    sourceSentence,
    contextBefore,
    contextAfter,
    blockId,
    textOffset,
    userMeaning,
    userMemo,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VocabularyEntry &&
          other.id == this.id &&
          other.documentId == this.documentId &&
          other.expressionKey == this.expressionKey &&
          other.expression == this.expression &&
          other.meaningKo == this.meaningKo &&
          other.sourceSentence == this.sourceSentence &&
          other.contextBefore == this.contextBefore &&
          other.contextAfter == this.contextAfter &&
          other.blockId == this.blockId &&
          other.textOffset == this.textOffset &&
          other.userMeaning == this.userMeaning &&
          other.userMemo == this.userMemo &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class VocabularyEntriesCompanion extends UpdateCompanion<VocabularyEntry> {
  final Value<String> id;
  final Value<String> documentId;
  final Value<String> expressionKey;
  final Value<String> expression;
  final Value<String?> meaningKo;
  final Value<String?> sourceSentence;
  final Value<String?> contextBefore;
  final Value<String?> contextAfter;
  final Value<String?> blockId;
  final Value<int?> textOffset;
  final Value<String?> userMeaning;
  final Value<String?> userMemo;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const VocabularyEntriesCompanion({
    this.id = const Value.absent(),
    this.documentId = const Value.absent(),
    this.expressionKey = const Value.absent(),
    this.expression = const Value.absent(),
    this.meaningKo = const Value.absent(),
    this.sourceSentence = const Value.absent(),
    this.contextBefore = const Value.absent(),
    this.contextAfter = const Value.absent(),
    this.blockId = const Value.absent(),
    this.textOffset = const Value.absent(),
    this.userMeaning = const Value.absent(),
    this.userMemo = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VocabularyEntriesCompanion.insert({
    required String id,
    required String documentId,
    required String expressionKey,
    required String expression,
    this.meaningKo = const Value.absent(),
    this.sourceSentence = const Value.absent(),
    this.contextBefore = const Value.absent(),
    this.contextAfter = const Value.absent(),
    this.blockId = const Value.absent(),
    this.textOffset = const Value.absent(),
    this.userMeaning = const Value.absent(),
    this.userMemo = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       documentId = Value(documentId),
       expressionKey = Value(expressionKey),
       expression = Value(expression),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<VocabularyEntry> custom({
    Expression<String>? id,
    Expression<String>? documentId,
    Expression<String>? expressionKey,
    Expression<String>? expression,
    Expression<String>? meaningKo,
    Expression<String>? sourceSentence,
    Expression<String>? contextBefore,
    Expression<String>? contextAfter,
    Expression<String>? blockId,
    Expression<int>? textOffset,
    Expression<String>? userMeaning,
    Expression<String>? userMemo,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (documentId != null) 'document_id': documentId,
      if (expressionKey != null) 'expression_key': expressionKey,
      if (expression != null) 'expression': expression,
      if (meaningKo != null) 'meaning_ko': meaningKo,
      if (sourceSentence != null) 'source_sentence': sourceSentence,
      if (contextBefore != null) 'context_before': contextBefore,
      if (contextAfter != null) 'context_after': contextAfter,
      if (blockId != null) 'block_id': blockId,
      if (textOffset != null) 'text_offset': textOffset,
      if (userMeaning != null) 'user_meaning': userMeaning,
      if (userMemo != null) 'user_memo': userMemo,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VocabularyEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? documentId,
    Value<String>? expressionKey,
    Value<String>? expression,
    Value<String?>? meaningKo,
    Value<String?>? sourceSentence,
    Value<String?>? contextBefore,
    Value<String?>? contextAfter,
    Value<String?>? blockId,
    Value<int?>? textOffset,
    Value<String?>? userMeaning,
    Value<String?>? userMemo,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return VocabularyEntriesCompanion(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      expressionKey: expressionKey ?? this.expressionKey,
      expression: expression ?? this.expression,
      meaningKo: meaningKo ?? this.meaningKo,
      sourceSentence: sourceSentence ?? this.sourceSentence,
      contextBefore: contextBefore ?? this.contextBefore,
      contextAfter: contextAfter ?? this.contextAfter,
      blockId: blockId ?? this.blockId,
      textOffset: textOffset ?? this.textOffset,
      userMeaning: userMeaning ?? this.userMeaning,
      userMemo: userMemo ?? this.userMemo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (expressionKey.present) {
      map['expression_key'] = Variable<String>(expressionKey.value);
    }
    if (expression.present) {
      map['expression'] = Variable<String>(expression.value);
    }
    if (meaningKo.present) {
      map['meaning_ko'] = Variable<String>(meaningKo.value);
    }
    if (sourceSentence.present) {
      map['source_sentence'] = Variable<String>(sourceSentence.value);
    }
    if (contextBefore.present) {
      map['context_before'] = Variable<String>(contextBefore.value);
    }
    if (contextAfter.present) {
      map['context_after'] = Variable<String>(contextAfter.value);
    }
    if (blockId.present) {
      map['block_id'] = Variable<String>(blockId.value);
    }
    if (textOffset.present) {
      map['text_offset'] = Variable<int>(textOffset.value);
    }
    if (userMeaning.present) {
      map['user_meaning'] = Variable<String>(userMeaning.value);
    }
    if (userMemo.present) {
      map['user_memo'] = Variable<String>(userMemo.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VocabularyEntriesCompanion(')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('expressionKey: $expressionKey, ')
          ..write('expression: $expression, ')
          ..write('meaningKo: $meaningKo, ')
          ..write('sourceSentence: $sourceSentence, ')
          ..write('contextBefore: $contextBefore, ')
          ..write('contextAfter: $contextAfter, ')
          ..write('blockId: $blockId, ')
          ..write('textOffset: $textOffset, ')
          ..write('userMeaning: $userMeaning, ')
          ..write('userMemo: $userMemo, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ViewerSettingsTable extends ViewerSettings
    with TableInfo<$ViewerSettingsTable, ViewerSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ViewerSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES documents (id)',
    ),
  );
  static const VerificationMeta _readingModeMeta = const VerificationMeta(
    'readingMode',
  );
  @override
  late final GeneratedColumn<String> readingMode = GeneratedColumn<String>(
    'reading_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _themeIdMeta = const VerificationMeta(
    'themeId',
  );
  @override
  late final GeneratedColumn<String> themeId = GeneratedColumn<String>(
    'theme_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fontFamilyMeta = const VerificationMeta(
    'fontFamily',
  );
  @override
  late final GeneratedColumn<String> fontFamily = GeneratedColumn<String>(
    'font_family',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fontScaleMeta = const VerificationMeta(
    'fontScale',
  );
  @override
  late final GeneratedColumn<double> fontScale = GeneratedColumn<double>(
    'font_scale',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lineHeightMeta = const VerificationMeta(
    'lineHeight',
  );
  @override
  late final GeneratedColumn<double> lineHeight = GeneratedColumn<double>(
    'line_height',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _marginScaleMeta = const VerificationMeta(
    'marginScale',
  );
  @override
  late final GeneratedColumn<double> marginScale = GeneratedColumn<double>(
    'margin_scale',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bottomMarginScaleMeta =
      const VerificationMeta('bottomMarginScale');
  @override
  late final GeneratedColumn<double> bottomMarginScale =
      GeneratedColumn<double>(
        'bottom_margin_scale',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(1.0),
      );
  static const VerificationMeta _assetOpenModeMeta = const VerificationMeta(
    'assetOpenMode',
  );
  @override
  late final GeneratedColumn<String> assetOpenMode = GeneratedColumn<String>(
    'asset_open_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    documentId,
    readingMode,
    themeId,
    fontFamily,
    fontScale,
    lineHeight,
    marginScale,
    bottomMarginScale,
    assetOpenMode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'viewer_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<ViewerSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('reading_mode')) {
      context.handle(
        _readingModeMeta,
        readingMode.isAcceptableOrUnknown(
          data['reading_mode']!,
          _readingModeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_readingModeMeta);
    }
    if (data.containsKey('theme_id')) {
      context.handle(
        _themeIdMeta,
        themeId.isAcceptableOrUnknown(data['theme_id']!, _themeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_themeIdMeta);
    }
    if (data.containsKey('font_family')) {
      context.handle(
        _fontFamilyMeta,
        fontFamily.isAcceptableOrUnknown(data['font_family']!, _fontFamilyMeta),
      );
    }
    if (data.containsKey('font_scale')) {
      context.handle(
        _fontScaleMeta,
        fontScale.isAcceptableOrUnknown(data['font_scale']!, _fontScaleMeta),
      );
    } else if (isInserting) {
      context.missing(_fontScaleMeta);
    }
    if (data.containsKey('line_height')) {
      context.handle(
        _lineHeightMeta,
        lineHeight.isAcceptableOrUnknown(data['line_height']!, _lineHeightMeta),
      );
    } else if (isInserting) {
      context.missing(_lineHeightMeta);
    }
    if (data.containsKey('margin_scale')) {
      context.handle(
        _marginScaleMeta,
        marginScale.isAcceptableOrUnknown(
          data['margin_scale']!,
          _marginScaleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_marginScaleMeta);
    }
    if (data.containsKey('bottom_margin_scale')) {
      context.handle(
        _bottomMarginScaleMeta,
        bottomMarginScale.isAcceptableOrUnknown(
          data['bottom_margin_scale']!,
          _bottomMarginScaleMeta,
        ),
      );
    }
    if (data.containsKey('asset_open_mode')) {
      context.handle(
        _assetOpenModeMeta,
        assetOpenMode.isAcceptableOrUnknown(
          data['asset_open_mode']!,
          _assetOpenModeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_assetOpenModeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {documentId};
  @override
  ViewerSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ViewerSetting(
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      readingMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reading_mode'],
      )!,
      themeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme_id'],
      )!,
      fontFamily: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}font_family'],
      ),
      fontScale: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}font_scale'],
      )!,
      lineHeight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}line_height'],
      )!,
      marginScale: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}margin_scale'],
      )!,
      bottomMarginScale: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bottom_margin_scale'],
      )!,
      assetOpenMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_open_mode'],
      )!,
    );
  }

  @override
  $ViewerSettingsTable createAlias(String alias) {
    return $ViewerSettingsTable(attachedDatabase, alias);
  }
}

class ViewerSetting extends DataClass implements Insertable<ViewerSetting> {
  final String documentId;
  final String readingMode;
  final String themeId;
  final String? fontFamily;
  final double fontScale;
  final double lineHeight;
  final double marginScale;
  final double bottomMarginScale;
  final String assetOpenMode;
  const ViewerSetting({
    required this.documentId,
    required this.readingMode,
    required this.themeId,
    this.fontFamily,
    required this.fontScale,
    required this.lineHeight,
    required this.marginScale,
    required this.bottomMarginScale,
    required this.assetOpenMode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['document_id'] = Variable<String>(documentId);
    map['reading_mode'] = Variable<String>(readingMode);
    map['theme_id'] = Variable<String>(themeId);
    if (!nullToAbsent || fontFamily != null) {
      map['font_family'] = Variable<String>(fontFamily);
    }
    map['font_scale'] = Variable<double>(fontScale);
    map['line_height'] = Variable<double>(lineHeight);
    map['margin_scale'] = Variable<double>(marginScale);
    map['bottom_margin_scale'] = Variable<double>(bottomMarginScale);
    map['asset_open_mode'] = Variable<String>(assetOpenMode);
    return map;
  }

  ViewerSettingsCompanion toCompanion(bool nullToAbsent) {
    return ViewerSettingsCompanion(
      documentId: Value(documentId),
      readingMode: Value(readingMode),
      themeId: Value(themeId),
      fontFamily: fontFamily == null && nullToAbsent
          ? const Value.absent()
          : Value(fontFamily),
      fontScale: Value(fontScale),
      lineHeight: Value(lineHeight),
      marginScale: Value(marginScale),
      bottomMarginScale: Value(bottomMarginScale),
      assetOpenMode: Value(assetOpenMode),
    );
  }

  factory ViewerSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ViewerSetting(
      documentId: serializer.fromJson<String>(json['documentId']),
      readingMode: serializer.fromJson<String>(json['readingMode']),
      themeId: serializer.fromJson<String>(json['themeId']),
      fontFamily: serializer.fromJson<String?>(json['fontFamily']),
      fontScale: serializer.fromJson<double>(json['fontScale']),
      lineHeight: serializer.fromJson<double>(json['lineHeight']),
      marginScale: serializer.fromJson<double>(json['marginScale']),
      bottomMarginScale: serializer.fromJson<double>(
        json['bottomMarginScale'],
      ),
      assetOpenMode: serializer.fromJson<String>(json['assetOpenMode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'documentId': serializer.toJson<String>(documentId),
      'readingMode': serializer.toJson<String>(readingMode),
      'themeId': serializer.toJson<String>(themeId),
      'fontFamily': serializer.toJson<String?>(fontFamily),
      'fontScale': serializer.toJson<double>(fontScale),
      'lineHeight': serializer.toJson<double>(lineHeight),
      'marginScale': serializer.toJson<double>(marginScale),
      'bottomMarginScale': serializer.toJson<double>(bottomMarginScale),
      'assetOpenMode': serializer.toJson<String>(assetOpenMode),
    };
  }

  ViewerSetting copyWith({
    String? documentId,
    String? readingMode,
    String? themeId,
    Value<String?> fontFamily = const Value.absent(),
    double? fontScale,
    double? lineHeight,
    double? marginScale,
    double? bottomMarginScale,
    String? assetOpenMode,
  }) => ViewerSetting(
    documentId: documentId ?? this.documentId,
    readingMode: readingMode ?? this.readingMode,
    themeId: themeId ?? this.themeId,
    fontFamily: fontFamily.present ? fontFamily.value : this.fontFamily,
    fontScale: fontScale ?? this.fontScale,
    lineHeight: lineHeight ?? this.lineHeight,
    marginScale: marginScale ?? this.marginScale,
    bottomMarginScale: bottomMarginScale ?? this.bottomMarginScale,
    assetOpenMode: assetOpenMode ?? this.assetOpenMode,
  );
  ViewerSetting copyWithCompanion(ViewerSettingsCompanion data) {
    return ViewerSetting(
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      readingMode: data.readingMode.present
          ? data.readingMode.value
          : this.readingMode,
      themeId: data.themeId.present ? data.themeId.value : this.themeId,
      fontFamily: data.fontFamily.present
          ? data.fontFamily.value
          : this.fontFamily,
      fontScale: data.fontScale.present ? data.fontScale.value : this.fontScale,
      lineHeight: data.lineHeight.present
          ? data.lineHeight.value
          : this.lineHeight,
      marginScale: data.marginScale.present
          ? data.marginScale.value
          : this.marginScale,
      bottomMarginScale: data.bottomMarginScale.present
          ? data.bottomMarginScale.value
          : this.bottomMarginScale,
      assetOpenMode: data.assetOpenMode.present
          ? data.assetOpenMode.value
          : this.assetOpenMode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ViewerSetting(')
          ..write('documentId: $documentId, ')
          ..write('readingMode: $readingMode, ')
          ..write('themeId: $themeId, ')
          ..write('fontFamily: $fontFamily, ')
          ..write('fontScale: $fontScale, ')
          ..write('lineHeight: $lineHeight, ')
          ..write('marginScale: $marginScale, ')
          ..write('bottomMarginScale: $bottomMarginScale, ')
          ..write('assetOpenMode: $assetOpenMode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    documentId,
    readingMode,
    themeId,
    fontFamily,
    fontScale,
    lineHeight,
    marginScale,
    bottomMarginScale,
    assetOpenMode,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ViewerSetting &&
          other.documentId == this.documentId &&
          other.readingMode == this.readingMode &&
          other.themeId == this.themeId &&
          other.fontFamily == this.fontFamily &&
          other.fontScale == this.fontScale &&
          other.lineHeight == this.lineHeight &&
          other.marginScale == this.marginScale &&
          other.bottomMarginScale == this.bottomMarginScale &&
          other.assetOpenMode == this.assetOpenMode);
}

class ViewerSettingsCompanion extends UpdateCompanion<ViewerSetting> {
  final Value<String> documentId;
  final Value<String> readingMode;
  final Value<String> themeId;
  final Value<String?> fontFamily;
  final Value<double> fontScale;
  final Value<double> lineHeight;
  final Value<double> marginScale;
  final Value<double> bottomMarginScale;
  final Value<String> assetOpenMode;
  final Value<int> rowid;
  const ViewerSettingsCompanion({
    this.documentId = const Value.absent(),
    this.readingMode = const Value.absent(),
    this.themeId = const Value.absent(),
    this.fontFamily = const Value.absent(),
    this.fontScale = const Value.absent(),
    this.lineHeight = const Value.absent(),
    this.marginScale = const Value.absent(),
    this.bottomMarginScale = const Value.absent(),
    this.assetOpenMode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ViewerSettingsCompanion.insert({
    required String documentId,
    required String readingMode,
    required String themeId,
    this.fontFamily = const Value.absent(),
    required double fontScale,
    required double lineHeight,
    required double marginScale,
    this.bottomMarginScale = const Value.absent(),
    required String assetOpenMode,
    this.rowid = const Value.absent(),
  }) : documentId = Value(documentId),
       readingMode = Value(readingMode),
       themeId = Value(themeId),
       fontScale = Value(fontScale),
       lineHeight = Value(lineHeight),
       marginScale = Value(marginScale),
       assetOpenMode = Value(assetOpenMode);
  static Insertable<ViewerSetting> custom({
    Expression<String>? documentId,
    Expression<String>? readingMode,
    Expression<String>? themeId,
    Expression<String>? fontFamily,
    Expression<double>? fontScale,
    Expression<double>? lineHeight,
    Expression<double>? marginScale,
    Expression<double>? bottomMarginScale,
    Expression<String>? assetOpenMode,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (documentId != null) 'document_id': documentId,
      if (readingMode != null) 'reading_mode': readingMode,
      if (themeId != null) 'theme_id': themeId,
      if (fontFamily != null) 'font_family': fontFamily,
      if (fontScale != null) 'font_scale': fontScale,
      if (lineHeight != null) 'line_height': lineHeight,
      if (marginScale != null) 'margin_scale': marginScale,
      if (bottomMarginScale != null)
        'bottom_margin_scale': bottomMarginScale,
      if (assetOpenMode != null) 'asset_open_mode': assetOpenMode,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ViewerSettingsCompanion copyWith({
    Value<String>? documentId,
    Value<String>? readingMode,
    Value<String>? themeId,
    Value<String?>? fontFamily,
    Value<double>? fontScale,
    Value<double>? lineHeight,
    Value<double>? marginScale,
    Value<double>? bottomMarginScale,
    Value<String>? assetOpenMode,
    Value<int>? rowid,
  }) {
    return ViewerSettingsCompanion(
      documentId: documentId ?? this.documentId,
      readingMode: readingMode ?? this.readingMode,
      themeId: themeId ?? this.themeId,
      fontFamily: fontFamily ?? this.fontFamily,
      fontScale: fontScale ?? this.fontScale,
      lineHeight: lineHeight ?? this.lineHeight,
      marginScale: marginScale ?? this.marginScale,
      bottomMarginScale: bottomMarginScale ?? this.bottomMarginScale,
      assetOpenMode: assetOpenMode ?? this.assetOpenMode,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (readingMode.present) {
      map['reading_mode'] = Variable<String>(readingMode.value);
    }
    if (themeId.present) {
      map['theme_id'] = Variable<String>(themeId.value);
    }
    if (fontFamily.present) {
      map['font_family'] = Variable<String>(fontFamily.value);
    }
    if (fontScale.present) {
      map['font_scale'] = Variable<double>(fontScale.value);
    }
    if (lineHeight.present) {
      map['line_height'] = Variable<double>(lineHeight.value);
    }
    if (marginScale.present) {
      map['margin_scale'] = Variable<double>(marginScale.value);
    }
    if (bottomMarginScale.present) {
      map['bottom_margin_scale'] = Variable<double>(bottomMarginScale.value);
    }
    if (assetOpenMode.present) {
      map['asset_open_mode'] = Variable<String>(assetOpenMode.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ViewerSettingsCompanion(')
          ..write('documentId: $documentId, ')
          ..write('readingMode: $readingMode, ')
          ..write('themeId: $themeId, ')
          ..write('fontFamily: $fontFamily, ')
          ..write('fontScale: $fontScale, ')
          ..write('lineHeight: $lineHeight, ')
          ..write('marginScale: $marginScale, ')
          ..write('bottomMarginScale: $bottomMarginScale, ')
          ..write('assetOpenMode: $assetOpenMode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LibraryFoldersTable libraryFolders = $LibraryFoldersTable(this);
  late final $DocumentsTable documents = $DocumentsTable(this);
  late final $VocabularyEntriesTable vocabularyEntries =
      $VocabularyEntriesTable(this);
  late final $ViewerSettingsTable viewerSettings = $ViewerSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    libraryFolders,
    documents,
    vocabularyEntries,
    viewerSettings,
  ];
}

typedef $$LibraryFoldersTableCreateCompanionBuilder =
    LibraryFoldersCompanion Function({
      required String id,
      required String name,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$LibraryFoldersTableUpdateCompanionBuilder =
    LibraryFoldersCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$LibraryFoldersTableReferences
    extends BaseReferences<_$AppDatabase, $LibraryFoldersTable, LibraryFolder> {
  $$LibraryFoldersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$DocumentsTable, List<Document>>
  _documentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.documents,
    aliasName: $_aliasNameGenerator(
      db.libraryFolders.id,
      db.documents.folderId,
    ),
  );

  $$DocumentsTableProcessedTableManager get documentsRefs {
    final manager = $$DocumentsTableTableManager(
      $_db,
      $_db.documents,
    ).filter((f) => f.folderId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_documentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LibraryFoldersTableFilterComposer
    extends Composer<_$AppDatabase, $LibraryFoldersTable> {
  $$LibraryFoldersTableFilterComposer({
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

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> documentsRefs(
    Expression<bool> Function($$DocumentsTableFilterComposer f) f,
  ) {
    final $$DocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableFilterComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibraryFoldersTableOrderingComposer
    extends Composer<_$AppDatabase, $LibraryFoldersTable> {
  $$LibraryFoldersTableOrderingComposer({
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

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LibraryFoldersTableAnnotationComposer
    extends Composer<_$AppDatabase, $LibraryFoldersTable> {
  $$LibraryFoldersTableAnnotationComposer({
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

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> documentsRefs<T extends Object>(
    Expression<T> Function($$DocumentsTableAnnotationComposer a) f,
  ) {
    final $$DocumentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableAnnotationComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibraryFoldersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LibraryFoldersTable,
          LibraryFolder,
          $$LibraryFoldersTableFilterComposer,
          $$LibraryFoldersTableOrderingComposer,
          $$LibraryFoldersTableAnnotationComposer,
          $$LibraryFoldersTableCreateCompanionBuilder,
          $$LibraryFoldersTableUpdateCompanionBuilder,
          (LibraryFolder, $$LibraryFoldersTableReferences),
          LibraryFolder,
          PrefetchHooks Function({bool documentsRefs})
        > {
  $$LibraryFoldersTableTableManager(
    _$AppDatabase db,
    $LibraryFoldersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryFoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryFoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryFoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryFoldersCompanion(
                id: id,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LibraryFoldersCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LibraryFoldersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({documentsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (documentsRefs) db.documents],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (documentsRefs)
                    await $_getPrefetchedData<
                      LibraryFolder,
                      $LibraryFoldersTable,
                      Document
                    >(
                      currentTable: table,
                      referencedTable: $$LibraryFoldersTableReferences
                          ._documentsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LibraryFoldersTableReferences(
                            db,
                            table,
                            p0,
                          ).documentsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.folderId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LibraryFoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LibraryFoldersTable,
      LibraryFolder,
      $$LibraryFoldersTableFilterComposer,
      $$LibraryFoldersTableOrderingComposer,
      $$LibraryFoldersTableAnnotationComposer,
      $$LibraryFoldersTableCreateCompanionBuilder,
      $$LibraryFoldersTableUpdateCompanionBuilder,
      (LibraryFolder, $$LibraryFoldersTableReferences),
      LibraryFolder,
      PrefetchHooks Function({bool documentsRefs})
    >;
typedef $$DocumentsTableCreateCompanionBuilder =
    DocumentsCompanion Function({
      required String id,
      required String title,
      required String sourceFilename,
      required String localPdfPath,
      Value<String?> packagePath,
      Value<String?> folderId,
      required String status,
      Value<String?> lastReadBlockId,
      Value<int?> lastReadOffset,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$DocumentsTableUpdateCompanionBuilder =
    DocumentsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> sourceFilename,
      Value<String> localPdfPath,
      Value<String?> packagePath,
      Value<String?> folderId,
      Value<String> status,
      Value<String?> lastReadBlockId,
      Value<int?> lastReadOffset,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$DocumentsTableReferences
    extends BaseReferences<_$AppDatabase, $DocumentsTable, Document> {
  $$DocumentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LibraryFoldersTable _folderIdTable(_$AppDatabase db) =>
      db.libraryFolders.createAlias(
        $_aliasNameGenerator(db.documents.folderId, db.libraryFolders.id),
      );

  $$LibraryFoldersTableProcessedTableManager? get folderId {
    final $_column = $_itemColumn<String>('folder_id');
    if ($_column == null) return null;
    final manager = $$LibraryFoldersTableTableManager(
      $_db,
      $_db.libraryFolders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_folderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$VocabularyEntriesTable, List<VocabularyEntry>>
  _vocabularyEntriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.vocabularyEntries,
        aliasName: $_aliasNameGenerator(
          db.documents.id,
          db.vocabularyEntries.documentId,
        ),
      );

  $$VocabularyEntriesTableProcessedTableManager get vocabularyEntriesRefs {
    final manager = $$VocabularyEntriesTableTableManager(
      $_db,
      $_db.vocabularyEntries,
    ).filter((f) => f.documentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _vocabularyEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ViewerSettingsTable, List<ViewerSetting>>
  _viewerSettingsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.viewerSettings,
    aliasName: $_aliasNameGenerator(
      db.documents.id,
      db.viewerSettings.documentId,
    ),
  );

  $$ViewerSettingsTableProcessedTableManager get viewerSettingsRefs {
    final manager = $$ViewerSettingsTableTableManager(
      $_db,
      $_db.viewerSettings,
    ).filter((f) => f.documentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_viewerSettingsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DocumentsTableFilterComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceFilename => $composableBuilder(
    column: $table.sourceFilename,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPdfPath => $composableBuilder(
    column: $table.localPdfPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get packagePath => $composableBuilder(
    column: $table.packagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastReadBlockId => $composableBuilder(
    column: $table.lastReadBlockId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastReadOffset => $composableBuilder(
    column: $table.lastReadOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LibraryFoldersTableFilterComposer get folderId {
    final $$LibraryFoldersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.libraryFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryFoldersTableFilterComposer(
            $db: $db,
            $table: $db.libraryFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> vocabularyEntriesRefs(
    Expression<bool> Function($$VocabularyEntriesTableFilterComposer f) f,
  ) {
    final $$VocabularyEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.vocabularyEntries,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VocabularyEntriesTableFilterComposer(
            $db: $db,
            $table: $db.vocabularyEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> viewerSettingsRefs(
    Expression<bool> Function($$ViewerSettingsTableFilterComposer f) f,
  ) {
    final $$ViewerSettingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.viewerSettings,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ViewerSettingsTableFilterComposer(
            $db: $db,
            $table: $db.viewerSettings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DocumentsTableOrderingComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceFilename => $composableBuilder(
    column: $table.sourceFilename,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPdfPath => $composableBuilder(
    column: $table.localPdfPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get packagePath => $composableBuilder(
    column: $table.packagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastReadBlockId => $composableBuilder(
    column: $table.lastReadBlockId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastReadOffset => $composableBuilder(
    column: $table.lastReadOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LibraryFoldersTableOrderingComposer get folderId {
    final $$LibraryFoldersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.libraryFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryFoldersTableOrderingComposer(
            $db: $db,
            $table: $db.libraryFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get sourceFilename => $composableBuilder(
    column: $table.sourceFilename,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localPdfPath => $composableBuilder(
    column: $table.localPdfPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get packagePath => $composableBuilder(
    column: $table.packagePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get lastReadBlockId => $composableBuilder(
    column: $table.lastReadBlockId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastReadOffset => $composableBuilder(
    column: $table.lastReadOffset,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$LibraryFoldersTableAnnotationComposer get folderId {
    final $$LibraryFoldersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.libraryFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryFoldersTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> vocabularyEntriesRefs<T extends Object>(
    Expression<T> Function($$VocabularyEntriesTableAnnotationComposer a) f,
  ) {
    final $$VocabularyEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.vocabularyEntries,
          getReferencedColumn: (t) => t.documentId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$VocabularyEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.vocabularyEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> viewerSettingsRefs<T extends Object>(
    Expression<T> Function($$ViewerSettingsTableAnnotationComposer a) f,
  ) {
    final $$ViewerSettingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.viewerSettings,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ViewerSettingsTableAnnotationComposer(
            $db: $db,
            $table: $db.viewerSettings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DocumentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DocumentsTable,
          Document,
          $$DocumentsTableFilterComposer,
          $$DocumentsTableOrderingComposer,
          $$DocumentsTableAnnotationComposer,
          $$DocumentsTableCreateCompanionBuilder,
          $$DocumentsTableUpdateCompanionBuilder,
          (Document, $$DocumentsTableReferences),
          Document,
          PrefetchHooks Function({
            bool folderId,
            bool vocabularyEntriesRefs,
            bool viewerSettingsRefs,
          })
        > {
  $$DocumentsTableTableManager(_$AppDatabase db, $DocumentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> sourceFilename = const Value.absent(),
                Value<String> localPdfPath = const Value.absent(),
                Value<String?> packagePath = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> lastReadBlockId = const Value.absent(),
                Value<int?> lastReadOffset = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentsCompanion(
                id: id,
                title: title,
                sourceFilename: sourceFilename,
                localPdfPath: localPdfPath,
                packagePath: packagePath,
                folderId: folderId,
                status: status,
                lastReadBlockId: lastReadBlockId,
                lastReadOffset: lastReadOffset,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String sourceFilename,
                required String localPdfPath,
                Value<String?> packagePath = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                required String status,
                Value<String?> lastReadBlockId = const Value.absent(),
                Value<int?> lastReadOffset = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => DocumentsCompanion.insert(
                id: id,
                title: title,
                sourceFilename: sourceFilename,
                localPdfPath: localPdfPath,
                packagePath: packagePath,
                folderId: folderId,
                status: status,
                lastReadBlockId: lastReadBlockId,
                lastReadOffset: lastReadOffset,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DocumentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                folderId = false,
                vocabularyEntriesRefs = false,
                viewerSettingsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (vocabularyEntriesRefs) db.vocabularyEntries,
                    if (viewerSettingsRefs) db.viewerSettings,
                  ],
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
                        if (folderId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.folderId,
                                    referencedTable: $$DocumentsTableReferences
                                        ._folderIdTable(db),
                                    referencedColumn: $$DocumentsTableReferences
                                        ._folderIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (vocabularyEntriesRefs)
                        await $_getPrefetchedData<
                          Document,
                          $DocumentsTable,
                          VocabularyEntry
                        >(
                          currentTable: table,
                          referencedTable: $$DocumentsTableReferences
                              ._vocabularyEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DocumentsTableReferences(
                                db,
                                table,
                                p0,
                              ).vocabularyEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.documentId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (viewerSettingsRefs)
                        await $_getPrefetchedData<
                          Document,
                          $DocumentsTable,
                          ViewerSetting
                        >(
                          currentTable: table,
                          referencedTable: $$DocumentsTableReferences
                              ._viewerSettingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DocumentsTableReferences(
                                db,
                                table,
                                p0,
                              ).viewerSettingsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.documentId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$DocumentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DocumentsTable,
      Document,
      $$DocumentsTableFilterComposer,
      $$DocumentsTableOrderingComposer,
      $$DocumentsTableAnnotationComposer,
      $$DocumentsTableCreateCompanionBuilder,
      $$DocumentsTableUpdateCompanionBuilder,
      (Document, $$DocumentsTableReferences),
      Document,
      PrefetchHooks Function({
        bool folderId,
        bool vocabularyEntriesRefs,
        bool viewerSettingsRefs,
      })
    >;
typedef $$VocabularyEntriesTableCreateCompanionBuilder =
    VocabularyEntriesCompanion Function({
      required String id,
      required String documentId,
      required String expressionKey,
      required String expression,
      Value<String?> meaningKo,
      Value<String?> sourceSentence,
      Value<String?> contextBefore,
      Value<String?> contextAfter,
      Value<String?> blockId,
      Value<int?> textOffset,
      Value<String?> userMeaning,
      Value<String?> userMemo,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$VocabularyEntriesTableUpdateCompanionBuilder =
    VocabularyEntriesCompanion Function({
      Value<String> id,
      Value<String> documentId,
      Value<String> expressionKey,
      Value<String> expression,
      Value<String?> meaningKo,
      Value<String?> sourceSentence,
      Value<String?> contextBefore,
      Value<String?> contextAfter,
      Value<String?> blockId,
      Value<int?> textOffset,
      Value<String?> userMeaning,
      Value<String?> userMemo,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$VocabularyEntriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $VocabularyEntriesTable,
          VocabularyEntry
        > {
  $$VocabularyEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DocumentsTable _documentIdTable(_$AppDatabase db) =>
      db.documents.createAlias(
        $_aliasNameGenerator(db.vocabularyEntries.documentId, db.documents.id),
      );

  $$DocumentsTableProcessedTableManager get documentId {
    final $_column = $_itemColumn<String>('document_id')!;

    final manager = $$DocumentsTableTableManager(
      $_db,
      $_db.documents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_documentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$VocabularyEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $VocabularyEntriesTable> {
  $$VocabularyEntriesTableFilterComposer({
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

  ColumnFilters<String> get expressionKey => $composableBuilder(
    column: $table.expressionKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expression => $composableBuilder(
    column: $table.expression,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get meaningKo => $composableBuilder(
    column: $table.meaningKo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceSentence => $composableBuilder(
    column: $table.sourceSentence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contextBefore => $composableBuilder(
    column: $table.contextBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contextAfter => $composableBuilder(
    column: $table.contextAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blockId => $composableBuilder(
    column: $table.blockId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get textOffset => $composableBuilder(
    column: $table.textOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userMeaning => $composableBuilder(
    column: $table.userMeaning,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userMemo => $composableBuilder(
    column: $table.userMemo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$DocumentsTableFilterComposer get documentId {
    final $$DocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableFilterComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VocabularyEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $VocabularyEntriesTable> {
  $$VocabularyEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get expressionKey => $composableBuilder(
    column: $table.expressionKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expression => $composableBuilder(
    column: $table.expression,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meaningKo => $composableBuilder(
    column: $table.meaningKo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceSentence => $composableBuilder(
    column: $table.sourceSentence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contextBefore => $composableBuilder(
    column: $table.contextBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contextAfter => $composableBuilder(
    column: $table.contextAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blockId => $composableBuilder(
    column: $table.blockId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get textOffset => $composableBuilder(
    column: $table.textOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userMeaning => $composableBuilder(
    column: $table.userMeaning,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userMemo => $composableBuilder(
    column: $table.userMemo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$DocumentsTableOrderingComposer get documentId {
    final $$DocumentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableOrderingComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VocabularyEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $VocabularyEntriesTable> {
  $$VocabularyEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get expressionKey => $composableBuilder(
    column: $table.expressionKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get expression => $composableBuilder(
    column: $table.expression,
    builder: (column) => column,
  );

  GeneratedColumn<String> get meaningKo =>
      $composableBuilder(column: $table.meaningKo, builder: (column) => column);

  GeneratedColumn<String> get sourceSentence => $composableBuilder(
    column: $table.sourceSentence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contextBefore => $composableBuilder(
    column: $table.contextBefore,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contextAfter => $composableBuilder(
    column: $table.contextAfter,
    builder: (column) => column,
  );

  GeneratedColumn<String> get blockId =>
      $composableBuilder(column: $table.blockId, builder: (column) => column);

  GeneratedColumn<int> get textOffset => $composableBuilder(
    column: $table.textOffset,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userMeaning => $composableBuilder(
    column: $table.userMeaning,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userMemo =>
      $composableBuilder(column: $table.userMemo, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$DocumentsTableAnnotationComposer get documentId {
    final $$DocumentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableAnnotationComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VocabularyEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VocabularyEntriesTable,
          VocabularyEntry,
          $$VocabularyEntriesTableFilterComposer,
          $$VocabularyEntriesTableOrderingComposer,
          $$VocabularyEntriesTableAnnotationComposer,
          $$VocabularyEntriesTableCreateCompanionBuilder,
          $$VocabularyEntriesTableUpdateCompanionBuilder,
          (VocabularyEntry, $$VocabularyEntriesTableReferences),
          VocabularyEntry,
          PrefetchHooks Function({bool documentId})
        > {
  $$VocabularyEntriesTableTableManager(
    _$AppDatabase db,
    $VocabularyEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VocabularyEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VocabularyEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VocabularyEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> documentId = const Value.absent(),
                Value<String> expressionKey = const Value.absent(),
                Value<String> expression = const Value.absent(),
                Value<String?> meaningKo = const Value.absent(),
                Value<String?> sourceSentence = const Value.absent(),
                Value<String?> contextBefore = const Value.absent(),
                Value<String?> contextAfter = const Value.absent(),
                Value<String?> blockId = const Value.absent(),
                Value<int?> textOffset = const Value.absent(),
                Value<String?> userMeaning = const Value.absent(),
                Value<String?> userMemo = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VocabularyEntriesCompanion(
                id: id,
                documentId: documentId,
                expressionKey: expressionKey,
                expression: expression,
                meaningKo: meaningKo,
                sourceSentence: sourceSentence,
                contextBefore: contextBefore,
                contextAfter: contextAfter,
                blockId: blockId,
                textOffset: textOffset,
                userMeaning: userMeaning,
                userMemo: userMemo,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String documentId,
                required String expressionKey,
                required String expression,
                Value<String?> meaningKo = const Value.absent(),
                Value<String?> sourceSentence = const Value.absent(),
                Value<String?> contextBefore = const Value.absent(),
                Value<String?> contextAfter = const Value.absent(),
                Value<String?> blockId = const Value.absent(),
                Value<int?> textOffset = const Value.absent(),
                Value<String?> userMeaning = const Value.absent(),
                Value<String?> userMemo = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => VocabularyEntriesCompanion.insert(
                id: id,
                documentId: documentId,
                expressionKey: expressionKey,
                expression: expression,
                meaningKo: meaningKo,
                sourceSentence: sourceSentence,
                contextBefore: contextBefore,
                contextAfter: contextAfter,
                blockId: blockId,
                textOffset: textOffset,
                userMeaning: userMeaning,
                userMemo: userMemo,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$VocabularyEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({documentId = false}) {
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
                    if (documentId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.documentId,
                                referencedTable:
                                    $$VocabularyEntriesTableReferences
                                        ._documentIdTable(db),
                                referencedColumn:
                                    $$VocabularyEntriesTableReferences
                                        ._documentIdTable(db)
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

typedef $$VocabularyEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VocabularyEntriesTable,
      VocabularyEntry,
      $$VocabularyEntriesTableFilterComposer,
      $$VocabularyEntriesTableOrderingComposer,
      $$VocabularyEntriesTableAnnotationComposer,
      $$VocabularyEntriesTableCreateCompanionBuilder,
      $$VocabularyEntriesTableUpdateCompanionBuilder,
      (VocabularyEntry, $$VocabularyEntriesTableReferences),
      VocabularyEntry,
      PrefetchHooks Function({bool documentId})
    >;
typedef $$ViewerSettingsTableCreateCompanionBuilder =
    ViewerSettingsCompanion Function({
      required String documentId,
      required String readingMode,
      required String themeId,
      Value<String?> fontFamily,
      required double fontScale,
      required double lineHeight,
      required double marginScale,
      required String assetOpenMode,
      Value<int> rowid,
    });
typedef $$ViewerSettingsTableUpdateCompanionBuilder =
    ViewerSettingsCompanion Function({
      Value<String> documentId,
      Value<String> readingMode,
      Value<String> themeId,
      Value<String?> fontFamily,
      Value<double> fontScale,
      Value<double> lineHeight,
      Value<double> marginScale,
      Value<String> assetOpenMode,
      Value<int> rowid,
    });

final class $$ViewerSettingsTableReferences
    extends BaseReferences<_$AppDatabase, $ViewerSettingsTable, ViewerSetting> {
  $$ViewerSettingsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DocumentsTable _documentIdTable(_$AppDatabase db) =>
      db.documents.createAlias(
        $_aliasNameGenerator(db.viewerSettings.documentId, db.documents.id),
      );

  $$DocumentsTableProcessedTableManager get documentId {
    final $_column = $_itemColumn<String>('document_id')!;

    final manager = $$DocumentsTableTableManager(
      $_db,
      $_db.documents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_documentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ViewerSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $ViewerSettingsTable> {
  $$ViewerSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get readingMode => $composableBuilder(
    column: $table.readingMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get themeId => $composableBuilder(
    column: $table.themeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fontFamily => $composableBuilder(
    column: $table.fontFamily,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fontScale => $composableBuilder(
    column: $table.fontScale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lineHeight => $composableBuilder(
    column: $table.lineHeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get marginScale => $composableBuilder(
    column: $table.marginScale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetOpenMode => $composableBuilder(
    column: $table.assetOpenMode,
    builder: (column) => ColumnFilters(column),
  );

  $$DocumentsTableFilterComposer get documentId {
    final $$DocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableFilterComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ViewerSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $ViewerSettingsTable> {
  $$ViewerSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get readingMode => $composableBuilder(
    column: $table.readingMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themeId => $composableBuilder(
    column: $table.themeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fontFamily => $composableBuilder(
    column: $table.fontFamily,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fontScale => $composableBuilder(
    column: $table.fontScale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lineHeight => $composableBuilder(
    column: $table.lineHeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get marginScale => $composableBuilder(
    column: $table.marginScale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetOpenMode => $composableBuilder(
    column: $table.assetOpenMode,
    builder: (column) => ColumnOrderings(column),
  );

  $$DocumentsTableOrderingComposer get documentId {
    final $$DocumentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableOrderingComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ViewerSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ViewerSettingsTable> {
  $$ViewerSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get readingMode => $composableBuilder(
    column: $table.readingMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get themeId =>
      $composableBuilder(column: $table.themeId, builder: (column) => column);

  GeneratedColumn<String> get fontFamily => $composableBuilder(
    column: $table.fontFamily,
    builder: (column) => column,
  );

  GeneratedColumn<double> get fontScale =>
      $composableBuilder(column: $table.fontScale, builder: (column) => column);

  GeneratedColumn<double> get lineHeight => $composableBuilder(
    column: $table.lineHeight,
    builder: (column) => column,
  );

  GeneratedColumn<double> get marginScale => $composableBuilder(
    column: $table.marginScale,
    builder: (column) => column,
  );

  GeneratedColumn<String> get assetOpenMode => $composableBuilder(
    column: $table.assetOpenMode,
    builder: (column) => column,
  );

  $$DocumentsTableAnnotationComposer get documentId {
    final $$DocumentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableAnnotationComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ViewerSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ViewerSettingsTable,
          ViewerSetting,
          $$ViewerSettingsTableFilterComposer,
          $$ViewerSettingsTableOrderingComposer,
          $$ViewerSettingsTableAnnotationComposer,
          $$ViewerSettingsTableCreateCompanionBuilder,
          $$ViewerSettingsTableUpdateCompanionBuilder,
          (ViewerSetting, $$ViewerSettingsTableReferences),
          ViewerSetting,
          PrefetchHooks Function({bool documentId})
        > {
  $$ViewerSettingsTableTableManager(
    _$AppDatabase db,
    $ViewerSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ViewerSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ViewerSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ViewerSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> documentId = const Value.absent(),
                Value<String> readingMode = const Value.absent(),
                Value<String> themeId = const Value.absent(),
                Value<String?> fontFamily = const Value.absent(),
                Value<double> fontScale = const Value.absent(),
                Value<double> lineHeight = const Value.absent(),
                Value<double> marginScale = const Value.absent(),
                Value<String> assetOpenMode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ViewerSettingsCompanion(
                documentId: documentId,
                readingMode: readingMode,
                themeId: themeId,
                fontFamily: fontFamily,
                fontScale: fontScale,
                lineHeight: lineHeight,
                marginScale: marginScale,
                assetOpenMode: assetOpenMode,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String documentId,
                required String readingMode,
                required String themeId,
                Value<String?> fontFamily = const Value.absent(),
                required double fontScale,
                required double lineHeight,
                required double marginScale,
                required String assetOpenMode,
                Value<int> rowid = const Value.absent(),
              }) => ViewerSettingsCompanion.insert(
                documentId: documentId,
                readingMode: readingMode,
                themeId: themeId,
                fontFamily: fontFamily,
                fontScale: fontScale,
                lineHeight: lineHeight,
                marginScale: marginScale,
                assetOpenMode: assetOpenMode,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ViewerSettingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({documentId = false}) {
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
                    if (documentId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.documentId,
                                referencedTable: $$ViewerSettingsTableReferences
                                    ._documentIdTable(db),
                                referencedColumn:
                                    $$ViewerSettingsTableReferences
                                        ._documentIdTable(db)
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

typedef $$ViewerSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ViewerSettingsTable,
      ViewerSetting,
      $$ViewerSettingsTableFilterComposer,
      $$ViewerSettingsTableOrderingComposer,
      $$ViewerSettingsTableAnnotationComposer,
      $$ViewerSettingsTableCreateCompanionBuilder,
      $$ViewerSettingsTableUpdateCompanionBuilder,
      (ViewerSetting, $$ViewerSettingsTableReferences),
      ViewerSetting,
      PrefetchHooks Function({bool documentId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LibraryFoldersTableTableManager get libraryFolders =>
      $$LibraryFoldersTableTableManager(_db, _db.libraryFolders);
  $$DocumentsTableTableManager get documents =>
      $$DocumentsTableTableManager(_db, _db.documents);
  $$VocabularyEntriesTableTableManager get vocabularyEntries =>
      $$VocabularyEntriesTableTableManager(_db, _db.vocabularyEntries);
  $$ViewerSettingsTableTableManager get viewerSettings =>
      $$ViewerSettingsTableTableManager(_db, _db.viewerSettings);
}
