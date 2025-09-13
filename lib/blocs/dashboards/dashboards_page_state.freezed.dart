// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dashboards_page_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DashboardsPageState {
  List<DashboardDefinition> get allDashboards;
  List<DashboardDefinition> get filteredSortedDashboards;
  Set<String> get selectedCategoryIds;

  /// Create a copy of DashboardsPageState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DashboardsPageStateCopyWith<DashboardsPageState> get copyWith =>
      _$DashboardsPageStateCopyWithImpl<DashboardsPageState>(
          this as DashboardsPageState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DashboardsPageState &&
            const DeepCollectionEquality()
                .equals(other.allDashboards, allDashboards) &&
            const DeepCollectionEquality().equals(
                other.filteredSortedDashboards, filteredSortedDashboards) &&
            const DeepCollectionEquality()
                .equals(other.selectedCategoryIds, selectedCategoryIds));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(allDashboards),
      const DeepCollectionEquality().hash(filteredSortedDashboards),
      const DeepCollectionEquality().hash(selectedCategoryIds));

  @override
  String toString() {
    return 'DashboardsPageState(allDashboards: $allDashboards, filteredSortedDashboards: $filteredSortedDashboards, selectedCategoryIds: $selectedCategoryIds)';
  }
}

/// @nodoc
abstract mixin class $DashboardsPageStateCopyWith<$Res> {
  factory $DashboardsPageStateCopyWith(
          DashboardsPageState value, $Res Function(DashboardsPageState) _then) =
      _$DashboardsPageStateCopyWithImpl;
  @useResult
  $Res call(
      {List<DashboardDefinition> allDashboards,
      List<DashboardDefinition> filteredSortedDashboards,
      Set<String> selectedCategoryIds});
}

/// @nodoc
class _$DashboardsPageStateCopyWithImpl<$Res>
    implements $DashboardsPageStateCopyWith<$Res> {
  _$DashboardsPageStateCopyWithImpl(this._self, this._then);

  final DashboardsPageState _self;
  final $Res Function(DashboardsPageState) _then;

  /// Create a copy of DashboardsPageState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? allDashboards = null,
    Object? filteredSortedDashboards = null,
    Object? selectedCategoryIds = null,
  }) {
    return _then(_self.copyWith(
      allDashboards: null == allDashboards
          ? _self.allDashboards
          : allDashboards // ignore: cast_nullable_to_non_nullable
              as List<DashboardDefinition>,
      filteredSortedDashboards: null == filteredSortedDashboards
          ? _self.filteredSortedDashboards
          : filteredSortedDashboards // ignore: cast_nullable_to_non_nullable
              as List<DashboardDefinition>,
      selectedCategoryIds: null == selectedCategoryIds
          ? _self.selectedCategoryIds
          : selectedCategoryIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
    ));
  }
}

/// Adds pattern-matching-related methods to [DashboardsPageState].
extension DashboardsPageStatePatterns on DashboardsPageState {
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
    TResult Function(_DashboardsPageState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DashboardsPageState() when $default != null:
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
    TResult Function(_DashboardsPageState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DashboardsPageState():
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
    TResult? Function(_DashboardsPageState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DashboardsPageState() when $default != null:
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
            List<DashboardDefinition> allDashboards,
            List<DashboardDefinition> filteredSortedDashboards,
            Set<String> selectedCategoryIds)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DashboardsPageState() when $default != null:
        return $default(_that.allDashboards, _that.filteredSortedDashboards,
            _that.selectedCategoryIds);
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
            List<DashboardDefinition> allDashboards,
            List<DashboardDefinition> filteredSortedDashboards,
            Set<String> selectedCategoryIds)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DashboardsPageState():
        return $default(_that.allDashboards, _that.filteredSortedDashboards,
            _that.selectedCategoryIds);
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
            List<DashboardDefinition> allDashboards,
            List<DashboardDefinition> filteredSortedDashboards,
            Set<String> selectedCategoryIds)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DashboardsPageState() when $default != null:
        return $default(_that.allDashboards, _that.filteredSortedDashboards,
            _that.selectedCategoryIds);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _DashboardsPageState implements DashboardsPageState {
  _DashboardsPageState(
      {required final List<DashboardDefinition> allDashboards,
      required final List<DashboardDefinition> filteredSortedDashboards,
      required final Set<String> selectedCategoryIds})
      : _allDashboards = allDashboards,
        _filteredSortedDashboards = filteredSortedDashboards,
        _selectedCategoryIds = selectedCategoryIds;

  final List<DashboardDefinition> _allDashboards;
  @override
  List<DashboardDefinition> get allDashboards {
    if (_allDashboards is EqualUnmodifiableListView) return _allDashboards;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_allDashboards);
  }

  final List<DashboardDefinition> _filteredSortedDashboards;
  @override
  List<DashboardDefinition> get filteredSortedDashboards {
    if (_filteredSortedDashboards is EqualUnmodifiableListView)
      return _filteredSortedDashboards;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_filteredSortedDashboards);
  }

  final Set<String> _selectedCategoryIds;
  @override
  Set<String> get selectedCategoryIds {
    if (_selectedCategoryIds is EqualUnmodifiableSetView)
      return _selectedCategoryIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_selectedCategoryIds);
  }

  /// Create a copy of DashboardsPageState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$DashboardsPageStateCopyWith<_DashboardsPageState> get copyWith =>
      __$DashboardsPageStateCopyWithImpl<_DashboardsPageState>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _DashboardsPageState &&
            const DeepCollectionEquality()
                .equals(other._allDashboards, _allDashboards) &&
            const DeepCollectionEquality().equals(
                other._filteredSortedDashboards, _filteredSortedDashboards) &&
            const DeepCollectionEquality()
                .equals(other._selectedCategoryIds, _selectedCategoryIds));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_allDashboards),
      const DeepCollectionEquality().hash(_filteredSortedDashboards),
      const DeepCollectionEquality().hash(_selectedCategoryIds));

  @override
  String toString() {
    return 'DashboardsPageState(allDashboards: $allDashboards, filteredSortedDashboards: $filteredSortedDashboards, selectedCategoryIds: $selectedCategoryIds)';
  }
}

/// @nodoc
abstract mixin class _$DashboardsPageStateCopyWith<$Res>
    implements $DashboardsPageStateCopyWith<$Res> {
  factory _$DashboardsPageStateCopyWith(_DashboardsPageState value,
          $Res Function(_DashboardsPageState) _then) =
      __$DashboardsPageStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {List<DashboardDefinition> allDashboards,
      List<DashboardDefinition> filteredSortedDashboards,
      Set<String> selectedCategoryIds});
}

/// @nodoc
class __$DashboardsPageStateCopyWithImpl<$Res>
    implements _$DashboardsPageStateCopyWith<$Res> {
  __$DashboardsPageStateCopyWithImpl(this._self, this._then);

  final _DashboardsPageState _self;
  final $Res Function(_DashboardsPageState) _then;

  /// Create a copy of DashboardsPageState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? allDashboards = null,
    Object? filteredSortedDashboards = null,
    Object? selectedCategoryIds = null,
  }) {
    return _then(_DashboardsPageState(
      allDashboards: null == allDashboards
          ? _self._allDashboards
          : allDashboards // ignore: cast_nullable_to_non_nullable
              as List<DashboardDefinition>,
      filteredSortedDashboards: null == filteredSortedDashboards
          ? _self._filteredSortedDashboards
          : filteredSortedDashboards // ignore: cast_nullable_to_non_nullable
              as List<DashboardDefinition>,
      selectedCategoryIds: null == selectedCategoryIds
          ? _self._selectedCategoryIds
          : selectedCategoryIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
    ));
  }
}

// dart format on
