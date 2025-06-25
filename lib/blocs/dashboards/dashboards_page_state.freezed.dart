// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dashboards_page_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$DashboardsPageState {
  List<DashboardDefinition> get allDashboards =>
      throw _privateConstructorUsedError;
  List<DashboardDefinition> get filteredSortedDashboards =>
      throw _privateConstructorUsedError;
  Set<String> get selectedCategoryIds => throw _privateConstructorUsedError;

  /// Create a copy of DashboardsPageState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DashboardsPageStateCopyWith<DashboardsPageState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DashboardsPageStateCopyWith<$Res> {
  factory $DashboardsPageStateCopyWith(
          DashboardsPageState value, $Res Function(DashboardsPageState) then) =
      _$DashboardsPageStateCopyWithImpl<$Res, DashboardsPageState>;
  @useResult
  $Res call(
      {List<DashboardDefinition> allDashboards,
      List<DashboardDefinition> filteredSortedDashboards,
      Set<String> selectedCategoryIds});
}

/// @nodoc
class _$DashboardsPageStateCopyWithImpl<$Res, $Val extends DashboardsPageState>
    implements $DashboardsPageStateCopyWith<$Res> {
  _$DashboardsPageStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DashboardsPageState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? allDashboards = null,
    Object? filteredSortedDashboards = null,
    Object? selectedCategoryIds = null,
  }) {
    return _then(_value.copyWith(
      allDashboards: null == allDashboards
          ? _value.allDashboards
          : allDashboards // ignore: cast_nullable_to_non_nullable
              as List<DashboardDefinition>,
      filteredSortedDashboards: null == filteredSortedDashboards
          ? _value.filteredSortedDashboards
          : filteredSortedDashboards // ignore: cast_nullable_to_non_nullable
              as List<DashboardDefinition>,
      selectedCategoryIds: null == selectedCategoryIds
          ? _value.selectedCategoryIds
          : selectedCategoryIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DashboardsPageStateImplCopyWith<$Res>
    implements $DashboardsPageStateCopyWith<$Res> {
  factory _$$DashboardsPageStateImplCopyWith(_$DashboardsPageStateImpl value,
          $Res Function(_$DashboardsPageStateImpl) then) =
      __$$DashboardsPageStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<DashboardDefinition> allDashboards,
      List<DashboardDefinition> filteredSortedDashboards,
      Set<String> selectedCategoryIds});
}

/// @nodoc
class __$$DashboardsPageStateImplCopyWithImpl<$Res>
    extends _$DashboardsPageStateCopyWithImpl<$Res, _$DashboardsPageStateImpl>
    implements _$$DashboardsPageStateImplCopyWith<$Res> {
  __$$DashboardsPageStateImplCopyWithImpl(_$DashboardsPageStateImpl _value,
      $Res Function(_$DashboardsPageStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of DashboardsPageState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? allDashboards = null,
    Object? filteredSortedDashboards = null,
    Object? selectedCategoryIds = null,
  }) {
    return _then(_$DashboardsPageStateImpl(
      allDashboards: null == allDashboards
          ? _value._allDashboards
          : allDashboards // ignore: cast_nullable_to_non_nullable
              as List<DashboardDefinition>,
      filteredSortedDashboards: null == filteredSortedDashboards
          ? _value._filteredSortedDashboards
          : filteredSortedDashboards // ignore: cast_nullable_to_non_nullable
              as List<DashboardDefinition>,
      selectedCategoryIds: null == selectedCategoryIds
          ? _value._selectedCategoryIds
          : selectedCategoryIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
    ));
  }
}

/// @nodoc

class _$DashboardsPageStateImpl implements _DashboardsPageState {
  _$DashboardsPageStateImpl(
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

  @override
  String toString() {
    return 'DashboardsPageState(allDashboards: $allDashboards, filteredSortedDashboards: $filteredSortedDashboards, selectedCategoryIds: $selectedCategoryIds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DashboardsPageStateImpl &&
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

  /// Create a copy of DashboardsPageState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DashboardsPageStateImplCopyWith<_$DashboardsPageStateImpl> get copyWith =>
      __$$DashboardsPageStateImplCopyWithImpl<_$DashboardsPageStateImpl>(
          this, _$identity);
}

abstract class _DashboardsPageState implements DashboardsPageState {
  factory _DashboardsPageState(
          {required final List<DashboardDefinition> allDashboards,
          required final List<DashboardDefinition> filteredSortedDashboards,
          required final Set<String> selectedCategoryIds}) =
      _$DashboardsPageStateImpl;

  @override
  List<DashboardDefinition> get allDashboards;
  @override
  List<DashboardDefinition> get filteredSortedDashboards;
  @override
  Set<String> get selectedCategoryIds;

  /// Create a copy of DashboardsPageState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DashboardsPageStateImplCopyWith<_$DashboardsPageStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
