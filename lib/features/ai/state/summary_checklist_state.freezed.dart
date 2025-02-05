// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'summary_checklist_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SummaryChecklistState _$SummaryChecklistStateFromJson(
    Map<String, dynamic> json) {
  return _SummaryChecklistState.fromJson(json);
}

/// @nodoc
mixin _$SummaryChecklistState {
  String? get summary => throw _privateConstructorUsedError;
  List<ChecklistItemData>? get checklistItems =>
      throw _privateConstructorUsedError;

  /// Serializes this SummaryChecklistState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SummaryChecklistState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SummaryChecklistStateCopyWith<SummaryChecklistState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SummaryChecklistStateCopyWith<$Res> {
  factory $SummaryChecklistStateCopyWith(SummaryChecklistState value,
          $Res Function(SummaryChecklistState) then) =
      _$SummaryChecklistStateCopyWithImpl<$Res, SummaryChecklistState>;
  @useResult
  $Res call({String? summary, List<ChecklistItemData>? checklistItems});
}

/// @nodoc
class _$SummaryChecklistStateCopyWithImpl<$Res,
        $Val extends SummaryChecklistState>
    implements $SummaryChecklistStateCopyWith<$Res> {
  _$SummaryChecklistStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SummaryChecklistState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? summary = freezed,
    Object? checklistItems = freezed,
  }) {
    return _then(_value.copyWith(
      summary: freezed == summary
          ? _value.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as String?,
      checklistItems: freezed == checklistItems
          ? _value.checklistItems
          : checklistItems // ignore: cast_nullable_to_non_nullable
              as List<ChecklistItemData>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SummaryChecklistStateImplCopyWith<$Res>
    implements $SummaryChecklistStateCopyWith<$Res> {
  factory _$$SummaryChecklistStateImplCopyWith(
          _$SummaryChecklistStateImpl value,
          $Res Function(_$SummaryChecklistStateImpl) then) =
      __$$SummaryChecklistStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String? summary, List<ChecklistItemData>? checklistItems});
}

/// @nodoc
class __$$SummaryChecklistStateImplCopyWithImpl<$Res>
    extends _$SummaryChecklistStateCopyWithImpl<$Res,
        _$SummaryChecklistStateImpl>
    implements _$$SummaryChecklistStateImplCopyWith<$Res> {
  __$$SummaryChecklistStateImplCopyWithImpl(_$SummaryChecklistStateImpl _value,
      $Res Function(_$SummaryChecklistStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of SummaryChecklistState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? summary = freezed,
    Object? checklistItems = freezed,
  }) {
    return _then(_$SummaryChecklistStateImpl(
      summary: freezed == summary
          ? _value.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as String?,
      checklistItems: freezed == checklistItems
          ? _value._checklistItems
          : checklistItems // ignore: cast_nullable_to_non_nullable
              as List<ChecklistItemData>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SummaryChecklistStateImpl implements _SummaryChecklistState {
  const _$SummaryChecklistStateImpl(
      {this.summary, final List<ChecklistItemData>? checklistItems})
      : _checklistItems = checklistItems;

  factory _$SummaryChecklistStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$SummaryChecklistStateImplFromJson(json);

  @override
  final String? summary;
  final List<ChecklistItemData>? _checklistItems;
  @override
  List<ChecklistItemData>? get checklistItems {
    final value = _checklistItems;
    if (value == null) return null;
    if (_checklistItems is EqualUnmodifiableListView) return _checklistItems;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  String toString() {
    return 'SummaryChecklistState(summary: $summary, checklistItems: $checklistItems)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SummaryChecklistStateImpl &&
            (identical(other.summary, summary) || other.summary == summary) &&
            const DeepCollectionEquality()
                .equals(other._checklistItems, _checklistItems));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, summary,
      const DeepCollectionEquality().hash(_checklistItems));

  /// Create a copy of SummaryChecklistState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SummaryChecklistStateImplCopyWith<_$SummaryChecklistStateImpl>
      get copyWith => __$$SummaryChecklistStateImplCopyWithImpl<
          _$SummaryChecklistStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SummaryChecklistStateImplToJson(
      this,
    );
  }
}

abstract class _SummaryChecklistState implements SummaryChecklistState {
  const factory _SummaryChecklistState(
          {final String? summary,
          final List<ChecklistItemData>? checklistItems}) =
      _$SummaryChecklistStateImpl;

  factory _SummaryChecklistState.fromJson(Map<String, dynamic> json) =
      _$SummaryChecklistStateImpl.fromJson;

  @override
  String? get summary;
  @override
  List<ChecklistItemData>? get checklistItems;

  /// Create a copy of SummaryChecklistState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SummaryChecklistStateImplCopyWith<_$SummaryChecklistStateImpl>
      get copyWith => throw _privateConstructorUsedError;
}
