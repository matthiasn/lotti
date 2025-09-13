// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'event_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EventData {
  String get title;
  double get stars;
  EventStatus get status;

  /// Create a copy of EventData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $EventDataCopyWith<EventData> get copyWith =>
      _$EventDataCopyWithImpl<EventData>(this as EventData, _$identity);

  /// Serializes this EventData to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is EventData &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.stars, stars) || other.stars == stars) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, title, stars, status);

  @override
  String toString() {
    return 'EventData(title: $title, stars: $stars, status: $status)';
  }
}

/// @nodoc
abstract mixin class $EventDataCopyWith<$Res> {
  factory $EventDataCopyWith(EventData value, $Res Function(EventData) _then) =
      _$EventDataCopyWithImpl;
  @useResult
  $Res call({String title, double stars, EventStatus status});
}

/// @nodoc
class _$EventDataCopyWithImpl<$Res> implements $EventDataCopyWith<$Res> {
  _$EventDataCopyWithImpl(this._self, this._then);

  final EventData _self;
  final $Res Function(EventData) _then;

  /// Create a copy of EventData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? stars = null,
    Object? status = null,
  }) {
    return _then(_self.copyWith(
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      stars: null == stars
          ? _self.stars
          : stars // ignore: cast_nullable_to_non_nullable
              as double,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as EventStatus,
    ));
  }
}

/// Adds pattern-matching-related methods to [EventData].
extension EventDataPatterns on EventData {
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
    TResult Function(_EventData value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _EventData() when $default != null:
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
    TResult Function(_EventData value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _EventData():
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
    TResult? Function(_EventData value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _EventData() when $default != null:
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
    TResult Function(String title, double stars, EventStatus status)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _EventData() when $default != null:
        return $default(_that.title, _that.stars, _that.status);
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
    TResult Function(String title, double stars, EventStatus status) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _EventData():
        return $default(_that.title, _that.stars, _that.status);
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
    TResult? Function(String title, double stars, EventStatus status)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _EventData() when $default != null:
        return $default(_that.title, _that.stars, _that.status);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _EventData implements EventData {
  const _EventData(
      {required this.title, required this.stars, required this.status});
  factory _EventData.fromJson(Map<String, dynamic> json) =>
      _$EventDataFromJson(json);

  @override
  final String title;
  @override
  final double stars;
  @override
  final EventStatus status;

  /// Create a copy of EventData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$EventDataCopyWith<_EventData> get copyWith =>
      __$EventDataCopyWithImpl<_EventData>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$EventDataToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _EventData &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.stars, stars) || other.stars == stars) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, title, stars, status);

  @override
  String toString() {
    return 'EventData(title: $title, stars: $stars, status: $status)';
  }
}

/// @nodoc
abstract mixin class _$EventDataCopyWith<$Res>
    implements $EventDataCopyWith<$Res> {
  factory _$EventDataCopyWith(
          _EventData value, $Res Function(_EventData) _then) =
      __$EventDataCopyWithImpl;
  @override
  @useResult
  $Res call({String title, double stars, EventStatus status});
}

/// @nodoc
class __$EventDataCopyWithImpl<$Res> implements _$EventDataCopyWith<$Res> {
  __$EventDataCopyWithImpl(this._self, this._then);

  final _EventData _self;
  final $Res Function(_EventData) _then;

  /// Create a copy of EventData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? title = null,
    Object? stars = null,
    Object? status = null,
  }) {
    return _then(_EventData(
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      stars: null == stars
          ? _self.stars
          : stars // ignore: cast_nullable_to_non_nullable
              as double,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as EventStatus,
    ));
  }
}

// dart format on
