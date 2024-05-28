// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'event_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

EventData _$EventDataFromJson(Map<String, dynamic> json) {
  return _EventData.fromJson(json);
}

/// @nodoc
mixin _$EventData {
  String get title => throw _privateConstructorUsedError;
  int get stars => throw _privateConstructorUsedError;
  EventStatus get status => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $EventDataCopyWith<EventData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EventDataCopyWith<$Res> {
  factory $EventDataCopyWith(EventData value, $Res Function(EventData) then) =
      _$EventDataCopyWithImpl<$Res, EventData>;
  @useResult
  $Res call({String title, int stars, EventStatus status});
}

/// @nodoc
class _$EventDataCopyWithImpl<$Res, $Val extends EventData>
    implements $EventDataCopyWith<$Res> {
  _$EventDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? stars = null,
    Object? status = null,
  }) {
    return _then(_value.copyWith(
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      stars: null == stars
          ? _value.stars
          : stars // ignore: cast_nullable_to_non_nullable
              as int,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as EventStatus,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$EventDataImplCopyWith<$Res>
    implements $EventDataCopyWith<$Res> {
  factory _$$EventDataImplCopyWith(
          _$EventDataImpl value, $Res Function(_$EventDataImpl) then) =
      __$$EventDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String title, int stars, EventStatus status});
}

/// @nodoc
class __$$EventDataImplCopyWithImpl<$Res>
    extends _$EventDataCopyWithImpl<$Res, _$EventDataImpl>
    implements _$$EventDataImplCopyWith<$Res> {
  __$$EventDataImplCopyWithImpl(
      _$EventDataImpl _value, $Res Function(_$EventDataImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? stars = null,
    Object? status = null,
  }) {
    return _then(_$EventDataImpl(
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      stars: null == stars
          ? _value.stars
          : stars // ignore: cast_nullable_to_non_nullable
              as int,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as EventStatus,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$EventDataImpl implements _EventData {
  const _$EventDataImpl(
      {required this.title, required this.stars, required this.status});

  factory _$EventDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$EventDataImplFromJson(json);

  @override
  final String title;
  @override
  final int stars;
  @override
  final EventStatus status;

  @override
  String toString() {
    return 'EventData(title: $title, stars: $stars, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EventDataImpl &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.stars, stars) || other.stars == stars) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, title, stars, status);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$EventDataImplCopyWith<_$EventDataImpl> get copyWith =>
      __$$EventDataImplCopyWithImpl<_$EventDataImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$EventDataImplToJson(
      this,
    );
  }
}

abstract class _EventData implements EventData {
  const factory _EventData(
      {required final String title,
      required final int stars,
      required final EventStatus status}) = _$EventDataImpl;

  factory _EventData.fromJson(Map<String, dynamic> json) =
      _$EventDataImpl.fromJson;

  @override
  String get title;
  @override
  int get stars;
  @override
  EventStatus get status;
  @override
  @JsonKey(ignore: true)
  _$$EventDataImplCopyWith<_$EventDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
