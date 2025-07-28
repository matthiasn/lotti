// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_functions.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SetTaskLanguageResult _$SetTaskLanguageResultFromJson(
    Map<String, dynamic> json) {
  return _SetTaskLanguageResult.fromJson(json);
}

/// @nodoc
mixin _$SetTaskLanguageResult {
  String get languageCode => throw _privateConstructorUsedError;
  LanguageDetectionConfidence get confidence =>
      throw _privateConstructorUsedError;
  String get reason => throw _privateConstructorUsedError;

  /// Serializes this SetTaskLanguageResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SetTaskLanguageResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SetTaskLanguageResultCopyWith<SetTaskLanguageResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SetTaskLanguageResultCopyWith<$Res> {
  factory $SetTaskLanguageResultCopyWith(SetTaskLanguageResult value,
          $Res Function(SetTaskLanguageResult) then) =
      _$SetTaskLanguageResultCopyWithImpl<$Res, SetTaskLanguageResult>;
  @useResult
  $Res call(
      {String languageCode,
      LanguageDetectionConfidence confidence,
      String reason});
}

/// @nodoc
class _$SetTaskLanguageResultCopyWithImpl<$Res,
        $Val extends SetTaskLanguageResult>
    implements $SetTaskLanguageResultCopyWith<$Res> {
  _$SetTaskLanguageResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SetTaskLanguageResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? languageCode = null,
    Object? confidence = null,
    Object? reason = null,
  }) {
    return _then(_value.copyWith(
      languageCode: null == languageCode
          ? _value.languageCode
          : languageCode // ignore: cast_nullable_to_non_nullable
              as String,
      confidence: null == confidence
          ? _value.confidence
          : confidence // ignore: cast_nullable_to_non_nullable
              as LanguageDetectionConfidence,
      reason: null == reason
          ? _value.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SetTaskLanguageResultImplCopyWith<$Res>
    implements $SetTaskLanguageResultCopyWith<$Res> {
  factory _$$SetTaskLanguageResultImplCopyWith(
          _$SetTaskLanguageResultImpl value,
          $Res Function(_$SetTaskLanguageResultImpl) then) =
      __$$SetTaskLanguageResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String languageCode,
      LanguageDetectionConfidence confidence,
      String reason});
}

/// @nodoc
class __$$SetTaskLanguageResultImplCopyWithImpl<$Res>
    extends _$SetTaskLanguageResultCopyWithImpl<$Res,
        _$SetTaskLanguageResultImpl>
    implements _$$SetTaskLanguageResultImplCopyWith<$Res> {
  __$$SetTaskLanguageResultImplCopyWithImpl(_$SetTaskLanguageResultImpl _value,
      $Res Function(_$SetTaskLanguageResultImpl) _then)
      : super(_value, _then);

  /// Create a copy of SetTaskLanguageResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? languageCode = null,
    Object? confidence = null,
    Object? reason = null,
  }) {
    return _then(_$SetTaskLanguageResultImpl(
      languageCode: null == languageCode
          ? _value.languageCode
          : languageCode // ignore: cast_nullable_to_non_nullable
              as String,
      confidence: null == confidence
          ? _value.confidence
          : confidence // ignore: cast_nullable_to_non_nullable
              as LanguageDetectionConfidence,
      reason: null == reason
          ? _value.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SetTaskLanguageResultImpl implements _SetTaskLanguageResult {
  const _$SetTaskLanguageResultImpl(
      {required this.languageCode,
      required this.confidence,
      required this.reason});

  factory _$SetTaskLanguageResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$SetTaskLanguageResultImplFromJson(json);

  @override
  final String languageCode;
  @override
  final LanguageDetectionConfidence confidence;
  @override
  final String reason;

  @override
  String toString() {
    return 'SetTaskLanguageResult(languageCode: $languageCode, confidence: $confidence, reason: $reason)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SetTaskLanguageResultImpl &&
            (identical(other.languageCode, languageCode) ||
                other.languageCode == languageCode) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence) &&
            (identical(other.reason, reason) || other.reason == reason));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, languageCode, confidence, reason);

  /// Create a copy of SetTaskLanguageResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SetTaskLanguageResultImplCopyWith<_$SetTaskLanguageResultImpl>
      get copyWith => __$$SetTaskLanguageResultImplCopyWithImpl<
          _$SetTaskLanguageResultImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SetTaskLanguageResultImplToJson(
      this,
    );
  }
}

abstract class _SetTaskLanguageResult implements SetTaskLanguageResult {
  const factory _SetTaskLanguageResult(
      {required final String languageCode,
      required final LanguageDetectionConfidence confidence,
      required final String reason}) = _$SetTaskLanguageResultImpl;

  factory _SetTaskLanguageResult.fromJson(Map<String, dynamic> json) =
      _$SetTaskLanguageResultImpl.fromJson;

  @override
  String get languageCode;
  @override
  LanguageDetectionConfidence get confidence;
  @override
  String get reason;

  /// Create a copy of SetTaskLanguageResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SetTaskLanguageResultImplCopyWith<_$SetTaskLanguageResultImpl>
      get copyWith => throw _privateConstructorUsedError;
}
