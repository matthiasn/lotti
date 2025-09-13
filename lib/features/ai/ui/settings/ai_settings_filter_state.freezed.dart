// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ai_settings_filter_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AiSettingsFilterState {
  /// Text query for searching across all AI configuration names and descriptions
  String get searchQuery;

  /// Selected provider IDs for filtering models (only used on Models tab)
  Set<String> get selectedProviders;

  /// Selected capabilities for filtering models (only used on Models tab)
  Set<Modality> get selectedCapabilities;

  /// Whether to show only reasoning-capable models (only used on Models tab)
  bool get reasoningFilter;

  /// Currently active tab
  AiSettingsTab get activeTab;

  /// Create a copy of AiSettingsFilterState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AiSettingsFilterStateCopyWith<AiSettingsFilterState> get copyWith =>
      _$AiSettingsFilterStateCopyWithImpl<AiSettingsFilterState>(
          this as AiSettingsFilterState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AiSettingsFilterState &&
            (identical(other.searchQuery, searchQuery) ||
                other.searchQuery == searchQuery) &&
            const DeepCollectionEquality()
                .equals(other.selectedProviders, selectedProviders) &&
            const DeepCollectionEquality()
                .equals(other.selectedCapabilities, selectedCapabilities) &&
            (identical(other.reasoningFilter, reasoningFilter) ||
                other.reasoningFilter == reasoningFilter) &&
            (identical(other.activeTab, activeTab) ||
                other.activeTab == activeTab));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      searchQuery,
      const DeepCollectionEquality().hash(selectedProviders),
      const DeepCollectionEquality().hash(selectedCapabilities),
      reasoningFilter,
      activeTab);

  @override
  String toString() {
    return 'AiSettingsFilterState(searchQuery: $searchQuery, selectedProviders: $selectedProviders, selectedCapabilities: $selectedCapabilities, reasoningFilter: $reasoningFilter, activeTab: $activeTab)';
  }
}

/// @nodoc
abstract mixin class $AiSettingsFilterStateCopyWith<$Res> {
  factory $AiSettingsFilterStateCopyWith(AiSettingsFilterState value,
          $Res Function(AiSettingsFilterState) _then) =
      _$AiSettingsFilterStateCopyWithImpl;
  @useResult
  $Res call(
      {String searchQuery,
      Set<String> selectedProviders,
      Set<Modality> selectedCapabilities,
      bool reasoningFilter,
      AiSettingsTab activeTab});
}

/// @nodoc
class _$AiSettingsFilterStateCopyWithImpl<$Res>
    implements $AiSettingsFilterStateCopyWith<$Res> {
  _$AiSettingsFilterStateCopyWithImpl(this._self, this._then);

  final AiSettingsFilterState _self;
  final $Res Function(AiSettingsFilterState) _then;

  /// Create a copy of AiSettingsFilterState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? searchQuery = null,
    Object? selectedProviders = null,
    Object? selectedCapabilities = null,
    Object? reasoningFilter = null,
    Object? activeTab = null,
  }) {
    return _then(_self.copyWith(
      searchQuery: null == searchQuery
          ? _self.searchQuery
          : searchQuery // ignore: cast_nullable_to_non_nullable
              as String,
      selectedProviders: null == selectedProviders
          ? _self.selectedProviders
          : selectedProviders // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      selectedCapabilities: null == selectedCapabilities
          ? _self.selectedCapabilities
          : selectedCapabilities // ignore: cast_nullable_to_non_nullable
              as Set<Modality>,
      reasoningFilter: null == reasoningFilter
          ? _self.reasoningFilter
          : reasoningFilter // ignore: cast_nullable_to_non_nullable
              as bool,
      activeTab: null == activeTab
          ? _self.activeTab
          : activeTab // ignore: cast_nullable_to_non_nullable
              as AiSettingsTab,
    ));
  }
}

/// Adds pattern-matching-related methods to [AiSettingsFilterState].
extension AiSettingsFilterStatePatterns on AiSettingsFilterState {
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
    TResult Function(_AiSettingsFilterState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AiSettingsFilterState() when $default != null:
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
    TResult Function(_AiSettingsFilterState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiSettingsFilterState():
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
    TResult? Function(_AiSettingsFilterState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiSettingsFilterState() when $default != null:
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
            String searchQuery,
            Set<String> selectedProviders,
            Set<Modality> selectedCapabilities,
            bool reasoningFilter,
            AiSettingsTab activeTab)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AiSettingsFilterState() when $default != null:
        return $default(_that.searchQuery, _that.selectedProviders,
            _that.selectedCapabilities, _that.reasoningFilter, _that.activeTab);
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
            String searchQuery,
            Set<String> selectedProviders,
            Set<Modality> selectedCapabilities,
            bool reasoningFilter,
            AiSettingsTab activeTab)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiSettingsFilterState():
        return $default(_that.searchQuery, _that.selectedProviders,
            _that.selectedCapabilities, _that.reasoningFilter, _that.activeTab);
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
            String searchQuery,
            Set<String> selectedProviders,
            Set<Modality> selectedCapabilities,
            bool reasoningFilter,
            AiSettingsTab activeTab)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiSettingsFilterState() when $default != null:
        return $default(_that.searchQuery, _that.selectedProviders,
            _that.selectedCapabilities, _that.reasoningFilter, _that.activeTab);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _AiSettingsFilterState implements AiSettingsFilterState {
  const _AiSettingsFilterState(
      {this.searchQuery = '',
      final Set<String> selectedProviders = const {},
      final Set<Modality> selectedCapabilities = const {},
      this.reasoningFilter = false,
      this.activeTab = AiSettingsTab.providers})
      : _selectedProviders = selectedProviders,
        _selectedCapabilities = selectedCapabilities;

  /// Text query for searching across all AI configuration names and descriptions
  @override
  @JsonKey()
  final String searchQuery;

  /// Selected provider IDs for filtering models (only used on Models tab)
  final Set<String> _selectedProviders;

  /// Selected provider IDs for filtering models (only used on Models tab)
  @override
  @JsonKey()
  Set<String> get selectedProviders {
    if (_selectedProviders is EqualUnmodifiableSetView)
      return _selectedProviders;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_selectedProviders);
  }

  /// Selected capabilities for filtering models (only used on Models tab)
  final Set<Modality> _selectedCapabilities;

  /// Selected capabilities for filtering models (only used on Models tab)
  @override
  @JsonKey()
  Set<Modality> get selectedCapabilities {
    if (_selectedCapabilities is EqualUnmodifiableSetView)
      return _selectedCapabilities;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_selectedCapabilities);
  }

  /// Whether to show only reasoning-capable models (only used on Models tab)
  @override
  @JsonKey()
  final bool reasoningFilter;

  /// Currently active tab
  @override
  @JsonKey()
  final AiSettingsTab activeTab;

  /// Create a copy of AiSettingsFilterState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AiSettingsFilterStateCopyWith<_AiSettingsFilterState> get copyWith =>
      __$AiSettingsFilterStateCopyWithImpl<_AiSettingsFilterState>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AiSettingsFilterState &&
            (identical(other.searchQuery, searchQuery) ||
                other.searchQuery == searchQuery) &&
            const DeepCollectionEquality()
                .equals(other._selectedProviders, _selectedProviders) &&
            const DeepCollectionEquality()
                .equals(other._selectedCapabilities, _selectedCapabilities) &&
            (identical(other.reasoningFilter, reasoningFilter) ||
                other.reasoningFilter == reasoningFilter) &&
            (identical(other.activeTab, activeTab) ||
                other.activeTab == activeTab));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      searchQuery,
      const DeepCollectionEquality().hash(_selectedProviders),
      const DeepCollectionEquality().hash(_selectedCapabilities),
      reasoningFilter,
      activeTab);

  @override
  String toString() {
    return 'AiSettingsFilterState(searchQuery: $searchQuery, selectedProviders: $selectedProviders, selectedCapabilities: $selectedCapabilities, reasoningFilter: $reasoningFilter, activeTab: $activeTab)';
  }
}

/// @nodoc
abstract mixin class _$AiSettingsFilterStateCopyWith<$Res>
    implements $AiSettingsFilterStateCopyWith<$Res> {
  factory _$AiSettingsFilterStateCopyWith(_AiSettingsFilterState value,
          $Res Function(_AiSettingsFilterState) _then) =
      __$AiSettingsFilterStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String searchQuery,
      Set<String> selectedProviders,
      Set<Modality> selectedCapabilities,
      bool reasoningFilter,
      AiSettingsTab activeTab});
}

/// @nodoc
class __$AiSettingsFilterStateCopyWithImpl<$Res>
    implements _$AiSettingsFilterStateCopyWith<$Res> {
  __$AiSettingsFilterStateCopyWithImpl(this._self, this._then);

  final _AiSettingsFilterState _self;
  final $Res Function(_AiSettingsFilterState) _then;

  /// Create a copy of AiSettingsFilterState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? searchQuery = null,
    Object? selectedProviders = null,
    Object? selectedCapabilities = null,
    Object? reasoningFilter = null,
    Object? activeTab = null,
  }) {
    return _then(_AiSettingsFilterState(
      searchQuery: null == searchQuery
          ? _self.searchQuery
          : searchQuery // ignore: cast_nullable_to_non_nullable
              as String,
      selectedProviders: null == selectedProviders
          ? _self._selectedProviders
          : selectedProviders // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      selectedCapabilities: null == selectedCapabilities
          ? _self._selectedCapabilities
          : selectedCapabilities // ignore: cast_nullable_to_non_nullable
              as Set<Modality>,
      reasoningFilter: null == reasoningFilter
          ? _self.reasoningFilter
          : reasoningFilter // ignore: cast_nullable_to_non_nullable
              as bool,
      activeTab: null == activeTab
          ? _self.activeTab
          : activeTab // ignore: cast_nullable_to_non_nullable
              as AiSettingsTab,
    ));
  }
}

// dart format on
