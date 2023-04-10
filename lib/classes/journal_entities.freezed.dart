// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'journal_entities.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

Metadata _$MetadataFromJson(Map<String, dynamic> json) {
  return _Metadata.fromJson(json);
}

/// @nodoc
mixin _$Metadata {
  String get id => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;
  DateTime get dateFrom => throw _privateConstructorUsedError;
  DateTime get dateTo => throw _privateConstructorUsedError;
  List<String>? get tags => throw _privateConstructorUsedError;
  List<String>? get tagIds => throw _privateConstructorUsedError;
  int? get utcOffset => throw _privateConstructorUsedError;
  String? get timezone => throw _privateConstructorUsedError;
  VectorClock? get vectorClock => throw _privateConstructorUsedError;
  DateTime? get deletedAt => throw _privateConstructorUsedError;
  EntryFlag? get flag => throw _privateConstructorUsedError;
  bool? get starred => throw _privateConstructorUsedError;
  bool? get private => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $MetadataCopyWith<Metadata> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MetadataCopyWith<$Res> {
  factory $MetadataCopyWith(Metadata value, $Res Function(Metadata) then) =
      _$MetadataCopyWithImpl<$Res, Metadata>;
  @useResult
  $Res call(
      {String id,
      DateTime createdAt,
      DateTime updatedAt,
      DateTime dateFrom,
      DateTime dateTo,
      List<String>? tags,
      List<String>? tagIds,
      int? utcOffset,
      String? timezone,
      VectorClock? vectorClock,
      DateTime? deletedAt,
      EntryFlag? flag,
      bool? starred,
      bool? private});
}

/// @nodoc
class _$MetadataCopyWithImpl<$Res, $Val extends Metadata>
    implements $MetadataCopyWith<$Res> {
  _$MetadataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? dateFrom = null,
    Object? dateTo = null,
    Object? tags = freezed,
    Object? tagIds = freezed,
    Object? utcOffset = freezed,
    Object? timezone = freezed,
    Object? vectorClock = freezed,
    Object? deletedAt = freezed,
    Object? flag = freezed,
    Object? starred = freezed,
    Object? private = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateFrom: null == dateFrom
          ? _value.dateFrom
          : dateFrom // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateTo: null == dateTo
          ? _value.dateTo
          : dateTo // ignore: cast_nullable_to_non_nullable
              as DateTime,
      tags: freezed == tags
          ? _value.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      tagIds: freezed == tagIds
          ? _value.tagIds
          : tagIds // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      utcOffset: freezed == utcOffset
          ? _value.utcOffset
          : utcOffset // ignore: cast_nullable_to_non_nullable
              as int?,
      timezone: freezed == timezone
          ? _value.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      vectorClock: freezed == vectorClock
          ? _value.vectorClock
          : vectorClock // ignore: cast_nullable_to_non_nullable
              as VectorClock?,
      deletedAt: freezed == deletedAt
          ? _value.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      flag: freezed == flag
          ? _value.flag
          : flag // ignore: cast_nullable_to_non_nullable
              as EntryFlag?,
      starred: freezed == starred
          ? _value.starred
          : starred // ignore: cast_nullable_to_non_nullable
              as bool?,
      private: freezed == private
          ? _value.private
          : private // ignore: cast_nullable_to_non_nullable
              as bool?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_MetadataCopyWith<$Res> implements $MetadataCopyWith<$Res> {
  factory _$$_MetadataCopyWith(
          _$_Metadata value, $Res Function(_$_Metadata) then) =
      __$$_MetadataCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      DateTime createdAt,
      DateTime updatedAt,
      DateTime dateFrom,
      DateTime dateTo,
      List<String>? tags,
      List<String>? tagIds,
      int? utcOffset,
      String? timezone,
      VectorClock? vectorClock,
      DateTime? deletedAt,
      EntryFlag? flag,
      bool? starred,
      bool? private});
}

/// @nodoc
class __$$_MetadataCopyWithImpl<$Res>
    extends _$MetadataCopyWithImpl<$Res, _$_Metadata>
    implements _$$_MetadataCopyWith<$Res> {
  __$$_MetadataCopyWithImpl(
      _$_Metadata _value, $Res Function(_$_Metadata) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? dateFrom = null,
    Object? dateTo = null,
    Object? tags = freezed,
    Object? tagIds = freezed,
    Object? utcOffset = freezed,
    Object? timezone = freezed,
    Object? vectorClock = freezed,
    Object? deletedAt = freezed,
    Object? flag = freezed,
    Object? starred = freezed,
    Object? private = freezed,
  }) {
    return _then(_$_Metadata(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateFrom: null == dateFrom
          ? _value.dateFrom
          : dateFrom // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateTo: null == dateTo
          ? _value.dateTo
          : dateTo // ignore: cast_nullable_to_non_nullable
              as DateTime,
      tags: freezed == tags
          ? _value._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      tagIds: freezed == tagIds
          ? _value._tagIds
          : tagIds // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      utcOffset: freezed == utcOffset
          ? _value.utcOffset
          : utcOffset // ignore: cast_nullable_to_non_nullable
              as int?,
      timezone: freezed == timezone
          ? _value.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      vectorClock: freezed == vectorClock
          ? _value.vectorClock
          : vectorClock // ignore: cast_nullable_to_non_nullable
              as VectorClock?,
      deletedAt: freezed == deletedAt
          ? _value.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      flag: freezed == flag
          ? _value.flag
          : flag // ignore: cast_nullable_to_non_nullable
              as EntryFlag?,
      starred: freezed == starred
          ? _value.starred
          : starred // ignore: cast_nullable_to_non_nullable
              as bool?,
      private: freezed == private
          ? _value.private
          : private // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$_Metadata implements _Metadata {
  _$_Metadata(
      {required this.id,
      required this.createdAt,
      required this.updatedAt,
      required this.dateFrom,
      required this.dateTo,
      final List<String>? tags,
      final List<String>? tagIds,
      this.utcOffset,
      this.timezone,
      this.vectorClock,
      this.deletedAt,
      this.flag,
      this.starred,
      this.private})
      : _tags = tags,
        _tagIds = tagIds;

  factory _$_Metadata.fromJson(Map<String, dynamic> json) =>
      _$$_MetadataFromJson(json);

  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final DateTime dateFrom;
  @override
  final DateTime dateTo;
  final List<String>? _tags;
  @override
  List<String>? get tags {
    final value = _tags;
    if (value == null) return null;
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final List<String>? _tagIds;
  @override
  List<String>? get tagIds {
    final value = _tagIds;
    if (value == null) return null;
    if (_tagIds is EqualUnmodifiableListView) return _tagIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final int? utcOffset;
  @override
  final String? timezone;
  @override
  final VectorClock? vectorClock;
  @override
  final DateTime? deletedAt;
  @override
  final EntryFlag? flag;
  @override
  final bool? starred;
  @override
  final bool? private;

  @override
  String toString() {
    return 'Metadata(id: $id, createdAt: $createdAt, updatedAt: $updatedAt, dateFrom: $dateFrom, dateTo: $dateTo, tags: $tags, tagIds: $tagIds, utcOffset: $utcOffset, timezone: $timezone, vectorClock: $vectorClock, deletedAt: $deletedAt, flag: $flag, starred: $starred, private: $private)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_Metadata &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.dateFrom, dateFrom) ||
                other.dateFrom == dateFrom) &&
            (identical(other.dateTo, dateTo) || other.dateTo == dateTo) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            const DeepCollectionEquality().equals(other._tagIds, _tagIds) &&
            (identical(other.utcOffset, utcOffset) ||
                other.utcOffset == utcOffset) &&
            (identical(other.timezone, timezone) ||
                other.timezone == timezone) &&
            (identical(other.vectorClock, vectorClock) ||
                other.vectorClock == vectorClock) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt) &&
            (identical(other.flag, flag) || other.flag == flag) &&
            (identical(other.starred, starred) || other.starred == starred) &&
            (identical(other.private, private) || other.private == private));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      createdAt,
      updatedAt,
      dateFrom,
      dateTo,
      const DeepCollectionEquality().hash(_tags),
      const DeepCollectionEquality().hash(_tagIds),
      utcOffset,
      timezone,
      vectorClock,
      deletedAt,
      flag,
      starred,
      private);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_MetadataCopyWith<_$_Metadata> get copyWith =>
      __$$_MetadataCopyWithImpl<_$_Metadata>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$_MetadataToJson(
      this,
    );
  }
}

abstract class _Metadata implements Metadata {
  factory _Metadata(
      {required final String id,
      required final DateTime createdAt,
      required final DateTime updatedAt,
      required final DateTime dateFrom,
      required final DateTime dateTo,
      final List<String>? tags,
      final List<String>? tagIds,
      final int? utcOffset,
      final String? timezone,
      final VectorClock? vectorClock,
      final DateTime? deletedAt,
      final EntryFlag? flag,
      final bool? starred,
      final bool? private}) = _$_Metadata;

  factory _Metadata.fromJson(Map<String, dynamic> json) = _$_Metadata.fromJson;

  @override
  String get id;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  @override
  DateTime get dateFrom;
  @override
  DateTime get dateTo;
  @override
  List<String>? get tags;
  @override
  List<String>? get tagIds;
  @override
  int? get utcOffset;
  @override
  String? get timezone;
  @override
  VectorClock? get vectorClock;
  @override
  DateTime? get deletedAt;
  @override
  EntryFlag? get flag;
  @override
  bool? get starred;
  @override
  bool? get private;
  @override
  @JsonKey(ignore: true)
  _$$_MetadataCopyWith<_$_Metadata> get copyWith =>
      throw _privateConstructorUsedError;
}

ImageData _$ImageDataFromJson(Map<String, dynamic> json) {
  return _ImageData.fromJson(json);
}

/// @nodoc
mixin _$ImageData {
  DateTime get capturedAt => throw _privateConstructorUsedError;
  String get imageId => throw _privateConstructorUsedError;
  String get imageFile => throw _privateConstructorUsedError;
  String get imageDirectory => throw _privateConstructorUsedError;
  Geolocation? get geolocation => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ImageDataCopyWith<ImageData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ImageDataCopyWith<$Res> {
  factory $ImageDataCopyWith(ImageData value, $Res Function(ImageData) then) =
      _$ImageDataCopyWithImpl<$Res, ImageData>;
  @useResult
  $Res call(
      {DateTime capturedAt,
      String imageId,
      String imageFile,
      String imageDirectory,
      Geolocation? geolocation});

  $GeolocationCopyWith<$Res>? get geolocation;
}

/// @nodoc
class _$ImageDataCopyWithImpl<$Res, $Val extends ImageData>
    implements $ImageDataCopyWith<$Res> {
  _$ImageDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? capturedAt = null,
    Object? imageId = null,
    Object? imageFile = null,
    Object? imageDirectory = null,
    Object? geolocation = freezed,
  }) {
    return _then(_value.copyWith(
      capturedAt: null == capturedAt
          ? _value.capturedAt
          : capturedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      imageId: null == imageId
          ? _value.imageId
          : imageId // ignore: cast_nullable_to_non_nullable
              as String,
      imageFile: null == imageFile
          ? _value.imageFile
          : imageFile // ignore: cast_nullable_to_non_nullable
              as String,
      imageDirectory: null == imageDirectory
          ? _value.imageDirectory
          : imageDirectory // ignore: cast_nullable_to_non_nullable
              as String,
      geolocation: freezed == geolocation
          ? _value.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $GeolocationCopyWith<$Res>? get geolocation {
    if (_value.geolocation == null) {
      return null;
    }

    return $GeolocationCopyWith<$Res>(_value.geolocation!, (value) {
      return _then(_value.copyWith(geolocation: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$_ImageDataCopyWith<$Res> implements $ImageDataCopyWith<$Res> {
  factory _$$_ImageDataCopyWith(
          _$_ImageData value, $Res Function(_$_ImageData) then) =
      __$$_ImageDataCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {DateTime capturedAt,
      String imageId,
      String imageFile,
      String imageDirectory,
      Geolocation? geolocation});

  @override
  $GeolocationCopyWith<$Res>? get geolocation;
}

/// @nodoc
class __$$_ImageDataCopyWithImpl<$Res>
    extends _$ImageDataCopyWithImpl<$Res, _$_ImageData>
    implements _$$_ImageDataCopyWith<$Res> {
  __$$_ImageDataCopyWithImpl(
      _$_ImageData _value, $Res Function(_$_ImageData) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? capturedAt = null,
    Object? imageId = null,
    Object? imageFile = null,
    Object? imageDirectory = null,
    Object? geolocation = freezed,
  }) {
    return _then(_$_ImageData(
      capturedAt: null == capturedAt
          ? _value.capturedAt
          : capturedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      imageId: null == imageId
          ? _value.imageId
          : imageId // ignore: cast_nullable_to_non_nullable
              as String,
      imageFile: null == imageFile
          ? _value.imageFile
          : imageFile // ignore: cast_nullable_to_non_nullable
              as String,
      imageDirectory: null == imageDirectory
          ? _value.imageDirectory
          : imageDirectory // ignore: cast_nullable_to_non_nullable
              as String,
      geolocation: freezed == geolocation
          ? _value.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$_ImageData implements _ImageData {
  _$_ImageData(
      {required this.capturedAt,
      required this.imageId,
      required this.imageFile,
      required this.imageDirectory,
      this.geolocation});

  factory _$_ImageData.fromJson(Map<String, dynamic> json) =>
      _$$_ImageDataFromJson(json);

  @override
  final DateTime capturedAt;
  @override
  final String imageId;
  @override
  final String imageFile;
  @override
  final String imageDirectory;
  @override
  final Geolocation? geolocation;

  @override
  String toString() {
    return 'ImageData(capturedAt: $capturedAt, imageId: $imageId, imageFile: $imageFile, imageDirectory: $imageDirectory, geolocation: $geolocation)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_ImageData &&
            (identical(other.capturedAt, capturedAt) ||
                other.capturedAt == capturedAt) &&
            (identical(other.imageId, imageId) || other.imageId == imageId) &&
            (identical(other.imageFile, imageFile) ||
                other.imageFile == imageFile) &&
            (identical(other.imageDirectory, imageDirectory) ||
                other.imageDirectory == imageDirectory) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType, capturedAt, imageId, imageFile, imageDirectory, geolocation);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_ImageDataCopyWith<_$_ImageData> get copyWith =>
      __$$_ImageDataCopyWithImpl<_$_ImageData>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$_ImageDataToJson(
      this,
    );
  }
}

abstract class _ImageData implements ImageData {
  factory _ImageData(
      {required final DateTime capturedAt,
      required final String imageId,
      required final String imageFile,
      required final String imageDirectory,
      final Geolocation? geolocation}) = _$_ImageData;

  factory _ImageData.fromJson(Map<String, dynamic> json) =
      _$_ImageData.fromJson;

  @override
  DateTime get capturedAt;
  @override
  String get imageId;
  @override
  String get imageFile;
  @override
  String get imageDirectory;
  @override
  Geolocation? get geolocation;
  @override
  @JsonKey(ignore: true)
  _$$_ImageDataCopyWith<_$_ImageData> get copyWith =>
      throw _privateConstructorUsedError;
}

AudioData _$AudioDataFromJson(Map<String, dynamic> json) {
  return _AudioData.fromJson(json);
}

/// @nodoc
mixin _$AudioData {
  DateTime get dateFrom => throw _privateConstructorUsedError;
  DateTime get dateTo => throw _privateConstructorUsedError;
  String get audioFile => throw _privateConstructorUsedError;
  String get audioDirectory => throw _privateConstructorUsedError;
  Duration get duration => throw _privateConstructorUsedError;
  String? get transcript => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $AudioDataCopyWith<AudioData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AudioDataCopyWith<$Res> {
  factory $AudioDataCopyWith(AudioData value, $Res Function(AudioData) then) =
      _$AudioDataCopyWithImpl<$Res, AudioData>;
  @useResult
  $Res call(
      {DateTime dateFrom,
      DateTime dateTo,
      String audioFile,
      String audioDirectory,
      Duration duration,
      String? transcript});
}

/// @nodoc
class _$AudioDataCopyWithImpl<$Res, $Val extends AudioData>
    implements $AudioDataCopyWith<$Res> {
  _$AudioDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dateFrom = null,
    Object? dateTo = null,
    Object? audioFile = null,
    Object? audioDirectory = null,
    Object? duration = null,
    Object? transcript = freezed,
  }) {
    return _then(_value.copyWith(
      dateFrom: null == dateFrom
          ? _value.dateFrom
          : dateFrom // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateTo: null == dateTo
          ? _value.dateTo
          : dateTo // ignore: cast_nullable_to_non_nullable
              as DateTime,
      audioFile: null == audioFile
          ? _value.audioFile
          : audioFile // ignore: cast_nullable_to_non_nullable
              as String,
      audioDirectory: null == audioDirectory
          ? _value.audioDirectory
          : audioDirectory // ignore: cast_nullable_to_non_nullable
              as String,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as Duration,
      transcript: freezed == transcript
          ? _value.transcript
          : transcript // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_AudioDataCopyWith<$Res> implements $AudioDataCopyWith<$Res> {
  factory _$$_AudioDataCopyWith(
          _$_AudioData value, $Res Function(_$_AudioData) then) =
      __$$_AudioDataCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {DateTime dateFrom,
      DateTime dateTo,
      String audioFile,
      String audioDirectory,
      Duration duration,
      String? transcript});
}

/// @nodoc
class __$$_AudioDataCopyWithImpl<$Res>
    extends _$AudioDataCopyWithImpl<$Res, _$_AudioData>
    implements _$$_AudioDataCopyWith<$Res> {
  __$$_AudioDataCopyWithImpl(
      _$_AudioData _value, $Res Function(_$_AudioData) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dateFrom = null,
    Object? dateTo = null,
    Object? audioFile = null,
    Object? audioDirectory = null,
    Object? duration = null,
    Object? transcript = freezed,
  }) {
    return _then(_$_AudioData(
      dateFrom: null == dateFrom
          ? _value.dateFrom
          : dateFrom // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateTo: null == dateTo
          ? _value.dateTo
          : dateTo // ignore: cast_nullable_to_non_nullable
              as DateTime,
      audioFile: null == audioFile
          ? _value.audioFile
          : audioFile // ignore: cast_nullable_to_non_nullable
              as String,
      audioDirectory: null == audioDirectory
          ? _value.audioDirectory
          : audioDirectory // ignore: cast_nullable_to_non_nullable
              as String,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as Duration,
      transcript: freezed == transcript
          ? _value.transcript
          : transcript // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$_AudioData implements _AudioData {
  _$_AudioData(
      {required this.dateFrom,
      required this.dateTo,
      required this.audioFile,
      required this.audioDirectory,
      required this.duration,
      this.transcript});

  factory _$_AudioData.fromJson(Map<String, dynamic> json) =>
      _$$_AudioDataFromJson(json);

  @override
  final DateTime dateFrom;
  @override
  final DateTime dateTo;
  @override
  final String audioFile;
  @override
  final String audioDirectory;
  @override
  final Duration duration;
  @override
  final String? transcript;

  @override
  String toString() {
    return 'AudioData(dateFrom: $dateFrom, dateTo: $dateTo, audioFile: $audioFile, audioDirectory: $audioDirectory, duration: $duration, transcript: $transcript)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_AudioData &&
            (identical(other.dateFrom, dateFrom) ||
                other.dateFrom == dateFrom) &&
            (identical(other.dateTo, dateTo) || other.dateTo == dateTo) &&
            (identical(other.audioFile, audioFile) ||
                other.audioFile == audioFile) &&
            (identical(other.audioDirectory, audioDirectory) ||
                other.audioDirectory == audioDirectory) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.transcript, transcript) ||
                other.transcript == transcript));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, dateFrom, dateTo, audioFile,
      audioDirectory, duration, transcript);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_AudioDataCopyWith<_$_AudioData> get copyWith =>
      __$$_AudioDataCopyWithImpl<_$_AudioData>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$_AudioDataToJson(
      this,
    );
  }
}

abstract class _AudioData implements AudioData {
  factory _AudioData(
      {required final DateTime dateFrom,
      required final DateTime dateTo,
      required final String audioFile,
      required final String audioDirectory,
      required final Duration duration,
      final String? transcript}) = _$_AudioData;

  factory _AudioData.fromJson(Map<String, dynamic> json) =
      _$_AudioData.fromJson;

  @override
  DateTime get dateFrom;
  @override
  DateTime get dateTo;
  @override
  String get audioFile;
  @override
  String get audioDirectory;
  @override
  Duration get duration;
  @override
  String? get transcript;
  @override
  @JsonKey(ignore: true)
  _$$_AudioDataCopyWith<_$_AudioData> get copyWith =>
      throw _privateConstructorUsedError;
}

SurveyData _$SurveyDataFromJson(Map<String, dynamic> json) {
  return _SurveyData.fromJson(json);
}

/// @nodoc
mixin _$SurveyData {
  RPTaskResult get taskResult => throw _privateConstructorUsedError;
  Map<String, Set<String>> get scoreDefinitions =>
      throw _privateConstructorUsedError;
  Map<String, int> get calculatedScores => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $SurveyDataCopyWith<SurveyData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SurveyDataCopyWith<$Res> {
  factory $SurveyDataCopyWith(
          SurveyData value, $Res Function(SurveyData) then) =
      _$SurveyDataCopyWithImpl<$Res, SurveyData>;
  @useResult
  $Res call(
      {RPTaskResult taskResult,
      Map<String, Set<String>> scoreDefinitions,
      Map<String, int> calculatedScores});
}

/// @nodoc
class _$SurveyDataCopyWithImpl<$Res, $Val extends SurveyData>
    implements $SurveyDataCopyWith<$Res> {
  _$SurveyDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? taskResult = null,
    Object? scoreDefinitions = null,
    Object? calculatedScores = null,
  }) {
    return _then(_value.copyWith(
      taskResult: null == taskResult
          ? _value.taskResult
          : taskResult // ignore: cast_nullable_to_non_nullable
              as RPTaskResult,
      scoreDefinitions: null == scoreDefinitions
          ? _value.scoreDefinitions
          : scoreDefinitions // ignore: cast_nullable_to_non_nullable
              as Map<String, Set<String>>,
      calculatedScores: null == calculatedScores
          ? _value.calculatedScores
          : calculatedScores // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_SurveyDataCopyWith<$Res>
    implements $SurveyDataCopyWith<$Res> {
  factory _$$_SurveyDataCopyWith(
          _$_SurveyData value, $Res Function(_$_SurveyData) then) =
      __$$_SurveyDataCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {RPTaskResult taskResult,
      Map<String, Set<String>> scoreDefinitions,
      Map<String, int> calculatedScores});
}

/// @nodoc
class __$$_SurveyDataCopyWithImpl<$Res>
    extends _$SurveyDataCopyWithImpl<$Res, _$_SurveyData>
    implements _$$_SurveyDataCopyWith<$Res> {
  __$$_SurveyDataCopyWithImpl(
      _$_SurveyData _value, $Res Function(_$_SurveyData) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? taskResult = null,
    Object? scoreDefinitions = null,
    Object? calculatedScores = null,
  }) {
    return _then(_$_SurveyData(
      taskResult: null == taskResult
          ? _value.taskResult
          : taskResult // ignore: cast_nullable_to_non_nullable
              as RPTaskResult,
      scoreDefinitions: null == scoreDefinitions
          ? _value._scoreDefinitions
          : scoreDefinitions // ignore: cast_nullable_to_non_nullable
              as Map<String, Set<String>>,
      calculatedScores: null == calculatedScores
          ? _value._calculatedScores
          : calculatedScores // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$_SurveyData implements _SurveyData {
  _$_SurveyData(
      {required this.taskResult,
      required final Map<String, Set<String>> scoreDefinitions,
      required final Map<String, int> calculatedScores})
      : _scoreDefinitions = scoreDefinitions,
        _calculatedScores = calculatedScores;

  factory _$_SurveyData.fromJson(Map<String, dynamic> json) =>
      _$$_SurveyDataFromJson(json);

  @override
  final RPTaskResult taskResult;
  final Map<String, Set<String>> _scoreDefinitions;
  @override
  Map<String, Set<String>> get scoreDefinitions {
    if (_scoreDefinitions is EqualUnmodifiableMapView) return _scoreDefinitions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_scoreDefinitions);
  }

  final Map<String, int> _calculatedScores;
  @override
  Map<String, int> get calculatedScores {
    if (_calculatedScores is EqualUnmodifiableMapView) return _calculatedScores;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_calculatedScores);
  }

  @override
  String toString() {
    return 'SurveyData(taskResult: $taskResult, scoreDefinitions: $scoreDefinitions, calculatedScores: $calculatedScores)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_SurveyData &&
            (identical(other.taskResult, taskResult) ||
                other.taskResult == taskResult) &&
            const DeepCollectionEquality()
                .equals(other._scoreDefinitions, _scoreDefinitions) &&
            const DeepCollectionEquality()
                .equals(other._calculatedScores, _calculatedScores));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      taskResult,
      const DeepCollectionEquality().hash(_scoreDefinitions),
      const DeepCollectionEquality().hash(_calculatedScores));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_SurveyDataCopyWith<_$_SurveyData> get copyWith =>
      __$$_SurveyDataCopyWithImpl<_$_SurveyData>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$_SurveyDataToJson(
      this,
    );
  }
}

abstract class _SurveyData implements SurveyData {
  factory _SurveyData(
      {required final RPTaskResult taskResult,
      required final Map<String, Set<String>> scoreDefinitions,
      required final Map<String, int> calculatedScores}) = _$_SurveyData;

  factory _SurveyData.fromJson(Map<String, dynamic> json) =
      _$_SurveyData.fromJson;

  @override
  RPTaskResult get taskResult;
  @override
  Map<String, Set<String>> get scoreDefinitions;
  @override
  Map<String, int> get calculatedScores;
  @override
  @JsonKey(ignore: true)
  _$$_SurveyDataCopyWith<_$_SurveyData> get copyWith =>
      throw _privateConstructorUsedError;
}

JournalEntity _$JournalEntityFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'journalEntry':
      return JournalEntry.fromJson(json);
    case 'journalImage':
      return JournalImage.fromJson(json);
    case 'journalAudio':
      return JournalAudio.fromJson(json);
    case 'task':
      return Task.fromJson(json);
    case 'quantitative':
      return QuantitativeEntry.fromJson(json);
    case 'measurement':
      return MeasurementEntry.fromJson(json);
    case 'workout':
      return WorkoutEntry.fromJson(json);
    case 'habitCompletion':
      return HabitCompletionEntry.fromJson(json);
    case 'survey':
      return SurveyEntry.fromJson(json);

    default:
      throw CheckedFromJsonException(json, 'runtimeType', 'JournalEntity',
          'Invalid union type "${json['runtimeType']}"!');
  }
}

/// @nodoc
mixin _$JournalEntity {
  Metadata get meta => throw _privateConstructorUsedError;
  EntryText? get entryText => throw _privateConstructorUsedError;
  Geolocation? get geolocation => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(Metadata meta, EntryText? entryText, Geolocation? geolocation)
        journalEntry,
    required TResult Function(Metadata meta, ImageData data,
            EntryText? entryText, Geolocation? geolocation)
        journalImage,
    required TResult Function(Metadata meta, AudioData data,
            EntryText? entryText, Geolocation? geolocation)
        journalAudio,
    required TResult Function(Metadata meta, TaskData data,
            EntryText? entryText, Geolocation? geolocation)
        task,
    required TResult Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)
        quantitative,
    required TResult Function(Metadata meta, MeasurementData data,
            EntryText? entryText, Geolocation? geolocation)
        measurement,
    required TResult Function(
            Metadata meta, WorkoutData data, EntryText? entryText, Geolocation? geolocation)
        workout,
    required TResult Function(Metadata meta, HabitCompletionData data, EntryText? entryText, Geolocation? geolocation) habitCompletion,
    required TResult Function(Metadata meta, SurveyData data, EntryText? entryText, Geolocation? geolocation) survey,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(Metadata meta, EntryText? entryText, Geolocation? geolocation)?
        journalEntry,
    TResult? Function(Metadata meta, ImageData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalImage,
    TResult? Function(Metadata meta, AudioData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalAudio,
    TResult? Function(Metadata meta, TaskData data, EntryText? entryText,
            Geolocation? geolocation)?
        task,
    TResult? Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)?
        quantitative,
    TResult? Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult? Function(
            Metadata meta, WorkoutData data, EntryText? entryText, Geolocation? geolocation)?
        workout,
    TResult? Function(Metadata meta, HabitCompletionData data, EntryText? entryText, Geolocation? geolocation)? habitCompletion,
    TResult? Function(Metadata meta, SurveyData data, EntryText? entryText, Geolocation? geolocation)? survey,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(Metadata meta, EntryText? entryText, Geolocation? geolocation)?
        journalEntry,
    TResult Function(Metadata meta, ImageData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalImage,
    TResult Function(Metadata meta, AudioData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalAudio,
    TResult Function(Metadata meta, TaskData data, EntryText? entryText,
            Geolocation? geolocation)?
        task,
    TResult Function(Metadata meta, QuantitativeData data, EntryText? entryText,
            Geolocation? geolocation)?
        quantitative,
    TResult Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult Function(
            Metadata meta, WorkoutData data, EntryText? entryText, Geolocation? geolocation)?
        workout,
    TResult Function(Metadata meta, HabitCompletionData data, EntryText? entryText, Geolocation? geolocation)? habitCompletion,
    TResult Function(Metadata meta, SurveyData data, EntryText? entryText, Geolocation? geolocation)? survey,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(JournalEntry value) journalEntry,
    required TResult Function(JournalImage value) journalImage,
    required TResult Function(JournalAudio value) journalAudio,
    required TResult Function(Task value) task,
    required TResult Function(QuantitativeEntry value) quantitative,
    required TResult Function(MeasurementEntry value) measurement,
    required TResult Function(WorkoutEntry value) workout,
    required TResult Function(HabitCompletionEntry value) habitCompletion,
    required TResult Function(SurveyEntry value) survey,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(JournalEntry value)? journalEntry,
    TResult? Function(JournalImage value)? journalImage,
    TResult? Function(JournalAudio value)? journalAudio,
    TResult? Function(Task value)? task,
    TResult? Function(QuantitativeEntry value)? quantitative,
    TResult? Function(MeasurementEntry value)? measurement,
    TResult? Function(WorkoutEntry value)? workout,
    TResult? Function(HabitCompletionEntry value)? habitCompletion,
    TResult? Function(SurveyEntry value)? survey,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(JournalEntry value)? journalEntry,
    TResult Function(JournalImage value)? journalImage,
    TResult Function(JournalAudio value)? journalAudio,
    TResult Function(Task value)? task,
    TResult Function(QuantitativeEntry value)? quantitative,
    TResult Function(MeasurementEntry value)? measurement,
    TResult Function(WorkoutEntry value)? workout,
    TResult Function(HabitCompletionEntry value)? habitCompletion,
    TResult Function(SurveyEntry value)? survey,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $JournalEntityCopyWith<JournalEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $JournalEntityCopyWith<$Res> {
  factory $JournalEntityCopyWith(
          JournalEntity value, $Res Function(JournalEntity) then) =
      _$JournalEntityCopyWithImpl<$Res, JournalEntity>;
  @useResult
  $Res call({Metadata meta, EntryText? entryText, Geolocation? geolocation});

  $MetadataCopyWith<$Res> get meta;
  $EntryTextCopyWith<$Res>? get entryText;
  $GeolocationCopyWith<$Res>? get geolocation;
}

/// @nodoc
class _$JournalEntityCopyWithImpl<$Res, $Val extends JournalEntity>
    implements $JournalEntityCopyWith<$Res> {
  _$JournalEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_value.copyWith(
      meta: null == meta
          ? _value.meta
          : meta // ignore: cast_nullable_to_non_nullable
              as Metadata,
      entryText: freezed == entryText
          ? _value.entryText
          : entryText // ignore: cast_nullable_to_non_nullable
              as EntryText?,
      geolocation: freezed == geolocation
          ? _value.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $MetadataCopyWith<$Res> get meta {
    return $MetadataCopyWith<$Res>(_value.meta, (value) {
      return _then(_value.copyWith(meta: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $EntryTextCopyWith<$Res>? get entryText {
    if (_value.entryText == null) {
      return null;
    }

    return $EntryTextCopyWith<$Res>(_value.entryText!, (value) {
      return _then(_value.copyWith(entryText: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $GeolocationCopyWith<$Res>? get geolocation {
    if (_value.geolocation == null) {
      return null;
    }

    return $GeolocationCopyWith<$Res>(_value.geolocation!, (value) {
      return _then(_value.copyWith(geolocation: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$JournalEntryCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory _$$JournalEntryCopyWith(
          _$JournalEntry value, $Res Function(_$JournalEntry) then) =
      __$$JournalEntryCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({Metadata meta, EntryText? entryText, Geolocation? geolocation});

  @override
  $MetadataCopyWith<$Res> get meta;
  @override
  $EntryTextCopyWith<$Res>? get entryText;
  @override
  $GeolocationCopyWith<$Res>? get geolocation;
}

/// @nodoc
class __$$JournalEntryCopyWithImpl<$Res>
    extends _$JournalEntityCopyWithImpl<$Res, _$JournalEntry>
    implements _$$JournalEntryCopyWith<$Res> {
  __$$JournalEntryCopyWithImpl(
      _$JournalEntry _value, $Res Function(_$JournalEntry) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$JournalEntry(
      meta: null == meta
          ? _value.meta
          : meta // ignore: cast_nullable_to_non_nullable
              as Metadata,
      entryText: freezed == entryText
          ? _value.entryText
          : entryText // ignore: cast_nullable_to_non_nullable
              as EntryText?,
      geolocation: freezed == geolocation
          ? _value.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$JournalEntry implements JournalEntry {
  _$JournalEntry(
      {required this.meta,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'journalEntry';

  factory _$JournalEntry.fromJson(Map<String, dynamic> json) =>
      _$$JournalEntryFromJson(json);

  @override
  final Metadata meta;
  @override
  final EntryText? entryText;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'JournalEntity.journalEntry(meta: $meta, entryText: $entryText, geolocation: $geolocation)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$JournalEntry &&
            (identical(other.meta, meta) || other.meta == meta) &&
            (identical(other.entryText, entryText) ||
                other.entryText == entryText) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, meta, entryText, geolocation);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$JournalEntryCopyWith<_$JournalEntry> get copyWith =>
      __$$JournalEntryCopyWithImpl<_$JournalEntry>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(Metadata meta, EntryText? entryText, Geolocation? geolocation)
        journalEntry,
    required TResult Function(Metadata meta, ImageData data,
            EntryText? entryText, Geolocation? geolocation)
        journalImage,
    required TResult Function(Metadata meta, AudioData data,
            EntryText? entryText, Geolocation? geolocation)
        journalAudio,
    required TResult Function(Metadata meta, TaskData data,
            EntryText? entryText, Geolocation? geolocation)
        task,
    required TResult Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)
        quantitative,
    required TResult Function(Metadata meta, MeasurementData data,
            EntryText? entryText, Geolocation? geolocation)
        measurement,
    required TResult Function(
            Metadata meta, WorkoutData data, EntryText? entryText, Geolocation? geolocation)
        workout,
    required TResult Function(Metadata meta, HabitCompletionData data, EntryText? entryText, Geolocation? geolocation) habitCompletion,
    required TResult Function(Metadata meta, SurveyData data, EntryText? entryText, Geolocation? geolocation) survey,
  }) {
    return journalEntry(meta, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(Metadata meta, EntryText? entryText, Geolocation? geolocation)?
        journalEntry,
    TResult? Function(Metadata meta, ImageData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalImage,
    TResult? Function(Metadata meta, AudioData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalAudio,
    TResult? Function(Metadata meta, TaskData data, EntryText? entryText,
            Geolocation? geolocation)?
        task,
    TResult? Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)?
        quantitative,
    TResult? Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult? Function(
            Metadata meta, WorkoutData data, EntryText? entryText, Geolocation? geolocation)?
        workout,
    TResult? Function(Metadata meta, HabitCompletionData data, EntryText? entryText, Geolocation? geolocation)? habitCompletion,
    TResult? Function(Metadata meta, SurveyData data, EntryText? entryText, Geolocation? geolocation)? survey,
  }) {
    return journalEntry?.call(meta, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(Metadata meta, EntryText? entryText, Geolocation? geolocation)?
        journalEntry,
    TResult Function(Metadata meta, ImageData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalImage,
    TResult Function(Metadata meta, AudioData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalAudio,
    TResult Function(Metadata meta, TaskData data, EntryText? entryText,
            Geolocation? geolocation)?
        task,
    TResult Function(Metadata meta, QuantitativeData data, EntryText? entryText,
            Geolocation? geolocation)?
        quantitative,
    TResult Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult Function(
            Metadata meta, WorkoutData data, EntryText? entryText, Geolocation? geolocation)?
        workout,
    TResult Function(Metadata meta, HabitCompletionData data, EntryText? entryText, Geolocation? geolocation)? habitCompletion,
    TResult Function(Metadata meta, SurveyData data, EntryText? entryText, Geolocation? geolocation)? survey,
    required TResult orElse(),
  }) {
    if (journalEntry != null) {
      return journalEntry(meta, entryText, geolocation);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(JournalEntry value) journalEntry,
    required TResult Function(JournalImage value) journalImage,
    required TResult Function(JournalAudio value) journalAudio,
    required TResult Function(Task value) task,
    required TResult Function(QuantitativeEntry value) quantitative,
    required TResult Function(MeasurementEntry value) measurement,
    required TResult Function(WorkoutEntry value) workout,
    required TResult Function(HabitCompletionEntry value) habitCompletion,
    required TResult Function(SurveyEntry value) survey,
  }) {
    return journalEntry(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(JournalEntry value)? journalEntry,
    TResult? Function(JournalImage value)? journalImage,
    TResult? Function(JournalAudio value)? journalAudio,
    TResult? Function(Task value)? task,
    TResult? Function(QuantitativeEntry value)? quantitative,
    TResult? Function(MeasurementEntry value)? measurement,
    TResult? Function(WorkoutEntry value)? workout,
    TResult? Function(HabitCompletionEntry value)? habitCompletion,
    TResult? Function(SurveyEntry value)? survey,
  }) {
    return journalEntry?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(JournalEntry value)? journalEntry,
    TResult Function(JournalImage value)? journalImage,
    TResult Function(JournalAudio value)? journalAudio,
    TResult Function(Task value)? task,
    TResult Function(QuantitativeEntry value)? quantitative,
    TResult Function(MeasurementEntry value)? measurement,
    TResult Function(WorkoutEntry value)? workout,
    TResult Function(HabitCompletionEntry value)? habitCompletion,
    TResult Function(SurveyEntry value)? survey,
    required TResult orElse(),
  }) {
    if (journalEntry != null) {
      return journalEntry(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$JournalEntryToJson(
      this,
    );
  }
}

abstract class JournalEntry implements JournalEntity {
  factory JournalEntry(
      {required final Metadata meta,
      final EntryText? entryText,
      final Geolocation? geolocation}) = _$JournalEntry;

  factory JournalEntry.fromJson(Map<String, dynamic> json) =
      _$JournalEntry.fromJson;

  @override
  Metadata get meta;
  @override
  EntryText? get entryText;
  @override
  Geolocation? get geolocation;
  @override
  @JsonKey(ignore: true)
  _$$JournalEntryCopyWith<_$JournalEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$JournalImageCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory _$$JournalImageCopyWith(
          _$JournalImage value, $Res Function(_$JournalImage) then) =
      __$$JournalImageCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {Metadata meta,
      ImageData data,
      EntryText? entryText,
      Geolocation? geolocation});

  @override
  $MetadataCopyWith<$Res> get meta;
  $ImageDataCopyWith<$Res> get data;
  @override
  $EntryTextCopyWith<$Res>? get entryText;
  @override
  $GeolocationCopyWith<$Res>? get geolocation;
}

/// @nodoc
class __$$JournalImageCopyWithImpl<$Res>
    extends _$JournalEntityCopyWithImpl<$Res, _$JournalImage>
    implements _$$JournalImageCopyWith<$Res> {
  __$$JournalImageCopyWithImpl(
      _$JournalImage _value, $Res Function(_$JournalImage) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = null,
    Object? data = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$JournalImage(
      meta: null == meta
          ? _value.meta
          : meta // ignore: cast_nullable_to_non_nullable
              as Metadata,
      data: null == data
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as ImageData,
      entryText: freezed == entryText
          ? _value.entryText
          : entryText // ignore: cast_nullable_to_non_nullable
              as EntryText?,
      geolocation: freezed == geolocation
          ? _value.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }

  @override
  @pragma('vm:prefer-inline')
  $ImageDataCopyWith<$Res> get data {
    return $ImageDataCopyWith<$Res>(_value.data, (value) {
      return _then(_value.copyWith(data: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _$JournalImage implements JournalImage {
  const _$JournalImage(
      {required this.meta,
      required this.data,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'journalImage';

  factory _$JournalImage.fromJson(Map<String, dynamic> json) =>
      _$$JournalImageFromJson(json);

  @override
  final Metadata meta;
  @override
  final ImageData data;
  @override
  final EntryText? entryText;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'JournalEntity.journalImage(meta: $meta, data: $data, entryText: $entryText, geolocation: $geolocation)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$JournalImage &&
            (identical(other.meta, meta) || other.meta == meta) &&
            (identical(other.data, data) || other.data == data) &&
            (identical(other.entryText, entryText) ||
                other.entryText == entryText) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, meta, data, entryText, geolocation);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$JournalImageCopyWith<_$JournalImage> get copyWith =>
      __$$JournalImageCopyWithImpl<_$JournalImage>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(Metadata meta, EntryText? entryText, Geolocation? geolocation)
        journalEntry,
    required TResult Function(Metadata meta, ImageData data,
            EntryText? entryText, Geolocation? geolocation)
        journalImage,
    required TResult Function(Metadata meta, AudioData data,
            EntryText? entryText, Geolocation? geolocation)
        journalAudio,
    required TResult Function(Metadata meta, TaskData data,
            EntryText? entryText, Geolocation? geolocation)
        task,
    required TResult Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)
        quantitative,
    required TResult Function(Metadata meta, MeasurementData data,
            EntryText? entryText, Geolocation? geolocation)
        measurement,
    required TResult Function(
            Metadata meta, WorkoutData data, EntryText? entryText, Geolocation? geolocation)
        workout,
    required TResult Function(Metadata meta, HabitCompletionData data, EntryText? entryText, Geolocation? geolocation) habitCompletion,
    required TResult Function(Metadata meta, SurveyData data, EntryText? entryText, Geolocation? geolocation) survey,
  }) {
    return journalImage(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(Metadata meta, EntryText? entryText, Geolocation? geolocation)?
        journalEntry,
    TResult? Function(Metadata meta, ImageData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalImage,
    TResult? Function(Metadata meta, AudioData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalAudio,
    TResult? Function(Metadata meta, TaskData data, EntryText? entryText,
            Geolocation? geolocation)?
        task,
    TResult? Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)?
        quantitative,
    TResult? Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult? Function(
            Metadata meta, WorkoutData data, EntryText? entryText, Geolocation? geolocation)?
        workout,
    TResult? Function(Metadata meta, HabitCompletionData data, EntryText? entryText, Geolocation? geolocation)? habitCompletion,
    TResult? Function(Metadata meta, SurveyData data, EntryText? entryText, Geolocation? geolocation)? survey,
  }) {
    return journalImage?.call(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(Metadata meta, EntryText? entryText, Geolocation? geolocation)?
        journalEntry,
    TResult Function(Metadata meta, ImageData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalImage,
    TResult Function(Metadata meta, AudioData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalAudio,
    TResult Function(Metadata meta, TaskData data, EntryText? entryText,
            Geolocation? geolocation)?
        task,
    TResult Function(Metadata meta, QuantitativeData data, EntryText? entryText,
            Geolocation? geolocation)?
        quantitative,
    TResult Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult Function(
            Metadata meta, WorkoutData data, EntryText? entryText, Geolocation? geolocation)?
        workout,
    TResult Function(Metadata meta, HabitCompletionData data, EntryText? entryText, Geolocation? geolocation)? habitCompletion,
    TResult Function(Metadata meta, SurveyData data, EntryText? entryText, Geolocation? geolocation)? survey,
    required TResult orElse(),
  }) {
    if (journalImage != null) {
      return journalImage(meta, data, entryText, geolocation);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(JournalEntry value) journalEntry,
    required TResult Function(JournalImage value) journalImage,
    required TResult Function(JournalAudio value) journalAudio,
    required TResult Function(Task value) task,
    required TResult Function(QuantitativeEntry value) quantitative,
    required TResult Function(MeasurementEntry value) measurement,
    required TResult Function(WorkoutEntry value) workout,
    required TResult Function(HabitCompletionEntry value) habitCompletion,
    required TResult Function(SurveyEntry value) survey,
  }) {
    return journalImage(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(JournalEntry value)? journalEntry,
    TResult? Function(JournalImage value)? journalImage,
    TResult? Function(JournalAudio value)? journalAudio,
    TResult? Function(Task value)? task,
    TResult? Function(QuantitativeEntry value)? quantitative,
    TResult? Function(MeasurementEntry value)? measurement,
    TResult? Function(WorkoutEntry value)? workout,
    TResult? Function(HabitCompletionEntry value)? habitCompletion,
    TResult? Function(SurveyEntry value)? survey,
  }) {
    return journalImage?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(JournalEntry value)? journalEntry,
    TResult Function(JournalImage value)? journalImage,
    TResult Function(JournalAudio value)? journalAudio,
    TResult Function(Task value)? task,
    TResult Function(QuantitativeEntry value)? quantitative,
    TResult Function(MeasurementEntry value)? measurement,
    TResult Function(WorkoutEntry value)? workout,
    TResult Function(HabitCompletionEntry value)? habitCompletion,
    TResult Function(SurveyEntry value)? survey,
    required TResult orElse(),
  }) {
    if (journalImage != null) {
      return journalImage(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$JournalImageToJson(
      this,
    );
  }
}

abstract class JournalImage implements JournalEntity {
  const factory JournalImage(
      {required final Metadata meta,
      required final ImageData data,
      final EntryText? entryText,
      final Geolocation? geolocation}) = _$JournalImage;

  factory JournalImage.fromJson(Map<String, dynamic> json) =
      _$JournalImage.fromJson;

  @override
  Metadata get meta;
  ImageData get data;
  @override
  EntryText? get entryText;
  @override
  Geolocation? get geolocation;
  @override
  @JsonKey(ignore: true)
  _$$JournalImageCopyWith<_$JournalImage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$JournalAudioCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory _$$JournalAudioCopyWith(
          _$JournalAudio value, $Res Function(_$JournalAudio) then) =
      __$$JournalAudioCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {Metadata meta,
      AudioData data,
      EntryText? entryText,
      Geolocation? geolocation});

  @override
  $MetadataCopyWith<$Res> get meta;
  $AudioDataCopyWith<$Res> get data;
  @override
  $EntryTextCopyWith<$Res>? get entryText;
  @override
  $GeolocationCopyWith<$Res>? get geolocation;
}

/// @nodoc
class __$$JournalAudioCopyWithImpl<$Res>
    extends _$JournalEntityCopyWithImpl<$Res, _$JournalAudio>
    implements _$$JournalAudioCopyWith<$Res> {
  __$$JournalAudioCopyWithImpl(
      _$JournalAudio _value, $Res Function(_$JournalAudio) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = null,
    Object? data = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$JournalAudio(
      meta: null == meta
          ? _value.meta
          : meta // ignore: cast_nullable_to_non_nullable
              as Metadata,
      data: null == data
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as AudioData,
      entryText: freezed == entryText
          ? _value.entryText
          : entryText // ignore: cast_nullable_to_non_nullable
              as EntryText?,
      geolocation: freezed == geolocation
          ? _value.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }

  @override
  @pragma('vm:prefer-inline')
  $AudioDataCopyWith<$Res> get data {
    return $AudioDataCopyWith<$Res>(_value.data, (value) {
      return _then(_value.copyWith(data: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _$JournalAudio implements JournalAudio {
  const _$JournalAudio(
      {required this.meta,
      required this.data,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'journalAudio';

  factory _$JournalAudio.fromJson(Map<String, dynamic> json) =>
      _$$JournalAudioFromJson(json);

  @override
  final Metadata meta;
  @override
  final AudioData data;
  @override
  final EntryText? entryText;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'JournalEntity.journalAudio(meta: $meta, data: $data, entryText: $entryText, geolocation: $geolocation)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$JournalAudio &&
            (identical(other.meta, meta) || other.meta == meta) &&
            (identical(other.data, data) || other.data == data) &&
            (identical(other.entryText, entryText) ||
                other.entryText == entryText) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, meta, data, entryText, geolocation);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$JournalAudioCopyWith<_$JournalAudio> get copyWith =>
      __$$JournalAudioCopyWithImpl<_$JournalAudio>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(Metadata meta, EntryText? entryText, Geolocation? geolocation)
        journalEntry,
    required TResult Function(Metadata meta, ImageData data,
            EntryText? entryText, Geolocation? geolocation)
        journalImage,
    required TResult Function(Metadata meta, AudioData data,
            EntryText? entryText, Geolocation? geolocation)
        journalAudio,
    required TResult Function(Metadata meta, TaskData data,
            EntryText? entryText, Geolocation? geolocation)
        task,
    required TResult Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)
        quantitative,
    required TResult Function(Metadata meta, MeasurementData data,
            EntryText? entryText, Geolocation? geolocation)
        measurement,
    required TResult Function(
            Metadata meta, WorkoutData data, EntryText? entryText, Geolocation? geolocation)
        workout,
    required TResult Function(Metadata meta, HabitCompletionData data, EntryText? entryText, Geolocation? geolocation) habitCompletion,
    required TResult Function(Metadata meta, SurveyData data, EntryText? entryText, Geolocation? geolocation) survey,
  }) {
    return journalAudio(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(Metadata meta, EntryText? entryText, Geolocation? geolocation)?
        journalEntry,
    TResult? Function(Metadata meta, ImageData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalImage,
    TResult? Function(Metadata meta, AudioData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalAudio,
    TResult? Function(Metadata meta, TaskData data, EntryText? entryText,
            Geolocation? geolocation)?
        task,
    TResult? Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)?
        quantitative,
    TResult? Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult? Function(
            Metadata meta, WorkoutData data, EntryText? entryText, Geolocation? geolocation)?
        workout,
    TResult? Function(Metadata meta, HabitCompletionData data, EntryText? entryText, Geolocation? geolocation)? habitCompletion,
    TResult? Function(Metadata meta, SurveyData data, EntryText? entryText, Geolocation? geolocation)? survey,
  }) {
    return journalAudio?.call(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(Metadata meta, EntryText? entryText, Geolocation? geolocation)?
        journalEntry,
    TResult Function(Metadata meta, ImageData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalImage,
    TResult Function(Metadata meta, AudioData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalAudio,
    TResult Function(Metadata meta, TaskData data, EntryText? entryText,
            Geolocation? geolocation)?
        task,
    TResult Function(Metadata meta, QuantitativeData data, EntryText? entryText,
            Geolocation? geolocation)?
        quantitative,
    TResult Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult Function(
            Metadata meta, WorkoutData data, EntryText? entryText, Geolocation? geolocation)?
        workout,
    TResult Function(Metadata meta, HabitCompletionData data, EntryText? entryText, Geolocation? geolocation)? habitCompletion,
    TResult Function(Metadata meta, SurveyData data, EntryText? entryText, Geolocation? geolocation)? survey,
    required TResult orElse(),
  }) {
    if (journalAudio != null) {
      return journalAudio(meta, data, entryText, geolocation);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(JournalEntry value) journalEntry,
    required TResult Function(JournalImage value) journalImage,
    required TResult Function(JournalAudio value) journalAudio,
    required TResult Function(Task value) task,
    required TResult Function(QuantitativeEntry value) quantitative,
    required TResult Function(MeasurementEntry value) measurement,
    required TResult Function(WorkoutEntry value) workout,
    required TResult Function(HabitCompletionEntry value) habitCompletion,
    required TResult Function(SurveyEntry value) survey,
  }) {
    return journalAudio(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(JournalEntry value)? journalEntry,
    TResult? Function(JournalImage value)? journalImage,
    TResult? Function(JournalAudio value)? journalAudio,
    TResult? Function(Task value)? task,
    TResult? Function(QuantitativeEntry value)? quantitative,
    TResult? Function(MeasurementEntry value)? measurement,
    TResult? Function(WorkoutEntry value)? workout,
    TResult? Function(HabitCompletionEntry value)? habitCompletion,
    TResult? Function(SurveyEntry value)? survey,
  }) {
    return journalAudio?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(JournalEntry value)? journalEntry,
    TResult Function(JournalImage value)? journalImage,
    TResult Function(JournalAudio value)? journalAudio,
    TResult Function(Task value)? task,
    TResult Function(QuantitativeEntry value)? quantitative,
    TResult Function(MeasurementEntry value)? measurement,
    TResult Function(WorkoutEntry value)? workout,
    TResult Function(HabitCompletionEntry value)? habitCompletion,
    TResult Function(SurveyEntry value)? survey,
    required TResult orElse(),
  }) {
    if (journalAudio != null) {
      return journalAudio(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$JournalAudioToJson(
      this,
    );
  }
}

abstract class JournalAudio implements JournalEntity {
  const factory JournalAudio(
      {required final Metadata meta,
      required final AudioData data,
      final EntryText? entryText,
      final Geolocation? geolocation}) = _$JournalAudio;

  factory JournalAudio.fromJson(Map<String, dynamic> json) =
      _$JournalAudio.fromJson;

  @override
  Metadata get meta;
  AudioData get data;
  @override
  EntryText? get entryText;
  @override
  Geolocation? get geolocation;
  @override
  @JsonKey(ignore: true)
  _$$JournalAudioCopyWith<_$JournalAudio> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$TaskCopyWith<$Res> implements $JournalEntityCopyWith<$Res> {
  factory _$$TaskCopyWith(_$Task value, $Res Function(_$Task) then) =
      __$$TaskCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {Metadata meta,
      TaskData data,
      EntryText? entryText,
      Geolocation? geolocation});

  @override
  $MetadataCopyWith<$Res> get meta;
  $TaskDataCopyWith<$Res> get data;
  @override
  $EntryTextCopyWith<$Res>? get entryText;
  @override
  $GeolocationCopyWith<$Res>? get geolocation;
}

/// @nodoc
class __$$TaskCopyWithImpl<$Res>
    extends _$JournalEntityCopyWithImpl<$Res, _$Task>
    implements _$$TaskCopyWith<$Res> {
  __$$TaskCopyWithImpl(_$Task _value, $Res Function(_$Task) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = null,
    Object? data = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$Task(
      meta: null == meta
          ? _value.meta
          : meta // ignore: cast_nullable_to_non_nullable
              as Metadata,
      data: null == data
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as TaskData,
      entryText: freezed == entryText
          ? _value.entryText
          : entryText // ignore: cast_nullable_to_non_nullable
              as EntryText?,
      geolocation: freezed == geolocation
          ? _value.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }

  @override
  @pragma('vm:prefer-inline')
  $TaskDataCopyWith<$Res> get data {
    return $TaskDataCopyWith<$Res>(_value.data, (value) {
      return _then(_value.copyWith(data: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _$Task implements Task {
  const _$Task(
      {required this.meta,
      required this.data,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'task';

  factory _$Task.fromJson(Map<String, dynamic> json) => _$$TaskFromJson(json);

  @override
  final Metadata meta;
  @override
  final TaskData data;
  @override
  final EntryText? entryText;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'JournalEntity.task(meta: $meta, data: $data, entryText: $entryText, geolocation: $geolocation)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$Task &&
            (identical(other.meta, meta) || other.meta == meta) &&
            (identical(other.data, data) || other.data == data) &&
            (identical(other.entryText, entryText) ||
                other.entryText == entryText) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, meta, data, entryText, geolocation);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskCopyWith<_$Task> get copyWith =>
      __$$TaskCopyWithImpl<_$Task>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(Metadata meta, EntryText? entryText, Geolocation? geolocation)
        journalEntry,
    required TResult Function(Metadata meta, ImageData data,
            EntryText? entryText, Geolocation? geolocation)
        journalImage,
    required TResult Function(Metadata meta, AudioData data,
            EntryText? entryText, Geolocation? geolocation)
        journalAudio,
    required TResult Function(Metadata meta, TaskData data,
            EntryText? entryText, Geolocation? geolocation)
        task,
    required TResult Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)
        quantitative,
    required TResult Function(Metadata meta, MeasurementData data,
            EntryText? entryText, Geolocation? geolocation)
        measurement,
    required TResult Function(
            Metadata meta, WorkoutData data, EntryText? entryText, Geolocation? geolocation)
        workout,
    required TResult Function(Metadata meta, HabitCompletionData data, EntryText? entryText, Geolocation? geolocation) habitCompletion,
    required TResult Function(Metadata meta, SurveyData data, EntryText? entryText, Geolocation? geolocation) survey,
  }) {
    return task(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(Metadata meta, EntryText? entryText, Geolocation? geolocation)?
        journalEntry,
    TResult? Function(Metadata meta, ImageData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalImage,
    TResult? Function(Metadata meta, AudioData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalAudio,
    TResult? Function(Metadata meta, TaskData data, EntryText? entryText,
            Geolocation? geolocation)?
        task,
    TResult? Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)?
        quantitative,
    TResult? Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult? Function(
            Metadata meta, WorkoutData data, EntryText? entryText, Geolocation? geolocation)?
        workout,
    TResult? Function(Metadata meta, HabitCompletionData data, EntryText? entryText, Geolocation? geolocation)? habitCompletion,
    TResult? Function(Metadata meta, SurveyData data, EntryText? entryText, Geolocation? geolocation)? survey,
  }) {
    return task?.call(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(Metadata meta, EntryText? entryText, Geolocation? geolocation)?
        journalEntry,
    TResult Function(Metadata meta, ImageData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalImage,
    TResult Function(Metadata meta, AudioData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalAudio,
    TResult Function(Metadata meta, TaskData data, EntryText? entryText,
            Geolocation? geolocation)?
        task,
    TResult Function(Metadata meta, QuantitativeData data, EntryText? entryText,
            Geolocation? geolocation)?
        quantitative,
    TResult Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult Function(
            Metadata meta, WorkoutData data, EntryText? entryText, Geolocation? geolocation)?
        workout,
    TResult Function(Metadata meta, HabitCompletionData data, EntryText? entryText, Geolocation? geolocation)? habitCompletion,
    TResult Function(Metadata meta, SurveyData data, EntryText? entryText, Geolocation? geolocation)? survey,
    required TResult orElse(),
  }) {
    if (task != null) {
      return task(meta, data, entryText, geolocation);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(JournalEntry value) journalEntry,
    required TResult Function(JournalImage value) journalImage,
    required TResult Function(JournalAudio value) journalAudio,
    required TResult Function(Task value) task,
    required TResult Function(QuantitativeEntry value) quantitative,
    required TResult Function(MeasurementEntry value) measurement,
    required TResult Function(WorkoutEntry value) workout,
    required TResult Function(HabitCompletionEntry value) habitCompletion,
    required TResult Function(SurveyEntry value) survey,
  }) {
    return task(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(JournalEntry value)? journalEntry,
    TResult? Function(JournalImage value)? journalImage,
    TResult? Function(JournalAudio value)? journalAudio,
    TResult? Function(Task value)? task,
    TResult? Function(QuantitativeEntry value)? quantitative,
    TResult? Function(MeasurementEntry value)? measurement,
    TResult? Function(WorkoutEntry value)? workout,
    TResult? Function(HabitCompletionEntry value)? habitCompletion,
    TResult? Function(SurveyEntry value)? survey,
  }) {
    return task?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(JournalEntry value)? journalEntry,
    TResult Function(JournalImage value)? journalImage,
    TResult Function(JournalAudio value)? journalAudio,
    TResult Function(Task value)? task,
    TResult Function(QuantitativeEntry value)? quantitative,
    TResult Function(MeasurementEntry value)? measurement,
    TResult Function(WorkoutEntry value)? workout,
    TResult Function(HabitCompletionEntry value)? habitCompletion,
    TResult Function(SurveyEntry value)? survey,
    required TResult orElse(),
  }) {
    if (task != null) {
      return task(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$TaskToJson(
      this,
    );
  }
}

abstract class Task implements JournalEntity {
  const factory Task(
      {required final Metadata meta,
      required final TaskData data,
      final EntryText? entryText,
      final Geolocation? geolocation}) = _$Task;

  factory Task.fromJson(Map<String, dynamic> json) = _$Task.fromJson;

  @override
  Metadata get meta;
  TaskData get data;
  @override
  EntryText? get entryText;
  @override
  Geolocation? get geolocation;
  @override
  @JsonKey(ignore: true)
  _$$TaskCopyWith<_$Task> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$QuantitativeEntryCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory _$$QuantitativeEntryCopyWith(
          _$QuantitativeEntry value, $Res Function(_$QuantitativeEntry) then) =
      __$$QuantitativeEntryCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {Metadata meta,
      QuantitativeData data,
      EntryText? entryText,
      Geolocation? geolocation});

  @override
  $MetadataCopyWith<$Res> get meta;
  $QuantitativeDataCopyWith<$Res> get data;
  @override
  $EntryTextCopyWith<$Res>? get entryText;
  @override
  $GeolocationCopyWith<$Res>? get geolocation;
}

/// @nodoc
class __$$QuantitativeEntryCopyWithImpl<$Res>
    extends _$JournalEntityCopyWithImpl<$Res, _$QuantitativeEntry>
    implements _$$QuantitativeEntryCopyWith<$Res> {
  __$$QuantitativeEntryCopyWithImpl(
      _$QuantitativeEntry _value, $Res Function(_$QuantitativeEntry) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = null,
    Object? data = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$QuantitativeEntry(
      meta: null == meta
          ? _value.meta
          : meta // ignore: cast_nullable_to_non_nullable
              as Metadata,
      data: null == data
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as QuantitativeData,
      entryText: freezed == entryText
          ? _value.entryText
          : entryText // ignore: cast_nullable_to_non_nullable
              as EntryText?,
      geolocation: freezed == geolocation
          ? _value.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }

  @override
  @pragma('vm:prefer-inline')
  $QuantitativeDataCopyWith<$Res> get data {
    return $QuantitativeDataCopyWith<$Res>(_value.data, (value) {
      return _then(_value.copyWith(data: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _$QuantitativeEntry implements QuantitativeEntry {
  const _$QuantitativeEntry(
      {required this.meta,
      required this.data,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'quantitative';

  factory _$QuantitativeEntry.fromJson(Map<String, dynamic> json) =>
      _$$QuantitativeEntryFromJson(json);

  @override
  final Metadata meta;
  @override
  final QuantitativeData data;
  @override
  final EntryText? entryText;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'JournalEntity.quantitative(meta: $meta, data: $data, entryText: $entryText, geolocation: $geolocation)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$QuantitativeEntry &&
            (identical(other.meta, meta) || other.meta == meta) &&
            (identical(other.data, data) || other.data == data) &&
            (identical(other.entryText, entryText) ||
                other.entryText == entryText) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, meta, data, entryText, geolocation);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$QuantitativeEntryCopyWith<_$QuantitativeEntry> get copyWith =>
      __$$QuantitativeEntryCopyWithImpl<_$QuantitativeEntry>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(Metadata meta, EntryText? entryText, Geolocation? geolocation)
        journalEntry,
    required TResult Function(Metadata meta, ImageData data,
            EntryText? entryText, Geolocation? geolocation)
        journalImage,
    required TResult Function(Metadata meta, AudioData data,
            EntryText? entryText, Geolocation? geolocation)
        journalAudio,
    required TResult Function(Metadata meta, TaskData data,
            EntryText? entryText, Geolocation? geolocation)
        task,
    required TResult Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)
        quantitative,
    required TResult Function(Metadata meta, MeasurementData data,
            EntryText? entryText, Geolocation? geolocation)
        measurement,
    required TResult Function(
            Metadata meta, WorkoutData data, EntryText? entryText, Geolocation? geolocation)
        workout,
    required TResult Function(Metadata meta, HabitCompletionData data, EntryText? entryText, Geolocation? geolocation) habitCompletion,
    required TResult Function(Metadata meta, SurveyData data, EntryText? entryText, Geolocation? geolocation) survey,
  }) {
    return quantitative(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(Metadata meta, EntryText? entryText, Geolocation? geolocation)?
        journalEntry,
    TResult? Function(Metadata meta, ImageData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalImage,
    TResult? Function(Metadata meta, AudioData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalAudio,
    TResult? Function(Metadata meta, TaskData data, EntryText? entryText,
            Geolocation? geolocation)?
        task,
    TResult? Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)?
        quantitative,
    TResult? Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult? Function(
            Metadata meta, WorkoutData data, EntryText? entryText, Geolocation? geolocation)?
        workout,
    TResult? Function(Metadata meta, HabitCompletionData data, EntryText? entryText, Geolocation? geolocation)? habitCompletion,
    TResult? Function(Metadata meta, SurveyData data, EntryText? entryText, Geolocation? geolocation)? survey,
  }) {
    return quantitative?.call(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(Metadata meta, EntryText? entryText, Geolocation? geolocation)?
        journalEntry,
    TResult Function(Metadata meta, ImageData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalImage,
    TResult Function(Metadata meta, AudioData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalAudio,
    TResult Function(Metadata meta, TaskData data, EntryText? entryText,
            Geolocation? geolocation)?
        task,
    TResult Function(Metadata meta, QuantitativeData data, EntryText? entryText,
            Geolocation? geolocation)?
        quantitative,
    TResult Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult Function(
            Metadata meta, WorkoutData data, EntryText? entryText, Geolocation? geolocation)?
        workout,
    TResult Function(Metadata meta, HabitCompletionData data, EntryText? entryText, Geolocation? geolocation)? habitCompletion,
    TResult Function(Metadata meta, SurveyData data, EntryText? entryText, Geolocation? geolocation)? survey,
    required TResult orElse(),
  }) {
    if (quantitative != null) {
      return quantitative(meta, data, entryText, geolocation);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(JournalEntry value) journalEntry,
    required TResult Function(JournalImage value) journalImage,
    required TResult Function(JournalAudio value) journalAudio,
    required TResult Function(Task value) task,
    required TResult Function(QuantitativeEntry value) quantitative,
    required TResult Function(MeasurementEntry value) measurement,
    required TResult Function(WorkoutEntry value) workout,
    required TResult Function(HabitCompletionEntry value) habitCompletion,
    required TResult Function(SurveyEntry value) survey,
  }) {
    return quantitative(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(JournalEntry value)? journalEntry,
    TResult? Function(JournalImage value)? journalImage,
    TResult? Function(JournalAudio value)? journalAudio,
    TResult? Function(Task value)? task,
    TResult? Function(QuantitativeEntry value)? quantitative,
    TResult? Function(MeasurementEntry value)? measurement,
    TResult? Function(WorkoutEntry value)? workout,
    TResult? Function(HabitCompletionEntry value)? habitCompletion,
    TResult? Function(SurveyEntry value)? survey,
  }) {
    return quantitative?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(JournalEntry value)? journalEntry,
    TResult Function(JournalImage value)? journalImage,
    TResult Function(JournalAudio value)? journalAudio,
    TResult Function(Task value)? task,
    TResult Function(QuantitativeEntry value)? quantitative,
    TResult Function(MeasurementEntry value)? measurement,
    TResult Function(WorkoutEntry value)? workout,
    TResult Function(HabitCompletionEntry value)? habitCompletion,
    TResult Function(SurveyEntry value)? survey,
    required TResult orElse(),
  }) {
    if (quantitative != null) {
      return quantitative(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$QuantitativeEntryToJson(
      this,
    );
  }
}

abstract class QuantitativeEntry implements JournalEntity {
  const factory QuantitativeEntry(
      {required final Metadata meta,
      required final QuantitativeData data,
      final EntryText? entryText,
      final Geolocation? geolocation}) = _$QuantitativeEntry;

  factory QuantitativeEntry.fromJson(Map<String, dynamic> json) =
      _$QuantitativeEntry.fromJson;

  @override
  Metadata get meta;
  QuantitativeData get data;
  @override
  EntryText? get entryText;
  @override
  Geolocation? get geolocation;
  @override
  @JsonKey(ignore: true)
  _$$QuantitativeEntryCopyWith<_$QuantitativeEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$MeasurementEntryCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory _$$MeasurementEntryCopyWith(
          _$MeasurementEntry value, $Res Function(_$MeasurementEntry) then) =
      __$$MeasurementEntryCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {Metadata meta,
      MeasurementData data,
      EntryText? entryText,
      Geolocation? geolocation});

  @override
  $MetadataCopyWith<$Res> get meta;
  $MeasurementDataCopyWith<$Res> get data;
  @override
  $EntryTextCopyWith<$Res>? get entryText;
  @override
  $GeolocationCopyWith<$Res>? get geolocation;
}

/// @nodoc
class __$$MeasurementEntryCopyWithImpl<$Res>
    extends _$JournalEntityCopyWithImpl<$Res, _$MeasurementEntry>
    implements _$$MeasurementEntryCopyWith<$Res> {
  __$$MeasurementEntryCopyWithImpl(
      _$MeasurementEntry _value, $Res Function(_$MeasurementEntry) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = null,
    Object? data = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$MeasurementEntry(
      meta: null == meta
          ? _value.meta
          : meta // ignore: cast_nullable_to_non_nullable
              as Metadata,
      data: null == data
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as MeasurementData,
      entryText: freezed == entryText
          ? _value.entryText
          : entryText // ignore: cast_nullable_to_non_nullable
              as EntryText?,
      geolocation: freezed == geolocation
          ? _value.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }

  @override
  @pragma('vm:prefer-inline')
  $MeasurementDataCopyWith<$Res> get data {
    return $MeasurementDataCopyWith<$Res>(_value.data, (value) {
      return _then(_value.copyWith(data: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _$MeasurementEntry implements MeasurementEntry {
  const _$MeasurementEntry(
      {required this.meta,
      required this.data,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'measurement';

  factory _$MeasurementEntry.fromJson(Map<String, dynamic> json) =>
      _$$MeasurementEntryFromJson(json);

  @override
  final Metadata meta;
  @override
  final MeasurementData data;
  @override
  final EntryText? entryText;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'JournalEntity.measurement(meta: $meta, data: $data, entryText: $entryText, geolocation: $geolocation)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MeasurementEntry &&
            (identical(other.meta, meta) || other.meta == meta) &&
            (identical(other.data, data) || other.data == data) &&
            (identical(other.entryText, entryText) ||
                other.entryText == entryText) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, meta, data, entryText, geolocation);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MeasurementEntryCopyWith<_$MeasurementEntry> get copyWith =>
      __$$MeasurementEntryCopyWithImpl<_$MeasurementEntry>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(Metadata meta, EntryText? entryText, Geolocation? geolocation)
        journalEntry,
    required TResult Function(Metadata meta, ImageData data,
            EntryText? entryText, Geolocation? geolocation)
        journalImage,
    required TResult Function(Metadata meta, AudioData data,
            EntryText? entryText, Geolocation? geolocation)
        journalAudio,
    required TResult Function(Metadata meta, TaskData data,
            EntryText? entryText, Geolocation? geolocation)
        task,
    required TResult Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)
        quantitative,
    required TResult Function(Metadata meta, MeasurementData data,
            EntryText? entryText, Geolocation? geolocation)
        measurement,
    required TResult Function(
            Metadata meta, WorkoutData data, EntryText? entryText, Geolocation? geolocation)
        workout,
    required TResult Function(Metadata meta, HabitCompletionData data, EntryText? entryText, Geolocation? geolocation) habitCompletion,
    required TResult Function(Metadata meta, SurveyData data, EntryText? entryText, Geolocation? geolocation) survey,
  }) {
    return measurement(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(Metadata meta, EntryText? entryText, Geolocation? geolocation)?
        journalEntry,
    TResult? Function(Metadata meta, ImageData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalImage,
    TResult? Function(Metadata meta, AudioData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalAudio,
    TResult? Function(Metadata meta, TaskData data, EntryText? entryText,
            Geolocation? geolocation)?
        task,
    TResult? Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)?
        quantitative,
    TResult? Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult? Function(
            Metadata meta, WorkoutData data, EntryText? entryText, Geolocation? geolocation)?
        workout,
    TResult? Function(Metadata meta, HabitCompletionData data, EntryText? entryText, Geolocation? geolocation)? habitCompletion,
    TResult? Function(Metadata meta, SurveyData data, EntryText? entryText, Geolocation? geolocation)? survey,
  }) {
    return measurement?.call(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(Metadata meta, EntryText? entryText, Geolocation? geolocation)?
        journalEntry,
    TResult Function(Metadata meta, ImageData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalImage,
    TResult Function(Metadata meta, AudioData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalAudio,
    TResult Function(Metadata meta, TaskData data, EntryText? entryText,
            Geolocation? geolocation)?
        task,
    TResult Function(Metadata meta, QuantitativeData data, EntryText? entryText,
            Geolocation? geolocation)?
        quantitative,
    TResult Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult Function(
            Metadata meta, WorkoutData data, EntryText? entryText, Geolocation? geolocation)?
        workout,
    TResult Function(Metadata meta, HabitCompletionData data, EntryText? entryText, Geolocation? geolocation)? habitCompletion,
    TResult Function(Metadata meta, SurveyData data, EntryText? entryText, Geolocation? geolocation)? survey,
    required TResult orElse(),
  }) {
    if (measurement != null) {
      return measurement(meta, data, entryText, geolocation);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(JournalEntry value) journalEntry,
    required TResult Function(JournalImage value) journalImage,
    required TResult Function(JournalAudio value) journalAudio,
    required TResult Function(Task value) task,
    required TResult Function(QuantitativeEntry value) quantitative,
    required TResult Function(MeasurementEntry value) measurement,
    required TResult Function(WorkoutEntry value) workout,
    required TResult Function(HabitCompletionEntry value) habitCompletion,
    required TResult Function(SurveyEntry value) survey,
  }) {
    return measurement(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(JournalEntry value)? journalEntry,
    TResult? Function(JournalImage value)? journalImage,
    TResult? Function(JournalAudio value)? journalAudio,
    TResult? Function(Task value)? task,
    TResult? Function(QuantitativeEntry value)? quantitative,
    TResult? Function(MeasurementEntry value)? measurement,
    TResult? Function(WorkoutEntry value)? workout,
    TResult? Function(HabitCompletionEntry value)? habitCompletion,
    TResult? Function(SurveyEntry value)? survey,
  }) {
    return measurement?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(JournalEntry value)? journalEntry,
    TResult Function(JournalImage value)? journalImage,
    TResult Function(JournalAudio value)? journalAudio,
    TResult Function(Task value)? task,
    TResult Function(QuantitativeEntry value)? quantitative,
    TResult Function(MeasurementEntry value)? measurement,
    TResult Function(WorkoutEntry value)? workout,
    TResult Function(HabitCompletionEntry value)? habitCompletion,
    TResult Function(SurveyEntry value)? survey,
    required TResult orElse(),
  }) {
    if (measurement != null) {
      return measurement(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$MeasurementEntryToJson(
      this,
    );
  }
}

abstract class MeasurementEntry implements JournalEntity {
  const factory MeasurementEntry(
      {required final Metadata meta,
      required final MeasurementData data,
      final EntryText? entryText,
      final Geolocation? geolocation}) = _$MeasurementEntry;

  factory MeasurementEntry.fromJson(Map<String, dynamic> json) =
      _$MeasurementEntry.fromJson;

  @override
  Metadata get meta;
  MeasurementData get data;
  @override
  EntryText? get entryText;
  @override
  Geolocation? get geolocation;
  @override
  @JsonKey(ignore: true)
  _$$MeasurementEntryCopyWith<_$MeasurementEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$WorkoutEntryCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory _$$WorkoutEntryCopyWith(
          _$WorkoutEntry value, $Res Function(_$WorkoutEntry) then) =
      __$$WorkoutEntryCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {Metadata meta,
      WorkoutData data,
      EntryText? entryText,
      Geolocation? geolocation});

  @override
  $MetadataCopyWith<$Res> get meta;
  $WorkoutDataCopyWith<$Res> get data;
  @override
  $EntryTextCopyWith<$Res>? get entryText;
  @override
  $GeolocationCopyWith<$Res>? get geolocation;
}

/// @nodoc
class __$$WorkoutEntryCopyWithImpl<$Res>
    extends _$JournalEntityCopyWithImpl<$Res, _$WorkoutEntry>
    implements _$$WorkoutEntryCopyWith<$Res> {
  __$$WorkoutEntryCopyWithImpl(
      _$WorkoutEntry _value, $Res Function(_$WorkoutEntry) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = null,
    Object? data = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$WorkoutEntry(
      meta: null == meta
          ? _value.meta
          : meta // ignore: cast_nullable_to_non_nullable
              as Metadata,
      data: null == data
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as WorkoutData,
      entryText: freezed == entryText
          ? _value.entryText
          : entryText // ignore: cast_nullable_to_non_nullable
              as EntryText?,
      geolocation: freezed == geolocation
          ? _value.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }

  @override
  @pragma('vm:prefer-inline')
  $WorkoutDataCopyWith<$Res> get data {
    return $WorkoutDataCopyWith<$Res>(_value.data, (value) {
      return _then(_value.copyWith(data: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _$WorkoutEntry implements WorkoutEntry {
  const _$WorkoutEntry(
      {required this.meta,
      required this.data,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'workout';

  factory _$WorkoutEntry.fromJson(Map<String, dynamic> json) =>
      _$$WorkoutEntryFromJson(json);

  @override
  final Metadata meta;
  @override
  final WorkoutData data;
  @override
  final EntryText? entryText;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'JournalEntity.workout(meta: $meta, data: $data, entryText: $entryText, geolocation: $geolocation)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WorkoutEntry &&
            (identical(other.meta, meta) || other.meta == meta) &&
            (identical(other.data, data) || other.data == data) &&
            (identical(other.entryText, entryText) ||
                other.entryText == entryText) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, meta, data, entryText, geolocation);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$WorkoutEntryCopyWith<_$WorkoutEntry> get copyWith =>
      __$$WorkoutEntryCopyWithImpl<_$WorkoutEntry>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(Metadata meta, EntryText? entryText, Geolocation? geolocation)
        journalEntry,
    required TResult Function(Metadata meta, ImageData data,
            EntryText? entryText, Geolocation? geolocation)
        journalImage,
    required TResult Function(Metadata meta, AudioData data,
            EntryText? entryText, Geolocation? geolocation)
        journalAudio,
    required TResult Function(Metadata meta, TaskData data,
            EntryText? entryText, Geolocation? geolocation)
        task,
    required TResult Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)
        quantitative,
    required TResult Function(Metadata meta, MeasurementData data,
            EntryText? entryText, Geolocation? geolocation)
        measurement,
    required TResult Function(
            Metadata meta, WorkoutData data, EntryText? entryText, Geolocation? geolocation)
        workout,
    required TResult Function(Metadata meta, HabitCompletionData data, EntryText? entryText, Geolocation? geolocation) habitCompletion,
    required TResult Function(Metadata meta, SurveyData data, EntryText? entryText, Geolocation? geolocation) survey,
  }) {
    return workout(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(Metadata meta, EntryText? entryText, Geolocation? geolocation)?
        journalEntry,
    TResult? Function(Metadata meta, ImageData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalImage,
    TResult? Function(Metadata meta, AudioData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalAudio,
    TResult? Function(Metadata meta, TaskData data, EntryText? entryText,
            Geolocation? geolocation)?
        task,
    TResult? Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)?
        quantitative,
    TResult? Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult? Function(
            Metadata meta, WorkoutData data, EntryText? entryText, Geolocation? geolocation)?
        workout,
    TResult? Function(Metadata meta, HabitCompletionData data, EntryText? entryText, Geolocation? geolocation)? habitCompletion,
    TResult? Function(Metadata meta, SurveyData data, EntryText? entryText, Geolocation? geolocation)? survey,
  }) {
    return workout?.call(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(Metadata meta, EntryText? entryText, Geolocation? geolocation)?
        journalEntry,
    TResult Function(Metadata meta, ImageData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalImage,
    TResult Function(Metadata meta, AudioData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalAudio,
    TResult Function(Metadata meta, TaskData data, EntryText? entryText,
            Geolocation? geolocation)?
        task,
    TResult Function(Metadata meta, QuantitativeData data, EntryText? entryText,
            Geolocation? geolocation)?
        quantitative,
    TResult Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult Function(
            Metadata meta, WorkoutData data, EntryText? entryText, Geolocation? geolocation)?
        workout,
    TResult Function(Metadata meta, HabitCompletionData data, EntryText? entryText, Geolocation? geolocation)? habitCompletion,
    TResult Function(Metadata meta, SurveyData data, EntryText? entryText, Geolocation? geolocation)? survey,
    required TResult orElse(),
  }) {
    if (workout != null) {
      return workout(meta, data, entryText, geolocation);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(JournalEntry value) journalEntry,
    required TResult Function(JournalImage value) journalImage,
    required TResult Function(JournalAudio value) journalAudio,
    required TResult Function(Task value) task,
    required TResult Function(QuantitativeEntry value) quantitative,
    required TResult Function(MeasurementEntry value) measurement,
    required TResult Function(WorkoutEntry value) workout,
    required TResult Function(HabitCompletionEntry value) habitCompletion,
    required TResult Function(SurveyEntry value) survey,
  }) {
    return workout(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(JournalEntry value)? journalEntry,
    TResult? Function(JournalImage value)? journalImage,
    TResult? Function(JournalAudio value)? journalAudio,
    TResult? Function(Task value)? task,
    TResult? Function(QuantitativeEntry value)? quantitative,
    TResult? Function(MeasurementEntry value)? measurement,
    TResult? Function(WorkoutEntry value)? workout,
    TResult? Function(HabitCompletionEntry value)? habitCompletion,
    TResult? Function(SurveyEntry value)? survey,
  }) {
    return workout?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(JournalEntry value)? journalEntry,
    TResult Function(JournalImage value)? journalImage,
    TResult Function(JournalAudio value)? journalAudio,
    TResult Function(Task value)? task,
    TResult Function(QuantitativeEntry value)? quantitative,
    TResult Function(MeasurementEntry value)? measurement,
    TResult Function(WorkoutEntry value)? workout,
    TResult Function(HabitCompletionEntry value)? habitCompletion,
    TResult Function(SurveyEntry value)? survey,
    required TResult orElse(),
  }) {
    if (workout != null) {
      return workout(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$WorkoutEntryToJson(
      this,
    );
  }
}

abstract class WorkoutEntry implements JournalEntity {
  const factory WorkoutEntry(
      {required final Metadata meta,
      required final WorkoutData data,
      final EntryText? entryText,
      final Geolocation? geolocation}) = _$WorkoutEntry;

  factory WorkoutEntry.fromJson(Map<String, dynamic> json) =
      _$WorkoutEntry.fromJson;

  @override
  Metadata get meta;
  WorkoutData get data;
  @override
  EntryText? get entryText;
  @override
  Geolocation? get geolocation;
  @override
  @JsonKey(ignore: true)
  _$$WorkoutEntryCopyWith<_$WorkoutEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$HabitCompletionEntryCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory _$$HabitCompletionEntryCopyWith(_$HabitCompletionEntry value,
          $Res Function(_$HabitCompletionEntry) then) =
      __$$HabitCompletionEntryCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {Metadata meta,
      HabitCompletionData data,
      EntryText? entryText,
      Geolocation? geolocation});

  @override
  $MetadataCopyWith<$Res> get meta;
  $HabitCompletionDataCopyWith<$Res> get data;
  @override
  $EntryTextCopyWith<$Res>? get entryText;
  @override
  $GeolocationCopyWith<$Res>? get geolocation;
}

/// @nodoc
class __$$HabitCompletionEntryCopyWithImpl<$Res>
    extends _$JournalEntityCopyWithImpl<$Res, _$HabitCompletionEntry>
    implements _$$HabitCompletionEntryCopyWith<$Res> {
  __$$HabitCompletionEntryCopyWithImpl(_$HabitCompletionEntry _value,
      $Res Function(_$HabitCompletionEntry) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = null,
    Object? data = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$HabitCompletionEntry(
      meta: null == meta
          ? _value.meta
          : meta // ignore: cast_nullable_to_non_nullable
              as Metadata,
      data: null == data
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as HabitCompletionData,
      entryText: freezed == entryText
          ? _value.entryText
          : entryText // ignore: cast_nullable_to_non_nullable
              as EntryText?,
      geolocation: freezed == geolocation
          ? _value.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }

  @override
  @pragma('vm:prefer-inline')
  $HabitCompletionDataCopyWith<$Res> get data {
    return $HabitCompletionDataCopyWith<$Res>(_value.data, (value) {
      return _then(_value.copyWith(data: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _$HabitCompletionEntry implements HabitCompletionEntry {
  const _$HabitCompletionEntry(
      {required this.meta,
      required this.data,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'habitCompletion';

  factory _$HabitCompletionEntry.fromJson(Map<String, dynamic> json) =>
      _$$HabitCompletionEntryFromJson(json);

  @override
  final Metadata meta;
  @override
  final HabitCompletionData data;
  @override
  final EntryText? entryText;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'JournalEntity.habitCompletion(meta: $meta, data: $data, entryText: $entryText, geolocation: $geolocation)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HabitCompletionEntry &&
            (identical(other.meta, meta) || other.meta == meta) &&
            (identical(other.data, data) || other.data == data) &&
            (identical(other.entryText, entryText) ||
                other.entryText == entryText) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, meta, data, entryText, geolocation);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$HabitCompletionEntryCopyWith<_$HabitCompletionEntry> get copyWith =>
      __$$HabitCompletionEntryCopyWithImpl<_$HabitCompletionEntry>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(Metadata meta, EntryText? entryText, Geolocation? geolocation)
        journalEntry,
    required TResult Function(Metadata meta, ImageData data,
            EntryText? entryText, Geolocation? geolocation)
        journalImage,
    required TResult Function(Metadata meta, AudioData data,
            EntryText? entryText, Geolocation? geolocation)
        journalAudio,
    required TResult Function(Metadata meta, TaskData data,
            EntryText? entryText, Geolocation? geolocation)
        task,
    required TResult Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)
        quantitative,
    required TResult Function(Metadata meta, MeasurementData data,
            EntryText? entryText, Geolocation? geolocation)
        measurement,
    required TResult Function(
            Metadata meta, WorkoutData data, EntryText? entryText, Geolocation? geolocation)
        workout,
    required TResult Function(Metadata meta, HabitCompletionData data, EntryText? entryText, Geolocation? geolocation) habitCompletion,
    required TResult Function(Metadata meta, SurveyData data, EntryText? entryText, Geolocation? geolocation) survey,
  }) {
    return habitCompletion(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(Metadata meta, EntryText? entryText, Geolocation? geolocation)?
        journalEntry,
    TResult? Function(Metadata meta, ImageData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalImage,
    TResult? Function(Metadata meta, AudioData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalAudio,
    TResult? Function(Metadata meta, TaskData data, EntryText? entryText,
            Geolocation? geolocation)?
        task,
    TResult? Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)?
        quantitative,
    TResult? Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult? Function(
            Metadata meta, WorkoutData data, EntryText? entryText, Geolocation? geolocation)?
        workout,
    TResult? Function(Metadata meta, HabitCompletionData data, EntryText? entryText, Geolocation? geolocation)? habitCompletion,
    TResult? Function(Metadata meta, SurveyData data, EntryText? entryText, Geolocation? geolocation)? survey,
  }) {
    return habitCompletion?.call(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(Metadata meta, EntryText? entryText, Geolocation? geolocation)?
        journalEntry,
    TResult Function(Metadata meta, ImageData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalImage,
    TResult Function(Metadata meta, AudioData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalAudio,
    TResult Function(Metadata meta, TaskData data, EntryText? entryText,
            Geolocation? geolocation)?
        task,
    TResult Function(Metadata meta, QuantitativeData data, EntryText? entryText,
            Geolocation? geolocation)?
        quantitative,
    TResult Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult Function(
            Metadata meta, WorkoutData data, EntryText? entryText, Geolocation? geolocation)?
        workout,
    TResult Function(Metadata meta, HabitCompletionData data, EntryText? entryText, Geolocation? geolocation)? habitCompletion,
    TResult Function(Metadata meta, SurveyData data, EntryText? entryText, Geolocation? geolocation)? survey,
    required TResult orElse(),
  }) {
    if (habitCompletion != null) {
      return habitCompletion(meta, data, entryText, geolocation);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(JournalEntry value) journalEntry,
    required TResult Function(JournalImage value) journalImage,
    required TResult Function(JournalAudio value) journalAudio,
    required TResult Function(Task value) task,
    required TResult Function(QuantitativeEntry value) quantitative,
    required TResult Function(MeasurementEntry value) measurement,
    required TResult Function(WorkoutEntry value) workout,
    required TResult Function(HabitCompletionEntry value) habitCompletion,
    required TResult Function(SurveyEntry value) survey,
  }) {
    return habitCompletion(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(JournalEntry value)? journalEntry,
    TResult? Function(JournalImage value)? journalImage,
    TResult? Function(JournalAudio value)? journalAudio,
    TResult? Function(Task value)? task,
    TResult? Function(QuantitativeEntry value)? quantitative,
    TResult? Function(MeasurementEntry value)? measurement,
    TResult? Function(WorkoutEntry value)? workout,
    TResult? Function(HabitCompletionEntry value)? habitCompletion,
    TResult? Function(SurveyEntry value)? survey,
  }) {
    return habitCompletion?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(JournalEntry value)? journalEntry,
    TResult Function(JournalImage value)? journalImage,
    TResult Function(JournalAudio value)? journalAudio,
    TResult Function(Task value)? task,
    TResult Function(QuantitativeEntry value)? quantitative,
    TResult Function(MeasurementEntry value)? measurement,
    TResult Function(WorkoutEntry value)? workout,
    TResult Function(HabitCompletionEntry value)? habitCompletion,
    TResult Function(SurveyEntry value)? survey,
    required TResult orElse(),
  }) {
    if (habitCompletion != null) {
      return habitCompletion(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$HabitCompletionEntryToJson(
      this,
    );
  }
}

abstract class HabitCompletionEntry implements JournalEntity {
  const factory HabitCompletionEntry(
      {required final Metadata meta,
      required final HabitCompletionData data,
      final EntryText? entryText,
      final Geolocation? geolocation}) = _$HabitCompletionEntry;

  factory HabitCompletionEntry.fromJson(Map<String, dynamic> json) =
      _$HabitCompletionEntry.fromJson;

  @override
  Metadata get meta;
  HabitCompletionData get data;
  @override
  EntryText? get entryText;
  @override
  Geolocation? get geolocation;
  @override
  @JsonKey(ignore: true)
  _$$HabitCompletionEntryCopyWith<_$HabitCompletionEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$SurveyEntryCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory _$$SurveyEntryCopyWith(
          _$SurveyEntry value, $Res Function(_$SurveyEntry) then) =
      __$$SurveyEntryCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {Metadata meta,
      SurveyData data,
      EntryText? entryText,
      Geolocation? geolocation});

  @override
  $MetadataCopyWith<$Res> get meta;
  $SurveyDataCopyWith<$Res> get data;
  @override
  $EntryTextCopyWith<$Res>? get entryText;
  @override
  $GeolocationCopyWith<$Res>? get geolocation;
}

/// @nodoc
class __$$SurveyEntryCopyWithImpl<$Res>
    extends _$JournalEntityCopyWithImpl<$Res, _$SurveyEntry>
    implements _$$SurveyEntryCopyWith<$Res> {
  __$$SurveyEntryCopyWithImpl(
      _$SurveyEntry _value, $Res Function(_$SurveyEntry) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = null,
    Object? data = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$SurveyEntry(
      meta: null == meta
          ? _value.meta
          : meta // ignore: cast_nullable_to_non_nullable
              as Metadata,
      data: null == data
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as SurveyData,
      entryText: freezed == entryText
          ? _value.entryText
          : entryText // ignore: cast_nullable_to_non_nullable
              as EntryText?,
      geolocation: freezed == geolocation
          ? _value.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }

  @override
  @pragma('vm:prefer-inline')
  $SurveyDataCopyWith<$Res> get data {
    return $SurveyDataCopyWith<$Res>(_value.data, (value) {
      return _then(_value.copyWith(data: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _$SurveyEntry implements SurveyEntry {
  const _$SurveyEntry(
      {required this.meta,
      required this.data,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'survey';

  factory _$SurveyEntry.fromJson(Map<String, dynamic> json) =>
      _$$SurveyEntryFromJson(json);

  @override
  final Metadata meta;
  @override
  final SurveyData data;
  @override
  final EntryText? entryText;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'JournalEntity.survey(meta: $meta, data: $data, entryText: $entryText, geolocation: $geolocation)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SurveyEntry &&
            (identical(other.meta, meta) || other.meta == meta) &&
            (identical(other.data, data) || other.data == data) &&
            (identical(other.entryText, entryText) ||
                other.entryText == entryText) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, meta, data, entryText, geolocation);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SurveyEntryCopyWith<_$SurveyEntry> get copyWith =>
      __$$SurveyEntryCopyWithImpl<_$SurveyEntry>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(Metadata meta, EntryText? entryText, Geolocation? geolocation)
        journalEntry,
    required TResult Function(Metadata meta, ImageData data,
            EntryText? entryText, Geolocation? geolocation)
        journalImage,
    required TResult Function(Metadata meta, AudioData data,
            EntryText? entryText, Geolocation? geolocation)
        journalAudio,
    required TResult Function(Metadata meta, TaskData data,
            EntryText? entryText, Geolocation? geolocation)
        task,
    required TResult Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)
        quantitative,
    required TResult Function(Metadata meta, MeasurementData data,
            EntryText? entryText, Geolocation? geolocation)
        measurement,
    required TResult Function(
            Metadata meta, WorkoutData data, EntryText? entryText, Geolocation? geolocation)
        workout,
    required TResult Function(Metadata meta, HabitCompletionData data, EntryText? entryText, Geolocation? geolocation) habitCompletion,
    required TResult Function(Metadata meta, SurveyData data, EntryText? entryText, Geolocation? geolocation) survey,
  }) {
    return survey(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(Metadata meta, EntryText? entryText, Geolocation? geolocation)?
        journalEntry,
    TResult? Function(Metadata meta, ImageData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalImage,
    TResult? Function(Metadata meta, AudioData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalAudio,
    TResult? Function(Metadata meta, TaskData data, EntryText? entryText,
            Geolocation? geolocation)?
        task,
    TResult? Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)?
        quantitative,
    TResult? Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult? Function(
            Metadata meta, WorkoutData data, EntryText? entryText, Geolocation? geolocation)?
        workout,
    TResult? Function(Metadata meta, HabitCompletionData data, EntryText? entryText, Geolocation? geolocation)? habitCompletion,
    TResult? Function(Metadata meta, SurveyData data, EntryText? entryText, Geolocation? geolocation)? survey,
  }) {
    return survey?.call(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(Metadata meta, EntryText? entryText, Geolocation? geolocation)?
        journalEntry,
    TResult Function(Metadata meta, ImageData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalImage,
    TResult Function(Metadata meta, AudioData data, EntryText? entryText,
            Geolocation? geolocation)?
        journalAudio,
    TResult Function(Metadata meta, TaskData data, EntryText? entryText,
            Geolocation? geolocation)?
        task,
    TResult Function(Metadata meta, QuantitativeData data, EntryText? entryText,
            Geolocation? geolocation)?
        quantitative,
    TResult Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult Function(
            Metadata meta, WorkoutData data, EntryText? entryText, Geolocation? geolocation)?
        workout,
    TResult Function(Metadata meta, HabitCompletionData data, EntryText? entryText, Geolocation? geolocation)? habitCompletion,
    TResult Function(Metadata meta, SurveyData data, EntryText? entryText, Geolocation? geolocation)? survey,
    required TResult orElse(),
  }) {
    if (survey != null) {
      return survey(meta, data, entryText, geolocation);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(JournalEntry value) journalEntry,
    required TResult Function(JournalImage value) journalImage,
    required TResult Function(JournalAudio value) journalAudio,
    required TResult Function(Task value) task,
    required TResult Function(QuantitativeEntry value) quantitative,
    required TResult Function(MeasurementEntry value) measurement,
    required TResult Function(WorkoutEntry value) workout,
    required TResult Function(HabitCompletionEntry value) habitCompletion,
    required TResult Function(SurveyEntry value) survey,
  }) {
    return survey(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(JournalEntry value)? journalEntry,
    TResult? Function(JournalImage value)? journalImage,
    TResult? Function(JournalAudio value)? journalAudio,
    TResult? Function(Task value)? task,
    TResult? Function(QuantitativeEntry value)? quantitative,
    TResult? Function(MeasurementEntry value)? measurement,
    TResult? Function(WorkoutEntry value)? workout,
    TResult? Function(HabitCompletionEntry value)? habitCompletion,
    TResult? Function(SurveyEntry value)? survey,
  }) {
    return survey?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(JournalEntry value)? journalEntry,
    TResult Function(JournalImage value)? journalImage,
    TResult Function(JournalAudio value)? journalAudio,
    TResult Function(Task value)? task,
    TResult Function(QuantitativeEntry value)? quantitative,
    TResult Function(MeasurementEntry value)? measurement,
    TResult Function(WorkoutEntry value)? workout,
    TResult Function(HabitCompletionEntry value)? habitCompletion,
    TResult Function(SurveyEntry value)? survey,
    required TResult orElse(),
  }) {
    if (survey != null) {
      return survey(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$SurveyEntryToJson(
      this,
    );
  }
}

abstract class SurveyEntry implements JournalEntity {
  const factory SurveyEntry(
      {required final Metadata meta,
      required final SurveyData data,
      final EntryText? entryText,
      final Geolocation? geolocation}) = _$SurveyEntry;

  factory SurveyEntry.fromJson(Map<String, dynamic> json) =
      _$SurveyEntry.fromJson;

  @override
  Metadata get meta;
  SurveyData get data;
  @override
  EntryText? get entryText;
  @override
  Geolocation? get geolocation;
  @override
  @JsonKey(ignore: true)
  _$$SurveyEntryCopyWith<_$SurveyEntry> get copyWith =>
      throw _privateConstructorUsedError;
}
