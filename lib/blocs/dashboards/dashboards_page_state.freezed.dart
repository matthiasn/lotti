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
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$DashboardsPageState {
  List<DashboardDefinition> get allDashboards =>
      throw _privateConstructorUsedError;
  List<DashboardDefinition> get filteredSortedDashboards =>
      throw _privateConstructorUsedError;
  Set<String> get selectedCategoryIds => throw _privateConstructorUsedError;
  bool get showSearch => throw _privateConstructorUsedError;
  String get searchString => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
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
      Set<String> selectedCategoryIds,
      bool showSearch,
      String searchString});
}

/// @nodoc
class _$DashboardsPageStateCopyWithImpl<$Res, $Val extends DashboardsPageState>
    implements $DashboardsPageStateCopyWith<$Res> {
  _$DashboardsPageStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? allDashboards = null,
    Object? filteredSortedDashboards = null,
    Object? selectedCategoryIds = null,
    Object? showSearch = null,
    Object? searchString = null,
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
      showSearch: null == showSearch
          ? _value.showSearch
          : showSearch // ignore: cast_nullable_to_non_nullable
              as bool,
      searchString: null == searchString
          ? _value.searchString
          : searchString // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_DashboardsPageStateCopyWith<$Res>
    implements $DashboardsPageStateCopyWith<$Res> {
  factory _$$_DashboardsPageStateCopyWith(_$_DashboardsPageState value,
          $Res Function(_$_DashboardsPageState) then) =
      __$$_DashboardsPageStateCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<DashboardDefinition> allDashboards,
      List<DashboardDefinition> filteredSortedDashboards,
      Set<String> selectedCategoryIds,
      bool showSearch,
      String searchString});
}

/// @nodoc
class __$$_DashboardsPageStateCopyWithImpl<$Res>
    extends _$DashboardsPageStateCopyWithImpl<$Res, _$_DashboardsPageState>
    implements _$$_DashboardsPageStateCopyWith<$Res> {
  __$$_DashboardsPageStateCopyWithImpl(_$_DashboardsPageState _value,
      $Res Function(_$_DashboardsPageState) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? allDashboards = null,
    Object? filteredSortedDashboards = null,
    Object? selectedCategoryIds = null,
    Object? showSearch = null,
    Object? searchString = null,
  }) {
    return _then(_$_DashboardsPageState(
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
      showSearch: null == showSearch
          ? _value.showSearch
          : showSearch // ignore: cast_nullable_to_non_nullable
              as bool,
      searchString: null == searchString
          ? _value.searchString
          : searchString // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$_DashboardsPageState implements _DashboardsPageState {
  _$_DashboardsPageState(
      {required final List<DashboardDefinition> allDashboards,
      required final List<DashboardDefinition> filteredSortedDashboards,
      required final Set<String> selectedCategoryIds,
      required this.showSearch,
      required this.searchString})
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
  final bool showSearch;
  @override
  final String searchString;

  @override
  String toString() {
    return 'DashboardsPageState(allDashboards: $allDashboards, filteredSortedDashboards: $filteredSortedDashboards, selectedCategoryIds: $selectedCategoryIds, showSearch: $showSearch, searchString: $searchString)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_DashboardsPageState &&
            const DeepCollectionEquality()
                .equals(other._allDashboards, _allDashboards) &&
            const DeepCollectionEquality().equals(
                other._filteredSortedDashboards, _filteredSortedDashboards) &&
            const DeepCollectionEquality()
                .equals(other._selectedCategoryIds, _selectedCategoryIds) &&
            (identical(other.showSearch, showSearch) ||
                other.showSearch == showSearch) &&
            (identical(other.searchString, searchString) ||
                other.searchString == searchString));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_allDashboards),
      const DeepCollectionEquality().hash(_filteredSortedDashboards),
      const DeepCollectionEquality().hash(_selectedCategoryIds),
      showSearch,
      searchString);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_DashboardsPageStateCopyWith<_$_DashboardsPageState> get copyWith =>
      __$$_DashboardsPageStateCopyWithImpl<_$_DashboardsPageState>(
          this, _$identity);
}

abstract class _DashboardsPageState implements DashboardsPageState {
  factory _DashboardsPageState(
      {required final List<DashboardDefinition> allDashboards,
      required final List<DashboardDefinition> filteredSortedDashboards,
      required final Set<String> selectedCategoryIds,
      required final bool showSearch,
      required final String searchString}) = _$_DashboardsPageState;

  @override
  List<DashboardDefinition> get allDashboards;
  @override
  List<DashboardDefinition> get filteredSortedDashboards;
  @override
  Set<String> get selectedCategoryIds;
  @override
  bool get showSearch;
  @override
  String get searchString;
  @override
  @JsonKey(ignore: true)
  _$$_DashboardsPageStateCopyWith<_$_DashboardsPageState> get copyWith =>
      throw _privateConstructorUsedError;
}
