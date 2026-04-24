// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_sessions_database.dart';

// ignore_for_file: type=lint
class $PendingSessionsTable extends PendingSessions
    with TableInfo<$PendingSessionsTable, PendingSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingSessionsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _tutorIdMeta = const VerificationMeta(
    'tutorId',
  );
  @override
  late final GeneratedColumn<String> tutorId = GeneratedColumn<String>(
    'tutor_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _studentIdMeta = const VerificationMeta(
    'studentId',
  );
  @override
  late final GeneratedColumn<String> studentId = GeneratedColumn<String>(
    'student_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courseIdMeta = const VerificationMeta(
    'courseId',
  );
  @override
  late final GeneratedColumn<String> courseId = GeneratedColumn<String>(
    'course_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduledStartMeta = const VerificationMeta(
    'scheduledStart',
  );
  @override
  late final GeneratedColumn<String> scheduledStart = GeneratedColumn<String>(
    'scheduled_start',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduledEndMeta = const VerificationMeta(
    'scheduledEnd',
  );
  @override
  late final GeneratedColumn<String> scheduledEnd = GeneratedColumn<String>(
    'scheduled_end',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookingSourceMeta = const VerificationMeta(
    'bookingSource',
  );
  @override
  late final GeneratedColumn<String> bookingSource = GeneratedColumn<String>(
    'booking_source',
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
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _tutorNameMeta = const VerificationMeta(
    'tutorName',
  );
  @override
  late final GeneratedColumn<String> tutorName = GeneratedColumn<String>(
    'tutor_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentAvailabilityIdMeta =
      const VerificationMeta('parentAvailabilityId');
  @override
  late final GeneratedColumn<String> parentAvailabilityId =
      GeneratedColumn<String>(
        'parent_availability_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _nextSlotIndexMeta = const VerificationMeta(
    'nextSlotIndex',
  );
  @override
  late final GeneratedColumn<int> nextSlotIndex = GeneratedColumn<int>(
    'next_slot_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tutorId,
    studentId,
    courseId,
    scheduledStart,
    scheduledEnd,
    location,
    bookingSource,
    createdAt,
    synced,
    tutorName,
    parentAvailabilityId,
    nextSlotIndex,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('tutor_id')) {
      context.handle(
        _tutorIdMeta,
        tutorId.isAcceptableOrUnknown(data['tutor_id']!, _tutorIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tutorIdMeta);
    }
    if (data.containsKey('student_id')) {
      context.handle(
        _studentIdMeta,
        studentId.isAcceptableOrUnknown(data['student_id']!, _studentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_studentIdMeta);
    }
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('scheduled_start')) {
      context.handle(
        _scheduledStartMeta,
        scheduledStart.isAcceptableOrUnknown(
          data['scheduled_start']!,
          _scheduledStartMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledStartMeta);
    }
    if (data.containsKey('scheduled_end')) {
      context.handle(
        _scheduledEndMeta,
        scheduledEnd.isAcceptableOrUnknown(
          data['scheduled_end']!,
          _scheduledEndMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledEndMeta);
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    } else if (isInserting) {
      context.missing(_locationMeta);
    }
    if (data.containsKey('booking_source')) {
      context.handle(
        _bookingSourceMeta,
        bookingSource.isAcceptableOrUnknown(
          data['booking_source']!,
          _bookingSourceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_bookingSourceMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    if (data.containsKey('tutor_name')) {
      context.handle(
        _tutorNameMeta,
        tutorName.isAcceptableOrUnknown(data['tutor_name']!, _tutorNameMeta),
      );
    }
    if (data.containsKey('parent_availability_id')) {
      context.handle(
        _parentAvailabilityIdMeta,
        parentAvailabilityId.isAcceptableOrUnknown(
          data['parent_availability_id']!,
          _parentAvailabilityIdMeta,
        ),
      );
    }
    if (data.containsKey('next_slot_index')) {
      context.handle(
        _nextSlotIndexMeta,
        nextSlotIndex.isAcceptableOrUnknown(
          data['next_slot_index']!,
          _nextSlotIndexMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      tutorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tutor_id'],
      )!,
      studentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}student_id'],
      )!,
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_id'],
      )!,
      scheduledStart: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheduled_start'],
      )!,
      scheduledEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheduled_end'],
      )!,
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      )!,
      bookingSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}booking_source'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
      tutorName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tutor_name'],
      ),
      parentAvailabilityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_availability_id'],
      ),
      nextSlotIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_slot_index'],
      ),
    );
  }

  @override
  $PendingSessionsTable createAlias(String alias) {
    return $PendingSessionsTable(attachedDatabase, alias);
  }
}

class PendingSession extends DataClass implements Insertable<PendingSession> {
  /// Auto-increment primary key — used to update individual rows after sync.
  final int id;
  final String tutorId;
  final String studentId;
  final String courseId;

  /// ISO-8601 strings — stored as text to avoid timezone drift issues.
  final String scheduledStart;
  final String scheduledEnd;
  final String location;
  final String bookingSource;
  final DateTime createdAt;

  /// false = waiting for sync; true = successfully POSTed to the server.
  final bool synced;
  final String? tutorName;
  final String? parentAvailabilityId;
  final int? nextSlotIndex;
  const PendingSession({
    required this.id,
    required this.tutorId,
    required this.studentId,
    required this.courseId,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.location,
    required this.bookingSource,
    required this.createdAt,
    required this.synced,
    this.tutorName,
    this.parentAvailabilityId,
    this.nextSlotIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['tutor_id'] = Variable<String>(tutorId);
    map['student_id'] = Variable<String>(studentId);
    map['course_id'] = Variable<String>(courseId);
    map['scheduled_start'] = Variable<String>(scheduledStart);
    map['scheduled_end'] = Variable<String>(scheduledEnd);
    map['location'] = Variable<String>(location);
    map['booking_source'] = Variable<String>(bookingSource);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['synced'] = Variable<bool>(synced);
    if (!nullToAbsent || tutorName != null) {
      map['tutor_name'] = Variable<String>(tutorName);
    }
    if (!nullToAbsent || parentAvailabilityId != null) {
      map['parent_availability_id'] = Variable<String>(parentAvailabilityId);
    }
    if (!nullToAbsent || nextSlotIndex != null) {
      map['next_slot_index'] = Variable<int>(nextSlotIndex);
    }
    return map;
  }

  PendingSessionsCompanion toCompanion(bool nullToAbsent) {
    return PendingSessionsCompanion(
      id: Value(id),
      tutorId: Value(tutorId),
      studentId: Value(studentId),
      courseId: Value(courseId),
      scheduledStart: Value(scheduledStart),
      scheduledEnd: Value(scheduledEnd),
      location: Value(location),
      bookingSource: Value(bookingSource),
      createdAt: Value(createdAt),
      synced: Value(synced),
      tutorName: tutorName == null && nullToAbsent
          ? const Value.absent()
          : Value(tutorName),
      parentAvailabilityId: parentAvailabilityId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentAvailabilityId),
      nextSlotIndex: nextSlotIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(nextSlotIndex),
    );
  }

  factory PendingSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingSession(
      id: serializer.fromJson<int>(json['id']),
      tutorId: serializer.fromJson<String>(json['tutorId']),
      studentId: serializer.fromJson<String>(json['studentId']),
      courseId: serializer.fromJson<String>(json['courseId']),
      scheduledStart: serializer.fromJson<String>(json['scheduledStart']),
      scheduledEnd: serializer.fromJson<String>(json['scheduledEnd']),
      location: serializer.fromJson<String>(json['location']),
      bookingSource: serializer.fromJson<String>(json['bookingSource']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      synced: serializer.fromJson<bool>(json['synced']),
      tutorName: serializer.fromJson<String?>(json['tutorName']),
      parentAvailabilityId: serializer.fromJson<String?>(
        json['parentAvailabilityId'],
      ),
      nextSlotIndex: serializer.fromJson<int?>(json['nextSlotIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tutorId': serializer.toJson<String>(tutorId),
      'studentId': serializer.toJson<String>(studentId),
      'courseId': serializer.toJson<String>(courseId),
      'scheduledStart': serializer.toJson<String>(scheduledStart),
      'scheduledEnd': serializer.toJson<String>(scheduledEnd),
      'location': serializer.toJson<String>(location),
      'bookingSource': serializer.toJson<String>(bookingSource),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'synced': serializer.toJson<bool>(synced),
      'tutorName': serializer.toJson<String?>(tutorName),
      'parentAvailabilityId': serializer.toJson<String?>(parentAvailabilityId),
      'nextSlotIndex': serializer.toJson<int?>(nextSlotIndex),
    };
  }

  PendingSession copyWith({
    int? id,
    String? tutorId,
    String? studentId,
    String? courseId,
    String? scheduledStart,
    String? scheduledEnd,
    String? location,
    String? bookingSource,
    DateTime? createdAt,
    bool? synced,
    Value<String?> tutorName = const Value.absent(),
    Value<String?> parentAvailabilityId = const Value.absent(),
    Value<int?> nextSlotIndex = const Value.absent(),
  }) => PendingSession(
    id: id ?? this.id,
    tutorId: tutorId ?? this.tutorId,
    studentId: studentId ?? this.studentId,
    courseId: courseId ?? this.courseId,
    scheduledStart: scheduledStart ?? this.scheduledStart,
    scheduledEnd: scheduledEnd ?? this.scheduledEnd,
    location: location ?? this.location,
    bookingSource: bookingSource ?? this.bookingSource,
    createdAt: createdAt ?? this.createdAt,
    synced: synced ?? this.synced,
    tutorName: tutorName.present ? tutorName.value : this.tutorName,
    parentAvailabilityId: parentAvailabilityId.present
        ? parentAvailabilityId.value
        : this.parentAvailabilityId,
    nextSlotIndex: nextSlotIndex.present
        ? nextSlotIndex.value
        : this.nextSlotIndex,
  );
  PendingSession copyWithCompanion(PendingSessionsCompanion data) {
    return PendingSession(
      id: data.id.present ? data.id.value : this.id,
      tutorId: data.tutorId.present ? data.tutorId.value : this.tutorId,
      studentId: data.studentId.present ? data.studentId.value : this.studentId,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      scheduledStart: data.scheduledStart.present
          ? data.scheduledStart.value
          : this.scheduledStart,
      scheduledEnd: data.scheduledEnd.present
          ? data.scheduledEnd.value
          : this.scheduledEnd,
      location: data.location.present ? data.location.value : this.location,
      bookingSource: data.bookingSource.present
          ? data.bookingSource.value
          : this.bookingSource,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      synced: data.synced.present ? data.synced.value : this.synced,
      tutorName: data.tutorName.present ? data.tutorName.value : this.tutorName,
      parentAvailabilityId: data.parentAvailabilityId.present
          ? data.parentAvailabilityId.value
          : this.parentAvailabilityId,
      nextSlotIndex: data.nextSlotIndex.present
          ? data.nextSlotIndex.value
          : this.nextSlotIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingSession(')
          ..write('id: $id, ')
          ..write('tutorId: $tutorId, ')
          ..write('studentId: $studentId, ')
          ..write('courseId: $courseId, ')
          ..write('scheduledStart: $scheduledStart, ')
          ..write('scheduledEnd: $scheduledEnd, ')
          ..write('location: $location, ')
          ..write('bookingSource: $bookingSource, ')
          ..write('createdAt: $createdAt, ')
          ..write('synced: $synced, ')
          ..write('tutorName: $tutorName, ')
          ..write('parentAvailabilityId: $parentAvailabilityId, ')
          ..write('nextSlotIndex: $nextSlotIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tutorId,
    studentId,
    courseId,
    scheduledStart,
    scheduledEnd,
    location,
    bookingSource,
    createdAt,
    synced,
    tutorName,
    parentAvailabilityId,
    nextSlotIndex,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingSession &&
          other.id == this.id &&
          other.tutorId == this.tutorId &&
          other.studentId == this.studentId &&
          other.courseId == this.courseId &&
          other.scheduledStart == this.scheduledStart &&
          other.scheduledEnd == this.scheduledEnd &&
          other.location == this.location &&
          other.bookingSource == this.bookingSource &&
          other.createdAt == this.createdAt &&
          other.synced == this.synced &&
          other.tutorName == this.tutorName &&
          other.parentAvailabilityId == this.parentAvailabilityId &&
          other.nextSlotIndex == this.nextSlotIndex);
}

class PendingSessionsCompanion extends UpdateCompanion<PendingSession> {
  final Value<int> id;
  final Value<String> tutorId;
  final Value<String> studentId;
  final Value<String> courseId;
  final Value<String> scheduledStart;
  final Value<String> scheduledEnd;
  final Value<String> location;
  final Value<String> bookingSource;
  final Value<DateTime> createdAt;
  final Value<bool> synced;
  final Value<String?> tutorName;
  final Value<String?> parentAvailabilityId;
  final Value<int?> nextSlotIndex;
  const PendingSessionsCompanion({
    this.id = const Value.absent(),
    this.tutorId = const Value.absent(),
    this.studentId = const Value.absent(),
    this.courseId = const Value.absent(),
    this.scheduledStart = const Value.absent(),
    this.scheduledEnd = const Value.absent(),
    this.location = const Value.absent(),
    this.bookingSource = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.synced = const Value.absent(),
    this.tutorName = const Value.absent(),
    this.parentAvailabilityId = const Value.absent(),
    this.nextSlotIndex = const Value.absent(),
  });
  PendingSessionsCompanion.insert({
    this.id = const Value.absent(),
    required String tutorId,
    required String studentId,
    required String courseId,
    required String scheduledStart,
    required String scheduledEnd,
    required String location,
    required String bookingSource,
    required DateTime createdAt,
    this.synced = const Value.absent(),
    this.tutorName = const Value.absent(),
    this.parentAvailabilityId = const Value.absent(),
    this.nextSlotIndex = const Value.absent(),
  }) : tutorId = Value(tutorId),
       studentId = Value(studentId),
       courseId = Value(courseId),
       scheduledStart = Value(scheduledStart),
       scheduledEnd = Value(scheduledEnd),
       location = Value(location),
       bookingSource = Value(bookingSource),
       createdAt = Value(createdAt);
  static Insertable<PendingSession> custom({
    Expression<int>? id,
    Expression<String>? tutorId,
    Expression<String>? studentId,
    Expression<String>? courseId,
    Expression<String>? scheduledStart,
    Expression<String>? scheduledEnd,
    Expression<String>? location,
    Expression<String>? bookingSource,
    Expression<DateTime>? createdAt,
    Expression<bool>? synced,
    Expression<String>? tutorName,
    Expression<String>? parentAvailabilityId,
    Expression<int>? nextSlotIndex,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tutorId != null) 'tutor_id': tutorId,
      if (studentId != null) 'student_id': studentId,
      if (courseId != null) 'course_id': courseId,
      if (scheduledStart != null) 'scheduled_start': scheduledStart,
      if (scheduledEnd != null) 'scheduled_end': scheduledEnd,
      if (location != null) 'location': location,
      if (bookingSource != null) 'booking_source': bookingSource,
      if (createdAt != null) 'created_at': createdAt,
      if (synced != null) 'synced': synced,
      if (tutorName != null) 'tutor_name': tutorName,
      if (parentAvailabilityId != null)
        'parent_availability_id': parentAvailabilityId,
      if (nextSlotIndex != null) 'next_slot_index': nextSlotIndex,
    });
  }

  PendingSessionsCompanion copyWith({
    Value<int>? id,
    Value<String>? tutorId,
    Value<String>? studentId,
    Value<String>? courseId,
    Value<String>? scheduledStart,
    Value<String>? scheduledEnd,
    Value<String>? location,
    Value<String>? bookingSource,
    Value<DateTime>? createdAt,
    Value<bool>? synced,
    Value<String?>? tutorName,
    Value<String?>? parentAvailabilityId,
    Value<int?>? nextSlotIndex,
  }) {
    return PendingSessionsCompanion(
      id: id ?? this.id,
      tutorId: tutorId ?? this.tutorId,
      studentId: studentId ?? this.studentId,
      courseId: courseId ?? this.courseId,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      scheduledEnd: scheduledEnd ?? this.scheduledEnd,
      location: location ?? this.location,
      bookingSource: bookingSource ?? this.bookingSource,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
      tutorName: tutorName ?? this.tutorName,
      parentAvailabilityId: parentAvailabilityId ?? this.parentAvailabilityId,
      nextSlotIndex: nextSlotIndex ?? this.nextSlotIndex,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (tutorId.present) {
      map['tutor_id'] = Variable<String>(tutorId.value);
    }
    if (studentId.present) {
      map['student_id'] = Variable<String>(studentId.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<String>(courseId.value);
    }
    if (scheduledStart.present) {
      map['scheduled_start'] = Variable<String>(scheduledStart.value);
    }
    if (scheduledEnd.present) {
      map['scheduled_end'] = Variable<String>(scheduledEnd.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (bookingSource.present) {
      map['booking_source'] = Variable<String>(bookingSource.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (tutorName.present) {
      map['tutor_name'] = Variable<String>(tutorName.value);
    }
    if (parentAvailabilityId.present) {
      map['parent_availability_id'] = Variable<String>(
        parentAvailabilityId.value,
      );
    }
    if (nextSlotIndex.present) {
      map['next_slot_index'] = Variable<int>(nextSlotIndex.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingSessionsCompanion(')
          ..write('id: $id, ')
          ..write('tutorId: $tutorId, ')
          ..write('studentId: $studentId, ')
          ..write('courseId: $courseId, ')
          ..write('scheduledStart: $scheduledStart, ')
          ..write('scheduledEnd: $scheduledEnd, ')
          ..write('location: $location, ')
          ..write('bookingSource: $bookingSource, ')
          ..write('createdAt: $createdAt, ')
          ..write('synced: $synced, ')
          ..write('tutorName: $tutorName, ')
          ..write('parentAvailabilityId: $parentAvailabilityId, ')
          ..write('nextSlotIndex: $nextSlotIndex')
          ..write(')'))
        .toString();
  }
}

abstract class _$PendingSessionsDatabase extends GeneratedDatabase {
  _$PendingSessionsDatabase(QueryExecutor e) : super(e);
  $PendingSessionsDatabaseManager get managers =>
      $PendingSessionsDatabaseManager(this);
  late final $PendingSessionsTable pendingSessions = $PendingSessionsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [pendingSessions];
}

typedef $$PendingSessionsTableCreateCompanionBuilder =
    PendingSessionsCompanion Function({
      Value<int> id,
      required String tutorId,
      required String studentId,
      required String courseId,
      required String scheduledStart,
      required String scheduledEnd,
      required String location,
      required String bookingSource,
      required DateTime createdAt,
      Value<bool> synced,
      Value<String?> tutorName,
      Value<String?> parentAvailabilityId,
      Value<int?> nextSlotIndex,
    });
typedef $$PendingSessionsTableUpdateCompanionBuilder =
    PendingSessionsCompanion Function({
      Value<int> id,
      Value<String> tutorId,
      Value<String> studentId,
      Value<String> courseId,
      Value<String> scheduledStart,
      Value<String> scheduledEnd,
      Value<String> location,
      Value<String> bookingSource,
      Value<DateTime> createdAt,
      Value<bool> synced,
      Value<String?> tutorName,
      Value<String?> parentAvailabilityId,
      Value<int?> nextSlotIndex,
    });

class $$PendingSessionsTableFilterComposer
    extends Composer<_$PendingSessionsDatabase, $PendingSessionsTable> {
  $$PendingSessionsTableFilterComposer({
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

  ColumnFilters<String> get tutorId => $composableBuilder(
    column: $table.tutorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get studentId => $composableBuilder(
    column: $table.studentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheduledStart => $composableBuilder(
    column: $table.scheduledStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheduledEnd => $composableBuilder(
    column: $table.scheduledEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookingSource => $composableBuilder(
    column: $table.bookingSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tutorName => $composableBuilder(
    column: $table.tutorName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentAvailabilityId => $composableBuilder(
    column: $table.parentAvailabilityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextSlotIndex => $composableBuilder(
    column: $table.nextSlotIndex,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingSessionsTableOrderingComposer
    extends Composer<_$PendingSessionsDatabase, $PendingSessionsTable> {
  $$PendingSessionsTableOrderingComposer({
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

  ColumnOrderings<String> get tutorId => $composableBuilder(
    column: $table.tutorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get studentId => $composableBuilder(
    column: $table.studentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduledStart => $composableBuilder(
    column: $table.scheduledStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduledEnd => $composableBuilder(
    column: $table.scheduledEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookingSource => $composableBuilder(
    column: $table.bookingSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tutorName => $composableBuilder(
    column: $table.tutorName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentAvailabilityId => $composableBuilder(
    column: $table.parentAvailabilityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextSlotIndex => $composableBuilder(
    column: $table.nextSlotIndex,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingSessionsTableAnnotationComposer
    extends Composer<_$PendingSessionsDatabase, $PendingSessionsTable> {
  $$PendingSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tutorId =>
      $composableBuilder(column: $table.tutorId, builder: (column) => column);

  GeneratedColumn<String> get studentId =>
      $composableBuilder(column: $table.studentId, builder: (column) => column);

  GeneratedColumn<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<String> get scheduledStart => $composableBuilder(
    column: $table.scheduledStart,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scheduledEnd => $composableBuilder(
    column: $table.scheduledEnd,
    builder: (column) => column,
  );

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get bookingSource => $composableBuilder(
    column: $table.bookingSource,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);

  GeneratedColumn<String> get tutorName =>
      $composableBuilder(column: $table.tutorName, builder: (column) => column);

  GeneratedColumn<String> get parentAvailabilityId => $composableBuilder(
    column: $table.parentAvailabilityId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nextSlotIndex => $composableBuilder(
    column: $table.nextSlotIndex,
    builder: (column) => column,
  );
}

class $$PendingSessionsTableTableManager
    extends
        RootTableManager<
          _$PendingSessionsDatabase,
          $PendingSessionsTable,
          PendingSession,
          $$PendingSessionsTableFilterComposer,
          $$PendingSessionsTableOrderingComposer,
          $$PendingSessionsTableAnnotationComposer,
          $$PendingSessionsTableCreateCompanionBuilder,
          $$PendingSessionsTableUpdateCompanionBuilder,
          (
            PendingSession,
            BaseReferences<
              _$PendingSessionsDatabase,
              $PendingSessionsTable,
              PendingSession
            >,
          ),
          PendingSession,
          PrefetchHooks Function()
        > {
  $$PendingSessionsTableTableManager(
    _$PendingSessionsDatabase db,
    $PendingSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> tutorId = const Value.absent(),
                Value<String> studentId = const Value.absent(),
                Value<String> courseId = const Value.absent(),
                Value<String> scheduledStart = const Value.absent(),
                Value<String> scheduledEnd = const Value.absent(),
                Value<String> location = const Value.absent(),
                Value<String> bookingSource = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<String?> tutorName = const Value.absent(),
                Value<String?> parentAvailabilityId = const Value.absent(),
                Value<int?> nextSlotIndex = const Value.absent(),
              }) => PendingSessionsCompanion(
                id: id,
                tutorId: tutorId,
                studentId: studentId,
                courseId: courseId,
                scheduledStart: scheduledStart,
                scheduledEnd: scheduledEnd,
                location: location,
                bookingSource: bookingSource,
                createdAt: createdAt,
                synced: synced,
                tutorName: tutorName,
                parentAvailabilityId: parentAvailabilityId,
                nextSlotIndex: nextSlotIndex,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String tutorId,
                required String studentId,
                required String courseId,
                required String scheduledStart,
                required String scheduledEnd,
                required String location,
                required String bookingSource,
                required DateTime createdAt,
                Value<bool> synced = const Value.absent(),
                Value<String?> tutorName = const Value.absent(),
                Value<String?> parentAvailabilityId = const Value.absent(),
                Value<int?> nextSlotIndex = const Value.absent(),
              }) => PendingSessionsCompanion.insert(
                id: id,
                tutorId: tutorId,
                studentId: studentId,
                courseId: courseId,
                scheduledStart: scheduledStart,
                scheduledEnd: scheduledEnd,
                location: location,
                bookingSource: bookingSource,
                createdAt: createdAt,
                synced: synced,
                tutorName: tutorName,
                parentAvailabilityId: parentAvailabilityId,
                nextSlotIndex: nextSlotIndex,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$PendingSessionsDatabase,
      $PendingSessionsTable,
      PendingSession,
      $$PendingSessionsTableFilterComposer,
      $$PendingSessionsTableOrderingComposer,
      $$PendingSessionsTableAnnotationComposer,
      $$PendingSessionsTableCreateCompanionBuilder,
      $$PendingSessionsTableUpdateCompanionBuilder,
      (
        PendingSession,
        BaseReferences<
          _$PendingSessionsDatabase,
          $PendingSessionsTable,
          PendingSession
        >,
      ),
      PendingSession,
      PrefetchHooks Function()
    >;

class $PendingSessionsDatabaseManager {
  final _$PendingSessionsDatabase _db;
  $PendingSessionsDatabaseManager(this._db);
  $$PendingSessionsTableTableManager get pendingSessions =>
      $$PendingSessionsTableTableManager(_db, _db.pendingSessions);
}
