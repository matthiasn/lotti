// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'habit_settings_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$HabitSettingsState {
  HabitDefinition get habitDefinition => throw _privateConstructorUsedError;
  bool get dirty => throw _privateConstructorUsedError;
  GlobalKey<FormBuilderState> get formKey => throw _privateConstructorUsedError;
  List<StoryTag> get storyTags => throw _privateConstructorUsedError;
  AutoCompleteRule? get autoCompleteRule => throw _privateConstructorUsedError;
  StoryTag? get defaultStory => throw _privateConstructorUsedError;

  /// Create a copy of HabitSettingsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $HabitSettingsStateCopyWith<HabitSettingsState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HabitSettingsStateCopyWith<$Res> {
  factory $HabitSettingsStateCopyWith(
          HabitSettingsState value, $Res Function(HabitSettingsState) then) =
      _$HabitSettingsStateCopyWithImpl<$Res, HabitSettingsState>;
  @useResult
  $Res call(
      {HabitDefinition habitDefinition,
      bool dirty,
      GlobalKey<FormBuilderState> formKey,
      List<StoryTag> storyTags,
      AutoCompleteRule? autoCompleteRule,
      StoryTag? defaultStory});

  $AutoCompleteRuleCopyWith<$Res>? get autoCompleteRule;
}

/// @nodoc
class _$HabitSettingsStateCopyWithImpl<$Res, $Val extends HabitSettingsState>
    implements $HabitSettingsStateCopyWith<$Res> {
  _$HabitSettingsStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of HabitSettingsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? habitDefinition = freezed,
    Object? dirty = null,
    Object? formKey = null,
    Object? storyTags = null,
    Object? autoCompleteRule = freezed,
    Object? defaultStory = freezed,
  }) {
    return _then(_value.copyWith(
      habitDefinition: freezed == habitDefinition
          ? _value.habitDefinition
          : habitDefinition // ignore: cast_nullable_to_non_nullable
              as HabitDefinition,
      dirty: null == dirty
          ? _value.dirty
          : dirty // ignore: cast_nullable_to_non_nullable
              as bool,
      formKey: null == formKey
          ? _value.formKey
          : formKey // ignore: cast_nullable_to_non_nullable
              as GlobalKey<FormBuilderState>,
      storyTags: null == storyTags
          ? _value.storyTags
          : storyTags // ignore: cast_nullable_to_non_nullable
              as List<StoryTag>,
      autoCompleteRule: freezed == autoCompleteRule
          ? _value.autoCompleteRule
          : autoCompleteRule // ignore: cast_nullable_to_non_nullable
              as AutoCompleteRule?,
      defaultStory: freezed == defaultStory
          ? _value.defaultStory
          : defaultStory // ignore: cast_nullable_to_non_nullable
              as StoryTag?,
    ) as $Val);
  }

  /// Create a copy of HabitSettingsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AutoCompleteRuleCopyWith<$Res>? get autoCompleteRule {
    if (_value.autoCompleteRule == null) {
      return null;
    }

    return $AutoCompleteRuleCopyWith<$Res>(_value.autoCompleteRule!, (value) {
      return _then(_value.copyWith(autoCompleteRule: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$HabitSettingsStateSavedImplCopyWith<$Res>
    implements $HabitSettingsStateCopyWith<$Res> {
  factory _$$HabitSettingsStateSavedImplCopyWith(
          _$HabitSettingsStateSavedImpl value,
          $Res Function(_$HabitSettingsStateSavedImpl) then) =
      __$$HabitSettingsStateSavedImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {HabitDefinition habitDefinition,
      bool dirty,
      GlobalKey<FormBuilderState> formKey,
      List<StoryTag> storyTags,
      AutoCompleteRule? autoCompleteRule,
      StoryTag? defaultStory});

  @override
  $AutoCompleteRuleCopyWith<$Res>? get autoCompleteRule;
}

/// @nodoc
class __$$HabitSettingsStateSavedImplCopyWithImpl<$Res>
    extends _$HabitSettingsStateCopyWithImpl<$Res,
        _$HabitSettingsStateSavedImpl>
    implements _$$HabitSettingsStateSavedImplCopyWith<$Res> {
  __$$HabitSettingsStateSavedImplCopyWithImpl(
      _$HabitSettingsStateSavedImpl _value,
      $Res Function(_$HabitSettingsStateSavedImpl) _then)
      : super(_value, _then);

  /// Create a copy of HabitSettingsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? habitDefinition = freezed,
    Object? dirty = null,
    Object? formKey = null,
    Object? storyTags = null,
    Object? autoCompleteRule = freezed,
    Object? defaultStory = freezed,
  }) {
    return _then(_$HabitSettingsStateSavedImpl(
      habitDefinition: freezed == habitDefinition
          ? _value.habitDefinition
          : habitDefinition // ignore: cast_nullable_to_non_nullable
              as HabitDefinition,
      dirty: null == dirty
          ? _value.dirty
          : dirty // ignore: cast_nullable_to_non_nullable
              as bool,
      formKey: null == formKey
          ? _value.formKey
          : formKey // ignore: cast_nullable_to_non_nullable
              as GlobalKey<FormBuilderState>,
      storyTags: null == storyTags
          ? _value._storyTags
          : storyTags // ignore: cast_nullable_to_non_nullable
              as List<StoryTag>,
      autoCompleteRule: freezed == autoCompleteRule
          ? _value.autoCompleteRule
          : autoCompleteRule // ignore: cast_nullable_to_non_nullable
              as AutoCompleteRule?,
      defaultStory: freezed == defaultStory
          ? _value.defaultStory
          : defaultStory // ignore: cast_nullable_to_non_nullable
              as StoryTag?,
    ));
  }
}

/// @nodoc

class _$HabitSettingsStateSavedImpl implements _HabitSettingsStateSaved {
  _$HabitSettingsStateSavedImpl(
      {required this.habitDefinition,
      required this.dirty,
      required this.formKey,
      required final List<StoryTag> storyTags,
      required this.autoCompleteRule,
      this.defaultStory})
      : _storyTags = storyTags;

  @override
  final HabitDefinition habitDefinition;
  @override
  final bool dirty;
  @override
  final GlobalKey<FormBuilderState> formKey;
  final List<StoryTag> _storyTags;
  @override
  List<StoryTag> get storyTags {
    if (_storyTags is EqualUnmodifiableListView) return _storyTags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_storyTags);
  }

  @override
  final AutoCompleteRule? autoCompleteRule;
  @override
  final StoryTag? defaultStory;

  @override
  String toString() {
    return 'HabitSettingsState(habitDefinition: $habitDefinition, dirty: $dirty, formKey: $formKey, storyTags: $storyTags, autoCompleteRule: $autoCompleteRule, defaultStory: $defaultStory)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HabitSettingsStateSavedImpl &&
            const DeepCollectionEquality()
                .equals(other.habitDefinition, habitDefinition) &&
            (identical(other.dirty, dirty) || other.dirty == dirty) &&
            (identical(other.formKey, formKey) || other.formKey == formKey) &&
            const DeepCollectionEquality()
                .equals(other._storyTags, _storyTags) &&
            (identical(other.autoCompleteRule, autoCompleteRule) ||
                other.autoCompleteRule == autoCompleteRule) &&
            const DeepCollectionEquality()
                .equals(other.defaultStory, defaultStory));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(habitDefinition),
      dirty,
      formKey,
      const DeepCollectionEquality().hash(_storyTags),
      autoCompleteRule,
      const DeepCollectionEquality().hash(defaultStory));

  /// Create a copy of HabitSettingsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HabitSettingsStateSavedImplCopyWith<_$HabitSettingsStateSavedImpl>
      get copyWith => __$$HabitSettingsStateSavedImplCopyWithImpl<
          _$HabitSettingsStateSavedImpl>(this, _$identity);
}

abstract class _HabitSettingsStateSaved implements HabitSettingsState {
  factory _HabitSettingsStateSaved(
      {required final HabitDefinition habitDefinition,
      required final bool dirty,
      required final GlobalKey<FormBuilderState> formKey,
      required final List<StoryTag> storyTags,
      required final AutoCompleteRule? autoCompleteRule,
      final StoryTag? defaultStory}) = _$HabitSettingsStateSavedImpl;

  @override
  HabitDefinition get habitDefinition;
  @override
  bool get dirty;
  @override
  GlobalKey<FormBuilderState> get formKey;
  @override
  List<StoryTag> get storyTags;
  @override
  AutoCompleteRule? get autoCompleteRule;
  @override
  StoryTag? get defaultStory;

  /// Create a copy of HabitSettingsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HabitSettingsStateSavedImplCopyWith<_$HabitSettingsStateSavedImpl>
      get copyWith => throw _privateConstructorUsedError;
}
