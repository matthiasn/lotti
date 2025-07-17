// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'checklist_completion_functions.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ChecklistCompletionSuggestion _$ChecklistCompletionSuggestionFromJson(
    Map<String, dynamic> json) {
  return _ChecklistCompletionSuggestion.fromJson(json);
}

/// @nodoc
mixin _$ChecklistCompletionSuggestion {
  String get checklistItemId => throw _privateConstructorUsedError;
  String get reason => throw _privateConstructorUsedError;
  ChecklistCompletionConfidence get confidence =>
      throw _privateConstructorUsedError;

  /// Serializes this ChecklistCompletionSuggestion to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ChecklistCompletionSuggestion
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChecklistCompletionSuggestionCopyWith<ChecklistCompletionSuggestion>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChecklistCompletionSuggestionCopyWith<$Res> {
  factory $ChecklistCompletionSuggestionCopyWith(
          ChecklistCompletionSuggestion value,
          $Res Function(ChecklistCompletionSuggestion) then) =
      _$ChecklistCompletionSuggestionCopyWithImpl<$Res,
          ChecklistCompletionSuggestion>;
  @useResult
  $Res call(
      {String checklistItemId,
      String reason,
      ChecklistCompletionConfidence confidence});
}

/// @nodoc
class _$ChecklistCompletionSuggestionCopyWithImpl<$Res,
        $Val extends ChecklistCompletionSuggestion>
    implements $ChecklistCompletionSuggestionCopyWith<$Res> {
  _$ChecklistCompletionSuggestionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChecklistCompletionSuggestion
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? checklistItemId = null,
    Object? reason = null,
    Object? confidence = null,
  }) {
    return _then(_value.copyWith(
      checklistItemId: null == checklistItemId
          ? _value.checklistItemId
          : checklistItemId // ignore: cast_nullable_to_non_nullable
              as String,
      reason: null == reason
          ? _value.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String,
      confidence: null == confidence
          ? _value.confidence
          : confidence // ignore: cast_nullable_to_non_nullable
              as ChecklistCompletionConfidence,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChecklistCompletionSuggestionImplCopyWith<$Res>
    implements $ChecklistCompletionSuggestionCopyWith<$Res> {
  factory _$$ChecklistCompletionSuggestionImplCopyWith(
          _$ChecklistCompletionSuggestionImpl value,
          $Res Function(_$ChecklistCompletionSuggestionImpl) then) =
      __$$ChecklistCompletionSuggestionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String checklistItemId,
      String reason,
      ChecklistCompletionConfidence confidence});
}

/// @nodoc
class __$$ChecklistCompletionSuggestionImplCopyWithImpl<$Res>
    extends _$ChecklistCompletionSuggestionCopyWithImpl<$Res,
        _$ChecklistCompletionSuggestionImpl>
    implements _$$ChecklistCompletionSuggestionImplCopyWith<$Res> {
  __$$ChecklistCompletionSuggestionImplCopyWithImpl(
      _$ChecklistCompletionSuggestionImpl _value,
      $Res Function(_$ChecklistCompletionSuggestionImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChecklistCompletionSuggestion
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? checklistItemId = null,
    Object? reason = null,
    Object? confidence = null,
  }) {
    return _then(_$ChecklistCompletionSuggestionImpl(
      checklistItemId: null == checklistItemId
          ? _value.checklistItemId
          : checklistItemId // ignore: cast_nullable_to_non_nullable
              as String,
      reason: null == reason
          ? _value.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String,
      confidence: null == confidence
          ? _value.confidence
          : confidence // ignore: cast_nullable_to_non_nullable
              as ChecklistCompletionConfidence,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ChecklistCompletionSuggestionImpl
    implements _ChecklistCompletionSuggestion {
  const _$ChecklistCompletionSuggestionImpl(
      {required this.checklistItemId,
      required this.reason,
      required this.confidence});

  factory _$ChecklistCompletionSuggestionImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$ChecklistCompletionSuggestionImplFromJson(json);

  @override
  final String checklistItemId;
  @override
  final String reason;
  @override
  final ChecklistCompletionConfidence confidence;

  @override
  String toString() {
    return 'ChecklistCompletionSuggestion(checklistItemId: $checklistItemId, reason: $reason, confidence: $confidence)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChecklistCompletionSuggestionImpl &&
            (identical(other.checklistItemId, checklistItemId) ||
                other.checklistItemId == checklistItemId) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, checklistItemId, reason, confidence);

  /// Create a copy of ChecklistCompletionSuggestion
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChecklistCompletionSuggestionImplCopyWith<
          _$ChecklistCompletionSuggestionImpl>
      get copyWith => __$$ChecklistCompletionSuggestionImplCopyWithImpl<
          _$ChecklistCompletionSuggestionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChecklistCompletionSuggestionImplToJson(
      this,
    );
  }
}

abstract class _ChecklistCompletionSuggestion
    implements ChecklistCompletionSuggestion {
  const factory _ChecklistCompletionSuggestion(
          {required final String checklistItemId,
          required final String reason,
          required final ChecklistCompletionConfidence confidence}) =
      _$ChecklistCompletionSuggestionImpl;

  factory _ChecklistCompletionSuggestion.fromJson(Map<String, dynamic> json) =
      _$ChecklistCompletionSuggestionImpl.fromJson;

  @override
  String get checklistItemId;
  @override
  String get reason;
  @override
  ChecklistCompletionConfidence get confidence;

  /// Create a copy of ChecklistCompletionSuggestion
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChecklistCompletionSuggestionImplCopyWith<
          _$ChecklistCompletionSuggestionImpl>
      get copyWith => throw _privateConstructorUsedError;
}
