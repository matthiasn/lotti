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
  String get match;
  Set<String> get tagIds;
  Set<DisplayFilter> get filters;
  bool get showPrivateEntries;
  bool get showTasks;
  List<String> get selectedEntryTypes;
  Set<String> get fullTextMatches;
  PagingController<int, JournalEntity>? get pagingController;
  List<String> get taskStatuses;
  Set<String> get selectedTaskStatuses;
  Set<String?> get selectedCategoryIds;
  Set<String> get selectedLabelIds;
  Set<String> get selectedPriorities;

  /// Create a copy of JournalPageState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $JournalPageStateCopyWith<JournalPageState> get copyWith =>
      _$JournalPageStateCopyWithImpl<JournalPageState>(
          this as JournalPageState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is JournalPageState &&
            (identical(other.match, match) || other.match == match) &&
            const DeepCollectionEquality().equals(other.tagIds, tagIds) &&
            const DeepCollectionEquality().equals(other.filters, filters) &&
            (identical(other.showPrivateEntries, showPrivateEntries) ||
                other.showPrivateEntries == showPrivateEntries) &&
            (identical(other.showTasks, showTasks) ||
                other.showTasks == showTasks) &&
            const DeepCollectionEquality()
                .equals(other.selectedEntryTypes, selectedEntryTypes) &&
            const DeepCollectionEquality()
                .equals(other.fullTextMatches, fullTextMatches) &&
            (identical(other.pagingController, pagingController) ||
                other.pagingController == pagingController) &&
            const DeepCollectionEquality()
                .equals(other.taskStatuses, taskStatuses) &&
            const DeepCollectionEquality()
                .equals(other.selectedTaskStatuses, selectedTaskStatuses) &&
            const DeepCollectionEquality()
                .equals(other.selectedCategoryIds, selectedCategoryIds) &&
            const DeepCollectionEquality()
                .equals(other.selectedLabelIds, selectedLabelIds) &&
            const DeepCollectionEquality()
                .equals(other.selectedPriorities, selectedPriorities));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      match,
      const DeepCollectionEquality().hash(tagIds),
      const DeepCollectionEquality().hash(filters),
      showPrivateEntries,
      showTasks,
      const DeepCollectionEquality().hash(selectedEntryTypes),
      const DeepCollectionEquality().hash(fullTextMatches),
      pagingController,
      const DeepCollectionEquality().hash(taskStatuses),
      const DeepCollectionEquality().hash(selectedTaskStatuses),
      const DeepCollectionEquality().hash(selectedCategoryIds),
      const DeepCollectionEquality().hash(selectedLabelIds),
      const DeepCollectionEquality().hash(selectedPriorities));

  @override
  String toString() {
    return 'JournalPageState(match: $match, tagIds: $tagIds, filters: $filters, showPrivateEntries: $showPrivateEntries, showTasks: $showTasks, selectedEntryTypes: $selectedEntryTypes, fullTextMatches: $fullTextMatches, pagingController: $pagingController, taskStatuses: $taskStatuses, selectedTaskStatuses: $selectedTaskStatuses, selectedCategoryIds: $selectedCategoryIds, selectedLabelIds: $selectedLabelIds, selectedPriorities: $selectedPriorities)';
  }
}

/// @nodoc
abstract mixin class $JournalPageStateCopyWith<$Res> {
  factory $JournalPageStateCopyWith(
          JournalPageState value, $Res Function(JournalPageState) _then) =
      _$JournalPageStateCopyWithImpl;
  @useResult
  $Res call(
      {String match,
      Set<String> tagIds,
      Set<DisplayFilter> filters,
      bool showPrivateEntries,
      bool showTasks,
      List<String> selectedEntryTypes,
      Set<String> fullTextMatches,
      PagingController<int, JournalEntity>? pagingController,
      List<String> taskStatuses,
      Set<String> selectedTaskStatuses,
      Set<String?> selectedCategoryIds,
      Set<String> selectedLabelIds,
      Set<String> selectedPriorities});
}

/// @nodoc
class _$JournalPageStateCopyWithImpl<$Res>
    implements $JournalPageStateCopyWith<$Res> {
  _$JournalPageStateCopyWithImpl(this._self, this._then);

  final JournalPageState _self;
  final $Res Function(JournalPageState) _then;

  /// Create a copy of JournalPageState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? match = null,
    Object? tagIds = null,
    Object? filters = null,
    Object? showPrivateEntries = null,
    Object? showTasks = null,
    Object? selectedEntryTypes = null,
    Object? fullTextMatches = null,
    Object? pagingController = freezed,
    Object? taskStatuses = null,
    Object? selectedTaskStatuses = null,
    Object? selectedCategoryIds = null,
    Object? selectedLabelIds = null,
    Object? selectedPriorities = null,
  }) {
    return _then(_self.copyWith(
      match: null == match
          ? _self.match
          : match // ignore: cast_nullable_to_non_nullable
              as String,
      tagIds: null == tagIds
          ? _self.tagIds
          : tagIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      filters: null == filters
          ? _self.filters
          : filters // ignore: cast_nullable_to_non_nullable
              as Set<DisplayFilter>,
      showPrivateEntries: null == showPrivateEntries
          ? _self.showPrivateEntries
          : showPrivateEntries // ignore: cast_nullable_to_non_nullable
              as bool,
      showTasks: null == showTasks
          ? _self.showTasks
          : showTasks // ignore: cast_nullable_to_non_nullable
              as bool,
      selectedEntryTypes: null == selectedEntryTypes
          ? _self.selectedEntryTypes
          : selectedEntryTypes // ignore: cast_nullable_to_non_nullable
              as List<String>,
      fullTextMatches: null == fullTextMatches
          ? _self.fullTextMatches
          : fullTextMatches // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      pagingController: freezed == pagingController
          ? _self.pagingController
          : pagingController // ignore: cast_nullable_to_non_nullable
              as PagingController<int, JournalEntity>?,
      taskStatuses: null == taskStatuses
          ? _self.taskStatuses
          : taskStatuses // ignore: cast_nullable_to_non_nullable
              as List<String>,
      selectedTaskStatuses: null == selectedTaskStatuses
          ? _self.selectedTaskStatuses
          : selectedTaskStatuses // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      selectedCategoryIds: null == selectedCategoryIds
          ? _self.selectedCategoryIds
          : selectedCategoryIds // ignore: cast_nullable_to_non_nullable
              as Set<String?>,
      selectedLabelIds: null == selectedLabelIds
          ? _self.selectedLabelIds
          : selectedLabelIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      selectedPriorities: null == selectedPriorities
          ? _self.selectedPriorities
          : selectedPriorities // ignore: cast_nullable_to_non_nullable
              as Set<String>,
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

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_JournalPageState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _JournalPageState() when $default != null:
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
    TResult Function(_JournalPageState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _JournalPageState():
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
    TResult? Function(_JournalPageState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _JournalPageState() when $default != null:
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
            String match,
            Set<String> tagIds,
            Set<DisplayFilter> filters,
            bool showPrivateEntries,
            bool showTasks,
            List<String> selectedEntryTypes,
            Set<String> fullTextMatches,
            PagingController<int, JournalEntity>? pagingController,
            List<String> taskStatuses,
            Set<String> selectedTaskStatuses,
            Set<String?> selectedCategoryIds,
            Set<String> selectedLabelIds,
            Set<String> selectedPriorities)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _JournalPageState() when $default != null:
        return $default(
            _that.match,
            _that.tagIds,
            _that.filters,
            _that.showPrivateEntries,
            _that.showTasks,
            _that.selectedEntryTypes,
            _that.fullTextMatches,
            _that.pagingController,
            _that.taskStatuses,
            _that.selectedTaskStatuses,
            _that.selectedCategoryIds,
            _that.selectedLabelIds,
            _that.selectedPriorities);
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
            String match,
            Set<String> tagIds,
            Set<DisplayFilter> filters,
            bool showPrivateEntries,
            bool showTasks,
            List<String> selectedEntryTypes,
            Set<String> fullTextMatches,
            PagingController<int, JournalEntity>? pagingController,
            List<String> taskStatuses,
            Set<String> selectedTaskStatuses,
            Set<String?> selectedCategoryIds,
            Set<String> selectedLabelIds,
            Set<String> selectedPriorities)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _JournalPageState():
        return $default(
            _that.match,
            _that.tagIds,
            _that.filters,
            _that.showPrivateEntries,
            _that.showTasks,
            _that.selectedEntryTypes,
            _that.fullTextMatches,
            _that.pagingController,
            _that.taskStatuses,
            _that.selectedTaskStatuses,
            _that.selectedCategoryIds,
            _that.selectedLabelIds,
            _that.selectedPriorities);
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
            String match,
            Set<String> tagIds,
            Set<DisplayFilter> filters,
            bool showPrivateEntries,
            bool showTasks,
            List<String> selectedEntryTypes,
            Set<String> fullTextMatches,
            PagingController<int, JournalEntity>? pagingController,
            List<String> taskStatuses,
            Set<String> selectedTaskStatuses,
            Set<String?> selectedCategoryIds,
            Set<String> selectedLabelIds,
            Set<String> selectedPriorities)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _JournalPageState() when $default != null:
        return $default(
            _that.match,
            _that.tagIds,
            _that.filters,
            _that.showPrivateEntries,
            _that.showTasks,
            _that.selectedEntryTypes,
            _that.fullTextMatches,
            _that.pagingController,
            _that.taskStatuses,
            _that.selectedTaskStatuses,
            _that.selectedCategoryIds,
            _that.selectedLabelIds,
            _that.selectedPriorities);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _JournalPageState implements JournalPageState {
  _JournalPageState(
      {required this.match,
      required final Set<String> tagIds,
      required final Set<DisplayFilter> filters,
      required this.showPrivateEntries,
      required this.showTasks,
      required final List<String> selectedEntryTypes,
      required final Set<String> fullTextMatches,
      required this.pagingController,
      required final List<String> taskStatuses,
      required final Set<String> selectedTaskStatuses,
      required final Set<String?> selectedCategoryIds,
      required final Set<String> selectedLabelIds,
      final Set<String> selectedPriorities = const <String>{}})
      : _tagIds = tagIds,
        _filters = filters,
        _selectedEntryTypes = selectedEntryTypes,
        _fullTextMatches = fullTextMatches,
        _taskStatuses = taskStatuses,
        _selectedTaskStatuses = selectedTaskStatuses,
        _selectedCategoryIds = selectedCategoryIds,
        _selectedLabelIds = selectedLabelIds,
        _selectedPriorities = selectedPriorities;

  @override
  final String match;
  final Set<String> _tagIds;
  @override
  Set<String> get tagIds {
    if (_tagIds is EqualUnmodifiableSetView) return _tagIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_tagIds);
  }

  final Set<DisplayFilter> _filters;
  @override
  Set<DisplayFilter> get filters {
    if (_filters is EqualUnmodifiableSetView) return _filters;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_filters);
  }

  @override
  final bool showPrivateEntries;
  @override
  final bool showTasks;
  final List<String> _selectedEntryTypes;
  @override
  List<String> get selectedEntryTypes {
    if (_selectedEntryTypes is EqualUnmodifiableListView)
      return _selectedEntryTypes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_selectedEntryTypes);
  }

  final Set<String> _fullTextMatches;
  @override
  Set<String> get fullTextMatches {
    if (_fullTextMatches is EqualUnmodifiableSetView) return _fullTextMatches;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_fullTextMatches);
  }

  @override
  final PagingController<int, JournalEntity>? pagingController;
  final List<String> _taskStatuses;
  @override
  List<String> get taskStatuses {
    if (_taskStatuses is EqualUnmodifiableListView) return _taskStatuses;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_taskStatuses);
  }

  final Set<String> _selectedTaskStatuses;
  @override
  Set<String> get selectedTaskStatuses {
    if (_selectedTaskStatuses is EqualUnmodifiableSetView)
      return _selectedTaskStatuses;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_selectedTaskStatuses);
  }

  final Set<String?> _selectedCategoryIds;
  @override
  Set<String?> get selectedCategoryIds {
    if (_selectedCategoryIds is EqualUnmodifiableSetView)
      return _selectedCategoryIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_selectedCategoryIds);
  }

  final Set<String> _selectedLabelIds;
  @override
  Set<String> get selectedLabelIds {
    if (_selectedLabelIds is EqualUnmodifiableSetView) return _selectedLabelIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_selectedLabelIds);
  }

  final Set<String> _selectedPriorities;
  @override
  @JsonKey()
  Set<String> get selectedPriorities {
    if (_selectedPriorities is EqualUnmodifiableSetView)
      return _selectedPriorities;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_selectedPriorities);
  }

  /// Create a copy of JournalPageState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$JournalPageStateCopyWith<_JournalPageState> get copyWith =>
      __$JournalPageStateCopyWithImpl<_JournalPageState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _JournalPageState &&
            (identical(other.match, match) || other.match == match) &&
            const DeepCollectionEquality().equals(other._tagIds, _tagIds) &&
            const DeepCollectionEquality().equals(other._filters, _filters) &&
            (identical(other.showPrivateEntries, showPrivateEntries) ||
                other.showPrivateEntries == showPrivateEntries) &&
            (identical(other.showTasks, showTasks) ||
                other.showTasks == showTasks) &&
            const DeepCollectionEquality()
                .equals(other._selectedEntryTypes, _selectedEntryTypes) &&
            const DeepCollectionEquality()
                .equals(other._fullTextMatches, _fullTextMatches) &&
            (identical(other.pagingController, pagingController) ||
                other.pagingController == pagingController) &&
            const DeepCollectionEquality()
                .equals(other._taskStatuses, _taskStatuses) &&
            const DeepCollectionEquality()
                .equals(other._selectedTaskStatuses, _selectedTaskStatuses) &&
            const DeepCollectionEquality()
                .equals(other._selectedCategoryIds, _selectedCategoryIds) &&
            const DeepCollectionEquality()
                .equals(other._selectedLabelIds, _selectedLabelIds) &&
            const DeepCollectionEquality()
                .equals(other._selectedPriorities, _selectedPriorities));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      match,
      const DeepCollectionEquality().hash(_tagIds),
      const DeepCollectionEquality().hash(_filters),
      showPrivateEntries,
      showTasks,
      const DeepCollectionEquality().hash(_selectedEntryTypes),
      const DeepCollectionEquality().hash(_fullTextMatches),
      pagingController,
      const DeepCollectionEquality().hash(_taskStatuses),
      const DeepCollectionEquality().hash(_selectedTaskStatuses),
      const DeepCollectionEquality().hash(_selectedCategoryIds),
      const DeepCollectionEquality().hash(_selectedLabelIds),
      const DeepCollectionEquality().hash(_selectedPriorities));

  @override
  String toString() {
    return 'JournalPageState(match: $match, tagIds: $tagIds, filters: $filters, showPrivateEntries: $showPrivateEntries, showTasks: $showTasks, selectedEntryTypes: $selectedEntryTypes, fullTextMatches: $fullTextMatches, pagingController: $pagingController, taskStatuses: $taskStatuses, selectedTaskStatuses: $selectedTaskStatuses, selectedCategoryIds: $selectedCategoryIds, selectedLabelIds: $selectedLabelIds, selectedPriorities: $selectedPriorities)';
  }
}

/// @nodoc
abstract mixin class _$JournalPageStateCopyWith<$Res>
    implements $JournalPageStateCopyWith<$Res> {
  factory _$JournalPageStateCopyWith(
          _JournalPageState value, $Res Function(_JournalPageState) _then) =
      __$JournalPageStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String match,
      Set<String> tagIds,
      Set<DisplayFilter> filters,
      bool showPrivateEntries,
      bool showTasks,
      List<String> selectedEntryTypes,
      Set<String> fullTextMatches,
      PagingController<int, JournalEntity>? pagingController,
      List<String> taskStatuses,
      Set<String> selectedTaskStatuses,
      Set<String?> selectedCategoryIds,
      Set<String> selectedLabelIds,
      Set<String> selectedPriorities});
}

/// @nodoc
class __$JournalPageStateCopyWithImpl<$Res>
    implements _$JournalPageStateCopyWith<$Res> {
  __$JournalPageStateCopyWithImpl(this._self, this._then);

  final _JournalPageState _self;
  final $Res Function(_JournalPageState) _then;

  /// Create a copy of JournalPageState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? match = null,
    Object? tagIds = null,
    Object? filters = null,
    Object? showPrivateEntries = null,
    Object? showTasks = null,
    Object? selectedEntryTypes = null,
    Object? fullTextMatches = null,
    Object? pagingController = freezed,
    Object? taskStatuses = null,
    Object? selectedTaskStatuses = null,
    Object? selectedCategoryIds = null,
    Object? selectedLabelIds = null,
    Object? selectedPriorities = null,
  }) {
    return _then(_JournalPageState(
      match: null == match
          ? _self.match
          : match // ignore: cast_nullable_to_non_nullable
              as String,
      tagIds: null == tagIds
          ? _self._tagIds
          : tagIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      filters: null == filters
          ? _self._filters
          : filters // ignore: cast_nullable_to_non_nullable
              as Set<DisplayFilter>,
      showPrivateEntries: null == showPrivateEntries
          ? _self.showPrivateEntries
          : showPrivateEntries // ignore: cast_nullable_to_non_nullable
              as bool,
      showTasks: null == showTasks
          ? _self.showTasks
          : showTasks // ignore: cast_nullable_to_non_nullable
              as bool,
      selectedEntryTypes: null == selectedEntryTypes
          ? _self._selectedEntryTypes
          : selectedEntryTypes // ignore: cast_nullable_to_non_nullable
              as List<String>,
      fullTextMatches: null == fullTextMatches
          ? _self._fullTextMatches
          : fullTextMatches // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      pagingController: freezed == pagingController
          ? _self.pagingController
          : pagingController // ignore: cast_nullable_to_non_nullable
              as PagingController<int, JournalEntity>?,
      taskStatuses: null == taskStatuses
          ? _self._taskStatuses
          : taskStatuses // ignore: cast_nullable_to_non_nullable
              as List<String>,
      selectedTaskStatuses: null == selectedTaskStatuses
          ? _self._selectedTaskStatuses
          : selectedTaskStatuses // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      selectedCategoryIds: null == selectedCategoryIds
          ? _self._selectedCategoryIds
          : selectedCategoryIds // ignore: cast_nullable_to_non_nullable
              as Set<String?>,
      selectedLabelIds: null == selectedLabelIds
          ? _self._selectedLabelIds
          : selectedLabelIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      selectedPriorities: null == selectedPriorities
          ? _self._selectedPriorities
          : selectedPriorities // ignore: cast_nullable_to_non_nullable
              as Set<String>,
    ));
  }
}

/// @nodoc
mixin _$TasksFilter {
  Set<String> get selectedCategoryIds;
  Set<String> get selectedTaskStatuses;
  Set<String> get selectedLabelIds;
  Set<String> get selectedPriorities;

  /// Create a copy of TasksFilter
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TasksFilterCopyWith<TasksFilter> get copyWith =>
      _$TasksFilterCopyWithImpl<TasksFilter>(this as TasksFilter, _$identity);

  /// Serializes this TasksFilter to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TasksFilter &&
            const DeepCollectionEquality()
                .equals(other.selectedCategoryIds, selectedCategoryIds) &&
            const DeepCollectionEquality()
                .equals(other.selectedTaskStatuses, selectedTaskStatuses) &&
            const DeepCollectionEquality()
                .equals(other.selectedLabelIds, selectedLabelIds) &&
            const DeepCollectionEquality()
                .equals(other.selectedPriorities, selectedPriorities));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(selectedCategoryIds),
      const DeepCollectionEquality().hash(selectedTaskStatuses),
      const DeepCollectionEquality().hash(selectedLabelIds),
      const DeepCollectionEquality().hash(selectedPriorities));

  @override
  String toString() {
    return 'TasksFilter(selectedCategoryIds: $selectedCategoryIds, selectedTaskStatuses: $selectedTaskStatuses, selectedLabelIds: $selectedLabelIds, selectedPriorities: $selectedPriorities)';
  }
}

/// @nodoc
abstract mixin class $TasksFilterCopyWith<$Res> {
  factory $TasksFilterCopyWith(
          TasksFilter value, $Res Function(TasksFilter) _then) =
      _$TasksFilterCopyWithImpl;
  @useResult
  $Res call(
      {Set<String> selectedCategoryIds,
      Set<String> selectedTaskStatuses,
      Set<String> selectedLabelIds,
      Set<String> selectedPriorities});
}

/// @nodoc
class _$TasksFilterCopyWithImpl<$Res> implements $TasksFilterCopyWith<$Res> {
  _$TasksFilterCopyWithImpl(this._self, this._then);

  final TasksFilter _self;
  final $Res Function(TasksFilter) _then;

  /// Create a copy of TasksFilter
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? selectedCategoryIds = null,
    Object? selectedTaskStatuses = null,
    Object? selectedLabelIds = null,
    Object? selectedPriorities = null,
  }) {
    return _then(_self.copyWith(
      selectedCategoryIds: null == selectedCategoryIds
          ? _self.selectedCategoryIds
          : selectedCategoryIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      selectedTaskStatuses: null == selectedTaskStatuses
          ? _self.selectedTaskStatuses
          : selectedTaskStatuses // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      selectedLabelIds: null == selectedLabelIds
          ? _self.selectedLabelIds
          : selectedLabelIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      selectedPriorities: null == selectedPriorities
          ? _self.selectedPriorities
          : selectedPriorities // ignore: cast_nullable_to_non_nullable
              as Set<String>,
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

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_TasksFilter value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TasksFilter() when $default != null:
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
    TResult Function(_TasksFilter value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TasksFilter():
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
    TResult? Function(_TasksFilter value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TasksFilter() when $default != null:
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
            Set<String> selectedCategoryIds,
            Set<String> selectedTaskStatuses,
            Set<String> selectedLabelIds,
            Set<String> selectedPriorities)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TasksFilter() when $default != null:
        return $default(_that.selectedCategoryIds, _that.selectedTaskStatuses,
            _that.selectedLabelIds, _that.selectedPriorities);
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
            Set<String> selectedCategoryIds,
            Set<String> selectedTaskStatuses,
            Set<String> selectedLabelIds,
            Set<String> selectedPriorities)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TasksFilter():
        return $default(_that.selectedCategoryIds, _that.selectedTaskStatuses,
            _that.selectedLabelIds, _that.selectedPriorities);
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
            Set<String> selectedCategoryIds,
            Set<String> selectedTaskStatuses,
            Set<String> selectedLabelIds,
            Set<String> selectedPriorities)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TasksFilter() when $default != null:
        return $default(_that.selectedCategoryIds, _that.selectedTaskStatuses,
            _that.selectedLabelIds, _that.selectedPriorities);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _TasksFilter implements TasksFilter {
  _TasksFilter(
      {final Set<String> selectedCategoryIds = const <String>{},
      final Set<String> selectedTaskStatuses = const <String>{},
      final Set<String> selectedLabelIds = const <String>{},
      final Set<String> selectedPriorities = const <String>{}})
      : _selectedCategoryIds = selectedCategoryIds,
        _selectedTaskStatuses = selectedTaskStatuses,
        _selectedLabelIds = selectedLabelIds,
        _selectedPriorities = selectedPriorities;
  factory _TasksFilter.fromJson(Map<String, dynamic> json) =>
      _$TasksFilterFromJson(json);

  final Set<String> _selectedCategoryIds;
  @override
  @JsonKey()
  Set<String> get selectedCategoryIds {
    if (_selectedCategoryIds is EqualUnmodifiableSetView)
      return _selectedCategoryIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_selectedCategoryIds);
  }

  final Set<String> _selectedTaskStatuses;
  @override
  @JsonKey()
  Set<String> get selectedTaskStatuses {
    if (_selectedTaskStatuses is EqualUnmodifiableSetView)
      return _selectedTaskStatuses;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_selectedTaskStatuses);
  }

  final Set<String> _selectedLabelIds;
  @override
  @JsonKey()
  Set<String> get selectedLabelIds {
    if (_selectedLabelIds is EqualUnmodifiableSetView) return _selectedLabelIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_selectedLabelIds);
  }

  final Set<String> _selectedPriorities;
  @override
  @JsonKey()
  Set<String> get selectedPriorities {
    if (_selectedPriorities is EqualUnmodifiableSetView)
      return _selectedPriorities;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_selectedPriorities);
  }

  /// Create a copy of TasksFilter
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TasksFilterCopyWith<_TasksFilter> get copyWith =>
      __$TasksFilterCopyWithImpl<_TasksFilter>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TasksFilterToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TasksFilter &&
            const DeepCollectionEquality()
                .equals(other._selectedCategoryIds, _selectedCategoryIds) &&
            const DeepCollectionEquality()
                .equals(other._selectedTaskStatuses, _selectedTaskStatuses) &&
            const DeepCollectionEquality()
                .equals(other._selectedLabelIds, _selectedLabelIds) &&
            const DeepCollectionEquality()
                .equals(other._selectedPriorities, _selectedPriorities));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_selectedCategoryIds),
      const DeepCollectionEquality().hash(_selectedTaskStatuses),
      const DeepCollectionEquality().hash(_selectedLabelIds),
      const DeepCollectionEquality().hash(_selectedPriorities));

  @override
  String toString() {
    return 'TasksFilter(selectedCategoryIds: $selectedCategoryIds, selectedTaskStatuses: $selectedTaskStatuses, selectedLabelIds: $selectedLabelIds, selectedPriorities: $selectedPriorities)';
  }
}

/// @nodoc
abstract mixin class _$TasksFilterCopyWith<$Res>
    implements $TasksFilterCopyWith<$Res> {
  factory _$TasksFilterCopyWith(
          _TasksFilter value, $Res Function(_TasksFilter) _then) =
      __$TasksFilterCopyWithImpl;
  @override
  @useResult
  $Res call(
      {Set<String> selectedCategoryIds,
      Set<String> selectedTaskStatuses,
      Set<String> selectedLabelIds,
      Set<String> selectedPriorities});
}

/// @nodoc
class __$TasksFilterCopyWithImpl<$Res> implements _$TasksFilterCopyWith<$Res> {
  __$TasksFilterCopyWithImpl(this._self, this._then);

  final _TasksFilter _self;
  final $Res Function(_TasksFilter) _then;

  /// Create a copy of TasksFilter
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? selectedCategoryIds = null,
    Object? selectedTaskStatuses = null,
    Object? selectedLabelIds = null,
    Object? selectedPriorities = null,
  }) {
    return _then(_TasksFilter(
      selectedCategoryIds: null == selectedCategoryIds
          ? _self._selectedCategoryIds
          : selectedCategoryIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      selectedTaskStatuses: null == selectedTaskStatuses
          ? _self._selectedTaskStatuses
          : selectedTaskStatuses // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      selectedLabelIds: null == selectedLabelIds
          ? _self._selectedLabelIds
          : selectedLabelIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      selectedPriorities: null == selectedPriorities
          ? _self._selectedPriorities
          : selectedPriorities // ignore: cast_nullable_to_non_nullable
              as Set<String>,
    ));
  }
}

// dart format on
