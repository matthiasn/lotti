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
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

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
  String? get categoryId => throw _privateConstructorUsedError;
  List<String>? get tags => throw _privateConstructorUsedError;
  List<String>? get tagIds => throw _privateConstructorUsedError;
  int? get utcOffset => throw _privateConstructorUsedError;
  String? get timezone => throw _privateConstructorUsedError;
  VectorClock? get vectorClock => throw _privateConstructorUsedError;
  DateTime? get deletedAt => throw _privateConstructorUsedError;
  EntryFlag? get flag => throw _privateConstructorUsedError;
  bool? get starred => throw _privateConstructorUsedError;
  bool? get private => throw _privateConstructorUsedError;

  /// Serializes this Metadata to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Metadata
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
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
      String? categoryId,
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

  /// Create a copy of Metadata
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? dateFrom = null,
    Object? dateTo = null,
    Object? categoryId = freezed,
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
      categoryId: freezed == categoryId
          ? _value.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String?,
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
abstract class _$$MetadataImplCopyWith<$Res>
    implements $MetadataCopyWith<$Res> {
  factory _$$MetadataImplCopyWith(
          _$MetadataImpl value, $Res Function(_$MetadataImpl) then) =
      __$$MetadataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      DateTime createdAt,
      DateTime updatedAt,
      DateTime dateFrom,
      DateTime dateTo,
      String? categoryId,
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
class __$$MetadataImplCopyWithImpl<$Res>
    extends _$MetadataCopyWithImpl<$Res, _$MetadataImpl>
    implements _$$MetadataImplCopyWith<$Res> {
  __$$MetadataImplCopyWithImpl(
      _$MetadataImpl _value, $Res Function(_$MetadataImpl) _then)
      : super(_value, _then);

  /// Create a copy of Metadata
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? dateFrom = null,
    Object? dateTo = null,
    Object? categoryId = freezed,
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
    return _then(_$MetadataImpl(
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
      categoryId: freezed == categoryId
          ? _value.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String?,
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
class _$MetadataImpl implements _Metadata {
  const _$MetadataImpl(
      {required this.id,
      required this.createdAt,
      required this.updatedAt,
      required this.dateFrom,
      required this.dateTo,
      this.categoryId,
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

  factory _$MetadataImpl.fromJson(Map<String, dynamic> json) =>
      _$$MetadataImplFromJson(json);

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
  @override
  final String? categoryId;
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
    return 'Metadata(id: $id, createdAt: $createdAt, updatedAt: $updatedAt, dateFrom: $dateFrom, dateTo: $dateTo, categoryId: $categoryId, tags: $tags, tagIds: $tagIds, utcOffset: $utcOffset, timezone: $timezone, vectorClock: $vectorClock, deletedAt: $deletedAt, flag: $flag, starred: $starred, private: $private)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MetadataImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.dateFrom, dateFrom) ||
                other.dateFrom == dateFrom) &&
            (identical(other.dateTo, dateTo) || other.dateTo == dateTo) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
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

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      createdAt,
      updatedAt,
      dateFrom,
      dateTo,
      categoryId,
      const DeepCollectionEquality().hash(_tags),
      const DeepCollectionEquality().hash(_tagIds),
      utcOffset,
      timezone,
      vectorClock,
      deletedAt,
      flag,
      starred,
      private);

  /// Create a copy of Metadata
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MetadataImplCopyWith<_$MetadataImpl> get copyWith =>
      __$$MetadataImplCopyWithImpl<_$MetadataImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MetadataImplToJson(
      this,
    );
  }
}

abstract class _Metadata implements Metadata {
  const factory _Metadata(
      {required final String id,
      required final DateTime createdAt,
      required final DateTime updatedAt,
      required final DateTime dateFrom,
      required final DateTime dateTo,
      final String? categoryId,
      final List<String>? tags,
      final List<String>? tagIds,
      final int? utcOffset,
      final String? timezone,
      final VectorClock? vectorClock,
      final DateTime? deletedAt,
      final EntryFlag? flag,
      final bool? starred,
      final bool? private}) = _$MetadataImpl;

  factory _Metadata.fromJson(Map<String, dynamic> json) =
      _$MetadataImpl.fromJson;

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
  String? get categoryId;
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

  /// Create a copy of Metadata
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MetadataImplCopyWith<_$MetadataImpl> get copyWith =>
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

  /// Serializes this ImageData to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ImageData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
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

  /// Create a copy of ImageData
  /// with the given fields replaced by the non-null parameter values.
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

  /// Create a copy of ImageData
  /// with the given fields replaced by the non-null parameter values.
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
abstract class _$$ImageDataImplCopyWith<$Res>
    implements $ImageDataCopyWith<$Res> {
  factory _$$ImageDataImplCopyWith(
          _$ImageDataImpl value, $Res Function(_$ImageDataImpl) then) =
      __$$ImageDataImplCopyWithImpl<$Res>;
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
class __$$ImageDataImplCopyWithImpl<$Res>
    extends _$ImageDataCopyWithImpl<$Res, _$ImageDataImpl>
    implements _$$ImageDataImplCopyWith<$Res> {
  __$$ImageDataImplCopyWithImpl(
      _$ImageDataImpl _value, $Res Function(_$ImageDataImpl) _then)
      : super(_value, _then);

  /// Create a copy of ImageData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? capturedAt = null,
    Object? imageId = null,
    Object? imageFile = null,
    Object? imageDirectory = null,
    Object? geolocation = freezed,
  }) {
    return _then(_$ImageDataImpl(
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
class _$ImageDataImpl implements _ImageData {
  const _$ImageDataImpl(
      {required this.capturedAt,
      required this.imageId,
      required this.imageFile,
      required this.imageDirectory,
      this.geolocation});

  factory _$ImageDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$ImageDataImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ImageDataImpl &&
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

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, capturedAt, imageId, imageFile, imageDirectory, geolocation);

  /// Create a copy of ImageData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ImageDataImplCopyWith<_$ImageDataImpl> get copyWith =>
      __$$ImageDataImplCopyWithImpl<_$ImageDataImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ImageDataImplToJson(
      this,
    );
  }
}

abstract class _ImageData implements ImageData {
  const factory _ImageData(
      {required final DateTime capturedAt,
      required final String imageId,
      required final String imageFile,
      required final String imageDirectory,
      final Geolocation? geolocation}) = _$ImageDataImpl;

  factory _ImageData.fromJson(Map<String, dynamic> json) =
      _$ImageDataImpl.fromJson;

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

  /// Create a copy of ImageData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ImageDataImplCopyWith<_$ImageDataImpl> get copyWith =>
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
  bool get autoTranscribeWasActive => throw _privateConstructorUsedError;
  String? get language => throw _privateConstructorUsedError;
  List<AudioTranscript>? get transcripts => throw _privateConstructorUsedError;

  /// Serializes this AudioData to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AudioData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
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
      bool autoTranscribeWasActive,
      String? language,
      List<AudioTranscript>? transcripts});
}

/// @nodoc
class _$AudioDataCopyWithImpl<$Res, $Val extends AudioData>
    implements $AudioDataCopyWith<$Res> {
  _$AudioDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AudioData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dateFrom = null,
    Object? dateTo = null,
    Object? audioFile = null,
    Object? audioDirectory = null,
    Object? duration = null,
    Object? autoTranscribeWasActive = null,
    Object? language = freezed,
    Object? transcripts = freezed,
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
      autoTranscribeWasActive: null == autoTranscribeWasActive
          ? _value.autoTranscribeWasActive
          : autoTranscribeWasActive // ignore: cast_nullable_to_non_nullable
              as bool,
      language: freezed == language
          ? _value.language
          : language // ignore: cast_nullable_to_non_nullable
              as String?,
      transcripts: freezed == transcripts
          ? _value.transcripts
          : transcripts // ignore: cast_nullable_to_non_nullable
              as List<AudioTranscript>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AudioDataImplCopyWith<$Res>
    implements $AudioDataCopyWith<$Res> {
  factory _$$AudioDataImplCopyWith(
          _$AudioDataImpl value, $Res Function(_$AudioDataImpl) then) =
      __$$AudioDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {DateTime dateFrom,
      DateTime dateTo,
      String audioFile,
      String audioDirectory,
      Duration duration,
      bool autoTranscribeWasActive,
      String? language,
      List<AudioTranscript>? transcripts});
}

/// @nodoc
class __$$AudioDataImplCopyWithImpl<$Res>
    extends _$AudioDataCopyWithImpl<$Res, _$AudioDataImpl>
    implements _$$AudioDataImplCopyWith<$Res> {
  __$$AudioDataImplCopyWithImpl(
      _$AudioDataImpl _value, $Res Function(_$AudioDataImpl) _then)
      : super(_value, _then);

  /// Create a copy of AudioData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dateFrom = null,
    Object? dateTo = null,
    Object? audioFile = null,
    Object? audioDirectory = null,
    Object? duration = null,
    Object? autoTranscribeWasActive = null,
    Object? language = freezed,
    Object? transcripts = freezed,
  }) {
    return _then(_$AudioDataImpl(
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
      autoTranscribeWasActive: null == autoTranscribeWasActive
          ? _value.autoTranscribeWasActive
          : autoTranscribeWasActive // ignore: cast_nullable_to_non_nullable
              as bool,
      language: freezed == language
          ? _value.language
          : language // ignore: cast_nullable_to_non_nullable
              as String?,
      transcripts: freezed == transcripts
          ? _value._transcripts
          : transcripts // ignore: cast_nullable_to_non_nullable
              as List<AudioTranscript>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AudioDataImpl implements _AudioData {
  const _$AudioDataImpl(
      {required this.dateFrom,
      required this.dateTo,
      required this.audioFile,
      required this.audioDirectory,
      required this.duration,
      this.autoTranscribeWasActive = false,
      this.language,
      final List<AudioTranscript>? transcripts})
      : _transcripts = transcripts;

  factory _$AudioDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$AudioDataImplFromJson(json);

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
  @JsonKey()
  final bool autoTranscribeWasActive;
  @override
  final String? language;
  final List<AudioTranscript>? _transcripts;
  @override
  List<AudioTranscript>? get transcripts {
    final value = _transcripts;
    if (value == null) return null;
    if (_transcripts is EqualUnmodifiableListView) return _transcripts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  String toString() {
    return 'AudioData(dateFrom: $dateFrom, dateTo: $dateTo, audioFile: $audioFile, audioDirectory: $audioDirectory, duration: $duration, autoTranscribeWasActive: $autoTranscribeWasActive, language: $language, transcripts: $transcripts)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AudioDataImpl &&
            (identical(other.dateFrom, dateFrom) ||
                other.dateFrom == dateFrom) &&
            (identical(other.dateTo, dateTo) || other.dateTo == dateTo) &&
            (identical(other.audioFile, audioFile) ||
                other.audioFile == audioFile) &&
            (identical(other.audioDirectory, audioDirectory) ||
                other.audioDirectory == audioDirectory) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(
                    other.autoTranscribeWasActive, autoTranscribeWasActive) ||
                other.autoTranscribeWasActive == autoTranscribeWasActive) &&
            (identical(other.language, language) ||
                other.language == language) &&
            const DeepCollectionEquality()
                .equals(other._transcripts, _transcripts));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      dateFrom,
      dateTo,
      audioFile,
      audioDirectory,
      duration,
      autoTranscribeWasActive,
      language,
      const DeepCollectionEquality().hash(_transcripts));

  /// Create a copy of AudioData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AudioDataImplCopyWith<_$AudioDataImpl> get copyWith =>
      __$$AudioDataImplCopyWithImpl<_$AudioDataImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AudioDataImplToJson(
      this,
    );
  }
}

abstract class _AudioData implements AudioData {
  const factory _AudioData(
      {required final DateTime dateFrom,
      required final DateTime dateTo,
      required final String audioFile,
      required final String audioDirectory,
      required final Duration duration,
      final bool autoTranscribeWasActive,
      final String? language,
      final List<AudioTranscript>? transcripts}) = _$AudioDataImpl;

  factory _AudioData.fromJson(Map<String, dynamic> json) =
      _$AudioDataImpl.fromJson;

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
  bool get autoTranscribeWasActive;
  @override
  String? get language;
  @override
  List<AudioTranscript>? get transcripts;

  /// Create a copy of AudioData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AudioDataImplCopyWith<_$AudioDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AudioTranscript _$AudioTranscriptFromJson(Map<String, dynamic> json) {
  return _AudioTranscript.fromJson(json);
}

/// @nodoc
mixin _$AudioTranscript {
  DateTime get created => throw _privateConstructorUsedError;
  String get library => throw _privateConstructorUsedError;
  String get model => throw _privateConstructorUsedError;
  String get detectedLanguage => throw _privateConstructorUsedError;
  String get transcript => throw _privateConstructorUsedError;
  Duration? get processingTime => throw _privateConstructorUsedError;

  /// Serializes this AudioTranscript to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AudioTranscript
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AudioTranscriptCopyWith<AudioTranscript> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AudioTranscriptCopyWith<$Res> {
  factory $AudioTranscriptCopyWith(
          AudioTranscript value, $Res Function(AudioTranscript) then) =
      _$AudioTranscriptCopyWithImpl<$Res, AudioTranscript>;
  @useResult
  $Res call(
      {DateTime created,
      String library,
      String model,
      String detectedLanguage,
      String transcript,
      Duration? processingTime});
}

/// @nodoc
class _$AudioTranscriptCopyWithImpl<$Res, $Val extends AudioTranscript>
    implements $AudioTranscriptCopyWith<$Res> {
  _$AudioTranscriptCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AudioTranscript
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? created = null,
    Object? library = null,
    Object? model = null,
    Object? detectedLanguage = null,
    Object? transcript = null,
    Object? processingTime = freezed,
  }) {
    return _then(_value.copyWith(
      created: null == created
          ? _value.created
          : created // ignore: cast_nullable_to_non_nullable
              as DateTime,
      library: null == library
          ? _value.library
          : library // ignore: cast_nullable_to_non_nullable
              as String,
      model: null == model
          ? _value.model
          : model // ignore: cast_nullable_to_non_nullable
              as String,
      detectedLanguage: null == detectedLanguage
          ? _value.detectedLanguage
          : detectedLanguage // ignore: cast_nullable_to_non_nullable
              as String,
      transcript: null == transcript
          ? _value.transcript
          : transcript // ignore: cast_nullable_to_non_nullable
              as String,
      processingTime: freezed == processingTime
          ? _value.processingTime
          : processingTime // ignore: cast_nullable_to_non_nullable
              as Duration?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AudioTranscriptImplCopyWith<$Res>
    implements $AudioTranscriptCopyWith<$Res> {
  factory _$$AudioTranscriptImplCopyWith(_$AudioTranscriptImpl value,
          $Res Function(_$AudioTranscriptImpl) then) =
      __$$AudioTranscriptImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {DateTime created,
      String library,
      String model,
      String detectedLanguage,
      String transcript,
      Duration? processingTime});
}

/// @nodoc
class __$$AudioTranscriptImplCopyWithImpl<$Res>
    extends _$AudioTranscriptCopyWithImpl<$Res, _$AudioTranscriptImpl>
    implements _$$AudioTranscriptImplCopyWith<$Res> {
  __$$AudioTranscriptImplCopyWithImpl(
      _$AudioTranscriptImpl _value, $Res Function(_$AudioTranscriptImpl) _then)
      : super(_value, _then);

  /// Create a copy of AudioTranscript
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? created = null,
    Object? library = null,
    Object? model = null,
    Object? detectedLanguage = null,
    Object? transcript = null,
    Object? processingTime = freezed,
  }) {
    return _then(_$AudioTranscriptImpl(
      created: null == created
          ? _value.created
          : created // ignore: cast_nullable_to_non_nullable
              as DateTime,
      library: null == library
          ? _value.library
          : library // ignore: cast_nullable_to_non_nullable
              as String,
      model: null == model
          ? _value.model
          : model // ignore: cast_nullable_to_non_nullable
              as String,
      detectedLanguage: null == detectedLanguage
          ? _value.detectedLanguage
          : detectedLanguage // ignore: cast_nullable_to_non_nullable
              as String,
      transcript: null == transcript
          ? _value.transcript
          : transcript // ignore: cast_nullable_to_non_nullable
              as String,
      processingTime: freezed == processingTime
          ? _value.processingTime
          : processingTime // ignore: cast_nullable_to_non_nullable
              as Duration?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AudioTranscriptImpl implements _AudioTranscript {
  const _$AudioTranscriptImpl(
      {required this.created,
      required this.library,
      required this.model,
      required this.detectedLanguage,
      required this.transcript,
      this.processingTime});

  factory _$AudioTranscriptImpl.fromJson(Map<String, dynamic> json) =>
      _$$AudioTranscriptImplFromJson(json);

  @override
  final DateTime created;
  @override
  final String library;
  @override
  final String model;
  @override
  final String detectedLanguage;
  @override
  final String transcript;
  @override
  final Duration? processingTime;

  @override
  String toString() {
    return 'AudioTranscript(created: $created, library: $library, model: $model, detectedLanguage: $detectedLanguage, transcript: $transcript, processingTime: $processingTime)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AudioTranscriptImpl &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.library, library) || other.library == library) &&
            (identical(other.model, model) || other.model == model) &&
            (identical(other.detectedLanguage, detectedLanguage) ||
                other.detectedLanguage == detectedLanguage) &&
            (identical(other.transcript, transcript) ||
                other.transcript == transcript) &&
            (identical(other.processingTime, processingTime) ||
                other.processingTime == processingTime));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, created, library, model,
      detectedLanguage, transcript, processingTime);

  /// Create a copy of AudioTranscript
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AudioTranscriptImplCopyWith<_$AudioTranscriptImpl> get copyWith =>
      __$$AudioTranscriptImplCopyWithImpl<_$AudioTranscriptImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AudioTranscriptImplToJson(
      this,
    );
  }
}

abstract class _AudioTranscript implements AudioTranscript {
  const factory _AudioTranscript(
      {required final DateTime created,
      required final String library,
      required final String model,
      required final String detectedLanguage,
      required final String transcript,
      final Duration? processingTime}) = _$AudioTranscriptImpl;

  factory _AudioTranscript.fromJson(Map<String, dynamic> json) =
      _$AudioTranscriptImpl.fromJson;

  @override
  DateTime get created;
  @override
  String get library;
  @override
  String get model;
  @override
  String get detectedLanguage;
  @override
  String get transcript;
  @override
  Duration? get processingTime;

  /// Create a copy of AudioTranscript
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AudioTranscriptImplCopyWith<_$AudioTranscriptImpl> get copyWith =>
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

  /// Serializes this SurveyData to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SurveyData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
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

  /// Create a copy of SurveyData
  /// with the given fields replaced by the non-null parameter values.
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
abstract class _$$SurveyDataImplCopyWith<$Res>
    implements $SurveyDataCopyWith<$Res> {
  factory _$$SurveyDataImplCopyWith(
          _$SurveyDataImpl value, $Res Function(_$SurveyDataImpl) then) =
      __$$SurveyDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {RPTaskResult taskResult,
      Map<String, Set<String>> scoreDefinitions,
      Map<String, int> calculatedScores});
}

/// @nodoc
class __$$SurveyDataImplCopyWithImpl<$Res>
    extends _$SurveyDataCopyWithImpl<$Res, _$SurveyDataImpl>
    implements _$$SurveyDataImplCopyWith<$Res> {
  __$$SurveyDataImplCopyWithImpl(
      _$SurveyDataImpl _value, $Res Function(_$SurveyDataImpl) _then)
      : super(_value, _then);

  /// Create a copy of SurveyData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? taskResult = null,
    Object? scoreDefinitions = null,
    Object? calculatedScores = null,
  }) {
    return _then(_$SurveyDataImpl(
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
class _$SurveyDataImpl implements _SurveyData {
  const _$SurveyDataImpl(
      {required this.taskResult,
      required final Map<String, Set<String>> scoreDefinitions,
      required final Map<String, int> calculatedScores})
      : _scoreDefinitions = scoreDefinitions,
        _calculatedScores = calculatedScores;

  factory _$SurveyDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$SurveyDataImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SurveyDataImpl &&
            (identical(other.taskResult, taskResult) ||
                other.taskResult == taskResult) &&
            const DeepCollectionEquality()
                .equals(other._scoreDefinitions, _scoreDefinitions) &&
            const DeepCollectionEquality()
                .equals(other._calculatedScores, _calculatedScores));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      taskResult,
      const DeepCollectionEquality().hash(_scoreDefinitions),
      const DeepCollectionEquality().hash(_calculatedScores));

  /// Create a copy of SurveyData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SurveyDataImplCopyWith<_$SurveyDataImpl> get copyWith =>
      __$$SurveyDataImplCopyWithImpl<_$SurveyDataImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SurveyDataImplToJson(
      this,
    );
  }
}

abstract class _SurveyData implements SurveyData {
  const factory _SurveyData(
      {required final RPTaskResult taskResult,
      required final Map<String, Set<String>> scoreDefinitions,
      required final Map<String, int> calculatedScores}) = _$SurveyDataImpl;

  factory _SurveyData.fromJson(Map<String, dynamic> json) =
      _$SurveyDataImpl.fromJson;

  @override
  RPTaskResult get taskResult;
  @override
  Map<String, Set<String>> get scoreDefinitions;
  @override
  Map<String, int> get calculatedScores;

  /// Create a copy of SurveyData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SurveyDataImplCopyWith<_$SurveyDataImpl> get copyWith =>
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
    case 'event':
      return JournalEvent.fromJson(json);
    case 'checklistItem':
      return ChecklistItem.fromJson(json);
    case 'checklist':
      return Checklist.fromJson(json);
    case 'quantitative':
      return QuantitativeEntry.fromJson(json);
    case 'measurement':
      return MeasurementEntry.fromJson(json);
    case 'aiResponse':
      return AiResponseEntry.fromJson(json);
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
    required TResult Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)
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
    required TResult Function(Metadata meta, EventData data,
            EntryText? entryText, Geolocation? geolocation)
        event,
    required TResult Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)
        checklistItem,
    required TResult Function(Metadata meta, ChecklistData data,
            EntryText? entryText, Geolocation? geolocation)
        checklist,
    required TResult Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)
        quantitative,
    required TResult Function(Metadata meta, MeasurementData data,
            EntryText? entryText, Geolocation? geolocation)
        measurement,
    required TResult Function(Metadata meta, AiResponseData data,
            EntryText? entryText, Geolocation? geolocation)
        aiResponse,
    required TResult Function(Metadata meta, WorkoutData data,
            EntryText? entryText, Geolocation? geolocation)
        workout,
    required TResult Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)
        habitCompletion,
    required TResult Function(Metadata meta, SurveyData data,
            EntryText? entryText, Geolocation? geolocation)
        survey,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)?
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
    TResult? Function(Metadata meta, EventData data, EntryText? entryText,
            Geolocation? geolocation)?
        event,
    TResult? Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)?
        checklistItem,
    TResult? Function(Metadata meta, ChecklistData data, EntryText? entryText,
            Geolocation? geolocation)?
        checklist,
    TResult? Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)?
        quantitative,
    TResult? Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult? Function(Metadata meta, AiResponseData data, EntryText? entryText,
            Geolocation? geolocation)?
        aiResponse,
    TResult? Function(Metadata meta, WorkoutData data, EntryText? entryText,
            Geolocation? geolocation)?
        workout,
    TResult? Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)?
        habitCompletion,
    TResult? Function(Metadata meta, SurveyData data, EntryText? entryText,
            Geolocation? geolocation)?
        survey,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)?
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
    TResult Function(Metadata meta, EventData data, EntryText? entryText,
            Geolocation? geolocation)?
        event,
    TResult Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)?
        checklistItem,
    TResult Function(Metadata meta, ChecklistData data, EntryText? entryText,
            Geolocation? geolocation)?
        checklist,
    TResult Function(Metadata meta, QuantitativeData data, EntryText? entryText,
            Geolocation? geolocation)?
        quantitative,
    TResult Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult Function(Metadata meta, AiResponseData data, EntryText? entryText,
            Geolocation? geolocation)?
        aiResponse,
    TResult Function(Metadata meta, WorkoutData data, EntryText? entryText,
            Geolocation? geolocation)?
        workout,
    TResult Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)?
        habitCompletion,
    TResult Function(Metadata meta, SurveyData data, EntryText? entryText,
            Geolocation? geolocation)?
        survey,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(JournalEntry value) journalEntry,
    required TResult Function(JournalImage value) journalImage,
    required TResult Function(JournalAudio value) journalAudio,
    required TResult Function(Task value) task,
    required TResult Function(JournalEvent value) event,
    required TResult Function(ChecklistItem value) checklistItem,
    required TResult Function(Checklist value) checklist,
    required TResult Function(QuantitativeEntry value) quantitative,
    required TResult Function(MeasurementEntry value) measurement,
    required TResult Function(AiResponseEntry value) aiResponse,
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
    TResult? Function(JournalEvent value)? event,
    TResult? Function(ChecklistItem value)? checklistItem,
    TResult? Function(Checklist value)? checklist,
    TResult? Function(QuantitativeEntry value)? quantitative,
    TResult? Function(MeasurementEntry value)? measurement,
    TResult? Function(AiResponseEntry value)? aiResponse,
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
    TResult Function(JournalEvent value)? event,
    TResult Function(ChecklistItem value)? checklistItem,
    TResult Function(Checklist value)? checklist,
    TResult Function(QuantitativeEntry value)? quantitative,
    TResult Function(MeasurementEntry value)? measurement,
    TResult Function(AiResponseEntry value)? aiResponse,
    TResult Function(WorkoutEntry value)? workout,
    TResult Function(HabitCompletionEntry value)? habitCompletion,
    TResult Function(SurveyEntry value)? survey,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  /// Serializes this JournalEntity to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
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

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
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

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MetadataCopyWith<$Res> get meta {
    return $MetadataCopyWith<$Res>(_value.meta, (value) {
      return _then(_value.copyWith(meta: value) as $Val);
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
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

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
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
abstract class _$$JournalEntryImplCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory _$$JournalEntryImplCopyWith(
          _$JournalEntryImpl value, $Res Function(_$JournalEntryImpl) then) =
      __$$JournalEntryImplCopyWithImpl<$Res>;
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
class __$$JournalEntryImplCopyWithImpl<$Res>
    extends _$JournalEntityCopyWithImpl<$Res, _$JournalEntryImpl>
    implements _$$JournalEntryImplCopyWith<$Res> {
  __$$JournalEntryImplCopyWithImpl(
      _$JournalEntryImpl _value, $Res Function(_$JournalEntryImpl) _then)
      : super(_value, _then);

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$JournalEntryImpl(
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
class _$JournalEntryImpl implements JournalEntry {
  const _$JournalEntryImpl(
      {required this.meta,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'journalEntry';

  factory _$JournalEntryImpl.fromJson(Map<String, dynamic> json) =>
      _$$JournalEntryImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$JournalEntryImpl &&
            (identical(other.meta, meta) || other.meta == meta) &&
            (identical(other.entryText, entryText) ||
                other.entryText == entryText) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, meta, entryText, geolocation);

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$JournalEntryImplCopyWith<_$JournalEntryImpl> get copyWith =>
      __$$JournalEntryImplCopyWithImpl<_$JournalEntryImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)
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
    required TResult Function(Metadata meta, EventData data,
            EntryText? entryText, Geolocation? geolocation)
        event,
    required TResult Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)
        checklistItem,
    required TResult Function(Metadata meta, ChecklistData data,
            EntryText? entryText, Geolocation? geolocation)
        checklist,
    required TResult Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)
        quantitative,
    required TResult Function(Metadata meta, MeasurementData data,
            EntryText? entryText, Geolocation? geolocation)
        measurement,
    required TResult Function(Metadata meta, AiResponseData data,
            EntryText? entryText, Geolocation? geolocation)
        aiResponse,
    required TResult Function(Metadata meta, WorkoutData data,
            EntryText? entryText, Geolocation? geolocation)
        workout,
    required TResult Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)
        habitCompletion,
    required TResult Function(Metadata meta, SurveyData data,
            EntryText? entryText, Geolocation? geolocation)
        survey,
  }) {
    return journalEntry(meta, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)?
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
    TResult? Function(Metadata meta, EventData data, EntryText? entryText,
            Geolocation? geolocation)?
        event,
    TResult? Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)?
        checklistItem,
    TResult? Function(Metadata meta, ChecklistData data, EntryText? entryText,
            Geolocation? geolocation)?
        checklist,
    TResult? Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)?
        quantitative,
    TResult? Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult? Function(Metadata meta, AiResponseData data, EntryText? entryText,
            Geolocation? geolocation)?
        aiResponse,
    TResult? Function(Metadata meta, WorkoutData data, EntryText? entryText,
            Geolocation? geolocation)?
        workout,
    TResult? Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)?
        habitCompletion,
    TResult? Function(Metadata meta, SurveyData data, EntryText? entryText,
            Geolocation? geolocation)?
        survey,
  }) {
    return journalEntry?.call(meta, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)?
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
    TResult Function(Metadata meta, EventData data, EntryText? entryText,
            Geolocation? geolocation)?
        event,
    TResult Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)?
        checklistItem,
    TResult Function(Metadata meta, ChecklistData data, EntryText? entryText,
            Geolocation? geolocation)?
        checklist,
    TResult Function(Metadata meta, QuantitativeData data, EntryText? entryText,
            Geolocation? geolocation)?
        quantitative,
    TResult Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult Function(Metadata meta, AiResponseData data, EntryText? entryText,
            Geolocation? geolocation)?
        aiResponse,
    TResult Function(Metadata meta, WorkoutData data, EntryText? entryText,
            Geolocation? geolocation)?
        workout,
    TResult Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)?
        habitCompletion,
    TResult Function(Metadata meta, SurveyData data, EntryText? entryText,
            Geolocation? geolocation)?
        survey,
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
    required TResult Function(JournalEvent value) event,
    required TResult Function(ChecklistItem value) checklistItem,
    required TResult Function(Checklist value) checklist,
    required TResult Function(QuantitativeEntry value) quantitative,
    required TResult Function(MeasurementEntry value) measurement,
    required TResult Function(AiResponseEntry value) aiResponse,
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
    TResult? Function(JournalEvent value)? event,
    TResult? Function(ChecklistItem value)? checklistItem,
    TResult? Function(Checklist value)? checklist,
    TResult? Function(QuantitativeEntry value)? quantitative,
    TResult? Function(MeasurementEntry value)? measurement,
    TResult? Function(AiResponseEntry value)? aiResponse,
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
    TResult Function(JournalEvent value)? event,
    TResult Function(ChecklistItem value)? checklistItem,
    TResult Function(Checklist value)? checklist,
    TResult Function(QuantitativeEntry value)? quantitative,
    TResult Function(MeasurementEntry value)? measurement,
    TResult Function(AiResponseEntry value)? aiResponse,
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
    return _$$JournalEntryImplToJson(
      this,
    );
  }
}

abstract class JournalEntry implements JournalEntity {
  const factory JournalEntry(
      {required final Metadata meta,
      final EntryText? entryText,
      final Geolocation? geolocation}) = _$JournalEntryImpl;

  factory JournalEntry.fromJson(Map<String, dynamic> json) =
      _$JournalEntryImpl.fromJson;

  @override
  Metadata get meta;
  @override
  EntryText? get entryText;
  @override
  Geolocation? get geolocation;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$JournalEntryImplCopyWith<_$JournalEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$JournalImageImplCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory _$$JournalImageImplCopyWith(
          _$JournalImageImpl value, $Res Function(_$JournalImageImpl) then) =
      __$$JournalImageImplCopyWithImpl<$Res>;
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
class __$$JournalImageImplCopyWithImpl<$Res>
    extends _$JournalEntityCopyWithImpl<$Res, _$JournalImageImpl>
    implements _$$JournalImageImplCopyWith<$Res> {
  __$$JournalImageImplCopyWithImpl(
      _$JournalImageImpl _value, $Res Function(_$JournalImageImpl) _then)
      : super(_value, _then);

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = null,
    Object? data = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$JournalImageImpl(
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

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
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
class _$JournalImageImpl implements JournalImage {
  const _$JournalImageImpl(
      {required this.meta,
      required this.data,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'journalImage';

  factory _$JournalImageImpl.fromJson(Map<String, dynamic> json) =>
      _$$JournalImageImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$JournalImageImpl &&
            (identical(other.meta, meta) || other.meta == meta) &&
            (identical(other.data, data) || other.data == data) &&
            (identical(other.entryText, entryText) ||
                other.entryText == entryText) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, meta, data, entryText, geolocation);

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$JournalImageImplCopyWith<_$JournalImageImpl> get copyWith =>
      __$$JournalImageImplCopyWithImpl<_$JournalImageImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)
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
    required TResult Function(Metadata meta, EventData data,
            EntryText? entryText, Geolocation? geolocation)
        event,
    required TResult Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)
        checklistItem,
    required TResult Function(Metadata meta, ChecklistData data,
            EntryText? entryText, Geolocation? geolocation)
        checklist,
    required TResult Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)
        quantitative,
    required TResult Function(Metadata meta, MeasurementData data,
            EntryText? entryText, Geolocation? geolocation)
        measurement,
    required TResult Function(Metadata meta, AiResponseData data,
            EntryText? entryText, Geolocation? geolocation)
        aiResponse,
    required TResult Function(Metadata meta, WorkoutData data,
            EntryText? entryText, Geolocation? geolocation)
        workout,
    required TResult Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)
        habitCompletion,
    required TResult Function(Metadata meta, SurveyData data,
            EntryText? entryText, Geolocation? geolocation)
        survey,
  }) {
    return journalImage(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)?
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
    TResult? Function(Metadata meta, EventData data, EntryText? entryText,
            Geolocation? geolocation)?
        event,
    TResult? Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)?
        checklistItem,
    TResult? Function(Metadata meta, ChecklistData data, EntryText? entryText,
            Geolocation? geolocation)?
        checklist,
    TResult? Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)?
        quantitative,
    TResult? Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult? Function(Metadata meta, AiResponseData data, EntryText? entryText,
            Geolocation? geolocation)?
        aiResponse,
    TResult? Function(Metadata meta, WorkoutData data, EntryText? entryText,
            Geolocation? geolocation)?
        workout,
    TResult? Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)?
        habitCompletion,
    TResult? Function(Metadata meta, SurveyData data, EntryText? entryText,
            Geolocation? geolocation)?
        survey,
  }) {
    return journalImage?.call(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)?
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
    TResult Function(Metadata meta, EventData data, EntryText? entryText,
            Geolocation? geolocation)?
        event,
    TResult Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)?
        checklistItem,
    TResult Function(Metadata meta, ChecklistData data, EntryText? entryText,
            Geolocation? geolocation)?
        checklist,
    TResult Function(Metadata meta, QuantitativeData data, EntryText? entryText,
            Geolocation? geolocation)?
        quantitative,
    TResult Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult Function(Metadata meta, AiResponseData data, EntryText? entryText,
            Geolocation? geolocation)?
        aiResponse,
    TResult Function(Metadata meta, WorkoutData data, EntryText? entryText,
            Geolocation? geolocation)?
        workout,
    TResult Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)?
        habitCompletion,
    TResult Function(Metadata meta, SurveyData data, EntryText? entryText,
            Geolocation? geolocation)?
        survey,
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
    required TResult Function(JournalEvent value) event,
    required TResult Function(ChecklistItem value) checklistItem,
    required TResult Function(Checklist value) checklist,
    required TResult Function(QuantitativeEntry value) quantitative,
    required TResult Function(MeasurementEntry value) measurement,
    required TResult Function(AiResponseEntry value) aiResponse,
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
    TResult? Function(JournalEvent value)? event,
    TResult? Function(ChecklistItem value)? checklistItem,
    TResult? Function(Checklist value)? checklist,
    TResult? Function(QuantitativeEntry value)? quantitative,
    TResult? Function(MeasurementEntry value)? measurement,
    TResult? Function(AiResponseEntry value)? aiResponse,
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
    TResult Function(JournalEvent value)? event,
    TResult Function(ChecklistItem value)? checklistItem,
    TResult Function(Checklist value)? checklist,
    TResult Function(QuantitativeEntry value)? quantitative,
    TResult Function(MeasurementEntry value)? measurement,
    TResult Function(AiResponseEntry value)? aiResponse,
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
    return _$$JournalImageImplToJson(
      this,
    );
  }
}

abstract class JournalImage implements JournalEntity {
  const factory JournalImage(
      {required final Metadata meta,
      required final ImageData data,
      final EntryText? entryText,
      final Geolocation? geolocation}) = _$JournalImageImpl;

  factory JournalImage.fromJson(Map<String, dynamic> json) =
      _$JournalImageImpl.fromJson;

  @override
  Metadata get meta;
  ImageData get data;
  @override
  EntryText? get entryText;
  @override
  Geolocation? get geolocation;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$JournalImageImplCopyWith<_$JournalImageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$JournalAudioImplCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory _$$JournalAudioImplCopyWith(
          _$JournalAudioImpl value, $Res Function(_$JournalAudioImpl) then) =
      __$$JournalAudioImplCopyWithImpl<$Res>;
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
class __$$JournalAudioImplCopyWithImpl<$Res>
    extends _$JournalEntityCopyWithImpl<$Res, _$JournalAudioImpl>
    implements _$$JournalAudioImplCopyWith<$Res> {
  __$$JournalAudioImplCopyWithImpl(
      _$JournalAudioImpl _value, $Res Function(_$JournalAudioImpl) _then)
      : super(_value, _then);

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = null,
    Object? data = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$JournalAudioImpl(
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

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
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
class _$JournalAudioImpl implements JournalAudio {
  const _$JournalAudioImpl(
      {required this.meta,
      required this.data,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'journalAudio';

  factory _$JournalAudioImpl.fromJson(Map<String, dynamic> json) =>
      _$$JournalAudioImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$JournalAudioImpl &&
            (identical(other.meta, meta) || other.meta == meta) &&
            (identical(other.data, data) || other.data == data) &&
            (identical(other.entryText, entryText) ||
                other.entryText == entryText) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, meta, data, entryText, geolocation);

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$JournalAudioImplCopyWith<_$JournalAudioImpl> get copyWith =>
      __$$JournalAudioImplCopyWithImpl<_$JournalAudioImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)
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
    required TResult Function(Metadata meta, EventData data,
            EntryText? entryText, Geolocation? geolocation)
        event,
    required TResult Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)
        checklistItem,
    required TResult Function(Metadata meta, ChecklistData data,
            EntryText? entryText, Geolocation? geolocation)
        checklist,
    required TResult Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)
        quantitative,
    required TResult Function(Metadata meta, MeasurementData data,
            EntryText? entryText, Geolocation? geolocation)
        measurement,
    required TResult Function(Metadata meta, AiResponseData data,
            EntryText? entryText, Geolocation? geolocation)
        aiResponse,
    required TResult Function(Metadata meta, WorkoutData data,
            EntryText? entryText, Geolocation? geolocation)
        workout,
    required TResult Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)
        habitCompletion,
    required TResult Function(Metadata meta, SurveyData data,
            EntryText? entryText, Geolocation? geolocation)
        survey,
  }) {
    return journalAudio(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)?
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
    TResult? Function(Metadata meta, EventData data, EntryText? entryText,
            Geolocation? geolocation)?
        event,
    TResult? Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)?
        checklistItem,
    TResult? Function(Metadata meta, ChecklistData data, EntryText? entryText,
            Geolocation? geolocation)?
        checklist,
    TResult? Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)?
        quantitative,
    TResult? Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult? Function(Metadata meta, AiResponseData data, EntryText? entryText,
            Geolocation? geolocation)?
        aiResponse,
    TResult? Function(Metadata meta, WorkoutData data, EntryText? entryText,
            Geolocation? geolocation)?
        workout,
    TResult? Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)?
        habitCompletion,
    TResult? Function(Metadata meta, SurveyData data, EntryText? entryText,
            Geolocation? geolocation)?
        survey,
  }) {
    return journalAudio?.call(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)?
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
    TResult Function(Metadata meta, EventData data, EntryText? entryText,
            Geolocation? geolocation)?
        event,
    TResult Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)?
        checklistItem,
    TResult Function(Metadata meta, ChecklistData data, EntryText? entryText,
            Geolocation? geolocation)?
        checklist,
    TResult Function(Metadata meta, QuantitativeData data, EntryText? entryText,
            Geolocation? geolocation)?
        quantitative,
    TResult Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult Function(Metadata meta, AiResponseData data, EntryText? entryText,
            Geolocation? geolocation)?
        aiResponse,
    TResult Function(Metadata meta, WorkoutData data, EntryText? entryText,
            Geolocation? geolocation)?
        workout,
    TResult Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)?
        habitCompletion,
    TResult Function(Metadata meta, SurveyData data, EntryText? entryText,
            Geolocation? geolocation)?
        survey,
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
    required TResult Function(JournalEvent value) event,
    required TResult Function(ChecklistItem value) checklistItem,
    required TResult Function(Checklist value) checklist,
    required TResult Function(QuantitativeEntry value) quantitative,
    required TResult Function(MeasurementEntry value) measurement,
    required TResult Function(AiResponseEntry value) aiResponse,
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
    TResult? Function(JournalEvent value)? event,
    TResult? Function(ChecklistItem value)? checklistItem,
    TResult? Function(Checklist value)? checklist,
    TResult? Function(QuantitativeEntry value)? quantitative,
    TResult? Function(MeasurementEntry value)? measurement,
    TResult? Function(AiResponseEntry value)? aiResponse,
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
    TResult Function(JournalEvent value)? event,
    TResult Function(ChecklistItem value)? checklistItem,
    TResult Function(Checklist value)? checklist,
    TResult Function(QuantitativeEntry value)? quantitative,
    TResult Function(MeasurementEntry value)? measurement,
    TResult Function(AiResponseEntry value)? aiResponse,
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
    return _$$JournalAudioImplToJson(
      this,
    );
  }
}

abstract class JournalAudio implements JournalEntity {
  const factory JournalAudio(
      {required final Metadata meta,
      required final AudioData data,
      final EntryText? entryText,
      final Geolocation? geolocation}) = _$JournalAudioImpl;

  factory JournalAudio.fromJson(Map<String, dynamic> json) =
      _$JournalAudioImpl.fromJson;

  @override
  Metadata get meta;
  AudioData get data;
  @override
  EntryText? get entryText;
  @override
  Geolocation? get geolocation;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$JournalAudioImplCopyWith<_$JournalAudioImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$TaskImplCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory _$$TaskImplCopyWith(
          _$TaskImpl value, $Res Function(_$TaskImpl) then) =
      __$$TaskImplCopyWithImpl<$Res>;
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
class __$$TaskImplCopyWithImpl<$Res>
    extends _$JournalEntityCopyWithImpl<$Res, _$TaskImpl>
    implements _$$TaskImplCopyWith<$Res> {
  __$$TaskImplCopyWithImpl(_$TaskImpl _value, $Res Function(_$TaskImpl) _then)
      : super(_value, _then);

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = null,
    Object? data = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$TaskImpl(
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

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
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
class _$TaskImpl implements Task {
  const _$TaskImpl(
      {required this.meta,
      required this.data,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'task';

  factory _$TaskImpl.fromJson(Map<String, dynamic> json) =>
      _$$TaskImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskImpl &&
            (identical(other.meta, meta) || other.meta == meta) &&
            (identical(other.data, data) || other.data == data) &&
            (identical(other.entryText, entryText) ||
                other.entryText == entryText) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, meta, data, entryText, geolocation);

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskImplCopyWith<_$TaskImpl> get copyWith =>
      __$$TaskImplCopyWithImpl<_$TaskImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)
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
    required TResult Function(Metadata meta, EventData data,
            EntryText? entryText, Geolocation? geolocation)
        event,
    required TResult Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)
        checklistItem,
    required TResult Function(Metadata meta, ChecklistData data,
            EntryText? entryText, Geolocation? geolocation)
        checklist,
    required TResult Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)
        quantitative,
    required TResult Function(Metadata meta, MeasurementData data,
            EntryText? entryText, Geolocation? geolocation)
        measurement,
    required TResult Function(Metadata meta, AiResponseData data,
            EntryText? entryText, Geolocation? geolocation)
        aiResponse,
    required TResult Function(Metadata meta, WorkoutData data,
            EntryText? entryText, Geolocation? geolocation)
        workout,
    required TResult Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)
        habitCompletion,
    required TResult Function(Metadata meta, SurveyData data,
            EntryText? entryText, Geolocation? geolocation)
        survey,
  }) {
    return task(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)?
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
    TResult? Function(Metadata meta, EventData data, EntryText? entryText,
            Geolocation? geolocation)?
        event,
    TResult? Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)?
        checklistItem,
    TResult? Function(Metadata meta, ChecklistData data, EntryText? entryText,
            Geolocation? geolocation)?
        checklist,
    TResult? Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)?
        quantitative,
    TResult? Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult? Function(Metadata meta, AiResponseData data, EntryText? entryText,
            Geolocation? geolocation)?
        aiResponse,
    TResult? Function(Metadata meta, WorkoutData data, EntryText? entryText,
            Geolocation? geolocation)?
        workout,
    TResult? Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)?
        habitCompletion,
    TResult? Function(Metadata meta, SurveyData data, EntryText? entryText,
            Geolocation? geolocation)?
        survey,
  }) {
    return task?.call(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)?
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
    TResult Function(Metadata meta, EventData data, EntryText? entryText,
            Geolocation? geolocation)?
        event,
    TResult Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)?
        checklistItem,
    TResult Function(Metadata meta, ChecklistData data, EntryText? entryText,
            Geolocation? geolocation)?
        checklist,
    TResult Function(Metadata meta, QuantitativeData data, EntryText? entryText,
            Geolocation? geolocation)?
        quantitative,
    TResult Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult Function(Metadata meta, AiResponseData data, EntryText? entryText,
            Geolocation? geolocation)?
        aiResponse,
    TResult Function(Metadata meta, WorkoutData data, EntryText? entryText,
            Geolocation? geolocation)?
        workout,
    TResult Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)?
        habitCompletion,
    TResult Function(Metadata meta, SurveyData data, EntryText? entryText,
            Geolocation? geolocation)?
        survey,
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
    required TResult Function(JournalEvent value) event,
    required TResult Function(ChecklistItem value) checklistItem,
    required TResult Function(Checklist value) checklist,
    required TResult Function(QuantitativeEntry value) quantitative,
    required TResult Function(MeasurementEntry value) measurement,
    required TResult Function(AiResponseEntry value) aiResponse,
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
    TResult? Function(JournalEvent value)? event,
    TResult? Function(ChecklistItem value)? checklistItem,
    TResult? Function(Checklist value)? checklist,
    TResult? Function(QuantitativeEntry value)? quantitative,
    TResult? Function(MeasurementEntry value)? measurement,
    TResult? Function(AiResponseEntry value)? aiResponse,
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
    TResult Function(JournalEvent value)? event,
    TResult Function(ChecklistItem value)? checklistItem,
    TResult Function(Checklist value)? checklist,
    TResult Function(QuantitativeEntry value)? quantitative,
    TResult Function(MeasurementEntry value)? measurement,
    TResult Function(AiResponseEntry value)? aiResponse,
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
    return _$$TaskImplToJson(
      this,
    );
  }
}

abstract class Task implements JournalEntity {
  const factory Task(
      {required final Metadata meta,
      required final TaskData data,
      final EntryText? entryText,
      final Geolocation? geolocation}) = _$TaskImpl;

  factory Task.fromJson(Map<String, dynamic> json) = _$TaskImpl.fromJson;

  @override
  Metadata get meta;
  TaskData get data;
  @override
  EntryText? get entryText;
  @override
  Geolocation? get geolocation;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskImplCopyWith<_$TaskImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$JournalEventImplCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory _$$JournalEventImplCopyWith(
          _$JournalEventImpl value, $Res Function(_$JournalEventImpl) then) =
      __$$JournalEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {Metadata meta,
      EventData data,
      EntryText? entryText,
      Geolocation? geolocation});

  @override
  $MetadataCopyWith<$Res> get meta;
  $EventDataCopyWith<$Res> get data;
  @override
  $EntryTextCopyWith<$Res>? get entryText;
  @override
  $GeolocationCopyWith<$Res>? get geolocation;
}

/// @nodoc
class __$$JournalEventImplCopyWithImpl<$Res>
    extends _$JournalEntityCopyWithImpl<$Res, _$JournalEventImpl>
    implements _$$JournalEventImplCopyWith<$Res> {
  __$$JournalEventImplCopyWithImpl(
      _$JournalEventImpl _value, $Res Function(_$JournalEventImpl) _then)
      : super(_value, _then);

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = null,
    Object? data = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$JournalEventImpl(
      meta: null == meta
          ? _value.meta
          : meta // ignore: cast_nullable_to_non_nullable
              as Metadata,
      data: null == data
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as EventData,
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

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $EventDataCopyWith<$Res> get data {
    return $EventDataCopyWith<$Res>(_value.data, (value) {
      return _then(_value.copyWith(data: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _$JournalEventImpl implements JournalEvent {
  const _$JournalEventImpl(
      {required this.meta,
      required this.data,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'event';

  factory _$JournalEventImpl.fromJson(Map<String, dynamic> json) =>
      _$$JournalEventImplFromJson(json);

  @override
  final Metadata meta;
  @override
  final EventData data;
  @override
  final EntryText? entryText;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'JournalEntity.event(meta: $meta, data: $data, entryText: $entryText, geolocation: $geolocation)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$JournalEventImpl &&
            (identical(other.meta, meta) || other.meta == meta) &&
            (identical(other.data, data) || other.data == data) &&
            (identical(other.entryText, entryText) ||
                other.entryText == entryText) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, meta, data, entryText, geolocation);

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$JournalEventImplCopyWith<_$JournalEventImpl> get copyWith =>
      __$$JournalEventImplCopyWithImpl<_$JournalEventImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)
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
    required TResult Function(Metadata meta, EventData data,
            EntryText? entryText, Geolocation? geolocation)
        event,
    required TResult Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)
        checklistItem,
    required TResult Function(Metadata meta, ChecklistData data,
            EntryText? entryText, Geolocation? geolocation)
        checklist,
    required TResult Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)
        quantitative,
    required TResult Function(Metadata meta, MeasurementData data,
            EntryText? entryText, Geolocation? geolocation)
        measurement,
    required TResult Function(Metadata meta, AiResponseData data,
            EntryText? entryText, Geolocation? geolocation)
        aiResponse,
    required TResult Function(Metadata meta, WorkoutData data,
            EntryText? entryText, Geolocation? geolocation)
        workout,
    required TResult Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)
        habitCompletion,
    required TResult Function(Metadata meta, SurveyData data,
            EntryText? entryText, Geolocation? geolocation)
        survey,
  }) {
    return event(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)?
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
    TResult? Function(Metadata meta, EventData data, EntryText? entryText,
            Geolocation? geolocation)?
        event,
    TResult? Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)?
        checklistItem,
    TResult? Function(Metadata meta, ChecklistData data, EntryText? entryText,
            Geolocation? geolocation)?
        checklist,
    TResult? Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)?
        quantitative,
    TResult? Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult? Function(Metadata meta, AiResponseData data, EntryText? entryText,
            Geolocation? geolocation)?
        aiResponse,
    TResult? Function(Metadata meta, WorkoutData data, EntryText? entryText,
            Geolocation? geolocation)?
        workout,
    TResult? Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)?
        habitCompletion,
    TResult? Function(Metadata meta, SurveyData data, EntryText? entryText,
            Geolocation? geolocation)?
        survey,
  }) {
    return event?.call(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)?
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
    TResult Function(Metadata meta, EventData data, EntryText? entryText,
            Geolocation? geolocation)?
        event,
    TResult Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)?
        checklistItem,
    TResult Function(Metadata meta, ChecklistData data, EntryText? entryText,
            Geolocation? geolocation)?
        checklist,
    TResult Function(Metadata meta, QuantitativeData data, EntryText? entryText,
            Geolocation? geolocation)?
        quantitative,
    TResult Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult Function(Metadata meta, AiResponseData data, EntryText? entryText,
            Geolocation? geolocation)?
        aiResponse,
    TResult Function(Metadata meta, WorkoutData data, EntryText? entryText,
            Geolocation? geolocation)?
        workout,
    TResult Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)?
        habitCompletion,
    TResult Function(Metadata meta, SurveyData data, EntryText? entryText,
            Geolocation? geolocation)?
        survey,
    required TResult orElse(),
  }) {
    if (event != null) {
      return event(meta, data, entryText, geolocation);
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
    required TResult Function(JournalEvent value) event,
    required TResult Function(ChecklistItem value) checklistItem,
    required TResult Function(Checklist value) checklist,
    required TResult Function(QuantitativeEntry value) quantitative,
    required TResult Function(MeasurementEntry value) measurement,
    required TResult Function(AiResponseEntry value) aiResponse,
    required TResult Function(WorkoutEntry value) workout,
    required TResult Function(HabitCompletionEntry value) habitCompletion,
    required TResult Function(SurveyEntry value) survey,
  }) {
    return event(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(JournalEntry value)? journalEntry,
    TResult? Function(JournalImage value)? journalImage,
    TResult? Function(JournalAudio value)? journalAudio,
    TResult? Function(Task value)? task,
    TResult? Function(JournalEvent value)? event,
    TResult? Function(ChecklistItem value)? checklistItem,
    TResult? Function(Checklist value)? checklist,
    TResult? Function(QuantitativeEntry value)? quantitative,
    TResult? Function(MeasurementEntry value)? measurement,
    TResult? Function(AiResponseEntry value)? aiResponse,
    TResult? Function(WorkoutEntry value)? workout,
    TResult? Function(HabitCompletionEntry value)? habitCompletion,
    TResult? Function(SurveyEntry value)? survey,
  }) {
    return event?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(JournalEntry value)? journalEntry,
    TResult Function(JournalImage value)? journalImage,
    TResult Function(JournalAudio value)? journalAudio,
    TResult Function(Task value)? task,
    TResult Function(JournalEvent value)? event,
    TResult Function(ChecklistItem value)? checklistItem,
    TResult Function(Checklist value)? checklist,
    TResult Function(QuantitativeEntry value)? quantitative,
    TResult Function(MeasurementEntry value)? measurement,
    TResult Function(AiResponseEntry value)? aiResponse,
    TResult Function(WorkoutEntry value)? workout,
    TResult Function(HabitCompletionEntry value)? habitCompletion,
    TResult Function(SurveyEntry value)? survey,
    required TResult orElse(),
  }) {
    if (event != null) {
      return event(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$JournalEventImplToJson(
      this,
    );
  }
}

abstract class JournalEvent implements JournalEntity {
  const factory JournalEvent(
      {required final Metadata meta,
      required final EventData data,
      final EntryText? entryText,
      final Geolocation? geolocation}) = _$JournalEventImpl;

  factory JournalEvent.fromJson(Map<String, dynamic> json) =
      _$JournalEventImpl.fromJson;

  @override
  Metadata get meta;
  EventData get data;
  @override
  EntryText? get entryText;
  @override
  Geolocation? get geolocation;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$JournalEventImplCopyWith<_$JournalEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ChecklistItemImplCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory _$$ChecklistItemImplCopyWith(
          _$ChecklistItemImpl value, $Res Function(_$ChecklistItemImpl) then) =
      __$$ChecklistItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {Metadata meta,
      ChecklistItemData data,
      EntryText? entryText,
      Geolocation? geolocation});

  @override
  $MetadataCopyWith<$Res> get meta;
  $ChecklistItemDataCopyWith<$Res> get data;
  @override
  $EntryTextCopyWith<$Res>? get entryText;
  @override
  $GeolocationCopyWith<$Res>? get geolocation;
}

/// @nodoc
class __$$ChecklistItemImplCopyWithImpl<$Res>
    extends _$JournalEntityCopyWithImpl<$Res, _$ChecklistItemImpl>
    implements _$$ChecklistItemImplCopyWith<$Res> {
  __$$ChecklistItemImplCopyWithImpl(
      _$ChecklistItemImpl _value, $Res Function(_$ChecklistItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = null,
    Object? data = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$ChecklistItemImpl(
      meta: null == meta
          ? _value.meta
          : meta // ignore: cast_nullable_to_non_nullable
              as Metadata,
      data: null == data
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as ChecklistItemData,
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

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ChecklistItemDataCopyWith<$Res> get data {
    return $ChecklistItemDataCopyWith<$Res>(_value.data, (value) {
      return _then(_value.copyWith(data: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _$ChecklistItemImpl implements ChecklistItem {
  const _$ChecklistItemImpl(
      {required this.meta,
      required this.data,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'checklistItem';

  factory _$ChecklistItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChecklistItemImplFromJson(json);

  @override
  final Metadata meta;
  @override
  final ChecklistItemData data;
  @override
  final EntryText? entryText;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'JournalEntity.checklistItem(meta: $meta, data: $data, entryText: $entryText, geolocation: $geolocation)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChecklistItemImpl &&
            (identical(other.meta, meta) || other.meta == meta) &&
            (identical(other.data, data) || other.data == data) &&
            (identical(other.entryText, entryText) ||
                other.entryText == entryText) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, meta, data, entryText, geolocation);

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChecklistItemImplCopyWith<_$ChecklistItemImpl> get copyWith =>
      __$$ChecklistItemImplCopyWithImpl<_$ChecklistItemImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)
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
    required TResult Function(Metadata meta, EventData data,
            EntryText? entryText, Geolocation? geolocation)
        event,
    required TResult Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)
        checklistItem,
    required TResult Function(Metadata meta, ChecklistData data,
            EntryText? entryText, Geolocation? geolocation)
        checklist,
    required TResult Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)
        quantitative,
    required TResult Function(Metadata meta, MeasurementData data,
            EntryText? entryText, Geolocation? geolocation)
        measurement,
    required TResult Function(Metadata meta, AiResponseData data,
            EntryText? entryText, Geolocation? geolocation)
        aiResponse,
    required TResult Function(Metadata meta, WorkoutData data,
            EntryText? entryText, Geolocation? geolocation)
        workout,
    required TResult Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)
        habitCompletion,
    required TResult Function(Metadata meta, SurveyData data,
            EntryText? entryText, Geolocation? geolocation)
        survey,
  }) {
    return checklistItem(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)?
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
    TResult? Function(Metadata meta, EventData data, EntryText? entryText,
            Geolocation? geolocation)?
        event,
    TResult? Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)?
        checklistItem,
    TResult? Function(Metadata meta, ChecklistData data, EntryText? entryText,
            Geolocation? geolocation)?
        checklist,
    TResult? Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)?
        quantitative,
    TResult? Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult? Function(Metadata meta, AiResponseData data, EntryText? entryText,
            Geolocation? geolocation)?
        aiResponse,
    TResult? Function(Metadata meta, WorkoutData data, EntryText? entryText,
            Geolocation? geolocation)?
        workout,
    TResult? Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)?
        habitCompletion,
    TResult? Function(Metadata meta, SurveyData data, EntryText? entryText,
            Geolocation? geolocation)?
        survey,
  }) {
    return checklistItem?.call(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)?
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
    TResult Function(Metadata meta, EventData data, EntryText? entryText,
            Geolocation? geolocation)?
        event,
    TResult Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)?
        checklistItem,
    TResult Function(Metadata meta, ChecklistData data, EntryText? entryText,
            Geolocation? geolocation)?
        checklist,
    TResult Function(Metadata meta, QuantitativeData data, EntryText? entryText,
            Geolocation? geolocation)?
        quantitative,
    TResult Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult Function(Metadata meta, AiResponseData data, EntryText? entryText,
            Geolocation? geolocation)?
        aiResponse,
    TResult Function(Metadata meta, WorkoutData data, EntryText? entryText,
            Geolocation? geolocation)?
        workout,
    TResult Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)?
        habitCompletion,
    TResult Function(Metadata meta, SurveyData data, EntryText? entryText,
            Geolocation? geolocation)?
        survey,
    required TResult orElse(),
  }) {
    if (checklistItem != null) {
      return checklistItem(meta, data, entryText, geolocation);
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
    required TResult Function(JournalEvent value) event,
    required TResult Function(ChecklistItem value) checklistItem,
    required TResult Function(Checklist value) checklist,
    required TResult Function(QuantitativeEntry value) quantitative,
    required TResult Function(MeasurementEntry value) measurement,
    required TResult Function(AiResponseEntry value) aiResponse,
    required TResult Function(WorkoutEntry value) workout,
    required TResult Function(HabitCompletionEntry value) habitCompletion,
    required TResult Function(SurveyEntry value) survey,
  }) {
    return checklistItem(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(JournalEntry value)? journalEntry,
    TResult? Function(JournalImage value)? journalImage,
    TResult? Function(JournalAudio value)? journalAudio,
    TResult? Function(Task value)? task,
    TResult? Function(JournalEvent value)? event,
    TResult? Function(ChecklistItem value)? checklistItem,
    TResult? Function(Checklist value)? checklist,
    TResult? Function(QuantitativeEntry value)? quantitative,
    TResult? Function(MeasurementEntry value)? measurement,
    TResult? Function(AiResponseEntry value)? aiResponse,
    TResult? Function(WorkoutEntry value)? workout,
    TResult? Function(HabitCompletionEntry value)? habitCompletion,
    TResult? Function(SurveyEntry value)? survey,
  }) {
    return checklistItem?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(JournalEntry value)? journalEntry,
    TResult Function(JournalImage value)? journalImage,
    TResult Function(JournalAudio value)? journalAudio,
    TResult Function(Task value)? task,
    TResult Function(JournalEvent value)? event,
    TResult Function(ChecklistItem value)? checklistItem,
    TResult Function(Checklist value)? checklist,
    TResult Function(QuantitativeEntry value)? quantitative,
    TResult Function(MeasurementEntry value)? measurement,
    TResult Function(AiResponseEntry value)? aiResponse,
    TResult Function(WorkoutEntry value)? workout,
    TResult Function(HabitCompletionEntry value)? habitCompletion,
    TResult Function(SurveyEntry value)? survey,
    required TResult orElse(),
  }) {
    if (checklistItem != null) {
      return checklistItem(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$ChecklistItemImplToJson(
      this,
    );
  }
}

abstract class ChecklistItem implements JournalEntity {
  const factory ChecklistItem(
      {required final Metadata meta,
      required final ChecklistItemData data,
      final EntryText? entryText,
      final Geolocation? geolocation}) = _$ChecklistItemImpl;

  factory ChecklistItem.fromJson(Map<String, dynamic> json) =
      _$ChecklistItemImpl.fromJson;

  @override
  Metadata get meta;
  ChecklistItemData get data;
  @override
  EntryText? get entryText;
  @override
  Geolocation? get geolocation;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChecklistItemImplCopyWith<_$ChecklistItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ChecklistImplCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory _$$ChecklistImplCopyWith(
          _$ChecklistImpl value, $Res Function(_$ChecklistImpl) then) =
      __$$ChecklistImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {Metadata meta,
      ChecklistData data,
      EntryText? entryText,
      Geolocation? geolocation});

  @override
  $MetadataCopyWith<$Res> get meta;
  $ChecklistDataCopyWith<$Res> get data;
  @override
  $EntryTextCopyWith<$Res>? get entryText;
  @override
  $GeolocationCopyWith<$Res>? get geolocation;
}

/// @nodoc
class __$$ChecklistImplCopyWithImpl<$Res>
    extends _$JournalEntityCopyWithImpl<$Res, _$ChecklistImpl>
    implements _$$ChecklistImplCopyWith<$Res> {
  __$$ChecklistImplCopyWithImpl(
      _$ChecklistImpl _value, $Res Function(_$ChecklistImpl) _then)
      : super(_value, _then);

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = null,
    Object? data = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$ChecklistImpl(
      meta: null == meta
          ? _value.meta
          : meta // ignore: cast_nullable_to_non_nullable
              as Metadata,
      data: null == data
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as ChecklistData,
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

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ChecklistDataCopyWith<$Res> get data {
    return $ChecklistDataCopyWith<$Res>(_value.data, (value) {
      return _then(_value.copyWith(data: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _$ChecklistImpl implements Checklist {
  const _$ChecklistImpl(
      {required this.meta,
      required this.data,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'checklist';

  factory _$ChecklistImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChecklistImplFromJson(json);

  @override
  final Metadata meta;
  @override
  final ChecklistData data;
  @override
  final EntryText? entryText;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'JournalEntity.checklist(meta: $meta, data: $data, entryText: $entryText, geolocation: $geolocation)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChecklistImpl &&
            (identical(other.meta, meta) || other.meta == meta) &&
            (identical(other.data, data) || other.data == data) &&
            (identical(other.entryText, entryText) ||
                other.entryText == entryText) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, meta, data, entryText, geolocation);

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChecklistImplCopyWith<_$ChecklistImpl> get copyWith =>
      __$$ChecklistImplCopyWithImpl<_$ChecklistImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)
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
    required TResult Function(Metadata meta, EventData data,
            EntryText? entryText, Geolocation? geolocation)
        event,
    required TResult Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)
        checklistItem,
    required TResult Function(Metadata meta, ChecklistData data,
            EntryText? entryText, Geolocation? geolocation)
        checklist,
    required TResult Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)
        quantitative,
    required TResult Function(Metadata meta, MeasurementData data,
            EntryText? entryText, Geolocation? geolocation)
        measurement,
    required TResult Function(Metadata meta, AiResponseData data,
            EntryText? entryText, Geolocation? geolocation)
        aiResponse,
    required TResult Function(Metadata meta, WorkoutData data,
            EntryText? entryText, Geolocation? geolocation)
        workout,
    required TResult Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)
        habitCompletion,
    required TResult Function(Metadata meta, SurveyData data,
            EntryText? entryText, Geolocation? geolocation)
        survey,
  }) {
    return checklist(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)?
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
    TResult? Function(Metadata meta, EventData data, EntryText? entryText,
            Geolocation? geolocation)?
        event,
    TResult? Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)?
        checklistItem,
    TResult? Function(Metadata meta, ChecklistData data, EntryText? entryText,
            Geolocation? geolocation)?
        checklist,
    TResult? Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)?
        quantitative,
    TResult? Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult? Function(Metadata meta, AiResponseData data, EntryText? entryText,
            Geolocation? geolocation)?
        aiResponse,
    TResult? Function(Metadata meta, WorkoutData data, EntryText? entryText,
            Geolocation? geolocation)?
        workout,
    TResult? Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)?
        habitCompletion,
    TResult? Function(Metadata meta, SurveyData data, EntryText? entryText,
            Geolocation? geolocation)?
        survey,
  }) {
    return checklist?.call(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)?
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
    TResult Function(Metadata meta, EventData data, EntryText? entryText,
            Geolocation? geolocation)?
        event,
    TResult Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)?
        checklistItem,
    TResult Function(Metadata meta, ChecklistData data, EntryText? entryText,
            Geolocation? geolocation)?
        checklist,
    TResult Function(Metadata meta, QuantitativeData data, EntryText? entryText,
            Geolocation? geolocation)?
        quantitative,
    TResult Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult Function(Metadata meta, AiResponseData data, EntryText? entryText,
            Geolocation? geolocation)?
        aiResponse,
    TResult Function(Metadata meta, WorkoutData data, EntryText? entryText,
            Geolocation? geolocation)?
        workout,
    TResult Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)?
        habitCompletion,
    TResult Function(Metadata meta, SurveyData data, EntryText? entryText,
            Geolocation? geolocation)?
        survey,
    required TResult orElse(),
  }) {
    if (checklist != null) {
      return checklist(meta, data, entryText, geolocation);
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
    required TResult Function(JournalEvent value) event,
    required TResult Function(ChecklistItem value) checklistItem,
    required TResult Function(Checklist value) checklist,
    required TResult Function(QuantitativeEntry value) quantitative,
    required TResult Function(MeasurementEntry value) measurement,
    required TResult Function(AiResponseEntry value) aiResponse,
    required TResult Function(WorkoutEntry value) workout,
    required TResult Function(HabitCompletionEntry value) habitCompletion,
    required TResult Function(SurveyEntry value) survey,
  }) {
    return checklist(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(JournalEntry value)? journalEntry,
    TResult? Function(JournalImage value)? journalImage,
    TResult? Function(JournalAudio value)? journalAudio,
    TResult? Function(Task value)? task,
    TResult? Function(JournalEvent value)? event,
    TResult? Function(ChecklistItem value)? checklistItem,
    TResult? Function(Checklist value)? checklist,
    TResult? Function(QuantitativeEntry value)? quantitative,
    TResult? Function(MeasurementEntry value)? measurement,
    TResult? Function(AiResponseEntry value)? aiResponse,
    TResult? Function(WorkoutEntry value)? workout,
    TResult? Function(HabitCompletionEntry value)? habitCompletion,
    TResult? Function(SurveyEntry value)? survey,
  }) {
    return checklist?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(JournalEntry value)? journalEntry,
    TResult Function(JournalImage value)? journalImage,
    TResult Function(JournalAudio value)? journalAudio,
    TResult Function(Task value)? task,
    TResult Function(JournalEvent value)? event,
    TResult Function(ChecklistItem value)? checklistItem,
    TResult Function(Checklist value)? checklist,
    TResult Function(QuantitativeEntry value)? quantitative,
    TResult Function(MeasurementEntry value)? measurement,
    TResult Function(AiResponseEntry value)? aiResponse,
    TResult Function(WorkoutEntry value)? workout,
    TResult Function(HabitCompletionEntry value)? habitCompletion,
    TResult Function(SurveyEntry value)? survey,
    required TResult orElse(),
  }) {
    if (checklist != null) {
      return checklist(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$ChecklistImplToJson(
      this,
    );
  }
}

abstract class Checklist implements JournalEntity {
  const factory Checklist(
      {required final Metadata meta,
      required final ChecklistData data,
      final EntryText? entryText,
      final Geolocation? geolocation}) = _$ChecklistImpl;

  factory Checklist.fromJson(Map<String, dynamic> json) =
      _$ChecklistImpl.fromJson;

  @override
  Metadata get meta;
  ChecklistData get data;
  @override
  EntryText? get entryText;
  @override
  Geolocation? get geolocation;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChecklistImplCopyWith<_$ChecklistImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$QuantitativeEntryImplCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory _$$QuantitativeEntryImplCopyWith(_$QuantitativeEntryImpl value,
          $Res Function(_$QuantitativeEntryImpl) then) =
      __$$QuantitativeEntryImplCopyWithImpl<$Res>;
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
class __$$QuantitativeEntryImplCopyWithImpl<$Res>
    extends _$JournalEntityCopyWithImpl<$Res, _$QuantitativeEntryImpl>
    implements _$$QuantitativeEntryImplCopyWith<$Res> {
  __$$QuantitativeEntryImplCopyWithImpl(_$QuantitativeEntryImpl _value,
      $Res Function(_$QuantitativeEntryImpl) _then)
      : super(_value, _then);

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = null,
    Object? data = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$QuantitativeEntryImpl(
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

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
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
class _$QuantitativeEntryImpl implements QuantitativeEntry {
  const _$QuantitativeEntryImpl(
      {required this.meta,
      required this.data,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'quantitative';

  factory _$QuantitativeEntryImpl.fromJson(Map<String, dynamic> json) =>
      _$$QuantitativeEntryImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$QuantitativeEntryImpl &&
            (identical(other.meta, meta) || other.meta == meta) &&
            (identical(other.data, data) || other.data == data) &&
            (identical(other.entryText, entryText) ||
                other.entryText == entryText) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, meta, data, entryText, geolocation);

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$QuantitativeEntryImplCopyWith<_$QuantitativeEntryImpl> get copyWith =>
      __$$QuantitativeEntryImplCopyWithImpl<_$QuantitativeEntryImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)
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
    required TResult Function(Metadata meta, EventData data,
            EntryText? entryText, Geolocation? geolocation)
        event,
    required TResult Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)
        checklistItem,
    required TResult Function(Metadata meta, ChecklistData data,
            EntryText? entryText, Geolocation? geolocation)
        checklist,
    required TResult Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)
        quantitative,
    required TResult Function(Metadata meta, MeasurementData data,
            EntryText? entryText, Geolocation? geolocation)
        measurement,
    required TResult Function(Metadata meta, AiResponseData data,
            EntryText? entryText, Geolocation? geolocation)
        aiResponse,
    required TResult Function(Metadata meta, WorkoutData data,
            EntryText? entryText, Geolocation? geolocation)
        workout,
    required TResult Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)
        habitCompletion,
    required TResult Function(Metadata meta, SurveyData data,
            EntryText? entryText, Geolocation? geolocation)
        survey,
  }) {
    return quantitative(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)?
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
    TResult? Function(Metadata meta, EventData data, EntryText? entryText,
            Geolocation? geolocation)?
        event,
    TResult? Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)?
        checklistItem,
    TResult? Function(Metadata meta, ChecklistData data, EntryText? entryText,
            Geolocation? geolocation)?
        checklist,
    TResult? Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)?
        quantitative,
    TResult? Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult? Function(Metadata meta, AiResponseData data, EntryText? entryText,
            Geolocation? geolocation)?
        aiResponse,
    TResult? Function(Metadata meta, WorkoutData data, EntryText? entryText,
            Geolocation? geolocation)?
        workout,
    TResult? Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)?
        habitCompletion,
    TResult? Function(Metadata meta, SurveyData data, EntryText? entryText,
            Geolocation? geolocation)?
        survey,
  }) {
    return quantitative?.call(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)?
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
    TResult Function(Metadata meta, EventData data, EntryText? entryText,
            Geolocation? geolocation)?
        event,
    TResult Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)?
        checklistItem,
    TResult Function(Metadata meta, ChecklistData data, EntryText? entryText,
            Geolocation? geolocation)?
        checklist,
    TResult Function(Metadata meta, QuantitativeData data, EntryText? entryText,
            Geolocation? geolocation)?
        quantitative,
    TResult Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult Function(Metadata meta, AiResponseData data, EntryText? entryText,
            Geolocation? geolocation)?
        aiResponse,
    TResult Function(Metadata meta, WorkoutData data, EntryText? entryText,
            Geolocation? geolocation)?
        workout,
    TResult Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)?
        habitCompletion,
    TResult Function(Metadata meta, SurveyData data, EntryText? entryText,
            Geolocation? geolocation)?
        survey,
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
    required TResult Function(JournalEvent value) event,
    required TResult Function(ChecklistItem value) checklistItem,
    required TResult Function(Checklist value) checklist,
    required TResult Function(QuantitativeEntry value) quantitative,
    required TResult Function(MeasurementEntry value) measurement,
    required TResult Function(AiResponseEntry value) aiResponse,
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
    TResult? Function(JournalEvent value)? event,
    TResult? Function(ChecklistItem value)? checklistItem,
    TResult? Function(Checklist value)? checklist,
    TResult? Function(QuantitativeEntry value)? quantitative,
    TResult? Function(MeasurementEntry value)? measurement,
    TResult? Function(AiResponseEntry value)? aiResponse,
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
    TResult Function(JournalEvent value)? event,
    TResult Function(ChecklistItem value)? checklistItem,
    TResult Function(Checklist value)? checklist,
    TResult Function(QuantitativeEntry value)? quantitative,
    TResult Function(MeasurementEntry value)? measurement,
    TResult Function(AiResponseEntry value)? aiResponse,
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
    return _$$QuantitativeEntryImplToJson(
      this,
    );
  }
}

abstract class QuantitativeEntry implements JournalEntity {
  const factory QuantitativeEntry(
      {required final Metadata meta,
      required final QuantitativeData data,
      final EntryText? entryText,
      final Geolocation? geolocation}) = _$QuantitativeEntryImpl;

  factory QuantitativeEntry.fromJson(Map<String, dynamic> json) =
      _$QuantitativeEntryImpl.fromJson;

  @override
  Metadata get meta;
  QuantitativeData get data;
  @override
  EntryText? get entryText;
  @override
  Geolocation? get geolocation;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$QuantitativeEntryImplCopyWith<_$QuantitativeEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$MeasurementEntryImplCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory _$$MeasurementEntryImplCopyWith(_$MeasurementEntryImpl value,
          $Res Function(_$MeasurementEntryImpl) then) =
      __$$MeasurementEntryImplCopyWithImpl<$Res>;
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
class __$$MeasurementEntryImplCopyWithImpl<$Res>
    extends _$JournalEntityCopyWithImpl<$Res, _$MeasurementEntryImpl>
    implements _$$MeasurementEntryImplCopyWith<$Res> {
  __$$MeasurementEntryImplCopyWithImpl(_$MeasurementEntryImpl _value,
      $Res Function(_$MeasurementEntryImpl) _then)
      : super(_value, _then);

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = null,
    Object? data = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$MeasurementEntryImpl(
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

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
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
class _$MeasurementEntryImpl implements MeasurementEntry {
  const _$MeasurementEntryImpl(
      {required this.meta,
      required this.data,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'measurement';

  factory _$MeasurementEntryImpl.fromJson(Map<String, dynamic> json) =>
      _$$MeasurementEntryImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MeasurementEntryImpl &&
            (identical(other.meta, meta) || other.meta == meta) &&
            (identical(other.data, data) || other.data == data) &&
            (identical(other.entryText, entryText) ||
                other.entryText == entryText) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, meta, data, entryText, geolocation);

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MeasurementEntryImplCopyWith<_$MeasurementEntryImpl> get copyWith =>
      __$$MeasurementEntryImplCopyWithImpl<_$MeasurementEntryImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)
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
    required TResult Function(Metadata meta, EventData data,
            EntryText? entryText, Geolocation? geolocation)
        event,
    required TResult Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)
        checklistItem,
    required TResult Function(Metadata meta, ChecklistData data,
            EntryText? entryText, Geolocation? geolocation)
        checklist,
    required TResult Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)
        quantitative,
    required TResult Function(Metadata meta, MeasurementData data,
            EntryText? entryText, Geolocation? geolocation)
        measurement,
    required TResult Function(Metadata meta, AiResponseData data,
            EntryText? entryText, Geolocation? geolocation)
        aiResponse,
    required TResult Function(Metadata meta, WorkoutData data,
            EntryText? entryText, Geolocation? geolocation)
        workout,
    required TResult Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)
        habitCompletion,
    required TResult Function(Metadata meta, SurveyData data,
            EntryText? entryText, Geolocation? geolocation)
        survey,
  }) {
    return measurement(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)?
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
    TResult? Function(Metadata meta, EventData data, EntryText? entryText,
            Geolocation? geolocation)?
        event,
    TResult? Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)?
        checklistItem,
    TResult? Function(Metadata meta, ChecklistData data, EntryText? entryText,
            Geolocation? geolocation)?
        checklist,
    TResult? Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)?
        quantitative,
    TResult? Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult? Function(Metadata meta, AiResponseData data, EntryText? entryText,
            Geolocation? geolocation)?
        aiResponse,
    TResult? Function(Metadata meta, WorkoutData data, EntryText? entryText,
            Geolocation? geolocation)?
        workout,
    TResult? Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)?
        habitCompletion,
    TResult? Function(Metadata meta, SurveyData data, EntryText? entryText,
            Geolocation? geolocation)?
        survey,
  }) {
    return measurement?.call(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)?
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
    TResult Function(Metadata meta, EventData data, EntryText? entryText,
            Geolocation? geolocation)?
        event,
    TResult Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)?
        checklistItem,
    TResult Function(Metadata meta, ChecklistData data, EntryText? entryText,
            Geolocation? geolocation)?
        checklist,
    TResult Function(Metadata meta, QuantitativeData data, EntryText? entryText,
            Geolocation? geolocation)?
        quantitative,
    TResult Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult Function(Metadata meta, AiResponseData data, EntryText? entryText,
            Geolocation? geolocation)?
        aiResponse,
    TResult Function(Metadata meta, WorkoutData data, EntryText? entryText,
            Geolocation? geolocation)?
        workout,
    TResult Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)?
        habitCompletion,
    TResult Function(Metadata meta, SurveyData data, EntryText? entryText,
            Geolocation? geolocation)?
        survey,
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
    required TResult Function(JournalEvent value) event,
    required TResult Function(ChecklistItem value) checklistItem,
    required TResult Function(Checklist value) checklist,
    required TResult Function(QuantitativeEntry value) quantitative,
    required TResult Function(MeasurementEntry value) measurement,
    required TResult Function(AiResponseEntry value) aiResponse,
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
    TResult? Function(JournalEvent value)? event,
    TResult? Function(ChecklistItem value)? checklistItem,
    TResult? Function(Checklist value)? checklist,
    TResult? Function(QuantitativeEntry value)? quantitative,
    TResult? Function(MeasurementEntry value)? measurement,
    TResult? Function(AiResponseEntry value)? aiResponse,
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
    TResult Function(JournalEvent value)? event,
    TResult Function(ChecklistItem value)? checklistItem,
    TResult Function(Checklist value)? checklist,
    TResult Function(QuantitativeEntry value)? quantitative,
    TResult Function(MeasurementEntry value)? measurement,
    TResult Function(AiResponseEntry value)? aiResponse,
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
    return _$$MeasurementEntryImplToJson(
      this,
    );
  }
}

abstract class MeasurementEntry implements JournalEntity {
  const factory MeasurementEntry(
      {required final Metadata meta,
      required final MeasurementData data,
      final EntryText? entryText,
      final Geolocation? geolocation}) = _$MeasurementEntryImpl;

  factory MeasurementEntry.fromJson(Map<String, dynamic> json) =
      _$MeasurementEntryImpl.fromJson;

  @override
  Metadata get meta;
  MeasurementData get data;
  @override
  EntryText? get entryText;
  @override
  Geolocation? get geolocation;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MeasurementEntryImplCopyWith<_$MeasurementEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$AiResponseEntryImplCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory _$$AiResponseEntryImplCopyWith(_$AiResponseEntryImpl value,
          $Res Function(_$AiResponseEntryImpl) then) =
      __$$AiResponseEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {Metadata meta,
      AiResponseData data,
      EntryText? entryText,
      Geolocation? geolocation});

  @override
  $MetadataCopyWith<$Res> get meta;
  $AiResponseDataCopyWith<$Res> get data;
  @override
  $EntryTextCopyWith<$Res>? get entryText;
  @override
  $GeolocationCopyWith<$Res>? get geolocation;
}

/// @nodoc
class __$$AiResponseEntryImplCopyWithImpl<$Res>
    extends _$JournalEntityCopyWithImpl<$Res, _$AiResponseEntryImpl>
    implements _$$AiResponseEntryImplCopyWith<$Res> {
  __$$AiResponseEntryImplCopyWithImpl(
      _$AiResponseEntryImpl _value, $Res Function(_$AiResponseEntryImpl) _then)
      : super(_value, _then);

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = null,
    Object? data = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$AiResponseEntryImpl(
      meta: null == meta
          ? _value.meta
          : meta // ignore: cast_nullable_to_non_nullable
              as Metadata,
      data: null == data
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as AiResponseData,
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

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AiResponseDataCopyWith<$Res> get data {
    return $AiResponseDataCopyWith<$Res>(_value.data, (value) {
      return _then(_value.copyWith(data: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _$AiResponseEntryImpl implements AiResponseEntry {
  const _$AiResponseEntryImpl(
      {required this.meta,
      required this.data,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'aiResponse';

  factory _$AiResponseEntryImpl.fromJson(Map<String, dynamic> json) =>
      _$$AiResponseEntryImplFromJson(json);

  @override
  final Metadata meta;
  @override
  final AiResponseData data;
  @override
  final EntryText? entryText;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'JournalEntity.aiResponse(meta: $meta, data: $data, entryText: $entryText, geolocation: $geolocation)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AiResponseEntryImpl &&
            (identical(other.meta, meta) || other.meta == meta) &&
            (identical(other.data, data) || other.data == data) &&
            (identical(other.entryText, entryText) ||
                other.entryText == entryText) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, meta, data, entryText, geolocation);

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AiResponseEntryImplCopyWith<_$AiResponseEntryImpl> get copyWith =>
      __$$AiResponseEntryImplCopyWithImpl<_$AiResponseEntryImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)
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
    required TResult Function(Metadata meta, EventData data,
            EntryText? entryText, Geolocation? geolocation)
        event,
    required TResult Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)
        checklistItem,
    required TResult Function(Metadata meta, ChecklistData data,
            EntryText? entryText, Geolocation? geolocation)
        checklist,
    required TResult Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)
        quantitative,
    required TResult Function(Metadata meta, MeasurementData data,
            EntryText? entryText, Geolocation? geolocation)
        measurement,
    required TResult Function(Metadata meta, AiResponseData data,
            EntryText? entryText, Geolocation? geolocation)
        aiResponse,
    required TResult Function(Metadata meta, WorkoutData data,
            EntryText? entryText, Geolocation? geolocation)
        workout,
    required TResult Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)
        habitCompletion,
    required TResult Function(Metadata meta, SurveyData data,
            EntryText? entryText, Geolocation? geolocation)
        survey,
  }) {
    return aiResponse(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)?
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
    TResult? Function(Metadata meta, EventData data, EntryText? entryText,
            Geolocation? geolocation)?
        event,
    TResult? Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)?
        checklistItem,
    TResult? Function(Metadata meta, ChecklistData data, EntryText? entryText,
            Geolocation? geolocation)?
        checklist,
    TResult? Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)?
        quantitative,
    TResult? Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult? Function(Metadata meta, AiResponseData data, EntryText? entryText,
            Geolocation? geolocation)?
        aiResponse,
    TResult? Function(Metadata meta, WorkoutData data, EntryText? entryText,
            Geolocation? geolocation)?
        workout,
    TResult? Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)?
        habitCompletion,
    TResult? Function(Metadata meta, SurveyData data, EntryText? entryText,
            Geolocation? geolocation)?
        survey,
  }) {
    return aiResponse?.call(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)?
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
    TResult Function(Metadata meta, EventData data, EntryText? entryText,
            Geolocation? geolocation)?
        event,
    TResult Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)?
        checklistItem,
    TResult Function(Metadata meta, ChecklistData data, EntryText? entryText,
            Geolocation? geolocation)?
        checklist,
    TResult Function(Metadata meta, QuantitativeData data, EntryText? entryText,
            Geolocation? geolocation)?
        quantitative,
    TResult Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult Function(Metadata meta, AiResponseData data, EntryText? entryText,
            Geolocation? geolocation)?
        aiResponse,
    TResult Function(Metadata meta, WorkoutData data, EntryText? entryText,
            Geolocation? geolocation)?
        workout,
    TResult Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)?
        habitCompletion,
    TResult Function(Metadata meta, SurveyData data, EntryText? entryText,
            Geolocation? geolocation)?
        survey,
    required TResult orElse(),
  }) {
    if (aiResponse != null) {
      return aiResponse(meta, data, entryText, geolocation);
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
    required TResult Function(JournalEvent value) event,
    required TResult Function(ChecklistItem value) checklistItem,
    required TResult Function(Checklist value) checklist,
    required TResult Function(QuantitativeEntry value) quantitative,
    required TResult Function(MeasurementEntry value) measurement,
    required TResult Function(AiResponseEntry value) aiResponse,
    required TResult Function(WorkoutEntry value) workout,
    required TResult Function(HabitCompletionEntry value) habitCompletion,
    required TResult Function(SurveyEntry value) survey,
  }) {
    return aiResponse(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(JournalEntry value)? journalEntry,
    TResult? Function(JournalImage value)? journalImage,
    TResult? Function(JournalAudio value)? journalAudio,
    TResult? Function(Task value)? task,
    TResult? Function(JournalEvent value)? event,
    TResult? Function(ChecklistItem value)? checklistItem,
    TResult? Function(Checklist value)? checklist,
    TResult? Function(QuantitativeEntry value)? quantitative,
    TResult? Function(MeasurementEntry value)? measurement,
    TResult? Function(AiResponseEntry value)? aiResponse,
    TResult? Function(WorkoutEntry value)? workout,
    TResult? Function(HabitCompletionEntry value)? habitCompletion,
    TResult? Function(SurveyEntry value)? survey,
  }) {
    return aiResponse?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(JournalEntry value)? journalEntry,
    TResult Function(JournalImage value)? journalImage,
    TResult Function(JournalAudio value)? journalAudio,
    TResult Function(Task value)? task,
    TResult Function(JournalEvent value)? event,
    TResult Function(ChecklistItem value)? checklistItem,
    TResult Function(Checklist value)? checklist,
    TResult Function(QuantitativeEntry value)? quantitative,
    TResult Function(MeasurementEntry value)? measurement,
    TResult Function(AiResponseEntry value)? aiResponse,
    TResult Function(WorkoutEntry value)? workout,
    TResult Function(HabitCompletionEntry value)? habitCompletion,
    TResult Function(SurveyEntry value)? survey,
    required TResult orElse(),
  }) {
    if (aiResponse != null) {
      return aiResponse(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$AiResponseEntryImplToJson(
      this,
    );
  }
}

abstract class AiResponseEntry implements JournalEntity {
  const factory AiResponseEntry(
      {required final Metadata meta,
      required final AiResponseData data,
      final EntryText? entryText,
      final Geolocation? geolocation}) = _$AiResponseEntryImpl;

  factory AiResponseEntry.fromJson(Map<String, dynamic> json) =
      _$AiResponseEntryImpl.fromJson;

  @override
  Metadata get meta;
  AiResponseData get data;
  @override
  EntryText? get entryText;
  @override
  Geolocation? get geolocation;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AiResponseEntryImplCopyWith<_$AiResponseEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$WorkoutEntryImplCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory _$$WorkoutEntryImplCopyWith(
          _$WorkoutEntryImpl value, $Res Function(_$WorkoutEntryImpl) then) =
      __$$WorkoutEntryImplCopyWithImpl<$Res>;
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
class __$$WorkoutEntryImplCopyWithImpl<$Res>
    extends _$JournalEntityCopyWithImpl<$Res, _$WorkoutEntryImpl>
    implements _$$WorkoutEntryImplCopyWith<$Res> {
  __$$WorkoutEntryImplCopyWithImpl(
      _$WorkoutEntryImpl _value, $Res Function(_$WorkoutEntryImpl) _then)
      : super(_value, _then);

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = null,
    Object? data = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$WorkoutEntryImpl(
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

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
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
class _$WorkoutEntryImpl implements WorkoutEntry {
  const _$WorkoutEntryImpl(
      {required this.meta,
      required this.data,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'workout';

  factory _$WorkoutEntryImpl.fromJson(Map<String, dynamic> json) =>
      _$$WorkoutEntryImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WorkoutEntryImpl &&
            (identical(other.meta, meta) || other.meta == meta) &&
            (identical(other.data, data) || other.data == data) &&
            (identical(other.entryText, entryText) ||
                other.entryText == entryText) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, meta, data, entryText, geolocation);

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WorkoutEntryImplCopyWith<_$WorkoutEntryImpl> get copyWith =>
      __$$WorkoutEntryImplCopyWithImpl<_$WorkoutEntryImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)
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
    required TResult Function(Metadata meta, EventData data,
            EntryText? entryText, Geolocation? geolocation)
        event,
    required TResult Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)
        checklistItem,
    required TResult Function(Metadata meta, ChecklistData data,
            EntryText? entryText, Geolocation? geolocation)
        checklist,
    required TResult Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)
        quantitative,
    required TResult Function(Metadata meta, MeasurementData data,
            EntryText? entryText, Geolocation? geolocation)
        measurement,
    required TResult Function(Metadata meta, AiResponseData data,
            EntryText? entryText, Geolocation? geolocation)
        aiResponse,
    required TResult Function(Metadata meta, WorkoutData data,
            EntryText? entryText, Geolocation? geolocation)
        workout,
    required TResult Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)
        habitCompletion,
    required TResult Function(Metadata meta, SurveyData data,
            EntryText? entryText, Geolocation? geolocation)
        survey,
  }) {
    return workout(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)?
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
    TResult? Function(Metadata meta, EventData data, EntryText? entryText,
            Geolocation? geolocation)?
        event,
    TResult? Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)?
        checklistItem,
    TResult? Function(Metadata meta, ChecklistData data, EntryText? entryText,
            Geolocation? geolocation)?
        checklist,
    TResult? Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)?
        quantitative,
    TResult? Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult? Function(Metadata meta, AiResponseData data, EntryText? entryText,
            Geolocation? geolocation)?
        aiResponse,
    TResult? Function(Metadata meta, WorkoutData data, EntryText? entryText,
            Geolocation? geolocation)?
        workout,
    TResult? Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)?
        habitCompletion,
    TResult? Function(Metadata meta, SurveyData data, EntryText? entryText,
            Geolocation? geolocation)?
        survey,
  }) {
    return workout?.call(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)?
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
    TResult Function(Metadata meta, EventData data, EntryText? entryText,
            Geolocation? geolocation)?
        event,
    TResult Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)?
        checklistItem,
    TResult Function(Metadata meta, ChecklistData data, EntryText? entryText,
            Geolocation? geolocation)?
        checklist,
    TResult Function(Metadata meta, QuantitativeData data, EntryText? entryText,
            Geolocation? geolocation)?
        quantitative,
    TResult Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult Function(Metadata meta, AiResponseData data, EntryText? entryText,
            Geolocation? geolocation)?
        aiResponse,
    TResult Function(Metadata meta, WorkoutData data, EntryText? entryText,
            Geolocation? geolocation)?
        workout,
    TResult Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)?
        habitCompletion,
    TResult Function(Metadata meta, SurveyData data, EntryText? entryText,
            Geolocation? geolocation)?
        survey,
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
    required TResult Function(JournalEvent value) event,
    required TResult Function(ChecklistItem value) checklistItem,
    required TResult Function(Checklist value) checklist,
    required TResult Function(QuantitativeEntry value) quantitative,
    required TResult Function(MeasurementEntry value) measurement,
    required TResult Function(AiResponseEntry value) aiResponse,
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
    TResult? Function(JournalEvent value)? event,
    TResult? Function(ChecklistItem value)? checklistItem,
    TResult? Function(Checklist value)? checklist,
    TResult? Function(QuantitativeEntry value)? quantitative,
    TResult? Function(MeasurementEntry value)? measurement,
    TResult? Function(AiResponseEntry value)? aiResponse,
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
    TResult Function(JournalEvent value)? event,
    TResult Function(ChecklistItem value)? checklistItem,
    TResult Function(Checklist value)? checklist,
    TResult Function(QuantitativeEntry value)? quantitative,
    TResult Function(MeasurementEntry value)? measurement,
    TResult Function(AiResponseEntry value)? aiResponse,
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
    return _$$WorkoutEntryImplToJson(
      this,
    );
  }
}

abstract class WorkoutEntry implements JournalEntity {
  const factory WorkoutEntry(
      {required final Metadata meta,
      required final WorkoutData data,
      final EntryText? entryText,
      final Geolocation? geolocation}) = _$WorkoutEntryImpl;

  factory WorkoutEntry.fromJson(Map<String, dynamic> json) =
      _$WorkoutEntryImpl.fromJson;

  @override
  Metadata get meta;
  WorkoutData get data;
  @override
  EntryText? get entryText;
  @override
  Geolocation? get geolocation;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WorkoutEntryImplCopyWith<_$WorkoutEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$HabitCompletionEntryImplCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory _$$HabitCompletionEntryImplCopyWith(_$HabitCompletionEntryImpl value,
          $Res Function(_$HabitCompletionEntryImpl) then) =
      __$$HabitCompletionEntryImplCopyWithImpl<$Res>;
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
class __$$HabitCompletionEntryImplCopyWithImpl<$Res>
    extends _$JournalEntityCopyWithImpl<$Res, _$HabitCompletionEntryImpl>
    implements _$$HabitCompletionEntryImplCopyWith<$Res> {
  __$$HabitCompletionEntryImplCopyWithImpl(_$HabitCompletionEntryImpl _value,
      $Res Function(_$HabitCompletionEntryImpl) _then)
      : super(_value, _then);

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = null,
    Object? data = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$HabitCompletionEntryImpl(
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

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
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
class _$HabitCompletionEntryImpl implements HabitCompletionEntry {
  const _$HabitCompletionEntryImpl(
      {required this.meta,
      required this.data,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'habitCompletion';

  factory _$HabitCompletionEntryImpl.fromJson(Map<String, dynamic> json) =>
      _$$HabitCompletionEntryImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HabitCompletionEntryImpl &&
            (identical(other.meta, meta) || other.meta == meta) &&
            (identical(other.data, data) || other.data == data) &&
            (identical(other.entryText, entryText) ||
                other.entryText == entryText) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, meta, data, entryText, geolocation);

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HabitCompletionEntryImplCopyWith<_$HabitCompletionEntryImpl>
      get copyWith =>
          __$$HabitCompletionEntryImplCopyWithImpl<_$HabitCompletionEntryImpl>(
              this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)
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
    required TResult Function(Metadata meta, EventData data,
            EntryText? entryText, Geolocation? geolocation)
        event,
    required TResult Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)
        checklistItem,
    required TResult Function(Metadata meta, ChecklistData data,
            EntryText? entryText, Geolocation? geolocation)
        checklist,
    required TResult Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)
        quantitative,
    required TResult Function(Metadata meta, MeasurementData data,
            EntryText? entryText, Geolocation? geolocation)
        measurement,
    required TResult Function(Metadata meta, AiResponseData data,
            EntryText? entryText, Geolocation? geolocation)
        aiResponse,
    required TResult Function(Metadata meta, WorkoutData data,
            EntryText? entryText, Geolocation? geolocation)
        workout,
    required TResult Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)
        habitCompletion,
    required TResult Function(Metadata meta, SurveyData data,
            EntryText? entryText, Geolocation? geolocation)
        survey,
  }) {
    return habitCompletion(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)?
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
    TResult? Function(Metadata meta, EventData data, EntryText? entryText,
            Geolocation? geolocation)?
        event,
    TResult? Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)?
        checklistItem,
    TResult? Function(Metadata meta, ChecklistData data, EntryText? entryText,
            Geolocation? geolocation)?
        checklist,
    TResult? Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)?
        quantitative,
    TResult? Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult? Function(Metadata meta, AiResponseData data, EntryText? entryText,
            Geolocation? geolocation)?
        aiResponse,
    TResult? Function(Metadata meta, WorkoutData data, EntryText? entryText,
            Geolocation? geolocation)?
        workout,
    TResult? Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)?
        habitCompletion,
    TResult? Function(Metadata meta, SurveyData data, EntryText? entryText,
            Geolocation? geolocation)?
        survey,
  }) {
    return habitCompletion?.call(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)?
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
    TResult Function(Metadata meta, EventData data, EntryText? entryText,
            Geolocation? geolocation)?
        event,
    TResult Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)?
        checklistItem,
    TResult Function(Metadata meta, ChecklistData data, EntryText? entryText,
            Geolocation? geolocation)?
        checklist,
    TResult Function(Metadata meta, QuantitativeData data, EntryText? entryText,
            Geolocation? geolocation)?
        quantitative,
    TResult Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult Function(Metadata meta, AiResponseData data, EntryText? entryText,
            Geolocation? geolocation)?
        aiResponse,
    TResult Function(Metadata meta, WorkoutData data, EntryText? entryText,
            Geolocation? geolocation)?
        workout,
    TResult Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)?
        habitCompletion,
    TResult Function(Metadata meta, SurveyData data, EntryText? entryText,
            Geolocation? geolocation)?
        survey,
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
    required TResult Function(JournalEvent value) event,
    required TResult Function(ChecklistItem value) checklistItem,
    required TResult Function(Checklist value) checklist,
    required TResult Function(QuantitativeEntry value) quantitative,
    required TResult Function(MeasurementEntry value) measurement,
    required TResult Function(AiResponseEntry value) aiResponse,
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
    TResult? Function(JournalEvent value)? event,
    TResult? Function(ChecklistItem value)? checklistItem,
    TResult? Function(Checklist value)? checklist,
    TResult? Function(QuantitativeEntry value)? quantitative,
    TResult? Function(MeasurementEntry value)? measurement,
    TResult? Function(AiResponseEntry value)? aiResponse,
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
    TResult Function(JournalEvent value)? event,
    TResult Function(ChecklistItem value)? checklistItem,
    TResult Function(Checklist value)? checklist,
    TResult Function(QuantitativeEntry value)? quantitative,
    TResult Function(MeasurementEntry value)? measurement,
    TResult Function(AiResponseEntry value)? aiResponse,
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
    return _$$HabitCompletionEntryImplToJson(
      this,
    );
  }
}

abstract class HabitCompletionEntry implements JournalEntity {
  const factory HabitCompletionEntry(
      {required final Metadata meta,
      required final HabitCompletionData data,
      final EntryText? entryText,
      final Geolocation? geolocation}) = _$HabitCompletionEntryImpl;

  factory HabitCompletionEntry.fromJson(Map<String, dynamic> json) =
      _$HabitCompletionEntryImpl.fromJson;

  @override
  Metadata get meta;
  HabitCompletionData get data;
  @override
  EntryText? get entryText;
  @override
  Geolocation? get geolocation;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HabitCompletionEntryImplCopyWith<_$HabitCompletionEntryImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$SurveyEntryImplCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory _$$SurveyEntryImplCopyWith(
          _$SurveyEntryImpl value, $Res Function(_$SurveyEntryImpl) then) =
      __$$SurveyEntryImplCopyWithImpl<$Res>;
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
class __$$SurveyEntryImplCopyWithImpl<$Res>
    extends _$JournalEntityCopyWithImpl<$Res, _$SurveyEntryImpl>
    implements _$$SurveyEntryImplCopyWith<$Res> {
  __$$SurveyEntryImplCopyWithImpl(
      _$SurveyEntryImpl _value, $Res Function(_$SurveyEntryImpl) _then)
      : super(_value, _then);

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = null,
    Object? data = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$SurveyEntryImpl(
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

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
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
class _$SurveyEntryImpl implements SurveyEntry {
  const _$SurveyEntryImpl(
      {required this.meta,
      required this.data,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'survey';

  factory _$SurveyEntryImpl.fromJson(Map<String, dynamic> json) =>
      _$$SurveyEntryImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SurveyEntryImpl &&
            (identical(other.meta, meta) || other.meta == meta) &&
            (identical(other.data, data) || other.data == data) &&
            (identical(other.entryText, entryText) ||
                other.entryText == entryText) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, meta, data, entryText, geolocation);

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SurveyEntryImplCopyWith<_$SurveyEntryImpl> get copyWith =>
      __$$SurveyEntryImplCopyWithImpl<_$SurveyEntryImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)
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
    required TResult Function(Metadata meta, EventData data,
            EntryText? entryText, Geolocation? geolocation)
        event,
    required TResult Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)
        checklistItem,
    required TResult Function(Metadata meta, ChecklistData data,
            EntryText? entryText, Geolocation? geolocation)
        checklist,
    required TResult Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)
        quantitative,
    required TResult Function(Metadata meta, MeasurementData data,
            EntryText? entryText, Geolocation? geolocation)
        measurement,
    required TResult Function(Metadata meta, AiResponseData data,
            EntryText? entryText, Geolocation? geolocation)
        aiResponse,
    required TResult Function(Metadata meta, WorkoutData data,
            EntryText? entryText, Geolocation? geolocation)
        workout,
    required TResult Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)
        habitCompletion,
    required TResult Function(Metadata meta, SurveyData data,
            EntryText? entryText, Geolocation? geolocation)
        survey,
  }) {
    return survey(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)?
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
    TResult? Function(Metadata meta, EventData data, EntryText? entryText,
            Geolocation? geolocation)?
        event,
    TResult? Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)?
        checklistItem,
    TResult? Function(Metadata meta, ChecklistData data, EntryText? entryText,
            Geolocation? geolocation)?
        checklist,
    TResult? Function(Metadata meta, QuantitativeData data,
            EntryText? entryText, Geolocation? geolocation)?
        quantitative,
    TResult? Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult? Function(Metadata meta, AiResponseData data, EntryText? entryText,
            Geolocation? geolocation)?
        aiResponse,
    TResult? Function(Metadata meta, WorkoutData data, EntryText? entryText,
            Geolocation? geolocation)?
        workout,
    TResult? Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)?
        habitCompletion,
    TResult? Function(Metadata meta, SurveyData data, EntryText? entryText,
            Geolocation? geolocation)?
        survey,
  }) {
    return survey?.call(meta, data, entryText, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            Metadata meta, EntryText? entryText, Geolocation? geolocation)?
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
    TResult Function(Metadata meta, EventData data, EntryText? entryText,
            Geolocation? geolocation)?
        event,
    TResult Function(Metadata meta, ChecklistItemData data,
            EntryText? entryText, Geolocation? geolocation)?
        checklistItem,
    TResult Function(Metadata meta, ChecklistData data, EntryText? entryText,
            Geolocation? geolocation)?
        checklist,
    TResult Function(Metadata meta, QuantitativeData data, EntryText? entryText,
            Geolocation? geolocation)?
        quantitative,
    TResult Function(Metadata meta, MeasurementData data, EntryText? entryText,
            Geolocation? geolocation)?
        measurement,
    TResult Function(Metadata meta, AiResponseData data, EntryText? entryText,
            Geolocation? geolocation)?
        aiResponse,
    TResult Function(Metadata meta, WorkoutData data, EntryText? entryText,
            Geolocation? geolocation)?
        workout,
    TResult Function(Metadata meta, HabitCompletionData data,
            EntryText? entryText, Geolocation? geolocation)?
        habitCompletion,
    TResult Function(Metadata meta, SurveyData data, EntryText? entryText,
            Geolocation? geolocation)?
        survey,
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
    required TResult Function(JournalEvent value) event,
    required TResult Function(ChecklistItem value) checklistItem,
    required TResult Function(Checklist value) checklist,
    required TResult Function(QuantitativeEntry value) quantitative,
    required TResult Function(MeasurementEntry value) measurement,
    required TResult Function(AiResponseEntry value) aiResponse,
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
    TResult? Function(JournalEvent value)? event,
    TResult? Function(ChecklistItem value)? checklistItem,
    TResult? Function(Checklist value)? checklist,
    TResult? Function(QuantitativeEntry value)? quantitative,
    TResult? Function(MeasurementEntry value)? measurement,
    TResult? Function(AiResponseEntry value)? aiResponse,
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
    TResult Function(JournalEvent value)? event,
    TResult Function(ChecklistItem value)? checklistItem,
    TResult Function(Checklist value)? checklist,
    TResult Function(QuantitativeEntry value)? quantitative,
    TResult Function(MeasurementEntry value)? measurement,
    TResult Function(AiResponseEntry value)? aiResponse,
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
    return _$$SurveyEntryImplToJson(
      this,
    );
  }
}

abstract class SurveyEntry implements JournalEntity {
  const factory SurveyEntry(
      {required final Metadata meta,
      required final SurveyData data,
      final EntryText? entryText,
      final Geolocation? geolocation}) = _$SurveyEntryImpl;

  factory SurveyEntry.fromJson(Map<String, dynamic> json) =
      _$SurveyEntryImpl.fromJson;

  @override
  Metadata get meta;
  SurveyData get data;
  @override
  EntryText? get entryText;
  @override
  Geolocation? get geolocation;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SurveyEntryImplCopyWith<_$SurveyEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
