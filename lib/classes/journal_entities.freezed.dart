// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'journal_entities.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Metadata {
  String get id;
  DateTime get createdAt;
  DateTime get updatedAt;
  DateTime get dateFrom;
  DateTime get dateTo;
  String? get categoryId;
  List<String>? get tags;
  List<String>? get tagIds;
  List<String>? get labelIds;
  int? get utcOffset;
  String? get timezone;
  VectorClock? get vectorClock;
  DateTime? get deletedAt;
  EntryFlag? get flag;
  bool? get starred;
  bool? get private;

  /// Create a copy of Metadata
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MetadataCopyWith<Metadata> get copyWith =>
      _$MetadataCopyWithImpl<Metadata>(this as Metadata, _$identity);

  /// Serializes this Metadata to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Metadata &&
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
            const DeepCollectionEquality().equals(other.tags, tags) &&
            const DeepCollectionEquality().equals(other.tagIds, tagIds) &&
            const DeepCollectionEquality().equals(other.labelIds, labelIds) &&
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
      const DeepCollectionEquality().hash(tags),
      const DeepCollectionEquality().hash(tagIds),
      const DeepCollectionEquality().hash(labelIds),
      utcOffset,
      timezone,
      vectorClock,
      deletedAt,
      flag,
      starred,
      private);

  @override
  String toString() {
    return 'Metadata(id: $id, createdAt: $createdAt, updatedAt: $updatedAt, dateFrom: $dateFrom, dateTo: $dateTo, categoryId: $categoryId, tags: $tags, tagIds: $tagIds, labelIds: $labelIds, utcOffset: $utcOffset, timezone: $timezone, vectorClock: $vectorClock, deletedAt: $deletedAt, flag: $flag, starred: $starred, private: $private)';
  }
}

/// @nodoc
abstract mixin class $MetadataCopyWith<$Res> {
  factory $MetadataCopyWith(Metadata value, $Res Function(Metadata) _then) =
      _$MetadataCopyWithImpl;
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
      List<String>? labelIds,
      int? utcOffset,
      String? timezone,
      VectorClock? vectorClock,
      DateTime? deletedAt,
      EntryFlag? flag,
      bool? starred,
      bool? private});
}

/// @nodoc
class _$MetadataCopyWithImpl<$Res> implements $MetadataCopyWith<$Res> {
  _$MetadataCopyWithImpl(this._self, this._then);

  final Metadata _self;
  final $Res Function(Metadata) _then;

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
    Object? labelIds = freezed,
    Object? utcOffset = freezed,
    Object? timezone = freezed,
    Object? vectorClock = freezed,
    Object? deletedAt = freezed,
    Object? flag = freezed,
    Object? starred = freezed,
    Object? private = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateFrom: null == dateFrom
          ? _self.dateFrom
          : dateFrom // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateTo: null == dateTo
          ? _self.dateTo
          : dateTo // ignore: cast_nullable_to_non_nullable
              as DateTime,
      categoryId: freezed == categoryId
          ? _self.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String?,
      tags: freezed == tags
          ? _self.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      tagIds: freezed == tagIds
          ? _self.tagIds
          : tagIds // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      labelIds: freezed == labelIds
          ? _self.labelIds
          : labelIds // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      utcOffset: freezed == utcOffset
          ? _self.utcOffset
          : utcOffset // ignore: cast_nullable_to_non_nullable
              as int?,
      timezone: freezed == timezone
          ? _self.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      vectorClock: freezed == vectorClock
          ? _self.vectorClock
          : vectorClock // ignore: cast_nullable_to_non_nullable
              as VectorClock?,
      deletedAt: freezed == deletedAt
          ? _self.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      flag: freezed == flag
          ? _self.flag
          : flag // ignore: cast_nullable_to_non_nullable
              as EntryFlag?,
      starred: freezed == starred
          ? _self.starred
          : starred // ignore: cast_nullable_to_non_nullable
              as bool?,
      private: freezed == private
          ? _self.private
          : private // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }
}

/// Adds pattern-matching-related methods to [Metadata].
extension MetadataPatterns on Metadata {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_Metadata value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Metadata() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_Metadata value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Metadata():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_Metadata value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Metadata() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            String id,
            DateTime createdAt,
            DateTime updatedAt,
            DateTime dateFrom,
            DateTime dateTo,
            String? categoryId,
            List<String>? tags,
            List<String>? tagIds,
            List<String>? labelIds,
            int? utcOffset,
            String? timezone,
            VectorClock? vectorClock,
            DateTime? deletedAt,
            EntryFlag? flag,
            bool? starred,
            bool? private)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Metadata() when $default != null:
        return $default(
            _that.id,
            _that.createdAt,
            _that.updatedAt,
            _that.dateFrom,
            _that.dateTo,
            _that.categoryId,
            _that.tags,
            _that.tagIds,
            _that.labelIds,
            _that.utcOffset,
            _that.timezone,
            _that.vectorClock,
            _that.deletedAt,
            _that.flag,
            _that.starred,
            _that.private);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            String id,
            DateTime createdAt,
            DateTime updatedAt,
            DateTime dateFrom,
            DateTime dateTo,
            String? categoryId,
            List<String>? tags,
            List<String>? tagIds,
            List<String>? labelIds,
            int? utcOffset,
            String? timezone,
            VectorClock? vectorClock,
            DateTime? deletedAt,
            EntryFlag? flag,
            bool? starred,
            bool? private)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Metadata():
        return $default(
            _that.id,
            _that.createdAt,
            _that.updatedAt,
            _that.dateFrom,
            _that.dateTo,
            _that.categoryId,
            _that.tags,
            _that.tagIds,
            _that.labelIds,
            _that.utcOffset,
            _that.timezone,
            _that.vectorClock,
            _that.deletedAt,
            _that.flag,
            _that.starred,
            _that.private);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            String id,
            DateTime createdAt,
            DateTime updatedAt,
            DateTime dateFrom,
            DateTime dateTo,
            String? categoryId,
            List<String>? tags,
            List<String>? tagIds,
            List<String>? labelIds,
            int? utcOffset,
            String? timezone,
            VectorClock? vectorClock,
            DateTime? deletedAt,
            EntryFlag? flag,
            bool? starred,
            bool? private)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Metadata() when $default != null:
        return $default(
            _that.id,
            _that.createdAt,
            _that.updatedAt,
            _that.dateFrom,
            _that.dateTo,
            _that.categoryId,
            _that.tags,
            _that.tagIds,
            _that.labelIds,
            _that.utcOffset,
            _that.timezone,
            _that.vectorClock,
            _that.deletedAt,
            _that.flag,
            _that.starred,
            _that.private);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Metadata implements Metadata {
  const _Metadata(
      {required this.id,
      required this.createdAt,
      required this.updatedAt,
      required this.dateFrom,
      required this.dateTo,
      this.categoryId,
      final List<String>? tags,
      final List<String>? tagIds,
      final List<String>? labelIds,
      this.utcOffset,
      this.timezone,
      this.vectorClock,
      this.deletedAt,
      this.flag,
      this.starred,
      this.private})
      : _tags = tags,
        _tagIds = tagIds,
        _labelIds = labelIds;
  factory _Metadata.fromJson(Map<String, dynamic> json) =>
      _$MetadataFromJson(json);

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

  final List<String>? _labelIds;
  @override
  List<String>? get labelIds {
    final value = _labelIds;
    if (value == null) return null;
    if (_labelIds is EqualUnmodifiableListView) return _labelIds;
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

  /// Create a copy of Metadata
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$MetadataCopyWith<_Metadata> get copyWith =>
      __$MetadataCopyWithImpl<_Metadata>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$MetadataToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Metadata &&
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
            const DeepCollectionEquality().equals(other._labelIds, _labelIds) &&
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
      const DeepCollectionEquality().hash(_labelIds),
      utcOffset,
      timezone,
      vectorClock,
      deletedAt,
      flag,
      starred,
      private);

  @override
  String toString() {
    return 'Metadata(id: $id, createdAt: $createdAt, updatedAt: $updatedAt, dateFrom: $dateFrom, dateTo: $dateTo, categoryId: $categoryId, tags: $tags, tagIds: $tagIds, labelIds: $labelIds, utcOffset: $utcOffset, timezone: $timezone, vectorClock: $vectorClock, deletedAt: $deletedAt, flag: $flag, starred: $starred, private: $private)';
  }
}

/// @nodoc
abstract mixin class _$MetadataCopyWith<$Res>
    implements $MetadataCopyWith<$Res> {
  factory _$MetadataCopyWith(_Metadata value, $Res Function(_Metadata) _then) =
      __$MetadataCopyWithImpl;
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
      List<String>? labelIds,
      int? utcOffset,
      String? timezone,
      VectorClock? vectorClock,
      DateTime? deletedAt,
      EntryFlag? flag,
      bool? starred,
      bool? private});
}

/// @nodoc
class __$MetadataCopyWithImpl<$Res> implements _$MetadataCopyWith<$Res> {
  __$MetadataCopyWithImpl(this._self, this._then);

  final _Metadata _self;
  final $Res Function(_Metadata) _then;

  /// Create a copy of Metadata
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? dateFrom = null,
    Object? dateTo = null,
    Object? categoryId = freezed,
    Object? tags = freezed,
    Object? tagIds = freezed,
    Object? labelIds = freezed,
    Object? utcOffset = freezed,
    Object? timezone = freezed,
    Object? vectorClock = freezed,
    Object? deletedAt = freezed,
    Object? flag = freezed,
    Object? starred = freezed,
    Object? private = freezed,
  }) {
    return _then(_Metadata(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateFrom: null == dateFrom
          ? _self.dateFrom
          : dateFrom // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateTo: null == dateTo
          ? _self.dateTo
          : dateTo // ignore: cast_nullable_to_non_nullable
              as DateTime,
      categoryId: freezed == categoryId
          ? _self.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String?,
      tags: freezed == tags
          ? _self._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      tagIds: freezed == tagIds
          ? _self._tagIds
          : tagIds // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      labelIds: freezed == labelIds
          ? _self._labelIds
          : labelIds // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      utcOffset: freezed == utcOffset
          ? _self.utcOffset
          : utcOffset // ignore: cast_nullable_to_non_nullable
              as int?,
      timezone: freezed == timezone
          ? _self.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      vectorClock: freezed == vectorClock
          ? _self.vectorClock
          : vectorClock // ignore: cast_nullable_to_non_nullable
              as VectorClock?,
      deletedAt: freezed == deletedAt
          ? _self.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      flag: freezed == flag
          ? _self.flag
          : flag // ignore: cast_nullable_to_non_nullable
              as EntryFlag?,
      starred: freezed == starred
          ? _self.starred
          : starred // ignore: cast_nullable_to_non_nullable
              as bool?,
      private: freezed == private
          ? _self.private
          : private // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }
}

/// @nodoc
mixin _$ImageData {
  DateTime get capturedAt;
  String get imageId;
  String get imageFile;
  String get imageDirectory;
  Geolocation? get geolocation;

  /// Create a copy of ImageData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ImageDataCopyWith<ImageData> get copyWith =>
      _$ImageDataCopyWithImpl<ImageData>(this as ImageData, _$identity);

  /// Serializes this ImageData to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ImageData &&
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

  @override
  String toString() {
    return 'ImageData(capturedAt: $capturedAt, imageId: $imageId, imageFile: $imageFile, imageDirectory: $imageDirectory, geolocation: $geolocation)';
  }
}

/// @nodoc
abstract mixin class $ImageDataCopyWith<$Res> {
  factory $ImageDataCopyWith(ImageData value, $Res Function(ImageData) _then) =
      _$ImageDataCopyWithImpl;
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
class _$ImageDataCopyWithImpl<$Res> implements $ImageDataCopyWith<$Res> {
  _$ImageDataCopyWithImpl(this._self, this._then);

  final ImageData _self;
  final $Res Function(ImageData) _then;

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
    return _then(_self.copyWith(
      capturedAt: null == capturedAt
          ? _self.capturedAt
          : capturedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      imageId: null == imageId
          ? _self.imageId
          : imageId // ignore: cast_nullable_to_non_nullable
              as String,
      imageFile: null == imageFile
          ? _self.imageFile
          : imageFile // ignore: cast_nullable_to_non_nullable
              as String,
      imageDirectory: null == imageDirectory
          ? _self.imageDirectory
          : imageDirectory // ignore: cast_nullable_to_non_nullable
              as String,
      geolocation: freezed == geolocation
          ? _self.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }

  /// Create a copy of ImageData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GeolocationCopyWith<$Res>? get geolocation {
    if (_self.geolocation == null) {
      return null;
    }

    return $GeolocationCopyWith<$Res>(_self.geolocation!, (value) {
      return _then(_self.copyWith(geolocation: value));
    });
  }
}

/// Adds pattern-matching-related methods to [ImageData].
extension ImageDataPatterns on ImageData {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_ImageData value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ImageData() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_ImageData value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ImageData():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_ImageData value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ImageData() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(DateTime capturedAt, String imageId, String imageFile,
            String imageDirectory, Geolocation? geolocation)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ImageData() when $default != null:
        return $default(_that.capturedAt, _that.imageId, _that.imageFile,
            _that.imageDirectory, _that.geolocation);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(DateTime capturedAt, String imageId, String imageFile,
            String imageDirectory, Geolocation? geolocation)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ImageData():
        return $default(_that.capturedAt, _that.imageId, _that.imageFile,
            _that.imageDirectory, _that.geolocation);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(DateTime capturedAt, String imageId, String imageFile,
            String imageDirectory, Geolocation? geolocation)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ImageData() when $default != null:
        return $default(_that.capturedAt, _that.imageId, _that.imageFile,
            _that.imageDirectory, _that.geolocation);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ImageData implements ImageData {
  const _ImageData(
      {required this.capturedAt,
      required this.imageId,
      required this.imageFile,
      required this.imageDirectory,
      this.geolocation});
  factory _ImageData.fromJson(Map<String, dynamic> json) =>
      _$ImageDataFromJson(json);

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

  /// Create a copy of ImageData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ImageDataCopyWith<_ImageData> get copyWith =>
      __$ImageDataCopyWithImpl<_ImageData>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ImageDataToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ImageData &&
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

  @override
  String toString() {
    return 'ImageData(capturedAt: $capturedAt, imageId: $imageId, imageFile: $imageFile, imageDirectory: $imageDirectory, geolocation: $geolocation)';
  }
}

/// @nodoc
abstract mixin class _$ImageDataCopyWith<$Res>
    implements $ImageDataCopyWith<$Res> {
  factory _$ImageDataCopyWith(
          _ImageData value, $Res Function(_ImageData) _then) =
      __$ImageDataCopyWithImpl;
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
class __$ImageDataCopyWithImpl<$Res> implements _$ImageDataCopyWith<$Res> {
  __$ImageDataCopyWithImpl(this._self, this._then);

  final _ImageData _self;
  final $Res Function(_ImageData) _then;

  /// Create a copy of ImageData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? capturedAt = null,
    Object? imageId = null,
    Object? imageFile = null,
    Object? imageDirectory = null,
    Object? geolocation = freezed,
  }) {
    return _then(_ImageData(
      capturedAt: null == capturedAt
          ? _self.capturedAt
          : capturedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      imageId: null == imageId
          ? _self.imageId
          : imageId // ignore: cast_nullable_to_non_nullable
              as String,
      imageFile: null == imageFile
          ? _self.imageFile
          : imageFile // ignore: cast_nullable_to_non_nullable
              as String,
      imageDirectory: null == imageDirectory
          ? _self.imageDirectory
          : imageDirectory // ignore: cast_nullable_to_non_nullable
              as String,
      geolocation: freezed == geolocation
          ? _self.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }

  /// Create a copy of ImageData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GeolocationCopyWith<$Res>? get geolocation {
    if (_self.geolocation == null) {
      return null;
    }

    return $GeolocationCopyWith<$Res>(_self.geolocation!, (value) {
      return _then(_self.copyWith(geolocation: value));
    });
  }
}

/// @nodoc
mixin _$AudioData {
  DateTime get dateFrom;
  DateTime get dateTo;
  String get audioFile;
  String get audioDirectory;
  Duration get duration;
  bool get autoTranscribeWasActive;
  String? get language;
  List<AudioTranscript>? get transcripts;

  /// Create a copy of AudioData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AudioDataCopyWith<AudioData> get copyWith =>
      _$AudioDataCopyWithImpl<AudioData>(this as AudioData, _$identity);

  /// Serializes this AudioData to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AudioData &&
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
                .equals(other.transcripts, transcripts));
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
      const DeepCollectionEquality().hash(transcripts));

  @override
  String toString() {
    return 'AudioData(dateFrom: $dateFrom, dateTo: $dateTo, audioFile: $audioFile, audioDirectory: $audioDirectory, duration: $duration, autoTranscribeWasActive: $autoTranscribeWasActive, language: $language, transcripts: $transcripts)';
  }
}

/// @nodoc
abstract mixin class $AudioDataCopyWith<$Res> {
  factory $AudioDataCopyWith(AudioData value, $Res Function(AudioData) _then) =
      _$AudioDataCopyWithImpl;
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
class _$AudioDataCopyWithImpl<$Res> implements $AudioDataCopyWith<$Res> {
  _$AudioDataCopyWithImpl(this._self, this._then);

  final AudioData _self;
  final $Res Function(AudioData) _then;

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
    return _then(_self.copyWith(
      dateFrom: null == dateFrom
          ? _self.dateFrom
          : dateFrom // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateTo: null == dateTo
          ? _self.dateTo
          : dateTo // ignore: cast_nullable_to_non_nullable
              as DateTime,
      audioFile: null == audioFile
          ? _self.audioFile
          : audioFile // ignore: cast_nullable_to_non_nullable
              as String,
      audioDirectory: null == audioDirectory
          ? _self.audioDirectory
          : audioDirectory // ignore: cast_nullable_to_non_nullable
              as String,
      duration: null == duration
          ? _self.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as Duration,
      autoTranscribeWasActive: null == autoTranscribeWasActive
          ? _self.autoTranscribeWasActive
          : autoTranscribeWasActive // ignore: cast_nullable_to_non_nullable
              as bool,
      language: freezed == language
          ? _self.language
          : language // ignore: cast_nullable_to_non_nullable
              as String?,
      transcripts: freezed == transcripts
          ? _self.transcripts
          : transcripts // ignore: cast_nullable_to_non_nullable
              as List<AudioTranscript>?,
    ));
  }
}

/// Adds pattern-matching-related methods to [AudioData].
extension AudioDataPatterns on AudioData {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_AudioData value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AudioData() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_AudioData value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AudioData():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_AudioData value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AudioData() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            DateTime dateFrom,
            DateTime dateTo,
            String audioFile,
            String audioDirectory,
            Duration duration,
            bool autoTranscribeWasActive,
            String? language,
            List<AudioTranscript>? transcripts)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AudioData() when $default != null:
        return $default(
            _that.dateFrom,
            _that.dateTo,
            _that.audioFile,
            _that.audioDirectory,
            _that.duration,
            _that.autoTranscribeWasActive,
            _that.language,
            _that.transcripts);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            DateTime dateFrom,
            DateTime dateTo,
            String audioFile,
            String audioDirectory,
            Duration duration,
            bool autoTranscribeWasActive,
            String? language,
            List<AudioTranscript>? transcripts)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AudioData():
        return $default(
            _that.dateFrom,
            _that.dateTo,
            _that.audioFile,
            _that.audioDirectory,
            _that.duration,
            _that.autoTranscribeWasActive,
            _that.language,
            _that.transcripts);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            DateTime dateFrom,
            DateTime dateTo,
            String audioFile,
            String audioDirectory,
            Duration duration,
            bool autoTranscribeWasActive,
            String? language,
            List<AudioTranscript>? transcripts)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AudioData() when $default != null:
        return $default(
            _that.dateFrom,
            _that.dateTo,
            _that.audioFile,
            _that.audioDirectory,
            _that.duration,
            _that.autoTranscribeWasActive,
            _that.language,
            _that.transcripts);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AudioData implements AudioData {
  const _AudioData(
      {required this.dateFrom,
      required this.dateTo,
      required this.audioFile,
      required this.audioDirectory,
      required this.duration,
      this.autoTranscribeWasActive = false,
      this.language,
      final List<AudioTranscript>? transcripts})
      : _transcripts = transcripts;
  factory _AudioData.fromJson(Map<String, dynamic> json) =>
      _$AudioDataFromJson(json);

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

  /// Create a copy of AudioData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AudioDataCopyWith<_AudioData> get copyWith =>
      __$AudioDataCopyWithImpl<_AudioData>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AudioDataToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AudioData &&
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

  @override
  String toString() {
    return 'AudioData(dateFrom: $dateFrom, dateTo: $dateTo, audioFile: $audioFile, audioDirectory: $audioDirectory, duration: $duration, autoTranscribeWasActive: $autoTranscribeWasActive, language: $language, transcripts: $transcripts)';
  }
}

/// @nodoc
abstract mixin class _$AudioDataCopyWith<$Res>
    implements $AudioDataCopyWith<$Res> {
  factory _$AudioDataCopyWith(
          _AudioData value, $Res Function(_AudioData) _then) =
      __$AudioDataCopyWithImpl;
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
class __$AudioDataCopyWithImpl<$Res> implements _$AudioDataCopyWith<$Res> {
  __$AudioDataCopyWithImpl(this._self, this._then);

  final _AudioData _self;
  final $Res Function(_AudioData) _then;

  /// Create a copy of AudioData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
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
    return _then(_AudioData(
      dateFrom: null == dateFrom
          ? _self.dateFrom
          : dateFrom // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateTo: null == dateTo
          ? _self.dateTo
          : dateTo // ignore: cast_nullable_to_non_nullable
              as DateTime,
      audioFile: null == audioFile
          ? _self.audioFile
          : audioFile // ignore: cast_nullable_to_non_nullable
              as String,
      audioDirectory: null == audioDirectory
          ? _self.audioDirectory
          : audioDirectory // ignore: cast_nullable_to_non_nullable
              as String,
      duration: null == duration
          ? _self.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as Duration,
      autoTranscribeWasActive: null == autoTranscribeWasActive
          ? _self.autoTranscribeWasActive
          : autoTranscribeWasActive // ignore: cast_nullable_to_non_nullable
              as bool,
      language: freezed == language
          ? _self.language
          : language // ignore: cast_nullable_to_non_nullable
              as String?,
      transcripts: freezed == transcripts
          ? _self._transcripts
          : transcripts // ignore: cast_nullable_to_non_nullable
              as List<AudioTranscript>?,
    ));
  }
}

/// @nodoc
mixin _$AudioTranscript {
  DateTime get created;
  String get library;
  String get model;
  String get detectedLanguage;
  String get transcript;
  Duration? get processingTime;

  /// Create a copy of AudioTranscript
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AudioTranscriptCopyWith<AudioTranscript> get copyWith =>
      _$AudioTranscriptCopyWithImpl<AudioTranscript>(
          this as AudioTranscript, _$identity);

  /// Serializes this AudioTranscript to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AudioTranscript &&
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

  @override
  String toString() {
    return 'AudioTranscript(created: $created, library: $library, model: $model, detectedLanguage: $detectedLanguage, transcript: $transcript, processingTime: $processingTime)';
  }
}

/// @nodoc
abstract mixin class $AudioTranscriptCopyWith<$Res> {
  factory $AudioTranscriptCopyWith(
          AudioTranscript value, $Res Function(AudioTranscript) _then) =
      _$AudioTranscriptCopyWithImpl;
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
class _$AudioTranscriptCopyWithImpl<$Res>
    implements $AudioTranscriptCopyWith<$Res> {
  _$AudioTranscriptCopyWithImpl(this._self, this._then);

  final AudioTranscript _self;
  final $Res Function(AudioTranscript) _then;

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
    return _then(_self.copyWith(
      created: null == created
          ? _self.created
          : created // ignore: cast_nullable_to_non_nullable
              as DateTime,
      library: null == library
          ? _self.library
          : library // ignore: cast_nullable_to_non_nullable
              as String,
      model: null == model
          ? _self.model
          : model // ignore: cast_nullable_to_non_nullable
              as String,
      detectedLanguage: null == detectedLanguage
          ? _self.detectedLanguage
          : detectedLanguage // ignore: cast_nullable_to_non_nullable
              as String,
      transcript: null == transcript
          ? _self.transcript
          : transcript // ignore: cast_nullable_to_non_nullable
              as String,
      processingTime: freezed == processingTime
          ? _self.processingTime
          : processingTime // ignore: cast_nullable_to_non_nullable
              as Duration?,
    ));
  }
}

/// Adds pattern-matching-related methods to [AudioTranscript].
extension AudioTranscriptPatterns on AudioTranscript {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_AudioTranscript value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AudioTranscript() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_AudioTranscript value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AudioTranscript():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_AudioTranscript value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AudioTranscript() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            DateTime created,
            String library,
            String model,
            String detectedLanguage,
            String transcript,
            Duration? processingTime)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AudioTranscript() when $default != null:
        return $default(_that.created, _that.library, _that.model,
            _that.detectedLanguage, _that.transcript, _that.processingTime);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            DateTime created,
            String library,
            String model,
            String detectedLanguage,
            String transcript,
            Duration? processingTime)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AudioTranscript():
        return $default(_that.created, _that.library, _that.model,
            _that.detectedLanguage, _that.transcript, _that.processingTime);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            DateTime created,
            String library,
            String model,
            String detectedLanguage,
            String transcript,
            Duration? processingTime)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AudioTranscript() when $default != null:
        return $default(_that.created, _that.library, _that.model,
            _that.detectedLanguage, _that.transcript, _that.processingTime);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AudioTranscript implements AudioTranscript {
  const _AudioTranscript(
      {required this.created,
      required this.library,
      required this.model,
      required this.detectedLanguage,
      required this.transcript,
      this.processingTime});
  factory _AudioTranscript.fromJson(Map<String, dynamic> json) =>
      _$AudioTranscriptFromJson(json);

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

  /// Create a copy of AudioTranscript
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AudioTranscriptCopyWith<_AudioTranscript> get copyWith =>
      __$AudioTranscriptCopyWithImpl<_AudioTranscript>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AudioTranscriptToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AudioTranscript &&
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

  @override
  String toString() {
    return 'AudioTranscript(created: $created, library: $library, model: $model, detectedLanguage: $detectedLanguage, transcript: $transcript, processingTime: $processingTime)';
  }
}

/// @nodoc
abstract mixin class _$AudioTranscriptCopyWith<$Res>
    implements $AudioTranscriptCopyWith<$Res> {
  factory _$AudioTranscriptCopyWith(
          _AudioTranscript value, $Res Function(_AudioTranscript) _then) =
      __$AudioTranscriptCopyWithImpl;
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
class __$AudioTranscriptCopyWithImpl<$Res>
    implements _$AudioTranscriptCopyWith<$Res> {
  __$AudioTranscriptCopyWithImpl(this._self, this._then);

  final _AudioTranscript _self;
  final $Res Function(_AudioTranscript) _then;

  /// Create a copy of AudioTranscript
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? created = null,
    Object? library = null,
    Object? model = null,
    Object? detectedLanguage = null,
    Object? transcript = null,
    Object? processingTime = freezed,
  }) {
    return _then(_AudioTranscript(
      created: null == created
          ? _self.created
          : created // ignore: cast_nullable_to_non_nullable
              as DateTime,
      library: null == library
          ? _self.library
          : library // ignore: cast_nullable_to_non_nullable
              as String,
      model: null == model
          ? _self.model
          : model // ignore: cast_nullable_to_non_nullable
              as String,
      detectedLanguage: null == detectedLanguage
          ? _self.detectedLanguage
          : detectedLanguage // ignore: cast_nullable_to_non_nullable
              as String,
      transcript: null == transcript
          ? _self.transcript
          : transcript // ignore: cast_nullable_to_non_nullable
              as String,
      processingTime: freezed == processingTime
          ? _self.processingTime
          : processingTime // ignore: cast_nullable_to_non_nullable
              as Duration?,
    ));
  }
}

/// @nodoc
mixin _$SurveyData {
  RPTaskResult get taskResult;
  Map<String, Set<String>> get scoreDefinitions;
  Map<String, int> get calculatedScores;

  /// Create a copy of SurveyData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SurveyDataCopyWith<SurveyData> get copyWith =>
      _$SurveyDataCopyWithImpl<SurveyData>(this as SurveyData, _$identity);

  /// Serializes this SurveyData to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SurveyData &&
            (identical(other.taskResult, taskResult) ||
                other.taskResult == taskResult) &&
            const DeepCollectionEquality()
                .equals(other.scoreDefinitions, scoreDefinitions) &&
            const DeepCollectionEquality()
                .equals(other.calculatedScores, calculatedScores));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      taskResult,
      const DeepCollectionEquality().hash(scoreDefinitions),
      const DeepCollectionEquality().hash(calculatedScores));

  @override
  String toString() {
    return 'SurveyData(taskResult: $taskResult, scoreDefinitions: $scoreDefinitions, calculatedScores: $calculatedScores)';
  }
}

/// @nodoc
abstract mixin class $SurveyDataCopyWith<$Res> {
  factory $SurveyDataCopyWith(
          SurveyData value, $Res Function(SurveyData) _then) =
      _$SurveyDataCopyWithImpl;
  @useResult
  $Res call(
      {RPTaskResult taskResult,
      Map<String, Set<String>> scoreDefinitions,
      Map<String, int> calculatedScores});
}

/// @nodoc
class _$SurveyDataCopyWithImpl<$Res> implements $SurveyDataCopyWith<$Res> {
  _$SurveyDataCopyWithImpl(this._self, this._then);

  final SurveyData _self;
  final $Res Function(SurveyData) _then;

  /// Create a copy of SurveyData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? taskResult = null,
    Object? scoreDefinitions = null,
    Object? calculatedScores = null,
  }) {
    return _then(_self.copyWith(
      taskResult: null == taskResult
          ? _self.taskResult
          : taskResult // ignore: cast_nullable_to_non_nullable
              as RPTaskResult,
      scoreDefinitions: null == scoreDefinitions
          ? _self.scoreDefinitions
          : scoreDefinitions // ignore: cast_nullable_to_non_nullable
              as Map<String, Set<String>>,
      calculatedScores: null == calculatedScores
          ? _self.calculatedScores
          : calculatedScores // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
    ));
  }
}

/// Adds pattern-matching-related methods to [SurveyData].
extension SurveyDataPatterns on SurveyData {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_SurveyData value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SurveyData() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_SurveyData value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SurveyData():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_SurveyData value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SurveyData() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            RPTaskResult taskResult,
            Map<String, Set<String>> scoreDefinitions,
            Map<String, int> calculatedScores)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SurveyData() when $default != null:
        return $default(
            _that.taskResult, _that.scoreDefinitions, _that.calculatedScores);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            RPTaskResult taskResult,
            Map<String, Set<String>> scoreDefinitions,
            Map<String, int> calculatedScores)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SurveyData():
        return $default(
            _that.taskResult, _that.scoreDefinitions, _that.calculatedScores);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            RPTaskResult taskResult,
            Map<String, Set<String>> scoreDefinitions,
            Map<String, int> calculatedScores)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SurveyData() when $default != null:
        return $default(
            _that.taskResult, _that.scoreDefinitions, _that.calculatedScores);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SurveyData implements SurveyData {
  const _SurveyData(
      {required this.taskResult,
      required final Map<String, Set<String>> scoreDefinitions,
      required final Map<String, int> calculatedScores})
      : _scoreDefinitions = scoreDefinitions,
        _calculatedScores = calculatedScores;
  factory _SurveyData.fromJson(Map<String, dynamic> json) =>
      _$SurveyDataFromJson(json);

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

  /// Create a copy of SurveyData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SurveyDataCopyWith<_SurveyData> get copyWith =>
      __$SurveyDataCopyWithImpl<_SurveyData>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SurveyDataToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SurveyData &&
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

  @override
  String toString() {
    return 'SurveyData(taskResult: $taskResult, scoreDefinitions: $scoreDefinitions, calculatedScores: $calculatedScores)';
  }
}

/// @nodoc
abstract mixin class _$SurveyDataCopyWith<$Res>
    implements $SurveyDataCopyWith<$Res> {
  factory _$SurveyDataCopyWith(
          _SurveyData value, $Res Function(_SurveyData) _then) =
      __$SurveyDataCopyWithImpl;
  @override
  @useResult
  $Res call(
      {RPTaskResult taskResult,
      Map<String, Set<String>> scoreDefinitions,
      Map<String, int> calculatedScores});
}

/// @nodoc
class __$SurveyDataCopyWithImpl<$Res> implements _$SurveyDataCopyWith<$Res> {
  __$SurveyDataCopyWithImpl(this._self, this._then);

  final _SurveyData _self;
  final $Res Function(_SurveyData) _then;

  /// Create a copy of SurveyData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? taskResult = null,
    Object? scoreDefinitions = null,
    Object? calculatedScores = null,
  }) {
    return _then(_SurveyData(
      taskResult: null == taskResult
          ? _self.taskResult
          : taskResult // ignore: cast_nullable_to_non_nullable
              as RPTaskResult,
      scoreDefinitions: null == scoreDefinitions
          ? _self._scoreDefinitions
          : scoreDefinitions // ignore: cast_nullable_to_non_nullable
              as Map<String, Set<String>>,
      calculatedScores: null == calculatedScores
          ? _self._calculatedScores
          : calculatedScores // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
    ));
  }
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
  Metadata get meta;
  EntryText? get entryText;
  Geolocation? get geolocation;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $JournalEntityCopyWith<JournalEntity> get copyWith =>
      _$JournalEntityCopyWithImpl<JournalEntity>(
          this as JournalEntity, _$identity);

  /// Serializes this JournalEntity to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is JournalEntity &&
            (identical(other.meta, meta) || other.meta == meta) &&
            (identical(other.entryText, entryText) ||
                other.entryText == entryText) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, meta, entryText, geolocation);

  @override
  String toString() {
    return 'JournalEntity(meta: $meta, entryText: $entryText, geolocation: $geolocation)';
  }
}

/// @nodoc
abstract mixin class $JournalEntityCopyWith<$Res> {
  factory $JournalEntityCopyWith(
          JournalEntity value, $Res Function(JournalEntity) _then) =
      _$JournalEntityCopyWithImpl;
  @useResult
  $Res call({Metadata meta, EntryText? entryText, Geolocation? geolocation});

  $MetadataCopyWith<$Res> get meta;
  $EntryTextCopyWith<$Res>? get entryText;
  $GeolocationCopyWith<$Res>? get geolocation;
}

/// @nodoc
class _$JournalEntityCopyWithImpl<$Res>
    implements $JournalEntityCopyWith<$Res> {
  _$JournalEntityCopyWithImpl(this._self, this._then);

  final JournalEntity _self;
  final $Res Function(JournalEntity) _then;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_self.copyWith(
      meta: null == meta
          ? _self.meta
          : meta // ignore: cast_nullable_to_non_nullable
              as Metadata,
      entryText: freezed == entryText
          ? _self.entryText
          : entryText // ignore: cast_nullable_to_non_nullable
              as EntryText?,
      geolocation: freezed == geolocation
          ? _self.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MetadataCopyWith<$Res> get meta {
    return $MetadataCopyWith<$Res>(_self.meta, (value) {
      return _then(_self.copyWith(meta: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $EntryTextCopyWith<$Res>? get entryText {
    if (_self.entryText == null) {
      return null;
    }

    return $EntryTextCopyWith<$Res>(_self.entryText!, (value) {
      return _then(_self.copyWith(entryText: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GeolocationCopyWith<$Res>? get geolocation {
    if (_self.geolocation == null) {
      return null;
    }

    return $GeolocationCopyWith<$Res>(_self.geolocation!, (value) {
      return _then(_self.copyWith(geolocation: value));
    });
  }
}

/// Adds pattern-matching-related methods to [JournalEntity].
extension JournalEntityPatterns on JournalEntity {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

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
    final _that = this;
    switch (_that) {
      case JournalEntry() when journalEntry != null:
        return journalEntry(_that);
      case JournalImage() when journalImage != null:
        return journalImage(_that);
      case JournalAudio() when journalAudio != null:
        return journalAudio(_that);
      case Task() when task != null:
        return task(_that);
      case JournalEvent() when event != null:
        return event(_that);
      case ChecklistItem() when checklistItem != null:
        return checklistItem(_that);
      case Checklist() when checklist != null:
        return checklist(_that);
      case QuantitativeEntry() when quantitative != null:
        return quantitative(_that);
      case MeasurementEntry() when measurement != null:
        return measurement(_that);
      case AiResponseEntry() when aiResponse != null:
        return aiResponse(_that);
      case WorkoutEntry() when workout != null:
        return workout(_that);
      case HabitCompletionEntry() when habitCompletion != null:
        return habitCompletion(_that);
      case SurveyEntry() when survey != null:
        return survey(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

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
    final _that = this;
    switch (_that) {
      case JournalEntry():
        return journalEntry(_that);
      case JournalImage():
        return journalImage(_that);
      case JournalAudio():
        return journalAudio(_that);
      case Task():
        return task(_that);
      case JournalEvent():
        return event(_that);
      case ChecklistItem():
        return checklistItem(_that);
      case Checklist():
        return checklist(_that);
      case QuantitativeEntry():
        return quantitative(_that);
      case MeasurementEntry():
        return measurement(_that);
      case AiResponseEntry():
        return aiResponse(_that);
      case WorkoutEntry():
        return workout(_that);
      case HabitCompletionEntry():
        return habitCompletion(_that);
      case SurveyEntry():
        return survey(_that);
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

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
    final _that = this;
    switch (_that) {
      case JournalEntry() when journalEntry != null:
        return journalEntry(_that);
      case JournalImage() when journalImage != null:
        return journalImage(_that);
      case JournalAudio() when journalAudio != null:
        return journalAudio(_that);
      case Task() when task != null:
        return task(_that);
      case JournalEvent() when event != null:
        return event(_that);
      case ChecklistItem() when checklistItem != null:
        return checklistItem(_that);
      case Checklist() when checklist != null:
        return checklist(_that);
      case QuantitativeEntry() when quantitative != null:
        return quantitative(_that);
      case MeasurementEntry() when measurement != null:
        return measurement(_that);
      case AiResponseEntry() when aiResponse != null:
        return aiResponse(_that);
      case WorkoutEntry() when workout != null:
        return workout(_that);
      case HabitCompletionEntry() when habitCompletion != null:
        return habitCompletion(_that);
      case SurveyEntry() when survey != null:
        return survey(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

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
    final _that = this;
    switch (_that) {
      case JournalEntry() when journalEntry != null:
        return journalEntry(_that.meta, _that.entryText, _that.geolocation);
      case JournalImage() when journalImage != null:
        return journalImage(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
      case JournalAudio() when journalAudio != null:
        return journalAudio(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
      case Task() when task != null:
        return task(_that.meta, _that.data, _that.entryText, _that.geolocation);
      case JournalEvent() when event != null:
        return event(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
      case ChecklistItem() when checklistItem != null:
        return checklistItem(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
      case Checklist() when checklist != null:
        return checklist(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
      case QuantitativeEntry() when quantitative != null:
        return quantitative(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
      case MeasurementEntry() when measurement != null:
        return measurement(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
      case AiResponseEntry() when aiResponse != null:
        return aiResponse(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
      case WorkoutEntry() when workout != null:
        return workout(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
      case HabitCompletionEntry() when habitCompletion != null:
        return habitCompletion(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
      case SurveyEntry() when survey != null:
        return survey(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

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
    final _that = this;
    switch (_that) {
      case JournalEntry():
        return journalEntry(_that.meta, _that.entryText, _that.geolocation);
      case JournalImage():
        return journalImage(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
      case JournalAudio():
        return journalAudio(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
      case Task():
        return task(_that.meta, _that.data, _that.entryText, _that.geolocation);
      case JournalEvent():
        return event(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
      case ChecklistItem():
        return checklistItem(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
      case Checklist():
        return checklist(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
      case QuantitativeEntry():
        return quantitative(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
      case MeasurementEntry():
        return measurement(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
      case AiResponseEntry():
        return aiResponse(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
      case WorkoutEntry():
        return workout(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
      case HabitCompletionEntry():
        return habitCompletion(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
      case SurveyEntry():
        return survey(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

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
    final _that = this;
    switch (_that) {
      case JournalEntry() when journalEntry != null:
        return journalEntry(_that.meta, _that.entryText, _that.geolocation);
      case JournalImage() when journalImage != null:
        return journalImage(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
      case JournalAudio() when journalAudio != null:
        return journalAudio(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
      case Task() when task != null:
        return task(_that.meta, _that.data, _that.entryText, _that.geolocation);
      case JournalEvent() when event != null:
        return event(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
      case ChecklistItem() when checklistItem != null:
        return checklistItem(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
      case Checklist() when checklist != null:
        return checklist(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
      case QuantitativeEntry() when quantitative != null:
        return quantitative(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
      case MeasurementEntry() when measurement != null:
        return measurement(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
      case AiResponseEntry() when aiResponse != null:
        return aiResponse(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
      case WorkoutEntry() when workout != null:
        return workout(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
      case HabitCompletionEntry() when habitCompletion != null:
        return habitCompletion(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
      case SurveyEntry() when survey != null:
        return survey(
            _that.meta, _that.data, _that.entryText, _that.geolocation);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class JournalEntry implements JournalEntity {
  const JournalEntry(
      {required this.meta,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'journalEntry';
  factory JournalEntry.fromJson(Map<String, dynamic> json) =>
      _$JournalEntryFromJson(json);

  @override
  final Metadata meta;
  @override
  final EntryText? entryText;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $JournalEntryCopyWith<JournalEntry> get copyWith =>
      _$JournalEntryCopyWithImpl<JournalEntry>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$JournalEntryToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is JournalEntry &&
            (identical(other.meta, meta) || other.meta == meta) &&
            (identical(other.entryText, entryText) ||
                other.entryText == entryText) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, meta, entryText, geolocation);

  @override
  String toString() {
    return 'JournalEntity.journalEntry(meta: $meta, entryText: $entryText, geolocation: $geolocation)';
  }
}

/// @nodoc
abstract mixin class $JournalEntryCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory $JournalEntryCopyWith(
          JournalEntry value, $Res Function(JournalEntry) _then) =
      _$JournalEntryCopyWithImpl;
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
class _$JournalEntryCopyWithImpl<$Res> implements $JournalEntryCopyWith<$Res> {
  _$JournalEntryCopyWithImpl(this._self, this._then);

  final JournalEntry _self;
  final $Res Function(JournalEntry) _then;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? meta = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(JournalEntry(
      meta: null == meta
          ? _self.meta
          : meta // ignore: cast_nullable_to_non_nullable
              as Metadata,
      entryText: freezed == entryText
          ? _self.entryText
          : entryText // ignore: cast_nullable_to_non_nullable
              as EntryText?,
      geolocation: freezed == geolocation
          ? _self.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MetadataCopyWith<$Res> get meta {
    return $MetadataCopyWith<$Res>(_self.meta, (value) {
      return _then(_self.copyWith(meta: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $EntryTextCopyWith<$Res>? get entryText {
    if (_self.entryText == null) {
      return null;
    }

    return $EntryTextCopyWith<$Res>(_self.entryText!, (value) {
      return _then(_self.copyWith(entryText: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GeolocationCopyWith<$Res>? get geolocation {
    if (_self.geolocation == null) {
      return null;
    }

    return $GeolocationCopyWith<$Res>(_self.geolocation!, (value) {
      return _then(_self.copyWith(geolocation: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class JournalImage implements JournalEntity {
  const JournalImage(
      {required this.meta,
      required this.data,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'journalImage';
  factory JournalImage.fromJson(Map<String, dynamic> json) =>
      _$JournalImageFromJson(json);

  @override
  final Metadata meta;
  final ImageData data;
  @override
  final EntryText? entryText;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $JournalImageCopyWith<JournalImage> get copyWith =>
      _$JournalImageCopyWithImpl<JournalImage>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$JournalImageToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is JournalImage &&
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

  @override
  String toString() {
    return 'JournalEntity.journalImage(meta: $meta, data: $data, entryText: $entryText, geolocation: $geolocation)';
  }
}

/// @nodoc
abstract mixin class $JournalImageCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory $JournalImageCopyWith(
          JournalImage value, $Res Function(JournalImage) _then) =
      _$JournalImageCopyWithImpl;
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
class _$JournalImageCopyWithImpl<$Res> implements $JournalImageCopyWith<$Res> {
  _$JournalImageCopyWithImpl(this._self, this._then);

  final JournalImage _self;
  final $Res Function(JournalImage) _then;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? meta = null,
    Object? data = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(JournalImage(
      meta: null == meta
          ? _self.meta
          : meta // ignore: cast_nullable_to_non_nullable
              as Metadata,
      data: null == data
          ? _self.data
          : data // ignore: cast_nullable_to_non_nullable
              as ImageData,
      entryText: freezed == entryText
          ? _self.entryText
          : entryText // ignore: cast_nullable_to_non_nullable
              as EntryText?,
      geolocation: freezed == geolocation
          ? _self.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MetadataCopyWith<$Res> get meta {
    return $MetadataCopyWith<$Res>(_self.meta, (value) {
      return _then(_self.copyWith(meta: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ImageDataCopyWith<$Res> get data {
    return $ImageDataCopyWith<$Res>(_self.data, (value) {
      return _then(_self.copyWith(data: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $EntryTextCopyWith<$Res>? get entryText {
    if (_self.entryText == null) {
      return null;
    }

    return $EntryTextCopyWith<$Res>(_self.entryText!, (value) {
      return _then(_self.copyWith(entryText: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GeolocationCopyWith<$Res>? get geolocation {
    if (_self.geolocation == null) {
      return null;
    }

    return $GeolocationCopyWith<$Res>(_self.geolocation!, (value) {
      return _then(_self.copyWith(geolocation: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class JournalAudio implements JournalEntity {
  const JournalAudio(
      {required this.meta,
      required this.data,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'journalAudio';
  factory JournalAudio.fromJson(Map<String, dynamic> json) =>
      _$JournalAudioFromJson(json);

  @override
  final Metadata meta;
  final AudioData data;
  @override
  final EntryText? entryText;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $JournalAudioCopyWith<JournalAudio> get copyWith =>
      _$JournalAudioCopyWithImpl<JournalAudio>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$JournalAudioToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is JournalAudio &&
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

  @override
  String toString() {
    return 'JournalEntity.journalAudio(meta: $meta, data: $data, entryText: $entryText, geolocation: $geolocation)';
  }
}

/// @nodoc
abstract mixin class $JournalAudioCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory $JournalAudioCopyWith(
          JournalAudio value, $Res Function(JournalAudio) _then) =
      _$JournalAudioCopyWithImpl;
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
class _$JournalAudioCopyWithImpl<$Res> implements $JournalAudioCopyWith<$Res> {
  _$JournalAudioCopyWithImpl(this._self, this._then);

  final JournalAudio _self;
  final $Res Function(JournalAudio) _then;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? meta = null,
    Object? data = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(JournalAudio(
      meta: null == meta
          ? _self.meta
          : meta // ignore: cast_nullable_to_non_nullable
              as Metadata,
      data: null == data
          ? _self.data
          : data // ignore: cast_nullable_to_non_nullable
              as AudioData,
      entryText: freezed == entryText
          ? _self.entryText
          : entryText // ignore: cast_nullable_to_non_nullable
              as EntryText?,
      geolocation: freezed == geolocation
          ? _self.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MetadataCopyWith<$Res> get meta {
    return $MetadataCopyWith<$Res>(_self.meta, (value) {
      return _then(_self.copyWith(meta: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AudioDataCopyWith<$Res> get data {
    return $AudioDataCopyWith<$Res>(_self.data, (value) {
      return _then(_self.copyWith(data: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $EntryTextCopyWith<$Res>? get entryText {
    if (_self.entryText == null) {
      return null;
    }

    return $EntryTextCopyWith<$Res>(_self.entryText!, (value) {
      return _then(_self.copyWith(entryText: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GeolocationCopyWith<$Res>? get geolocation {
    if (_self.geolocation == null) {
      return null;
    }

    return $GeolocationCopyWith<$Res>(_self.geolocation!, (value) {
      return _then(_self.copyWith(geolocation: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class Task implements JournalEntity {
  const Task(
      {required this.meta,
      required this.data,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'task';
  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);

  @override
  final Metadata meta;
  final TaskData data;
  @override
  final EntryText? entryText;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TaskCopyWith<Task> get copyWith =>
      _$TaskCopyWithImpl<Task>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TaskToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Task &&
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

  @override
  String toString() {
    return 'JournalEntity.task(meta: $meta, data: $data, entryText: $entryText, geolocation: $geolocation)';
  }
}

/// @nodoc
abstract mixin class $TaskCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory $TaskCopyWith(Task value, $Res Function(Task) _then) =
      _$TaskCopyWithImpl;
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
class _$TaskCopyWithImpl<$Res> implements $TaskCopyWith<$Res> {
  _$TaskCopyWithImpl(this._self, this._then);

  final Task _self;
  final $Res Function(Task) _then;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? meta = null,
    Object? data = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(Task(
      meta: null == meta
          ? _self.meta
          : meta // ignore: cast_nullable_to_non_nullable
              as Metadata,
      data: null == data
          ? _self.data
          : data // ignore: cast_nullable_to_non_nullable
              as TaskData,
      entryText: freezed == entryText
          ? _self.entryText
          : entryText // ignore: cast_nullable_to_non_nullable
              as EntryText?,
      geolocation: freezed == geolocation
          ? _self.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MetadataCopyWith<$Res> get meta {
    return $MetadataCopyWith<$Res>(_self.meta, (value) {
      return _then(_self.copyWith(meta: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TaskDataCopyWith<$Res> get data {
    return $TaskDataCopyWith<$Res>(_self.data, (value) {
      return _then(_self.copyWith(data: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $EntryTextCopyWith<$Res>? get entryText {
    if (_self.entryText == null) {
      return null;
    }

    return $EntryTextCopyWith<$Res>(_self.entryText!, (value) {
      return _then(_self.copyWith(entryText: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GeolocationCopyWith<$Res>? get geolocation {
    if (_self.geolocation == null) {
      return null;
    }

    return $GeolocationCopyWith<$Res>(_self.geolocation!, (value) {
      return _then(_self.copyWith(geolocation: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class JournalEvent implements JournalEntity {
  const JournalEvent(
      {required this.meta,
      required this.data,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'event';
  factory JournalEvent.fromJson(Map<String, dynamic> json) =>
      _$JournalEventFromJson(json);

  @override
  final Metadata meta;
  final EventData data;
  @override
  final EntryText? entryText;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $JournalEventCopyWith<JournalEvent> get copyWith =>
      _$JournalEventCopyWithImpl<JournalEvent>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$JournalEventToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is JournalEvent &&
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

  @override
  String toString() {
    return 'JournalEntity.event(meta: $meta, data: $data, entryText: $entryText, geolocation: $geolocation)';
  }
}

/// @nodoc
abstract mixin class $JournalEventCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory $JournalEventCopyWith(
          JournalEvent value, $Res Function(JournalEvent) _then) =
      _$JournalEventCopyWithImpl;
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
class _$JournalEventCopyWithImpl<$Res> implements $JournalEventCopyWith<$Res> {
  _$JournalEventCopyWithImpl(this._self, this._then);

  final JournalEvent _self;
  final $Res Function(JournalEvent) _then;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? meta = null,
    Object? data = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(JournalEvent(
      meta: null == meta
          ? _self.meta
          : meta // ignore: cast_nullable_to_non_nullable
              as Metadata,
      data: null == data
          ? _self.data
          : data // ignore: cast_nullable_to_non_nullable
              as EventData,
      entryText: freezed == entryText
          ? _self.entryText
          : entryText // ignore: cast_nullable_to_non_nullable
              as EntryText?,
      geolocation: freezed == geolocation
          ? _self.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MetadataCopyWith<$Res> get meta {
    return $MetadataCopyWith<$Res>(_self.meta, (value) {
      return _then(_self.copyWith(meta: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $EventDataCopyWith<$Res> get data {
    return $EventDataCopyWith<$Res>(_self.data, (value) {
      return _then(_self.copyWith(data: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $EntryTextCopyWith<$Res>? get entryText {
    if (_self.entryText == null) {
      return null;
    }

    return $EntryTextCopyWith<$Res>(_self.entryText!, (value) {
      return _then(_self.copyWith(entryText: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GeolocationCopyWith<$Res>? get geolocation {
    if (_self.geolocation == null) {
      return null;
    }

    return $GeolocationCopyWith<$Res>(_self.geolocation!, (value) {
      return _then(_self.copyWith(geolocation: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class ChecklistItem implements JournalEntity {
  const ChecklistItem(
      {required this.meta,
      required this.data,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'checklistItem';
  factory ChecklistItem.fromJson(Map<String, dynamic> json) =>
      _$ChecklistItemFromJson(json);

  @override
  final Metadata meta;
  final ChecklistItemData data;
  @override
  final EntryText? entryText;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ChecklistItemCopyWith<ChecklistItem> get copyWith =>
      _$ChecklistItemCopyWithImpl<ChecklistItem>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ChecklistItemToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ChecklistItem &&
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

  @override
  String toString() {
    return 'JournalEntity.checklistItem(meta: $meta, data: $data, entryText: $entryText, geolocation: $geolocation)';
  }
}

/// @nodoc
abstract mixin class $ChecklistItemCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory $ChecklistItemCopyWith(
          ChecklistItem value, $Res Function(ChecklistItem) _then) =
      _$ChecklistItemCopyWithImpl;
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
class _$ChecklistItemCopyWithImpl<$Res>
    implements $ChecklistItemCopyWith<$Res> {
  _$ChecklistItemCopyWithImpl(this._self, this._then);

  final ChecklistItem _self;
  final $Res Function(ChecklistItem) _then;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? meta = null,
    Object? data = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(ChecklistItem(
      meta: null == meta
          ? _self.meta
          : meta // ignore: cast_nullable_to_non_nullable
              as Metadata,
      data: null == data
          ? _self.data
          : data // ignore: cast_nullable_to_non_nullable
              as ChecklistItemData,
      entryText: freezed == entryText
          ? _self.entryText
          : entryText // ignore: cast_nullable_to_non_nullable
              as EntryText?,
      geolocation: freezed == geolocation
          ? _self.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MetadataCopyWith<$Res> get meta {
    return $MetadataCopyWith<$Res>(_self.meta, (value) {
      return _then(_self.copyWith(meta: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ChecklistItemDataCopyWith<$Res> get data {
    return $ChecklistItemDataCopyWith<$Res>(_self.data, (value) {
      return _then(_self.copyWith(data: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $EntryTextCopyWith<$Res>? get entryText {
    if (_self.entryText == null) {
      return null;
    }

    return $EntryTextCopyWith<$Res>(_self.entryText!, (value) {
      return _then(_self.copyWith(entryText: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GeolocationCopyWith<$Res>? get geolocation {
    if (_self.geolocation == null) {
      return null;
    }

    return $GeolocationCopyWith<$Res>(_self.geolocation!, (value) {
      return _then(_self.copyWith(geolocation: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class Checklist implements JournalEntity {
  const Checklist(
      {required this.meta,
      required this.data,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'checklist';
  factory Checklist.fromJson(Map<String, dynamic> json) =>
      _$ChecklistFromJson(json);

  @override
  final Metadata meta;
  final ChecklistData data;
  @override
  final EntryText? entryText;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ChecklistCopyWith<Checklist> get copyWith =>
      _$ChecklistCopyWithImpl<Checklist>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ChecklistToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Checklist &&
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

  @override
  String toString() {
    return 'JournalEntity.checklist(meta: $meta, data: $data, entryText: $entryText, geolocation: $geolocation)';
  }
}

/// @nodoc
abstract mixin class $ChecklistCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory $ChecklistCopyWith(Checklist value, $Res Function(Checklist) _then) =
      _$ChecklistCopyWithImpl;
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
class _$ChecklistCopyWithImpl<$Res> implements $ChecklistCopyWith<$Res> {
  _$ChecklistCopyWithImpl(this._self, this._then);

  final Checklist _self;
  final $Res Function(Checklist) _then;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? meta = null,
    Object? data = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(Checklist(
      meta: null == meta
          ? _self.meta
          : meta // ignore: cast_nullable_to_non_nullable
              as Metadata,
      data: null == data
          ? _self.data
          : data // ignore: cast_nullable_to_non_nullable
              as ChecklistData,
      entryText: freezed == entryText
          ? _self.entryText
          : entryText // ignore: cast_nullable_to_non_nullable
              as EntryText?,
      geolocation: freezed == geolocation
          ? _self.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MetadataCopyWith<$Res> get meta {
    return $MetadataCopyWith<$Res>(_self.meta, (value) {
      return _then(_self.copyWith(meta: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ChecklistDataCopyWith<$Res> get data {
    return $ChecklistDataCopyWith<$Res>(_self.data, (value) {
      return _then(_self.copyWith(data: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $EntryTextCopyWith<$Res>? get entryText {
    if (_self.entryText == null) {
      return null;
    }

    return $EntryTextCopyWith<$Res>(_self.entryText!, (value) {
      return _then(_self.copyWith(entryText: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GeolocationCopyWith<$Res>? get geolocation {
    if (_self.geolocation == null) {
      return null;
    }

    return $GeolocationCopyWith<$Res>(_self.geolocation!, (value) {
      return _then(_self.copyWith(geolocation: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class QuantitativeEntry implements JournalEntity {
  const QuantitativeEntry(
      {required this.meta,
      required this.data,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'quantitative';
  factory QuantitativeEntry.fromJson(Map<String, dynamic> json) =>
      _$QuantitativeEntryFromJson(json);

  @override
  final Metadata meta;
  final QuantitativeData data;
  @override
  final EntryText? entryText;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $QuantitativeEntryCopyWith<QuantitativeEntry> get copyWith =>
      _$QuantitativeEntryCopyWithImpl<QuantitativeEntry>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$QuantitativeEntryToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is QuantitativeEntry &&
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

  @override
  String toString() {
    return 'JournalEntity.quantitative(meta: $meta, data: $data, entryText: $entryText, geolocation: $geolocation)';
  }
}

/// @nodoc
abstract mixin class $QuantitativeEntryCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory $QuantitativeEntryCopyWith(
          QuantitativeEntry value, $Res Function(QuantitativeEntry) _then) =
      _$QuantitativeEntryCopyWithImpl;
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
class _$QuantitativeEntryCopyWithImpl<$Res>
    implements $QuantitativeEntryCopyWith<$Res> {
  _$QuantitativeEntryCopyWithImpl(this._self, this._then);

  final QuantitativeEntry _self;
  final $Res Function(QuantitativeEntry) _then;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? meta = null,
    Object? data = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(QuantitativeEntry(
      meta: null == meta
          ? _self.meta
          : meta // ignore: cast_nullable_to_non_nullable
              as Metadata,
      data: null == data
          ? _self.data
          : data // ignore: cast_nullable_to_non_nullable
              as QuantitativeData,
      entryText: freezed == entryText
          ? _self.entryText
          : entryText // ignore: cast_nullable_to_non_nullable
              as EntryText?,
      geolocation: freezed == geolocation
          ? _self.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MetadataCopyWith<$Res> get meta {
    return $MetadataCopyWith<$Res>(_self.meta, (value) {
      return _then(_self.copyWith(meta: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $QuantitativeDataCopyWith<$Res> get data {
    return $QuantitativeDataCopyWith<$Res>(_self.data, (value) {
      return _then(_self.copyWith(data: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $EntryTextCopyWith<$Res>? get entryText {
    if (_self.entryText == null) {
      return null;
    }

    return $EntryTextCopyWith<$Res>(_self.entryText!, (value) {
      return _then(_self.copyWith(entryText: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GeolocationCopyWith<$Res>? get geolocation {
    if (_self.geolocation == null) {
      return null;
    }

    return $GeolocationCopyWith<$Res>(_self.geolocation!, (value) {
      return _then(_self.copyWith(geolocation: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class MeasurementEntry implements JournalEntity {
  const MeasurementEntry(
      {required this.meta,
      required this.data,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'measurement';
  factory MeasurementEntry.fromJson(Map<String, dynamic> json) =>
      _$MeasurementEntryFromJson(json);

  @override
  final Metadata meta;
  final MeasurementData data;
  @override
  final EntryText? entryText;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MeasurementEntryCopyWith<MeasurementEntry> get copyWith =>
      _$MeasurementEntryCopyWithImpl<MeasurementEntry>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$MeasurementEntryToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MeasurementEntry &&
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

  @override
  String toString() {
    return 'JournalEntity.measurement(meta: $meta, data: $data, entryText: $entryText, geolocation: $geolocation)';
  }
}

/// @nodoc
abstract mixin class $MeasurementEntryCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory $MeasurementEntryCopyWith(
          MeasurementEntry value, $Res Function(MeasurementEntry) _then) =
      _$MeasurementEntryCopyWithImpl;
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
class _$MeasurementEntryCopyWithImpl<$Res>
    implements $MeasurementEntryCopyWith<$Res> {
  _$MeasurementEntryCopyWithImpl(this._self, this._then);

  final MeasurementEntry _self;
  final $Res Function(MeasurementEntry) _then;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? meta = null,
    Object? data = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(MeasurementEntry(
      meta: null == meta
          ? _self.meta
          : meta // ignore: cast_nullable_to_non_nullable
              as Metadata,
      data: null == data
          ? _self.data
          : data // ignore: cast_nullable_to_non_nullable
              as MeasurementData,
      entryText: freezed == entryText
          ? _self.entryText
          : entryText // ignore: cast_nullable_to_non_nullable
              as EntryText?,
      geolocation: freezed == geolocation
          ? _self.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MetadataCopyWith<$Res> get meta {
    return $MetadataCopyWith<$Res>(_self.meta, (value) {
      return _then(_self.copyWith(meta: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MeasurementDataCopyWith<$Res> get data {
    return $MeasurementDataCopyWith<$Res>(_self.data, (value) {
      return _then(_self.copyWith(data: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $EntryTextCopyWith<$Res>? get entryText {
    if (_self.entryText == null) {
      return null;
    }

    return $EntryTextCopyWith<$Res>(_self.entryText!, (value) {
      return _then(_self.copyWith(entryText: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GeolocationCopyWith<$Res>? get geolocation {
    if (_self.geolocation == null) {
      return null;
    }

    return $GeolocationCopyWith<$Res>(_self.geolocation!, (value) {
      return _then(_self.copyWith(geolocation: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class AiResponseEntry implements JournalEntity {
  const AiResponseEntry(
      {required this.meta,
      required this.data,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'aiResponse';
  factory AiResponseEntry.fromJson(Map<String, dynamic> json) =>
      _$AiResponseEntryFromJson(json);

  @override
  final Metadata meta;
  final AiResponseData data;
  @override
  final EntryText? entryText;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AiResponseEntryCopyWith<AiResponseEntry> get copyWith =>
      _$AiResponseEntryCopyWithImpl<AiResponseEntry>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AiResponseEntryToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AiResponseEntry &&
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

  @override
  String toString() {
    return 'JournalEntity.aiResponse(meta: $meta, data: $data, entryText: $entryText, geolocation: $geolocation)';
  }
}

/// @nodoc
abstract mixin class $AiResponseEntryCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory $AiResponseEntryCopyWith(
          AiResponseEntry value, $Res Function(AiResponseEntry) _then) =
      _$AiResponseEntryCopyWithImpl;
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
class _$AiResponseEntryCopyWithImpl<$Res>
    implements $AiResponseEntryCopyWith<$Res> {
  _$AiResponseEntryCopyWithImpl(this._self, this._then);

  final AiResponseEntry _self;
  final $Res Function(AiResponseEntry) _then;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? meta = null,
    Object? data = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(AiResponseEntry(
      meta: null == meta
          ? _self.meta
          : meta // ignore: cast_nullable_to_non_nullable
              as Metadata,
      data: null == data
          ? _self.data
          : data // ignore: cast_nullable_to_non_nullable
              as AiResponseData,
      entryText: freezed == entryText
          ? _self.entryText
          : entryText // ignore: cast_nullable_to_non_nullable
              as EntryText?,
      geolocation: freezed == geolocation
          ? _self.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MetadataCopyWith<$Res> get meta {
    return $MetadataCopyWith<$Res>(_self.meta, (value) {
      return _then(_self.copyWith(meta: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AiResponseDataCopyWith<$Res> get data {
    return $AiResponseDataCopyWith<$Res>(_self.data, (value) {
      return _then(_self.copyWith(data: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $EntryTextCopyWith<$Res>? get entryText {
    if (_self.entryText == null) {
      return null;
    }

    return $EntryTextCopyWith<$Res>(_self.entryText!, (value) {
      return _then(_self.copyWith(entryText: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GeolocationCopyWith<$Res>? get geolocation {
    if (_self.geolocation == null) {
      return null;
    }

    return $GeolocationCopyWith<$Res>(_self.geolocation!, (value) {
      return _then(_self.copyWith(geolocation: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class WorkoutEntry implements JournalEntity {
  const WorkoutEntry(
      {required this.meta,
      required this.data,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'workout';
  factory WorkoutEntry.fromJson(Map<String, dynamic> json) =>
      _$WorkoutEntryFromJson(json);

  @override
  final Metadata meta;
  final WorkoutData data;
  @override
  final EntryText? entryText;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $WorkoutEntryCopyWith<WorkoutEntry> get copyWith =>
      _$WorkoutEntryCopyWithImpl<WorkoutEntry>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$WorkoutEntryToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is WorkoutEntry &&
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

  @override
  String toString() {
    return 'JournalEntity.workout(meta: $meta, data: $data, entryText: $entryText, geolocation: $geolocation)';
  }
}

/// @nodoc
abstract mixin class $WorkoutEntryCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory $WorkoutEntryCopyWith(
          WorkoutEntry value, $Res Function(WorkoutEntry) _then) =
      _$WorkoutEntryCopyWithImpl;
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
class _$WorkoutEntryCopyWithImpl<$Res> implements $WorkoutEntryCopyWith<$Res> {
  _$WorkoutEntryCopyWithImpl(this._self, this._then);

  final WorkoutEntry _self;
  final $Res Function(WorkoutEntry) _then;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? meta = null,
    Object? data = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(WorkoutEntry(
      meta: null == meta
          ? _self.meta
          : meta // ignore: cast_nullable_to_non_nullable
              as Metadata,
      data: null == data
          ? _self.data
          : data // ignore: cast_nullable_to_non_nullable
              as WorkoutData,
      entryText: freezed == entryText
          ? _self.entryText
          : entryText // ignore: cast_nullable_to_non_nullable
              as EntryText?,
      geolocation: freezed == geolocation
          ? _self.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MetadataCopyWith<$Res> get meta {
    return $MetadataCopyWith<$Res>(_self.meta, (value) {
      return _then(_self.copyWith(meta: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $WorkoutDataCopyWith<$Res> get data {
    return $WorkoutDataCopyWith<$Res>(_self.data, (value) {
      return _then(_self.copyWith(data: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $EntryTextCopyWith<$Res>? get entryText {
    if (_self.entryText == null) {
      return null;
    }

    return $EntryTextCopyWith<$Res>(_self.entryText!, (value) {
      return _then(_self.copyWith(entryText: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GeolocationCopyWith<$Res>? get geolocation {
    if (_self.geolocation == null) {
      return null;
    }

    return $GeolocationCopyWith<$Res>(_self.geolocation!, (value) {
      return _then(_self.copyWith(geolocation: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class HabitCompletionEntry implements JournalEntity {
  const HabitCompletionEntry(
      {required this.meta,
      required this.data,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'habitCompletion';
  factory HabitCompletionEntry.fromJson(Map<String, dynamic> json) =>
      _$HabitCompletionEntryFromJson(json);

  @override
  final Metadata meta;
  final HabitCompletionData data;
  @override
  final EntryText? entryText;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HabitCompletionEntryCopyWith<HabitCompletionEntry> get copyWith =>
      _$HabitCompletionEntryCopyWithImpl<HabitCompletionEntry>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$HabitCompletionEntryToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is HabitCompletionEntry &&
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

  @override
  String toString() {
    return 'JournalEntity.habitCompletion(meta: $meta, data: $data, entryText: $entryText, geolocation: $geolocation)';
  }
}

/// @nodoc
abstract mixin class $HabitCompletionEntryCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory $HabitCompletionEntryCopyWith(HabitCompletionEntry value,
          $Res Function(HabitCompletionEntry) _then) =
      _$HabitCompletionEntryCopyWithImpl;
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
class _$HabitCompletionEntryCopyWithImpl<$Res>
    implements $HabitCompletionEntryCopyWith<$Res> {
  _$HabitCompletionEntryCopyWithImpl(this._self, this._then);

  final HabitCompletionEntry _self;
  final $Res Function(HabitCompletionEntry) _then;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? meta = null,
    Object? data = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(HabitCompletionEntry(
      meta: null == meta
          ? _self.meta
          : meta // ignore: cast_nullable_to_non_nullable
              as Metadata,
      data: null == data
          ? _self.data
          : data // ignore: cast_nullable_to_non_nullable
              as HabitCompletionData,
      entryText: freezed == entryText
          ? _self.entryText
          : entryText // ignore: cast_nullable_to_non_nullable
              as EntryText?,
      geolocation: freezed == geolocation
          ? _self.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MetadataCopyWith<$Res> get meta {
    return $MetadataCopyWith<$Res>(_self.meta, (value) {
      return _then(_self.copyWith(meta: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $HabitCompletionDataCopyWith<$Res> get data {
    return $HabitCompletionDataCopyWith<$Res>(_self.data, (value) {
      return _then(_self.copyWith(data: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $EntryTextCopyWith<$Res>? get entryText {
    if (_self.entryText == null) {
      return null;
    }

    return $EntryTextCopyWith<$Res>(_self.entryText!, (value) {
      return _then(_self.copyWith(entryText: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GeolocationCopyWith<$Res>? get geolocation {
    if (_self.geolocation == null) {
      return null;
    }

    return $GeolocationCopyWith<$Res>(_self.geolocation!, (value) {
      return _then(_self.copyWith(geolocation: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class SurveyEntry implements JournalEntity {
  const SurveyEntry(
      {required this.meta,
      required this.data,
      this.entryText,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'survey';
  factory SurveyEntry.fromJson(Map<String, dynamic> json) =>
      _$SurveyEntryFromJson(json);

  @override
  final Metadata meta;
  final SurveyData data;
  @override
  final EntryText? entryText;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SurveyEntryCopyWith<SurveyEntry> get copyWith =>
      _$SurveyEntryCopyWithImpl<SurveyEntry>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SurveyEntryToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SurveyEntry &&
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

  @override
  String toString() {
    return 'JournalEntity.survey(meta: $meta, data: $data, entryText: $entryText, geolocation: $geolocation)';
  }
}

/// @nodoc
abstract mixin class $SurveyEntryCopyWith<$Res>
    implements $JournalEntityCopyWith<$Res> {
  factory $SurveyEntryCopyWith(
          SurveyEntry value, $Res Function(SurveyEntry) _then) =
      _$SurveyEntryCopyWithImpl;
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
class _$SurveyEntryCopyWithImpl<$Res> implements $SurveyEntryCopyWith<$Res> {
  _$SurveyEntryCopyWithImpl(this._self, this._then);

  final SurveyEntry _self;
  final $Res Function(SurveyEntry) _then;

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? meta = null,
    Object? data = null,
    Object? entryText = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(SurveyEntry(
      meta: null == meta
          ? _self.meta
          : meta // ignore: cast_nullable_to_non_nullable
              as Metadata,
      data: null == data
          ? _self.data
          : data // ignore: cast_nullable_to_non_nullable
              as SurveyData,
      entryText: freezed == entryText
          ? _self.entryText
          : entryText // ignore: cast_nullable_to_non_nullable
              as EntryText?,
      geolocation: freezed == geolocation
          ? _self.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MetadataCopyWith<$Res> get meta {
    return $MetadataCopyWith<$Res>(_self.meta, (value) {
      return _then(_self.copyWith(meta: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SurveyDataCopyWith<$Res> get data {
    return $SurveyDataCopyWith<$Res>(_self.data, (value) {
      return _then(_self.copyWith(data: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $EntryTextCopyWith<$Res>? get entryText {
    if (_self.entryText == null) {
      return null;
    }

    return $EntryTextCopyWith<$Res>(_self.entryText!, (value) {
      return _then(_self.copyWith(entryText: value));
    });
  }

  /// Create a copy of JournalEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GeolocationCopyWith<$Res>? get geolocation {
    if (_self.geolocation == null) {
      return null;
    }

    return $GeolocationCopyWith<$Res>(_self.geolocation!, (value) {
      return _then(_self.copyWith(geolocation: value));
    });
  }
}

// dart format on
