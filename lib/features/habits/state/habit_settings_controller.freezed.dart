// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'habit_settings_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HabitSettingsState {
  HabitDefinition get habitDefinition;
  bool get dirty;
  GlobalKey<FormBuilderState> get formKey;
  List<StoryTag> get storyTags;
  AutoCompleteRule? get autoCompleteRule;
  StoryTag? get defaultStory;

  /// Create a copy of HabitSettingsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HabitSettingsStateCopyWith<HabitSettingsState> get copyWith =>
      _$HabitSettingsStateCopyWithImpl<HabitSettingsState>(
          this as HabitSettingsState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is HabitSettingsState &&
            const DeepCollectionEquality()
                .equals(other.habitDefinition, habitDefinition) &&
            (identical(other.dirty, dirty) || other.dirty == dirty) &&
            (identical(other.formKey, formKey) || other.formKey == formKey) &&
            const DeepCollectionEquality().equals(other.storyTags, storyTags) &&
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
      const DeepCollectionEquality().hash(storyTags),
      autoCompleteRule,
      const DeepCollectionEquality().hash(defaultStory));

  @override
  String toString() {
    return 'HabitSettingsState(habitDefinition: $habitDefinition, dirty: $dirty, formKey: $formKey, storyTags: $storyTags, autoCompleteRule: $autoCompleteRule, defaultStory: $defaultStory)';
  }
}

/// @nodoc
abstract mixin class $HabitSettingsStateCopyWith<$Res> {
  factory $HabitSettingsStateCopyWith(
          HabitSettingsState value, $Res Function(HabitSettingsState) _then) =
      _$HabitSettingsStateCopyWithImpl;
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
class _$HabitSettingsStateCopyWithImpl<$Res>
    implements $HabitSettingsStateCopyWith<$Res> {
  _$HabitSettingsStateCopyWithImpl(this._self, this._then);

  final HabitSettingsState _self;
  final $Res Function(HabitSettingsState) _then;

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
    return _then(_self.copyWith(
      habitDefinition: freezed == habitDefinition
          ? _self.habitDefinition
          : habitDefinition // ignore: cast_nullable_to_non_nullable
              as HabitDefinition,
      dirty: null == dirty
          ? _self.dirty
          : dirty // ignore: cast_nullable_to_non_nullable
              as bool,
      formKey: null == formKey
          ? _self.formKey
          : formKey // ignore: cast_nullable_to_non_nullable
              as GlobalKey<FormBuilderState>,
      storyTags: null == storyTags
          ? _self.storyTags
          : storyTags // ignore: cast_nullable_to_non_nullable
              as List<StoryTag>,
      autoCompleteRule: freezed == autoCompleteRule
          ? _self.autoCompleteRule
          : autoCompleteRule // ignore: cast_nullable_to_non_nullable
              as AutoCompleteRule?,
      defaultStory: freezed == defaultStory
          ? _self.defaultStory
          : defaultStory // ignore: cast_nullable_to_non_nullable
              as StoryTag?,
    ));
  }

  /// Create a copy of HabitSettingsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AutoCompleteRuleCopyWith<$Res>? get autoCompleteRule {
    if (_self.autoCompleteRule == null) {
      return null;
    }

    return $AutoCompleteRuleCopyWith<$Res>(_self.autoCompleteRule!, (value) {
      return _then(_self.copyWith(autoCompleteRule: value));
    });
  }
}

/// Adds pattern-matching-related methods to [HabitSettingsState].
extension HabitSettingsStatePatterns on HabitSettingsState {
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
    TResult Function(_HabitSettingsState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HabitSettingsState() when $default != null:
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
    TResult Function(_HabitSettingsState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HabitSettingsState():
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
    TResult? Function(_HabitSettingsState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HabitSettingsState() when $default != null:
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
            HabitDefinition habitDefinition,
            bool dirty,
            GlobalKey<FormBuilderState> formKey,
            List<StoryTag> storyTags,
            AutoCompleteRule? autoCompleteRule,
            StoryTag? defaultStory)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HabitSettingsState() when $default != null:
        return $default(_that.habitDefinition, _that.dirty, _that.formKey,
            _that.storyTags, _that.autoCompleteRule, _that.defaultStory);
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
            HabitDefinition habitDefinition,
            bool dirty,
            GlobalKey<FormBuilderState> formKey,
            List<StoryTag> storyTags,
            AutoCompleteRule? autoCompleteRule,
            StoryTag? defaultStory)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HabitSettingsState():
        return $default(_that.habitDefinition, _that.dirty, _that.formKey,
            _that.storyTags, _that.autoCompleteRule, _that.defaultStory);
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
            HabitDefinition habitDefinition,
            bool dirty,
            GlobalKey<FormBuilderState> formKey,
            List<StoryTag> storyTags,
            AutoCompleteRule? autoCompleteRule,
            StoryTag? defaultStory)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HabitSettingsState() when $default != null:
        return $default(_that.habitDefinition, _that.dirty, _that.formKey,
            _that.storyTags, _that.autoCompleteRule, _that.defaultStory);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _HabitSettingsState implements HabitSettingsState {
  const _HabitSettingsState(
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

  /// Create a copy of HabitSettingsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$HabitSettingsStateCopyWith<_HabitSettingsState> get copyWith =>
      __$HabitSettingsStateCopyWithImpl<_HabitSettingsState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _HabitSettingsState &&
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

  @override
  String toString() {
    return 'HabitSettingsState(habitDefinition: $habitDefinition, dirty: $dirty, formKey: $formKey, storyTags: $storyTags, autoCompleteRule: $autoCompleteRule, defaultStory: $defaultStory)';
  }
}

/// @nodoc
abstract mixin class _$HabitSettingsStateCopyWith<$Res>
    implements $HabitSettingsStateCopyWith<$Res> {
  factory _$HabitSettingsStateCopyWith(
          _HabitSettingsState value, $Res Function(_HabitSettingsState) _then) =
      __$HabitSettingsStateCopyWithImpl;
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
class __$HabitSettingsStateCopyWithImpl<$Res>
    implements _$HabitSettingsStateCopyWith<$Res> {
  __$HabitSettingsStateCopyWithImpl(this._self, this._then);

  final _HabitSettingsState _self;
  final $Res Function(_HabitSettingsState) _then;

  /// Create a copy of HabitSettingsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? habitDefinition = freezed,
    Object? dirty = null,
    Object? formKey = null,
    Object? storyTags = null,
    Object? autoCompleteRule = freezed,
    Object? defaultStory = freezed,
  }) {
    return _then(_HabitSettingsState(
      habitDefinition: freezed == habitDefinition
          ? _self.habitDefinition
          : habitDefinition // ignore: cast_nullable_to_non_nullable
              as HabitDefinition,
      dirty: null == dirty
          ? _self.dirty
          : dirty // ignore: cast_nullable_to_non_nullable
              as bool,
      formKey: null == formKey
          ? _self.formKey
          : formKey // ignore: cast_nullable_to_non_nullable
              as GlobalKey<FormBuilderState>,
      storyTags: null == storyTags
          ? _self._storyTags
          : storyTags // ignore: cast_nullable_to_non_nullable
              as List<StoryTag>,
      autoCompleteRule: freezed == autoCompleteRule
          ? _self.autoCompleteRule
          : autoCompleteRule // ignore: cast_nullable_to_non_nullable
              as AutoCompleteRule?,
      defaultStory: freezed == defaultStory
          ? _self.defaultStory
          : defaultStory // ignore: cast_nullable_to_non_nullable
              as StoryTag?,
    ));
  }

  /// Create a copy of HabitSettingsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AutoCompleteRuleCopyWith<$Res>? get autoCompleteRule {
    if (_self.autoCompleteRule == null) {
      return null;
    }

    return $AutoCompleteRuleCopyWith<$Res>(_self.autoCompleteRule!, (value) {
      return _then(_self.copyWith(autoCompleteRule: value));
    });
  }
}

// dart format on
