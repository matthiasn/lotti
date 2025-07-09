// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_sticky_headers_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$TaskStickyHeadersState {
  bool get isTaskHeaderVisible => throw _privateConstructorUsedError;
  bool get isAiSummaryVisible => throw _privateConstructorUsedError;
  bool get isChecklistsVisible => throw _privateConstructorUsedError;
  double get scrollOffset => throw _privateConstructorUsedError;

  /// Create a copy of TaskStickyHeadersState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TaskStickyHeadersStateCopyWith<TaskStickyHeadersState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TaskStickyHeadersStateCopyWith<$Res> {
  factory $TaskStickyHeadersStateCopyWith(TaskStickyHeadersState value,
          $Res Function(TaskStickyHeadersState) then) =
      _$TaskStickyHeadersStateCopyWithImpl<$Res, TaskStickyHeadersState>;
  @useResult
  $Res call(
      {bool isTaskHeaderVisible,
      bool isAiSummaryVisible,
      bool isChecklistsVisible,
      double scrollOffset});
}

/// @nodoc
class _$TaskStickyHeadersStateCopyWithImpl<$Res,
        $Val extends TaskStickyHeadersState>
    implements $TaskStickyHeadersStateCopyWith<$Res> {
  _$TaskStickyHeadersStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TaskStickyHeadersState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isTaskHeaderVisible = null,
    Object? isAiSummaryVisible = null,
    Object? isChecklistsVisible = null,
    Object? scrollOffset = null,
  }) {
    return _then(_value.copyWith(
      isTaskHeaderVisible: null == isTaskHeaderVisible
          ? _value.isTaskHeaderVisible
          : isTaskHeaderVisible // ignore: cast_nullable_to_non_nullable
              as bool,
      isAiSummaryVisible: null == isAiSummaryVisible
          ? _value.isAiSummaryVisible
          : isAiSummaryVisible // ignore: cast_nullable_to_non_nullable
              as bool,
      isChecklistsVisible: null == isChecklistsVisible
          ? _value.isChecklistsVisible
          : isChecklistsVisible // ignore: cast_nullable_to_non_nullable
              as bool,
      scrollOffset: null == scrollOffset
          ? _value.scrollOffset
          : scrollOffset // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TaskStickyHeadersStateImplCopyWith<$Res>
    implements $TaskStickyHeadersStateCopyWith<$Res> {
  factory _$$TaskStickyHeadersStateImplCopyWith(
          _$TaskStickyHeadersStateImpl value,
          $Res Function(_$TaskStickyHeadersStateImpl) then) =
      __$$TaskStickyHeadersStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool isTaskHeaderVisible,
      bool isAiSummaryVisible,
      bool isChecklistsVisible,
      double scrollOffset});
}

/// @nodoc
class __$$TaskStickyHeadersStateImplCopyWithImpl<$Res>
    extends _$TaskStickyHeadersStateCopyWithImpl<$Res,
        _$TaskStickyHeadersStateImpl>
    implements _$$TaskStickyHeadersStateImplCopyWith<$Res> {
  __$$TaskStickyHeadersStateImplCopyWithImpl(
      _$TaskStickyHeadersStateImpl _value,
      $Res Function(_$TaskStickyHeadersStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of TaskStickyHeadersState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isTaskHeaderVisible = null,
    Object? isAiSummaryVisible = null,
    Object? isChecklistsVisible = null,
    Object? scrollOffset = null,
  }) {
    return _then(_$TaskStickyHeadersStateImpl(
      isTaskHeaderVisible: null == isTaskHeaderVisible
          ? _value.isTaskHeaderVisible
          : isTaskHeaderVisible // ignore: cast_nullable_to_non_nullable
              as bool,
      isAiSummaryVisible: null == isAiSummaryVisible
          ? _value.isAiSummaryVisible
          : isAiSummaryVisible // ignore: cast_nullable_to_non_nullable
              as bool,
      isChecklistsVisible: null == isChecklistsVisible
          ? _value.isChecklistsVisible
          : isChecklistsVisible // ignore: cast_nullable_to_non_nullable
              as bool,
      scrollOffset: null == scrollOffset
          ? _value.scrollOffset
          : scrollOffset // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc

class _$TaskStickyHeadersStateImpl implements _TaskStickyHeadersState {
  const _$TaskStickyHeadersStateImpl(
      {required this.isTaskHeaderVisible,
      required this.isAiSummaryVisible,
      required this.isChecklistsVisible,
      this.scrollOffset = 0.0});

  @override
  final bool isTaskHeaderVisible;
  @override
  final bool isAiSummaryVisible;
  @override
  final bool isChecklistsVisible;
  @override
  @JsonKey()
  final double scrollOffset;

  @override
  String toString() {
    return 'TaskStickyHeadersState(isTaskHeaderVisible: $isTaskHeaderVisible, isAiSummaryVisible: $isAiSummaryVisible, isChecklistsVisible: $isChecklistsVisible, scrollOffset: $scrollOffset)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskStickyHeadersStateImpl &&
            (identical(other.isTaskHeaderVisible, isTaskHeaderVisible) ||
                other.isTaskHeaderVisible == isTaskHeaderVisible) &&
            (identical(other.isAiSummaryVisible, isAiSummaryVisible) ||
                other.isAiSummaryVisible == isAiSummaryVisible) &&
            (identical(other.isChecklistsVisible, isChecklistsVisible) ||
                other.isChecklistsVisible == isChecklistsVisible) &&
            (identical(other.scrollOffset, scrollOffset) ||
                other.scrollOffset == scrollOffset));
  }

  @override
  int get hashCode => Object.hash(runtimeType, isTaskHeaderVisible,
      isAiSummaryVisible, isChecklistsVisible, scrollOffset);

  /// Create a copy of TaskStickyHeadersState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskStickyHeadersStateImplCopyWith<_$TaskStickyHeadersStateImpl>
      get copyWith => __$$TaskStickyHeadersStateImplCopyWithImpl<
          _$TaskStickyHeadersStateImpl>(this, _$identity);
}

abstract class _TaskStickyHeadersState implements TaskStickyHeadersState {
  const factory _TaskStickyHeadersState(
      {required final bool isTaskHeaderVisible,
      required final bool isAiSummaryVisible,
      required final bool isChecklistsVisible,
      final double scrollOffset}) = _$TaskStickyHeadersStateImpl;

  @override
  bool get isTaskHeaderVisible;
  @override
  bool get isAiSummaryVisible;
  @override
  bool get isChecklistsVisible;
  @override
  double get scrollOffset;

  /// Create a copy of TaskStickyHeadersState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskStickyHeadersStateImplCopyWith<_$TaskStickyHeadersStateImpl>
      get copyWith => throw _privateConstructorUsedError;
}
