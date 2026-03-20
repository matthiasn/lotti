// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'journal_page_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$JournalPageState {

 String get match; Set<DisplayFilter> get filters; bool get showPrivateEntries; bool get showTasks; List<String> get selectedEntryTypes; Set<String> get fullTextMatches;@JsonKey(includeFromJson: false, includeToJson: false) PagingController<int, JournalEntity>? get pagingController; List<String> get taskStatuses; Set<String> get selectedTaskStatuses; Set<String> get selectedCategoryIds; Set<String> get selectedProjectIds; Set<String> get selectedLabelIds; Set<String> get selectedPriorities; TaskSortOption get sortOption; bool get showCreationDate; bool get showDueDate; bool get showCoverArt; bool get showProjectsHeader; SearchMode get searchMode; bool get showDistances; AgentAssignmentFilter get agentAssignmentFilter; bool get enableVectorSearch; bool get enableProjects; bool get vectorSearchInFlight; Duration? get vectorSearchElapsed; int get vectorSearchResultCount; Map<String, double> get vectorSearchDistances;
/// Create a copy of JournalPageState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JournalPageStateCopyWith<JournalPageState> get copyWith => _$JournalPageStateCopyWithImpl<JournalPageState>(this as JournalPageState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JournalPageState&&(identical(other.match, match) || other.match == match)&&const DeepCollectionEquality().equals(other.filters, filters)&&(identical(other.showPrivateEntries, showPrivateEntries) || other.showPrivateEntries == showPrivateEntries)&&(identical(other.showTasks, showTasks) || other.showTasks == showTasks)&&const DeepCollectionEquality().equals(other.selectedEntryTypes, selectedEntryTypes)&&const DeepCollectionEquality().equals(other.fullTextMatches, fullTextMatches)&&(identical(other.pagingController, pagingController) || other.pagingController == pagingController)&&const DeepCollectionEquality().equals(other.taskStatuses, taskStatuses)&&const DeepCollectionEquality().equals(other.selectedTaskStatuses, selectedTaskStatuses)&&const DeepCollectionEquality().equals(other.selectedCategoryIds, selectedCategoryIds)&&const DeepCollectionEquality().equals(other.selectedProjectIds, selectedProjectIds)&&const DeepCollectionEquality().equals(other.selectedLabelIds, selectedLabelIds)&&const DeepCollectionEquality().equals(other.selectedPriorities, selectedPriorities)&&(identical(other.sortOption, sortOption) || other.sortOption == sortOption)&&(identical(other.showCreationDate, showCreationDate) || other.showCreationDate == showCreationDate)&&(identical(other.showDueDate, showDueDate) || other.showDueDate == showDueDate)&&(identical(other.showCoverArt, showCoverArt) || other.showCoverArt == showCoverArt)&&(identical(other.showProjectsHeader, showProjectsHeader) || other.showProjectsHeader == showProjectsHeader)&&(identical(other.searchMode, searchMode) || other.searchMode == searchMode)&&(identical(other.showDistances, showDistances) || other.showDistances == showDistances)&&(identical(other.agentAssignmentFilter, agentAssignmentFilter) || other.agentAssignmentFilter == agentAssignmentFilter)&&(identical(other.enableVectorSearch, enableVectorSearch) || other.enableVectorSearch == enableVectorSearch)&&(identical(other.enableProjects, enableProjects) || other.enableProjects == enableProjects)&&(identical(other.vectorSearchInFlight, vectorSearchInFlight) || other.vectorSearchInFlight == vectorSearchInFlight)&&(identical(other.vectorSearchElapsed, vectorSearchElapsed) || other.vectorSearchElapsed == vectorSearchElapsed)&&(identical(other.vectorSearchResultCount, vectorSearchResultCount) || other.vectorSearchResultCount == vectorSearchResultCount)&&const DeepCollectionEquality().equals(other.vectorSearchDistances, vectorSearchDistances));
}


@override
int get hashCode => Object.hashAll([runtimeType,match,const DeepCollectionEquality().hash(filters),showPrivateEntries,showTasks,const DeepCollectionEquality().hash(selectedEntryTypes),const DeepCollectionEquality().hash(fullTextMatches),pagingController,const DeepCollectionEquality().hash(taskStatuses),const DeepCollectionEquality().hash(selectedTaskStatuses),const DeepCollectionEquality().hash(selectedCategoryIds),const DeepCollectionEquality().hash(selectedProjectIds),const DeepCollectionEquality().hash(selectedLabelIds),const DeepCollectionEquality().hash(selectedPriorities),sortOption,showCreationDate,showDueDate,showCoverArt,showProjectsHeader,searchMode,showDistances,agentAssignmentFilter,enableVectorSearch,enableProjects,vectorSearchInFlight,vectorSearchElapsed,vectorSearchResultCount,const DeepCollectionEquality().hash(vectorSearchDistances)]);

@override
String toString() {
  return 'JournalPageState(match: $match, filters: $filters, showPrivateEntries: $showPrivateEntries, showTasks: $showTasks, selectedEntryTypes: $selectedEntryTypes, fullTextMatches: $fullTextMatches, pagingController: $pagingController, taskStatuses: $taskStatuses, selectedTaskStatuses: $selectedTaskStatuses, selectedCategoryIds: $selectedCategoryIds, selectedProjectIds: $selectedProjectIds, selectedLabelIds: $selectedLabelIds, selectedPriorities: $selectedPriorities, sortOption: $sortOption, showCreationDate: $showCreationDate, showDueDate: $showDueDate, showCoverArt: $showCoverArt, showProjectsHeader: $showProjectsHeader, searchMode: $searchMode, showDistances: $showDistances, agentAssignmentFilter: $agentAssignmentFilter, enableVectorSearch: $enableVectorSearch, enableProjects: $enableProjects, vectorSearchInFlight: $vectorSearchInFlight, vectorSearchElapsed: $vectorSearchElapsed, vectorSearchResultCount: $vectorSearchResultCount, vectorSearchDistances: $vectorSearchDistances)';
}


}

/// @nodoc
abstract mixin class $JournalPageStateCopyWith<$Res>  {
  factory $JournalPageStateCopyWith(JournalPageState value, $Res Function(JournalPageState) _then) = _$JournalPageStateCopyWithImpl;
@useResult
$Res call({
 String match, Set<DisplayFilter> filters, bool showPrivateEntries, bool showTasks, List<String> selectedEntryTypes, Set<String> fullTextMatches,@JsonKey(includeFromJson: false, includeToJson: false) PagingController<int, JournalEntity>? pagingController, List<String> taskStatuses, Set<String> selectedTaskStatuses, Set<String> selectedCategoryIds, Set<String> selectedProjectIds, Set<String> selectedLabelIds, Set<String> selectedPriorities, TaskSortOption sortOption, bool showCreationDate, bool showDueDate, bool showCoverArt, bool showProjectsHeader, SearchMode searchMode, bool showDistances, AgentAssignmentFilter agentAssignmentFilter, bool enableVectorSearch, bool enableProjects, bool vectorSearchInFlight, Duration? vectorSearchElapsed, int vectorSearchResultCount, Map<String, double> vectorSearchDistances
});




}
/// @nodoc
class _$JournalPageStateCopyWithImpl<$Res>
    implements $JournalPageStateCopyWith<$Res> {
  _$JournalPageStateCopyWithImpl(this._self, this._then);

  final JournalPageState _self;
  final $Res Function(JournalPageState) _then;

/// Create a copy of JournalPageState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? match = null,Object? filters = null,Object? showPrivateEntries = null,Object? showTasks = null,Object? selectedEntryTypes = null,Object? fullTextMatches = null,Object? pagingController = freezed,Object? taskStatuses = null,Object? selectedTaskStatuses = null,Object? selectedCategoryIds = null,Object? selectedProjectIds = null,Object? selectedLabelIds = null,Object? selectedPriorities = null,Object? sortOption = null,Object? showCreationDate = null,Object? showDueDate = null,Object? showCoverArt = null,Object? showProjectsHeader = null,Object? searchMode = null,Object? showDistances = null,Object? agentAssignmentFilter = null,Object? enableVectorSearch = null,Object? enableProjects = null,Object? vectorSearchInFlight = null,Object? vectorSearchElapsed = freezed,Object? vectorSearchResultCount = null,Object? vectorSearchDistances = null,}) {
  return _then(_self.copyWith(
match: null == match ? _self.match : match // ignore: cast_nullable_to_non_nullable
as String,filters: null == filters ? _self.filters : filters // ignore: cast_nullable_to_non_nullable
as Set<DisplayFilter>,showPrivateEntries: null == showPrivateEntries ? _self.showPrivateEntries : showPrivateEntries // ignore: cast_nullable_to_non_nullable
as bool,showTasks: null == showTasks ? _self.showTasks : showTasks // ignore: cast_nullable_to_non_nullable
as bool,selectedEntryTypes: null == selectedEntryTypes ? _self.selectedEntryTypes : selectedEntryTypes // ignore: cast_nullable_to_non_nullable
as List<String>,fullTextMatches: null == fullTextMatches ? _self.fullTextMatches : fullTextMatches // ignore: cast_nullable_to_non_nullable
as Set<String>,pagingController: freezed == pagingController ? _self.pagingController : pagingController // ignore: cast_nullable_to_non_nullable
as PagingController<int, JournalEntity>?,taskStatuses: null == taskStatuses ? _self.taskStatuses : taskStatuses // ignore: cast_nullable_to_non_nullable
as List<String>,selectedTaskStatuses: null == selectedTaskStatuses ? _self.selectedTaskStatuses : selectedTaskStatuses // ignore: cast_nullable_to_non_nullable
as Set<String>,selectedCategoryIds: null == selectedCategoryIds ? _self.selectedCategoryIds : selectedCategoryIds // ignore: cast_nullable_to_non_nullable
as Set<String>,selectedProjectIds: null == selectedProjectIds ? _self.selectedProjectIds : selectedProjectIds // ignore: cast_nullable_to_non_nullable
as Set<String>,selectedLabelIds: null == selectedLabelIds ? _self.selectedLabelIds : selectedLabelIds // ignore: cast_nullable_to_non_nullable
as Set<String>,selectedPriorities: null == selectedPriorities ? _self.selectedPriorities : selectedPriorities // ignore: cast_nullable_to_non_nullable
as Set<String>,sortOption: null == sortOption ? _self.sortOption : sortOption // ignore: cast_nullable_to_non_nullable
as TaskSortOption,showCreationDate: null == showCreationDate ? _self.showCreationDate : showCreationDate // ignore: cast_nullable_to_non_nullable
as bool,showDueDate: null == showDueDate ? _self.showDueDate : showDueDate // ignore: cast_nullable_to_non_nullable
as bool,showCoverArt: null == showCoverArt ? _self.showCoverArt : showCoverArt // ignore: cast_nullable_to_non_nullable
as bool,showProjectsHeader: null == showProjectsHeader ? _self.showProjectsHeader : showProjectsHeader // ignore: cast_nullable_to_non_nullable
as bool,searchMode: null == searchMode ? _self.searchMode : searchMode // ignore: cast_nullable_to_non_nullable
as SearchMode,showDistances: null == showDistances ? _self.showDistances : showDistances // ignore: cast_nullable_to_non_nullable
as bool,agentAssignmentFilter: null == agentAssignmentFilter ? _self.agentAssignmentFilter : agentAssignmentFilter // ignore: cast_nullable_to_non_nullable
as AgentAssignmentFilter,enableVectorSearch: null == enableVectorSearch ? _self.enableVectorSearch : enableVectorSearch // ignore: cast_nullable_to_non_nullable
as bool,enableProjects: null == enableProjects ? _self.enableProjects : enableProjects // ignore: cast_nullable_to_non_nullable
as bool,vectorSearchInFlight: null == vectorSearchInFlight ? _self.vectorSearchInFlight : vectorSearchInFlight // ignore: cast_nullable_to_non_nullable
as bool,vectorSearchElapsed: freezed == vectorSearchElapsed ? _self.vectorSearchElapsed : vectorSearchElapsed // ignore: cast_nullable_to_non_nullable
as Duration?,vectorSearchResultCount: null == vectorSearchResultCount ? _self.vectorSearchResultCount : vectorSearchResultCount // ignore: cast_nullable_to_non_nullable
as int,vectorSearchDistances: null == vectorSearchDistances ? _self.vectorSearchDistances : vectorSearchDistances // ignore: cast_nullable_to_non_nullable
as Map<String, double>,
  ));
}

}


/// Adds pattern-matching-related methods to [JournalPageState].
extension JournalPageStatePatterns on JournalPageState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _JournalPageState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _JournalPageState() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _JournalPageState value)  $default,){
final _that = this;
switch (_that) {
case _JournalPageState():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _JournalPageState value)?  $default,){
final _that = this;
switch (_that) {
case _JournalPageState() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String match,  Set<DisplayFilter> filters,  bool showPrivateEntries,  bool showTasks,  List<String> selectedEntryTypes,  Set<String> fullTextMatches, @JsonKey(includeFromJson: false, includeToJson: false)  PagingController<int, JournalEntity>? pagingController,  List<String> taskStatuses,  Set<String> selectedTaskStatuses,  Set<String> selectedCategoryIds,  Set<String> selectedProjectIds,  Set<String> selectedLabelIds,  Set<String> selectedPriorities,  TaskSortOption sortOption,  bool showCreationDate,  bool showDueDate,  bool showCoverArt,  bool showProjectsHeader,  SearchMode searchMode,  bool showDistances,  AgentAssignmentFilter agentAssignmentFilter,  bool enableVectorSearch,  bool enableProjects,  bool vectorSearchInFlight,  Duration? vectorSearchElapsed,  int vectorSearchResultCount,  Map<String, double> vectorSearchDistances)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _JournalPageState() when $default != null:
return $default(_that.match,_that.filters,_that.showPrivateEntries,_that.showTasks,_that.selectedEntryTypes,_that.fullTextMatches,_that.pagingController,_that.taskStatuses,_that.selectedTaskStatuses,_that.selectedCategoryIds,_that.selectedProjectIds,_that.selectedLabelIds,_that.selectedPriorities,_that.sortOption,_that.showCreationDate,_that.showDueDate,_that.showCoverArt,_that.showProjectsHeader,_that.searchMode,_that.showDistances,_that.agentAssignmentFilter,_that.enableVectorSearch,_that.enableProjects,_that.vectorSearchInFlight,_that.vectorSearchElapsed,_that.vectorSearchResultCount,_that.vectorSearchDistances);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String match,  Set<DisplayFilter> filters,  bool showPrivateEntries,  bool showTasks,  List<String> selectedEntryTypes,  Set<String> fullTextMatches, @JsonKey(includeFromJson: false, includeToJson: false)  PagingController<int, JournalEntity>? pagingController,  List<String> taskStatuses,  Set<String> selectedTaskStatuses,  Set<String> selectedCategoryIds,  Set<String> selectedProjectIds,  Set<String> selectedLabelIds,  Set<String> selectedPriorities,  TaskSortOption sortOption,  bool showCreationDate,  bool showDueDate,  bool showCoverArt,  bool showProjectsHeader,  SearchMode searchMode,  bool showDistances,  AgentAssignmentFilter agentAssignmentFilter,  bool enableVectorSearch,  bool enableProjects,  bool vectorSearchInFlight,  Duration? vectorSearchElapsed,  int vectorSearchResultCount,  Map<String, double> vectorSearchDistances)  $default,) {final _that = this;
switch (_that) {
case _JournalPageState():
return $default(_that.match,_that.filters,_that.showPrivateEntries,_that.showTasks,_that.selectedEntryTypes,_that.fullTextMatches,_that.pagingController,_that.taskStatuses,_that.selectedTaskStatuses,_that.selectedCategoryIds,_that.selectedProjectIds,_that.selectedLabelIds,_that.selectedPriorities,_that.sortOption,_that.showCreationDate,_that.showDueDate,_that.showCoverArt,_that.showProjectsHeader,_that.searchMode,_that.showDistances,_that.agentAssignmentFilter,_that.enableVectorSearch,_that.enableProjects,_that.vectorSearchInFlight,_that.vectorSearchElapsed,_that.vectorSearchResultCount,_that.vectorSearchDistances);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String match,  Set<DisplayFilter> filters,  bool showPrivateEntries,  bool showTasks,  List<String> selectedEntryTypes,  Set<String> fullTextMatches, @JsonKey(includeFromJson: false, includeToJson: false)  PagingController<int, JournalEntity>? pagingController,  List<String> taskStatuses,  Set<String> selectedTaskStatuses,  Set<String> selectedCategoryIds,  Set<String> selectedProjectIds,  Set<String> selectedLabelIds,  Set<String> selectedPriorities,  TaskSortOption sortOption,  bool showCreationDate,  bool showDueDate,  bool showCoverArt,  bool showProjectsHeader,  SearchMode searchMode,  bool showDistances,  AgentAssignmentFilter agentAssignmentFilter,  bool enableVectorSearch,  bool enableProjects,  bool vectorSearchInFlight,  Duration? vectorSearchElapsed,  int vectorSearchResultCount,  Map<String, double> vectorSearchDistances)?  $default,) {final _that = this;
switch (_that) {
case _JournalPageState() when $default != null:
return $default(_that.match,_that.filters,_that.showPrivateEntries,_that.showTasks,_that.selectedEntryTypes,_that.fullTextMatches,_that.pagingController,_that.taskStatuses,_that.selectedTaskStatuses,_that.selectedCategoryIds,_that.selectedProjectIds,_that.selectedLabelIds,_that.selectedPriorities,_that.sortOption,_that.showCreationDate,_that.showDueDate,_that.showCoverArt,_that.showProjectsHeader,_that.searchMode,_that.showDistances,_that.agentAssignmentFilter,_that.enableVectorSearch,_that.enableProjects,_that.vectorSearchInFlight,_that.vectorSearchElapsed,_that.vectorSearchResultCount,_that.vectorSearchDistances);case _:
  return null;

}
}

}

/// @nodoc


class _JournalPageState implements JournalPageState {
  const _JournalPageState({this.match = '', final  Set<DisplayFilter> filters = const <DisplayFilter>{}, this.showPrivateEntries = false, this.showTasks = false, final  List<String> selectedEntryTypes = const [], final  Set<String> fullTextMatches = const <String>{}, @JsonKey(includeFromJson: false, includeToJson: false) this.pagingController, final  List<String> taskStatuses = const [], final  Set<String> selectedTaskStatuses = const <String>{}, final  Set<String> selectedCategoryIds = const <String>{}, final  Set<String> selectedProjectIds = const <String>{}, final  Set<String> selectedLabelIds = const <String>{}, final  Set<String> selectedPriorities = const <String>{}, this.sortOption = TaskSortOption.byPriority, this.showCreationDate = false, this.showDueDate = true, this.showCoverArt = true, this.showProjectsHeader = true, this.searchMode = SearchMode.fullText, this.showDistances = false, this.agentAssignmentFilter = AgentAssignmentFilter.all, this.enableVectorSearch = false, this.enableProjects = false, this.vectorSearchInFlight = false, this.vectorSearchElapsed, this.vectorSearchResultCount = 0, final  Map<String, double> vectorSearchDistances = const <String, double>{}}): _filters = filters,_selectedEntryTypes = selectedEntryTypes,_fullTextMatches = fullTextMatches,_taskStatuses = taskStatuses,_selectedTaskStatuses = selectedTaskStatuses,_selectedCategoryIds = selectedCategoryIds,_selectedProjectIds = selectedProjectIds,_selectedLabelIds = selectedLabelIds,_selectedPriorities = selectedPriorities,_vectorSearchDistances = vectorSearchDistances;
  

@override@JsonKey() final  String match;
 final  Set<DisplayFilter> _filters;
@override@JsonKey() Set<DisplayFilter> get filters {
  if (_filters is EqualUnmodifiableSetView) return _filters;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_filters);
}

@override@JsonKey() final  bool showPrivateEntries;
@override@JsonKey() final  bool showTasks;
 final  List<String> _selectedEntryTypes;
@override@JsonKey() List<String> get selectedEntryTypes {
  if (_selectedEntryTypes is EqualUnmodifiableListView) return _selectedEntryTypes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_selectedEntryTypes);
}

 final  Set<String> _fullTextMatches;
@override@JsonKey() Set<String> get fullTextMatches {
  if (_fullTextMatches is EqualUnmodifiableSetView) return _fullTextMatches;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_fullTextMatches);
}

@override@JsonKey(includeFromJson: false, includeToJson: false) final  PagingController<int, JournalEntity>? pagingController;
 final  List<String> _taskStatuses;
@override@JsonKey() List<String> get taskStatuses {
  if (_taskStatuses is EqualUnmodifiableListView) return _taskStatuses;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_taskStatuses);
}

 final  Set<String> _selectedTaskStatuses;
@override@JsonKey() Set<String> get selectedTaskStatuses {
  if (_selectedTaskStatuses is EqualUnmodifiableSetView) return _selectedTaskStatuses;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_selectedTaskStatuses);
}

 final  Set<String> _selectedCategoryIds;
@override@JsonKey() Set<String> get selectedCategoryIds {
  if (_selectedCategoryIds is EqualUnmodifiableSetView) return _selectedCategoryIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_selectedCategoryIds);
}

 final  Set<String> _selectedProjectIds;
@override@JsonKey() Set<String> get selectedProjectIds {
  if (_selectedProjectIds is EqualUnmodifiableSetView) return _selectedProjectIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_selectedProjectIds);
}

 final  Set<String> _selectedLabelIds;
@override@JsonKey() Set<String> get selectedLabelIds {
  if (_selectedLabelIds is EqualUnmodifiableSetView) return _selectedLabelIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_selectedLabelIds);
}

 final  Set<String> _selectedPriorities;
@override@JsonKey() Set<String> get selectedPriorities {
  if (_selectedPriorities is EqualUnmodifiableSetView) return _selectedPriorities;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_selectedPriorities);
}

@override@JsonKey() final  TaskSortOption sortOption;
@override@JsonKey() final  bool showCreationDate;
@override@JsonKey() final  bool showDueDate;
@override@JsonKey() final  bool showCoverArt;
@override@JsonKey() final  bool showProjectsHeader;
@override@JsonKey() final  SearchMode searchMode;
@override@JsonKey() final  bool showDistances;
@override@JsonKey() final  AgentAssignmentFilter agentAssignmentFilter;
@override@JsonKey() final  bool enableVectorSearch;
@override@JsonKey() final  bool enableProjects;
@override@JsonKey() final  bool vectorSearchInFlight;
@override final  Duration? vectorSearchElapsed;
@override@JsonKey() final  int vectorSearchResultCount;
 final  Map<String, double> _vectorSearchDistances;
@override@JsonKey() Map<String, double> get vectorSearchDistances {
  if (_vectorSearchDistances is EqualUnmodifiableMapView) return _vectorSearchDistances;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_vectorSearchDistances);
}


/// Create a copy of JournalPageState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$JournalPageStateCopyWith<_JournalPageState> get copyWith => __$JournalPageStateCopyWithImpl<_JournalPageState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _JournalPageState&&(identical(other.match, match) || other.match == match)&&const DeepCollectionEquality().equals(other._filters, _filters)&&(identical(other.showPrivateEntries, showPrivateEntries) || other.showPrivateEntries == showPrivateEntries)&&(identical(other.showTasks, showTasks) || other.showTasks == showTasks)&&const DeepCollectionEquality().equals(other._selectedEntryTypes, _selectedEntryTypes)&&const DeepCollectionEquality().equals(other._fullTextMatches, _fullTextMatches)&&(identical(other.pagingController, pagingController) || other.pagingController == pagingController)&&const DeepCollectionEquality().equals(other._taskStatuses, _taskStatuses)&&const DeepCollectionEquality().equals(other._selectedTaskStatuses, _selectedTaskStatuses)&&const DeepCollectionEquality().equals(other._selectedCategoryIds, _selectedCategoryIds)&&const DeepCollectionEquality().equals(other._selectedProjectIds, _selectedProjectIds)&&const DeepCollectionEquality().equals(other._selectedLabelIds, _selectedLabelIds)&&const DeepCollectionEquality().equals(other._selectedPriorities, _selectedPriorities)&&(identical(other.sortOption, sortOption) || other.sortOption == sortOption)&&(identical(other.showCreationDate, showCreationDate) || other.showCreationDate == showCreationDate)&&(identical(other.showDueDate, showDueDate) || other.showDueDate == showDueDate)&&(identical(other.showCoverArt, showCoverArt) || other.showCoverArt == showCoverArt)&&(identical(other.showProjectsHeader, showProjectsHeader) || other.showProjectsHeader == showProjectsHeader)&&(identical(other.searchMode, searchMode) || other.searchMode == searchMode)&&(identical(other.showDistances, showDistances) || other.showDistances == showDistances)&&(identical(other.agentAssignmentFilter, agentAssignmentFilter) || other.agentAssignmentFilter == agentAssignmentFilter)&&(identical(other.enableVectorSearch, enableVectorSearch) || other.enableVectorSearch == enableVectorSearch)&&(identical(other.enableProjects, enableProjects) || other.enableProjects == enableProjects)&&(identical(other.vectorSearchInFlight, vectorSearchInFlight) || other.vectorSearchInFlight == vectorSearchInFlight)&&(identical(other.vectorSearchElapsed, vectorSearchElapsed) || other.vectorSearchElapsed == vectorSearchElapsed)&&(identical(other.vectorSearchResultCount, vectorSearchResultCount) || other.vectorSearchResultCount == vectorSearchResultCount)&&const DeepCollectionEquality().equals(other._vectorSearchDistances, _vectorSearchDistances));
}


@override
int get hashCode => Object.hashAll([runtimeType,match,const DeepCollectionEquality().hash(_filters),showPrivateEntries,showTasks,const DeepCollectionEquality().hash(_selectedEntryTypes),const DeepCollectionEquality().hash(_fullTextMatches),pagingController,const DeepCollectionEquality().hash(_taskStatuses),const DeepCollectionEquality().hash(_selectedTaskStatuses),const DeepCollectionEquality().hash(_selectedCategoryIds),const DeepCollectionEquality().hash(_selectedProjectIds),const DeepCollectionEquality().hash(_selectedLabelIds),const DeepCollectionEquality().hash(_selectedPriorities),sortOption,showCreationDate,showDueDate,showCoverArt,showProjectsHeader,searchMode,showDistances,agentAssignmentFilter,enableVectorSearch,enableProjects,vectorSearchInFlight,vectorSearchElapsed,vectorSearchResultCount,const DeepCollectionEquality().hash(_vectorSearchDistances)]);

@override
String toString() {
  return 'JournalPageState(match: $match, filters: $filters, showPrivateEntries: $showPrivateEntries, showTasks: $showTasks, selectedEntryTypes: $selectedEntryTypes, fullTextMatches: $fullTextMatches, pagingController: $pagingController, taskStatuses: $taskStatuses, selectedTaskStatuses: $selectedTaskStatuses, selectedCategoryIds: $selectedCategoryIds, selectedProjectIds: $selectedProjectIds, selectedLabelIds: $selectedLabelIds, selectedPriorities: $selectedPriorities, sortOption: $sortOption, showCreationDate: $showCreationDate, showDueDate: $showDueDate, showCoverArt: $showCoverArt, showProjectsHeader: $showProjectsHeader, searchMode: $searchMode, showDistances: $showDistances, agentAssignmentFilter: $agentAssignmentFilter, enableVectorSearch: $enableVectorSearch, enableProjects: $enableProjects, vectorSearchInFlight: $vectorSearchInFlight, vectorSearchElapsed: $vectorSearchElapsed, vectorSearchResultCount: $vectorSearchResultCount, vectorSearchDistances: $vectorSearchDistances)';
}


}

/// @nodoc
abstract mixin class _$JournalPageStateCopyWith<$Res> implements $JournalPageStateCopyWith<$Res> {
  factory _$JournalPageStateCopyWith(_JournalPageState value, $Res Function(_JournalPageState) _then) = __$JournalPageStateCopyWithImpl;
@override @useResult
$Res call({
 String match, Set<DisplayFilter> filters, bool showPrivateEntries, bool showTasks, List<String> selectedEntryTypes, Set<String> fullTextMatches,@JsonKey(includeFromJson: false, includeToJson: false) PagingController<int, JournalEntity>? pagingController, List<String> taskStatuses, Set<String> selectedTaskStatuses, Set<String> selectedCategoryIds, Set<String> selectedProjectIds, Set<String> selectedLabelIds, Set<String> selectedPriorities, TaskSortOption sortOption, bool showCreationDate, bool showDueDate, bool showCoverArt, bool showProjectsHeader, SearchMode searchMode, bool showDistances, AgentAssignmentFilter agentAssignmentFilter, bool enableVectorSearch, bool enableProjects, bool vectorSearchInFlight, Duration? vectorSearchElapsed, int vectorSearchResultCount, Map<String, double> vectorSearchDistances
});




}
/// @nodoc
class __$JournalPageStateCopyWithImpl<$Res>
    implements _$JournalPageStateCopyWith<$Res> {
  __$JournalPageStateCopyWithImpl(this._self, this._then);

  final _JournalPageState _self;
  final $Res Function(_JournalPageState) _then;

/// Create a copy of JournalPageState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? match = null,Object? filters = null,Object? showPrivateEntries = null,Object? showTasks = null,Object? selectedEntryTypes = null,Object? fullTextMatches = null,Object? pagingController = freezed,Object? taskStatuses = null,Object? selectedTaskStatuses = null,Object? selectedCategoryIds = null,Object? selectedProjectIds = null,Object? selectedLabelIds = null,Object? selectedPriorities = null,Object? sortOption = null,Object? showCreationDate = null,Object? showDueDate = null,Object? showCoverArt = null,Object? showProjectsHeader = null,Object? searchMode = null,Object? showDistances = null,Object? agentAssignmentFilter = null,Object? enableVectorSearch = null,Object? enableProjects = null,Object? vectorSearchInFlight = null,Object? vectorSearchElapsed = freezed,Object? vectorSearchResultCount = null,Object? vectorSearchDistances = null,}) {
  return _then(_JournalPageState(
match: null == match ? _self.match : match // ignore: cast_nullable_to_non_nullable
as String,filters: null == filters ? _self._filters : filters // ignore: cast_nullable_to_non_nullable
as Set<DisplayFilter>,showPrivateEntries: null == showPrivateEntries ? _self.showPrivateEntries : showPrivateEntries // ignore: cast_nullable_to_non_nullable
as bool,showTasks: null == showTasks ? _self.showTasks : showTasks // ignore: cast_nullable_to_non_nullable
as bool,selectedEntryTypes: null == selectedEntryTypes ? _self._selectedEntryTypes : selectedEntryTypes // ignore: cast_nullable_to_non_nullable
as List<String>,fullTextMatches: null == fullTextMatches ? _self._fullTextMatches : fullTextMatches // ignore: cast_nullable_to_non_nullable
as Set<String>,pagingController: freezed == pagingController ? _self.pagingController : pagingController // ignore: cast_nullable_to_non_nullable
as PagingController<int, JournalEntity>?,taskStatuses: null == taskStatuses ? _self._taskStatuses : taskStatuses // ignore: cast_nullable_to_non_nullable
as List<String>,selectedTaskStatuses: null == selectedTaskStatuses ? _self._selectedTaskStatuses : selectedTaskStatuses // ignore: cast_nullable_to_non_nullable
as Set<String>,selectedCategoryIds: null == selectedCategoryIds ? _self._selectedCategoryIds : selectedCategoryIds // ignore: cast_nullable_to_non_nullable
as Set<String>,selectedProjectIds: null == selectedProjectIds ? _self._selectedProjectIds : selectedProjectIds // ignore: cast_nullable_to_non_nullable
as Set<String>,selectedLabelIds: null == selectedLabelIds ? _self._selectedLabelIds : selectedLabelIds // ignore: cast_nullable_to_non_nullable
as Set<String>,selectedPriorities: null == selectedPriorities ? _self._selectedPriorities : selectedPriorities // ignore: cast_nullable_to_non_nullable
as Set<String>,sortOption: null == sortOption ? _self.sortOption : sortOption // ignore: cast_nullable_to_non_nullable
as TaskSortOption,showCreationDate: null == showCreationDate ? _self.showCreationDate : showCreationDate // ignore: cast_nullable_to_non_nullable
as bool,showDueDate: null == showDueDate ? _self.showDueDate : showDueDate // ignore: cast_nullable_to_non_nullable
as bool,showCoverArt: null == showCoverArt ? _self.showCoverArt : showCoverArt // ignore: cast_nullable_to_non_nullable
as bool,showProjectsHeader: null == showProjectsHeader ? _self.showProjectsHeader : showProjectsHeader // ignore: cast_nullable_to_non_nullable
as bool,searchMode: null == searchMode ? _self.searchMode : searchMode // ignore: cast_nullable_to_non_nullable
as SearchMode,showDistances: null == showDistances ? _self.showDistances : showDistances // ignore: cast_nullable_to_non_nullable
as bool,agentAssignmentFilter: null == agentAssignmentFilter ? _self.agentAssignmentFilter : agentAssignmentFilter // ignore: cast_nullable_to_non_nullable
as AgentAssignmentFilter,enableVectorSearch: null == enableVectorSearch ? _self.enableVectorSearch : enableVectorSearch // ignore: cast_nullable_to_non_nullable
as bool,enableProjects: null == enableProjects ? _self.enableProjects : enableProjects // ignore: cast_nullable_to_non_nullable
as bool,vectorSearchInFlight: null == vectorSearchInFlight ? _self.vectorSearchInFlight : vectorSearchInFlight // ignore: cast_nullable_to_non_nullable
as bool,vectorSearchElapsed: freezed == vectorSearchElapsed ? _self.vectorSearchElapsed : vectorSearchElapsed // ignore: cast_nullable_to_non_nullable
as Duration?,vectorSearchResultCount: null == vectorSearchResultCount ? _self.vectorSearchResultCount : vectorSearchResultCount // ignore: cast_nullable_to_non_nullable
as int,vectorSearchDistances: null == vectorSearchDistances ? _self._vectorSearchDistances : vectorSearchDistances // ignore: cast_nullable_to_non_nullable
as Map<String, double>,
  ));
}


}


/// @nodoc
mixin _$TasksFilter {

 Set<String> get selectedCategoryIds; Set<String> get selectedProjectIds; Set<String> get selectedTaskStatuses; Set<String> get selectedLabelIds; Set<String> get selectedPriorities; TaskSortOption get sortOption; bool get showCreationDate; bool get showDueDate; bool get showCoverArt; bool get showProjectsHeader; bool get showDistances; AgentAssignmentFilter get agentAssignmentFilter;
/// Create a copy of TasksFilter
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TasksFilterCopyWith<TasksFilter> get copyWith => _$TasksFilterCopyWithImpl<TasksFilter>(this as TasksFilter, _$identity);

  /// Serializes this TasksFilter to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TasksFilter&&const DeepCollectionEquality().equals(other.selectedCategoryIds, selectedCategoryIds)&&const DeepCollectionEquality().equals(other.selectedProjectIds, selectedProjectIds)&&const DeepCollectionEquality().equals(other.selectedTaskStatuses, selectedTaskStatuses)&&const DeepCollectionEquality().equals(other.selectedLabelIds, selectedLabelIds)&&const DeepCollectionEquality().equals(other.selectedPriorities, selectedPriorities)&&(identical(other.sortOption, sortOption) || other.sortOption == sortOption)&&(identical(other.showCreationDate, showCreationDate) || other.showCreationDate == showCreationDate)&&(identical(other.showDueDate, showDueDate) || other.showDueDate == showDueDate)&&(identical(other.showCoverArt, showCoverArt) || other.showCoverArt == showCoverArt)&&(identical(other.showProjectsHeader, showProjectsHeader) || other.showProjectsHeader == showProjectsHeader)&&(identical(other.showDistances, showDistances) || other.showDistances == showDistances)&&(identical(other.agentAssignmentFilter, agentAssignmentFilter) || other.agentAssignmentFilter == agentAssignmentFilter));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(selectedCategoryIds),const DeepCollectionEquality().hash(selectedProjectIds),const DeepCollectionEquality().hash(selectedTaskStatuses),const DeepCollectionEquality().hash(selectedLabelIds),const DeepCollectionEquality().hash(selectedPriorities),sortOption,showCreationDate,showDueDate,showCoverArt,showProjectsHeader,showDistances,agentAssignmentFilter);

@override
String toString() {
  return 'TasksFilter(selectedCategoryIds: $selectedCategoryIds, selectedProjectIds: $selectedProjectIds, selectedTaskStatuses: $selectedTaskStatuses, selectedLabelIds: $selectedLabelIds, selectedPriorities: $selectedPriorities, sortOption: $sortOption, showCreationDate: $showCreationDate, showDueDate: $showDueDate, showCoverArt: $showCoverArt, showProjectsHeader: $showProjectsHeader, showDistances: $showDistances, agentAssignmentFilter: $agentAssignmentFilter)';
}


}

/// @nodoc
abstract mixin class $TasksFilterCopyWith<$Res>  {
  factory $TasksFilterCopyWith(TasksFilter value, $Res Function(TasksFilter) _then) = _$TasksFilterCopyWithImpl;
@useResult
$Res call({
 Set<String> selectedCategoryIds, Set<String> selectedProjectIds, Set<String> selectedTaskStatuses, Set<String> selectedLabelIds, Set<String> selectedPriorities, TaskSortOption sortOption, bool showCreationDate, bool showDueDate, bool showCoverArt, bool showProjectsHeader, bool showDistances, AgentAssignmentFilter agentAssignmentFilter
});




}
/// @nodoc
class _$TasksFilterCopyWithImpl<$Res>
    implements $TasksFilterCopyWith<$Res> {
  _$TasksFilterCopyWithImpl(this._self, this._then);

  final TasksFilter _self;
  final $Res Function(TasksFilter) _then;

/// Create a copy of TasksFilter
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? selectedCategoryIds = null,Object? selectedProjectIds = null,Object? selectedTaskStatuses = null,Object? selectedLabelIds = null,Object? selectedPriorities = null,Object? sortOption = null,Object? showCreationDate = null,Object? showDueDate = null,Object? showCoverArt = null,Object? showProjectsHeader = null,Object? showDistances = null,Object? agentAssignmentFilter = null,}) {
  return _then(_self.copyWith(
selectedCategoryIds: null == selectedCategoryIds ? _self.selectedCategoryIds : selectedCategoryIds // ignore: cast_nullable_to_non_nullable
as Set<String>,selectedProjectIds: null == selectedProjectIds ? _self.selectedProjectIds : selectedProjectIds // ignore: cast_nullable_to_non_nullable
as Set<String>,selectedTaskStatuses: null == selectedTaskStatuses ? _self.selectedTaskStatuses : selectedTaskStatuses // ignore: cast_nullable_to_non_nullable
as Set<String>,selectedLabelIds: null == selectedLabelIds ? _self.selectedLabelIds : selectedLabelIds // ignore: cast_nullable_to_non_nullable
as Set<String>,selectedPriorities: null == selectedPriorities ? _self.selectedPriorities : selectedPriorities // ignore: cast_nullable_to_non_nullable
as Set<String>,sortOption: null == sortOption ? _self.sortOption : sortOption // ignore: cast_nullable_to_non_nullable
as TaskSortOption,showCreationDate: null == showCreationDate ? _self.showCreationDate : showCreationDate // ignore: cast_nullable_to_non_nullable
as bool,showDueDate: null == showDueDate ? _self.showDueDate : showDueDate // ignore: cast_nullable_to_non_nullable
as bool,showCoverArt: null == showCoverArt ? _self.showCoverArt : showCoverArt // ignore: cast_nullable_to_non_nullable
as bool,showProjectsHeader: null == showProjectsHeader ? _self.showProjectsHeader : showProjectsHeader // ignore: cast_nullable_to_non_nullable
as bool,showDistances: null == showDistances ? _self.showDistances : showDistances // ignore: cast_nullable_to_non_nullable
as bool,agentAssignmentFilter: null == agentAssignmentFilter ? _self.agentAssignmentFilter : agentAssignmentFilter // ignore: cast_nullable_to_non_nullable
as AgentAssignmentFilter,
  ));
}

}


/// Adds pattern-matching-related methods to [TasksFilter].
extension TasksFilterPatterns on TasksFilter {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TasksFilter value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TasksFilter() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TasksFilter value)  $default,){
final _that = this;
switch (_that) {
case _TasksFilter():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TasksFilter value)?  $default,){
final _that = this;
switch (_that) {
case _TasksFilter() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Set<String> selectedCategoryIds,  Set<String> selectedProjectIds,  Set<String> selectedTaskStatuses,  Set<String> selectedLabelIds,  Set<String> selectedPriorities,  TaskSortOption sortOption,  bool showCreationDate,  bool showDueDate,  bool showCoverArt,  bool showProjectsHeader,  bool showDistances,  AgentAssignmentFilter agentAssignmentFilter)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TasksFilter() when $default != null:
return $default(_that.selectedCategoryIds,_that.selectedProjectIds,_that.selectedTaskStatuses,_that.selectedLabelIds,_that.selectedPriorities,_that.sortOption,_that.showCreationDate,_that.showDueDate,_that.showCoverArt,_that.showProjectsHeader,_that.showDistances,_that.agentAssignmentFilter);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Set<String> selectedCategoryIds,  Set<String> selectedProjectIds,  Set<String> selectedTaskStatuses,  Set<String> selectedLabelIds,  Set<String> selectedPriorities,  TaskSortOption sortOption,  bool showCreationDate,  bool showDueDate,  bool showCoverArt,  bool showProjectsHeader,  bool showDistances,  AgentAssignmentFilter agentAssignmentFilter)  $default,) {final _that = this;
switch (_that) {
case _TasksFilter():
return $default(_that.selectedCategoryIds,_that.selectedProjectIds,_that.selectedTaskStatuses,_that.selectedLabelIds,_that.selectedPriorities,_that.sortOption,_that.showCreationDate,_that.showDueDate,_that.showCoverArt,_that.showProjectsHeader,_that.showDistances,_that.agentAssignmentFilter);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Set<String> selectedCategoryIds,  Set<String> selectedProjectIds,  Set<String> selectedTaskStatuses,  Set<String> selectedLabelIds,  Set<String> selectedPriorities,  TaskSortOption sortOption,  bool showCreationDate,  bool showDueDate,  bool showCoverArt,  bool showProjectsHeader,  bool showDistances,  AgentAssignmentFilter agentAssignmentFilter)?  $default,) {final _that = this;
switch (_that) {
case _TasksFilter() when $default != null:
return $default(_that.selectedCategoryIds,_that.selectedProjectIds,_that.selectedTaskStatuses,_that.selectedLabelIds,_that.selectedPriorities,_that.sortOption,_that.showCreationDate,_that.showDueDate,_that.showCoverArt,_that.showProjectsHeader,_that.showDistances,_that.agentAssignmentFilter);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TasksFilter implements TasksFilter {
  const _TasksFilter({final  Set<String> selectedCategoryIds = const <String>{}, final  Set<String> selectedProjectIds = const <String>{}, final  Set<String> selectedTaskStatuses = const <String>{}, final  Set<String> selectedLabelIds = const <String>{}, final  Set<String> selectedPriorities = const <String>{}, this.sortOption = TaskSortOption.byPriority, this.showCreationDate = false, this.showDueDate = true, this.showCoverArt = true, this.showProjectsHeader = true, this.showDistances = false, this.agentAssignmentFilter = AgentAssignmentFilter.all}): _selectedCategoryIds = selectedCategoryIds,_selectedProjectIds = selectedProjectIds,_selectedTaskStatuses = selectedTaskStatuses,_selectedLabelIds = selectedLabelIds,_selectedPriorities = selectedPriorities;
  factory _TasksFilter.fromJson(Map<String, dynamic> json) => _$TasksFilterFromJson(json);

 final  Set<String> _selectedCategoryIds;
@override@JsonKey() Set<String> get selectedCategoryIds {
  if (_selectedCategoryIds is EqualUnmodifiableSetView) return _selectedCategoryIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_selectedCategoryIds);
}

 final  Set<String> _selectedProjectIds;
@override@JsonKey() Set<String> get selectedProjectIds {
  if (_selectedProjectIds is EqualUnmodifiableSetView) return _selectedProjectIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_selectedProjectIds);
}

 final  Set<String> _selectedTaskStatuses;
@override@JsonKey() Set<String> get selectedTaskStatuses {
  if (_selectedTaskStatuses is EqualUnmodifiableSetView) return _selectedTaskStatuses;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_selectedTaskStatuses);
}

 final  Set<String> _selectedLabelIds;
@override@JsonKey() Set<String> get selectedLabelIds {
  if (_selectedLabelIds is EqualUnmodifiableSetView) return _selectedLabelIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_selectedLabelIds);
}

 final  Set<String> _selectedPriorities;
@override@JsonKey() Set<String> get selectedPriorities {
  if (_selectedPriorities is EqualUnmodifiableSetView) return _selectedPriorities;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_selectedPriorities);
}

@override@JsonKey() final  TaskSortOption sortOption;
@override@JsonKey() final  bool showCreationDate;
@override@JsonKey() final  bool showDueDate;
@override@JsonKey() final  bool showCoverArt;
@override@JsonKey() final  bool showProjectsHeader;
@override@JsonKey() final  bool showDistances;
@override@JsonKey() final  AgentAssignmentFilter agentAssignmentFilter;

/// Create a copy of TasksFilter
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TasksFilterCopyWith<_TasksFilter> get copyWith => __$TasksFilterCopyWithImpl<_TasksFilter>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TasksFilterToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TasksFilter&&const DeepCollectionEquality().equals(other._selectedCategoryIds, _selectedCategoryIds)&&const DeepCollectionEquality().equals(other._selectedProjectIds, _selectedProjectIds)&&const DeepCollectionEquality().equals(other._selectedTaskStatuses, _selectedTaskStatuses)&&const DeepCollectionEquality().equals(other._selectedLabelIds, _selectedLabelIds)&&const DeepCollectionEquality().equals(other._selectedPriorities, _selectedPriorities)&&(identical(other.sortOption, sortOption) || other.sortOption == sortOption)&&(identical(other.showCreationDate, showCreationDate) || other.showCreationDate == showCreationDate)&&(identical(other.showDueDate, showDueDate) || other.showDueDate == showDueDate)&&(identical(other.showCoverArt, showCoverArt) || other.showCoverArt == showCoverArt)&&(identical(other.showProjectsHeader, showProjectsHeader) || other.showProjectsHeader == showProjectsHeader)&&(identical(other.showDistances, showDistances) || other.showDistances == showDistances)&&(identical(other.agentAssignmentFilter, agentAssignmentFilter) || other.agentAssignmentFilter == agentAssignmentFilter));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_selectedCategoryIds),const DeepCollectionEquality().hash(_selectedProjectIds),const DeepCollectionEquality().hash(_selectedTaskStatuses),const DeepCollectionEquality().hash(_selectedLabelIds),const DeepCollectionEquality().hash(_selectedPriorities),sortOption,showCreationDate,showDueDate,showCoverArt,showProjectsHeader,showDistances,agentAssignmentFilter);

@override
String toString() {
  return 'TasksFilter(selectedCategoryIds: $selectedCategoryIds, selectedProjectIds: $selectedProjectIds, selectedTaskStatuses: $selectedTaskStatuses, selectedLabelIds: $selectedLabelIds, selectedPriorities: $selectedPriorities, sortOption: $sortOption, showCreationDate: $showCreationDate, showDueDate: $showDueDate, showCoverArt: $showCoverArt, showProjectsHeader: $showProjectsHeader, showDistances: $showDistances, agentAssignmentFilter: $agentAssignmentFilter)';
}


}

/// @nodoc
abstract mixin class _$TasksFilterCopyWith<$Res> implements $TasksFilterCopyWith<$Res> {
  factory _$TasksFilterCopyWith(_TasksFilter value, $Res Function(_TasksFilter) _then) = __$TasksFilterCopyWithImpl;
@override @useResult
$Res call({
 Set<String> selectedCategoryIds, Set<String> selectedProjectIds, Set<String> selectedTaskStatuses, Set<String> selectedLabelIds, Set<String> selectedPriorities, TaskSortOption sortOption, bool showCreationDate, bool showDueDate, bool showCoverArt, bool showProjectsHeader, bool showDistances, AgentAssignmentFilter agentAssignmentFilter
});




}
/// @nodoc
class __$TasksFilterCopyWithImpl<$Res>
    implements _$TasksFilterCopyWith<$Res> {
  __$TasksFilterCopyWithImpl(this._self, this._then);

  final _TasksFilter _self;
  final $Res Function(_TasksFilter) _then;

/// Create a copy of TasksFilter
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? selectedCategoryIds = null,Object? selectedProjectIds = null,Object? selectedTaskStatuses = null,Object? selectedLabelIds = null,Object? selectedPriorities = null,Object? sortOption = null,Object? showCreationDate = null,Object? showDueDate = null,Object? showCoverArt = null,Object? showProjectsHeader = null,Object? showDistances = null,Object? agentAssignmentFilter = null,}) {
  return _then(_TasksFilter(
selectedCategoryIds: null == selectedCategoryIds ? _self._selectedCategoryIds : selectedCategoryIds // ignore: cast_nullable_to_non_nullable
as Set<String>,selectedProjectIds: null == selectedProjectIds ? _self._selectedProjectIds : selectedProjectIds // ignore: cast_nullable_to_non_nullable
as Set<String>,selectedTaskStatuses: null == selectedTaskStatuses ? _self._selectedTaskStatuses : selectedTaskStatuses // ignore: cast_nullable_to_non_nullable
as Set<String>,selectedLabelIds: null == selectedLabelIds ? _self._selectedLabelIds : selectedLabelIds // ignore: cast_nullable_to_non_nullable
as Set<String>,selectedPriorities: null == selectedPriorities ? _self._selectedPriorities : selectedPriorities // ignore: cast_nullable_to_non_nullable
as Set<String>,sortOption: null == sortOption ? _self.sortOption : sortOption // ignore: cast_nullable_to_non_nullable
as TaskSortOption,showCreationDate: null == showCreationDate ? _self.showCreationDate : showCreationDate // ignore: cast_nullable_to_non_nullable
as bool,showDueDate: null == showDueDate ? _self.showDueDate : showDueDate // ignore: cast_nullable_to_non_nullable
as bool,showCoverArt: null == showCoverArt ? _self.showCoverArt : showCoverArt // ignore: cast_nullable_to_non_nullable
as bool,showProjectsHeader: null == showProjectsHeader ? _self.showProjectsHeader : showProjectsHeader // ignore: cast_nullable_to_non_nullable
as bool,showDistances: null == showDistances ? _self.showDistances : showDistances // ignore: cast_nullable_to_non_nullable
as bool,agentAssignmentFilter: null == agentAssignmentFilter ? _self.agentAssignmentFilter : agentAssignmentFilter // ignore: cast_nullable_to_non_nullable
as AgentAssignmentFilter,
  ));
}


}

// dart format on
