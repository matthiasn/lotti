// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'habits_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HabitsState {
  List<HabitDefinition> get habitDefinitions;
  List<HabitDefinition> get openHabits;
  List<HabitDefinition> get openNow;
  List<HabitDefinition> get pendingLater;
  List<HabitDefinition> get completed;
  List<JournalEntity> get habitCompletions;
  Set<String> get completedToday;
  Set<String> get successfulToday;
  Set<String> get selectedCategoryIds;
  List<String> get days;
  Map<String, Set<String>> get successfulByDay;
  Map<String, Set<String>> get skippedByDay;
  Map<String, Set<String>> get failedByDay;
  Map<String, Set<String>> get allByDay;
  int get successPercentage;
  int get skippedPercentage;
  int get failedPercentage;
  String get selectedInfoYmd;
  int get shortStreakCount;
  int get longStreakCount;
  int get timeSpanDays;
  double get minY;
  bool get zeroBased;
  bool get isVisible;
  bool get showTimeSpan;
  bool get showSearch;
  String get searchString;
  HabitDisplayFilter get displayFilter;

  /// Create a copy of HabitsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HabitsStateCopyWith<HabitsState> get copyWith =>
      _$HabitsStateCopyWithImpl<HabitsState>(this as HabitsState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is HabitsState &&
            const DeepCollectionEquality()
                .equals(other.habitDefinitions, habitDefinitions) &&
            const DeepCollectionEquality()
                .equals(other.openHabits, openHabits) &&
            const DeepCollectionEquality().equals(other.openNow, openNow) &&
            const DeepCollectionEquality()
                .equals(other.pendingLater, pendingLater) &&
            const DeepCollectionEquality().equals(other.completed, completed) &&
            const DeepCollectionEquality()
                .equals(other.habitCompletions, habitCompletions) &&
            const DeepCollectionEquality()
                .equals(other.completedToday, completedToday) &&
            const DeepCollectionEquality()
                .equals(other.successfulToday, successfulToday) &&
            const DeepCollectionEquality()
                .equals(other.selectedCategoryIds, selectedCategoryIds) &&
            const DeepCollectionEquality().equals(other.days, days) &&
            const DeepCollectionEquality()
                .equals(other.successfulByDay, successfulByDay) &&
            const DeepCollectionEquality()
                .equals(other.skippedByDay, skippedByDay) &&
            const DeepCollectionEquality()
                .equals(other.failedByDay, failedByDay) &&
            const DeepCollectionEquality().equals(other.allByDay, allByDay) &&
            (identical(other.successPercentage, successPercentage) ||
                other.successPercentage == successPercentage) &&
            (identical(other.skippedPercentage, skippedPercentage) ||
                other.skippedPercentage == skippedPercentage) &&
            (identical(other.failedPercentage, failedPercentage) ||
                other.failedPercentage == failedPercentage) &&
            (identical(other.selectedInfoYmd, selectedInfoYmd) ||
                other.selectedInfoYmd == selectedInfoYmd) &&
            (identical(other.shortStreakCount, shortStreakCount) ||
                other.shortStreakCount == shortStreakCount) &&
            (identical(other.longStreakCount, longStreakCount) ||
                other.longStreakCount == longStreakCount) &&
            (identical(other.timeSpanDays, timeSpanDays) ||
                other.timeSpanDays == timeSpanDays) &&
            (identical(other.minY, minY) || other.minY == minY) &&
            (identical(other.zeroBased, zeroBased) ||
                other.zeroBased == zeroBased) &&
            (identical(other.isVisible, isVisible) ||
                other.isVisible == isVisible) &&
            (identical(other.showTimeSpan, showTimeSpan) ||
                other.showTimeSpan == showTimeSpan) &&
            (identical(other.showSearch, showSearch) ||
                other.showSearch == showSearch) &&
            (identical(other.searchString, searchString) ||
                other.searchString == searchString) &&
            (identical(other.displayFilter, displayFilter) ||
                other.displayFilter == displayFilter));
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        const DeepCollectionEquality().hash(habitDefinitions),
        const DeepCollectionEquality().hash(openHabits),
        const DeepCollectionEquality().hash(openNow),
        const DeepCollectionEquality().hash(pendingLater),
        const DeepCollectionEquality().hash(completed),
        const DeepCollectionEquality().hash(habitCompletions),
        const DeepCollectionEquality().hash(completedToday),
        const DeepCollectionEquality().hash(successfulToday),
        const DeepCollectionEquality().hash(selectedCategoryIds),
        const DeepCollectionEquality().hash(days),
        const DeepCollectionEquality().hash(successfulByDay),
        const DeepCollectionEquality().hash(skippedByDay),
        const DeepCollectionEquality().hash(failedByDay),
        const DeepCollectionEquality().hash(allByDay),
        successPercentage,
        skippedPercentage,
        failedPercentage,
        selectedInfoYmd,
        shortStreakCount,
        longStreakCount,
        timeSpanDays,
        minY,
        zeroBased,
        isVisible,
        showTimeSpan,
        showSearch,
        searchString,
        displayFilter
      ]);

  @override
  String toString() {
    return 'HabitsState(habitDefinitions: $habitDefinitions, openHabits: $openHabits, openNow: $openNow, pendingLater: $pendingLater, completed: $completed, habitCompletions: $habitCompletions, completedToday: $completedToday, successfulToday: $successfulToday, selectedCategoryIds: $selectedCategoryIds, days: $days, successfulByDay: $successfulByDay, skippedByDay: $skippedByDay, failedByDay: $failedByDay, allByDay: $allByDay, successPercentage: $successPercentage, skippedPercentage: $skippedPercentage, failedPercentage: $failedPercentage, selectedInfoYmd: $selectedInfoYmd, shortStreakCount: $shortStreakCount, longStreakCount: $longStreakCount, timeSpanDays: $timeSpanDays, minY: $minY, zeroBased: $zeroBased, isVisible: $isVisible, showTimeSpan: $showTimeSpan, showSearch: $showSearch, searchString: $searchString, displayFilter: $displayFilter)';
  }
}

/// @nodoc
abstract mixin class $HabitsStateCopyWith<$Res> {
  factory $HabitsStateCopyWith(
          HabitsState value, $Res Function(HabitsState) _then) =
      _$HabitsStateCopyWithImpl;
  @useResult
  $Res call(
      {List<HabitDefinition> habitDefinitions,
      List<HabitDefinition> openHabits,
      List<HabitDefinition> openNow,
      List<HabitDefinition> pendingLater,
      List<HabitDefinition> completed,
      List<JournalEntity> habitCompletions,
      Set<String> completedToday,
      Set<String> successfulToday,
      Set<String> selectedCategoryIds,
      List<String> days,
      Map<String, Set<String>> successfulByDay,
      Map<String, Set<String>> skippedByDay,
      Map<String, Set<String>> failedByDay,
      Map<String, Set<String>> allByDay,
      int successPercentage,
      int skippedPercentage,
      int failedPercentage,
      String selectedInfoYmd,
      int shortStreakCount,
      int longStreakCount,
      int timeSpanDays,
      double minY,
      bool zeroBased,
      bool isVisible,
      bool showTimeSpan,
      bool showSearch,
      String searchString,
      HabitDisplayFilter displayFilter});
}

/// @nodoc
class _$HabitsStateCopyWithImpl<$Res> implements $HabitsStateCopyWith<$Res> {
  _$HabitsStateCopyWithImpl(this._self, this._then);

  final HabitsState _self;
  final $Res Function(HabitsState) _then;

  /// Create a copy of HabitsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? habitDefinitions = null,
    Object? openHabits = null,
    Object? openNow = null,
    Object? pendingLater = null,
    Object? completed = null,
    Object? habitCompletions = null,
    Object? completedToday = null,
    Object? successfulToday = null,
    Object? selectedCategoryIds = null,
    Object? days = null,
    Object? successfulByDay = null,
    Object? skippedByDay = null,
    Object? failedByDay = null,
    Object? allByDay = null,
    Object? successPercentage = null,
    Object? skippedPercentage = null,
    Object? failedPercentage = null,
    Object? selectedInfoYmd = null,
    Object? shortStreakCount = null,
    Object? longStreakCount = null,
    Object? timeSpanDays = null,
    Object? minY = null,
    Object? zeroBased = null,
    Object? isVisible = null,
    Object? showTimeSpan = null,
    Object? showSearch = null,
    Object? searchString = null,
    Object? displayFilter = null,
  }) {
    return _then(_self.copyWith(
      habitDefinitions: null == habitDefinitions
          ? _self.habitDefinitions
          : habitDefinitions // ignore: cast_nullable_to_non_nullable
              as List<HabitDefinition>,
      openHabits: null == openHabits
          ? _self.openHabits
          : openHabits // ignore: cast_nullable_to_non_nullable
              as List<HabitDefinition>,
      openNow: null == openNow
          ? _self.openNow
          : openNow // ignore: cast_nullable_to_non_nullable
              as List<HabitDefinition>,
      pendingLater: null == pendingLater
          ? _self.pendingLater
          : pendingLater // ignore: cast_nullable_to_non_nullable
              as List<HabitDefinition>,
      completed: null == completed
          ? _self.completed
          : completed // ignore: cast_nullable_to_non_nullable
              as List<HabitDefinition>,
      habitCompletions: null == habitCompletions
          ? _self.habitCompletions
          : habitCompletions // ignore: cast_nullable_to_non_nullable
              as List<JournalEntity>,
      completedToday: null == completedToday
          ? _self.completedToday
          : completedToday // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      successfulToday: null == successfulToday
          ? _self.successfulToday
          : successfulToday // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      selectedCategoryIds: null == selectedCategoryIds
          ? _self.selectedCategoryIds
          : selectedCategoryIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      days: null == days
          ? _self.days
          : days // ignore: cast_nullable_to_non_nullable
              as List<String>,
      successfulByDay: null == successfulByDay
          ? _self.successfulByDay
          : successfulByDay // ignore: cast_nullable_to_non_nullable
              as Map<String, Set<String>>,
      skippedByDay: null == skippedByDay
          ? _self.skippedByDay
          : skippedByDay // ignore: cast_nullable_to_non_nullable
              as Map<String, Set<String>>,
      failedByDay: null == failedByDay
          ? _self.failedByDay
          : failedByDay // ignore: cast_nullable_to_non_nullable
              as Map<String, Set<String>>,
      allByDay: null == allByDay
          ? _self.allByDay
          : allByDay // ignore: cast_nullable_to_non_nullable
              as Map<String, Set<String>>,
      successPercentage: null == successPercentage
          ? _self.successPercentage
          : successPercentage // ignore: cast_nullable_to_non_nullable
              as int,
      skippedPercentage: null == skippedPercentage
          ? _self.skippedPercentage
          : skippedPercentage // ignore: cast_nullable_to_non_nullable
              as int,
      failedPercentage: null == failedPercentage
          ? _self.failedPercentage
          : failedPercentage // ignore: cast_nullable_to_non_nullable
              as int,
      selectedInfoYmd: null == selectedInfoYmd
          ? _self.selectedInfoYmd
          : selectedInfoYmd // ignore: cast_nullable_to_non_nullable
              as String,
      shortStreakCount: null == shortStreakCount
          ? _self.shortStreakCount
          : shortStreakCount // ignore: cast_nullable_to_non_nullable
              as int,
      longStreakCount: null == longStreakCount
          ? _self.longStreakCount
          : longStreakCount // ignore: cast_nullable_to_non_nullable
              as int,
      timeSpanDays: null == timeSpanDays
          ? _self.timeSpanDays
          : timeSpanDays // ignore: cast_nullable_to_non_nullable
              as int,
      minY: null == minY
          ? _self.minY
          : minY // ignore: cast_nullable_to_non_nullable
              as double,
      zeroBased: null == zeroBased
          ? _self.zeroBased
          : zeroBased // ignore: cast_nullable_to_non_nullable
              as bool,
      isVisible: null == isVisible
          ? _self.isVisible
          : isVisible // ignore: cast_nullable_to_non_nullable
              as bool,
      showTimeSpan: null == showTimeSpan
          ? _self.showTimeSpan
          : showTimeSpan // ignore: cast_nullable_to_non_nullable
              as bool,
      showSearch: null == showSearch
          ? _self.showSearch
          : showSearch // ignore: cast_nullable_to_non_nullable
              as bool,
      searchString: null == searchString
          ? _self.searchString
          : searchString // ignore: cast_nullable_to_non_nullable
              as String,
      displayFilter: null == displayFilter
          ? _self.displayFilter
          : displayFilter // ignore: cast_nullable_to_non_nullable
              as HabitDisplayFilter,
    ));
  }
}

/// Adds pattern-matching-related methods to [HabitsState].
extension HabitsStatePatterns on HabitsState {
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
    TResult Function(_HabitsStateSaved value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HabitsStateSaved() when $default != null:
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
    TResult Function(_HabitsStateSaved value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HabitsStateSaved():
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
    TResult? Function(_HabitsStateSaved value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HabitsStateSaved() when $default != null:
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
            List<HabitDefinition> habitDefinitions,
            List<HabitDefinition> openHabits,
            List<HabitDefinition> openNow,
            List<HabitDefinition> pendingLater,
            List<HabitDefinition> completed,
            List<JournalEntity> habitCompletions,
            Set<String> completedToday,
            Set<String> successfulToday,
            Set<String> selectedCategoryIds,
            List<String> days,
            Map<String, Set<String>> successfulByDay,
            Map<String, Set<String>> skippedByDay,
            Map<String, Set<String>> failedByDay,
            Map<String, Set<String>> allByDay,
            int successPercentage,
            int skippedPercentage,
            int failedPercentage,
            String selectedInfoYmd,
            int shortStreakCount,
            int longStreakCount,
            int timeSpanDays,
            double minY,
            bool zeroBased,
            bool isVisible,
            bool showTimeSpan,
            bool showSearch,
            String searchString,
            HabitDisplayFilter displayFilter)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HabitsStateSaved() when $default != null:
        return $default(
            _that.habitDefinitions,
            _that.openHabits,
            _that.openNow,
            _that.pendingLater,
            _that.completed,
            _that.habitCompletions,
            _that.completedToday,
            _that.successfulToday,
            _that.selectedCategoryIds,
            _that.days,
            _that.successfulByDay,
            _that.skippedByDay,
            _that.failedByDay,
            _that.allByDay,
            _that.successPercentage,
            _that.skippedPercentage,
            _that.failedPercentage,
            _that.selectedInfoYmd,
            _that.shortStreakCount,
            _that.longStreakCount,
            _that.timeSpanDays,
            _that.minY,
            _that.zeroBased,
            _that.isVisible,
            _that.showTimeSpan,
            _that.showSearch,
            _that.searchString,
            _that.displayFilter);
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
            List<HabitDefinition> habitDefinitions,
            List<HabitDefinition> openHabits,
            List<HabitDefinition> openNow,
            List<HabitDefinition> pendingLater,
            List<HabitDefinition> completed,
            List<JournalEntity> habitCompletions,
            Set<String> completedToday,
            Set<String> successfulToday,
            Set<String> selectedCategoryIds,
            List<String> days,
            Map<String, Set<String>> successfulByDay,
            Map<String, Set<String>> skippedByDay,
            Map<String, Set<String>> failedByDay,
            Map<String, Set<String>> allByDay,
            int successPercentage,
            int skippedPercentage,
            int failedPercentage,
            String selectedInfoYmd,
            int shortStreakCount,
            int longStreakCount,
            int timeSpanDays,
            double minY,
            bool zeroBased,
            bool isVisible,
            bool showTimeSpan,
            bool showSearch,
            String searchString,
            HabitDisplayFilter displayFilter)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HabitsStateSaved():
        return $default(
            _that.habitDefinitions,
            _that.openHabits,
            _that.openNow,
            _that.pendingLater,
            _that.completed,
            _that.habitCompletions,
            _that.completedToday,
            _that.successfulToday,
            _that.selectedCategoryIds,
            _that.days,
            _that.successfulByDay,
            _that.skippedByDay,
            _that.failedByDay,
            _that.allByDay,
            _that.successPercentage,
            _that.skippedPercentage,
            _that.failedPercentage,
            _that.selectedInfoYmd,
            _that.shortStreakCount,
            _that.longStreakCount,
            _that.timeSpanDays,
            _that.minY,
            _that.zeroBased,
            _that.isVisible,
            _that.showTimeSpan,
            _that.showSearch,
            _that.searchString,
            _that.displayFilter);
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
            List<HabitDefinition> habitDefinitions,
            List<HabitDefinition> openHabits,
            List<HabitDefinition> openNow,
            List<HabitDefinition> pendingLater,
            List<HabitDefinition> completed,
            List<JournalEntity> habitCompletions,
            Set<String> completedToday,
            Set<String> successfulToday,
            Set<String> selectedCategoryIds,
            List<String> days,
            Map<String, Set<String>> successfulByDay,
            Map<String, Set<String>> skippedByDay,
            Map<String, Set<String>> failedByDay,
            Map<String, Set<String>> allByDay,
            int successPercentage,
            int skippedPercentage,
            int failedPercentage,
            String selectedInfoYmd,
            int shortStreakCount,
            int longStreakCount,
            int timeSpanDays,
            double minY,
            bool zeroBased,
            bool isVisible,
            bool showTimeSpan,
            bool showSearch,
            String searchString,
            HabitDisplayFilter displayFilter)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HabitsStateSaved() when $default != null:
        return $default(
            _that.habitDefinitions,
            _that.openHabits,
            _that.openNow,
            _that.pendingLater,
            _that.completed,
            _that.habitCompletions,
            _that.completedToday,
            _that.successfulToday,
            _that.selectedCategoryIds,
            _that.days,
            _that.successfulByDay,
            _that.skippedByDay,
            _that.failedByDay,
            _that.allByDay,
            _that.successPercentage,
            _that.skippedPercentage,
            _that.failedPercentage,
            _that.selectedInfoYmd,
            _that.shortStreakCount,
            _that.longStreakCount,
            _that.timeSpanDays,
            _that.minY,
            _that.zeroBased,
            _that.isVisible,
            _that.showTimeSpan,
            _that.showSearch,
            _that.searchString,
            _that.displayFilter);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _HabitsStateSaved implements HabitsState {
  _HabitsStateSaved(
      {required final List<HabitDefinition> habitDefinitions,
      required final List<HabitDefinition> openHabits,
      required final List<HabitDefinition> openNow,
      required final List<HabitDefinition> pendingLater,
      required final List<HabitDefinition> completed,
      required final List<JournalEntity> habitCompletions,
      required final Set<String> completedToday,
      required final Set<String> successfulToday,
      required final Set<String> selectedCategoryIds,
      required final List<String> days,
      required final Map<String, Set<String>> successfulByDay,
      required final Map<String, Set<String>> skippedByDay,
      required final Map<String, Set<String>> failedByDay,
      required final Map<String, Set<String>> allByDay,
      required this.successPercentage,
      required this.skippedPercentage,
      required this.failedPercentage,
      required this.selectedInfoYmd,
      required this.shortStreakCount,
      required this.longStreakCount,
      required this.timeSpanDays,
      required this.minY,
      required this.zeroBased,
      required this.isVisible,
      required this.showTimeSpan,
      required this.showSearch,
      required this.searchString,
      required this.displayFilter})
      : _habitDefinitions = habitDefinitions,
        _openHabits = openHabits,
        _openNow = openNow,
        _pendingLater = pendingLater,
        _completed = completed,
        _habitCompletions = habitCompletions,
        _completedToday = completedToday,
        _successfulToday = successfulToday,
        _selectedCategoryIds = selectedCategoryIds,
        _days = days,
        _successfulByDay = successfulByDay,
        _skippedByDay = skippedByDay,
        _failedByDay = failedByDay,
        _allByDay = allByDay;

  final List<HabitDefinition> _habitDefinitions;
  @override
  List<HabitDefinition> get habitDefinitions {
    if (_habitDefinitions is EqualUnmodifiableListView)
      return _habitDefinitions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_habitDefinitions);
  }

  final List<HabitDefinition> _openHabits;
  @override
  List<HabitDefinition> get openHabits {
    if (_openHabits is EqualUnmodifiableListView) return _openHabits;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_openHabits);
  }

  final List<HabitDefinition> _openNow;
  @override
  List<HabitDefinition> get openNow {
    if (_openNow is EqualUnmodifiableListView) return _openNow;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_openNow);
  }

  final List<HabitDefinition> _pendingLater;
  @override
  List<HabitDefinition> get pendingLater {
    if (_pendingLater is EqualUnmodifiableListView) return _pendingLater;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_pendingLater);
  }

  final List<HabitDefinition> _completed;
  @override
  List<HabitDefinition> get completed {
    if (_completed is EqualUnmodifiableListView) return _completed;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_completed);
  }

  final List<JournalEntity> _habitCompletions;
  @override
  List<JournalEntity> get habitCompletions {
    if (_habitCompletions is EqualUnmodifiableListView)
      return _habitCompletions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_habitCompletions);
  }

  final Set<String> _completedToday;
  @override
  Set<String> get completedToday {
    if (_completedToday is EqualUnmodifiableSetView) return _completedToday;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_completedToday);
  }

  final Set<String> _successfulToday;
  @override
  Set<String> get successfulToday {
    if (_successfulToday is EqualUnmodifiableSetView) return _successfulToday;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_successfulToday);
  }

  final Set<String> _selectedCategoryIds;
  @override
  Set<String> get selectedCategoryIds {
    if (_selectedCategoryIds is EqualUnmodifiableSetView)
      return _selectedCategoryIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_selectedCategoryIds);
  }

  final List<String> _days;
  @override
  List<String> get days {
    if (_days is EqualUnmodifiableListView) return _days;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_days);
  }

  final Map<String, Set<String>> _successfulByDay;
  @override
  Map<String, Set<String>> get successfulByDay {
    if (_successfulByDay is EqualUnmodifiableMapView) return _successfulByDay;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_successfulByDay);
  }

  final Map<String, Set<String>> _skippedByDay;
  @override
  Map<String, Set<String>> get skippedByDay {
    if (_skippedByDay is EqualUnmodifiableMapView) return _skippedByDay;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_skippedByDay);
  }

  final Map<String, Set<String>> _failedByDay;
  @override
  Map<String, Set<String>> get failedByDay {
    if (_failedByDay is EqualUnmodifiableMapView) return _failedByDay;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_failedByDay);
  }

  final Map<String, Set<String>> _allByDay;
  @override
  Map<String, Set<String>> get allByDay {
    if (_allByDay is EqualUnmodifiableMapView) return _allByDay;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_allByDay);
  }

  @override
  final int successPercentage;
  @override
  final int skippedPercentage;
  @override
  final int failedPercentage;
  @override
  final String selectedInfoYmd;
  @override
  final int shortStreakCount;
  @override
  final int longStreakCount;
  @override
  final int timeSpanDays;
  @override
  final double minY;
  @override
  final bool zeroBased;
  @override
  final bool isVisible;
  @override
  final bool showTimeSpan;
  @override
  final bool showSearch;
  @override
  final String searchString;
  @override
  final HabitDisplayFilter displayFilter;

  /// Create a copy of HabitsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$HabitsStateSavedCopyWith<_HabitsStateSaved> get copyWith =>
      __$HabitsStateSavedCopyWithImpl<_HabitsStateSaved>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _HabitsStateSaved &&
            const DeepCollectionEquality()
                .equals(other._habitDefinitions, _habitDefinitions) &&
            const DeepCollectionEquality()
                .equals(other._openHabits, _openHabits) &&
            const DeepCollectionEquality().equals(other._openNow, _openNow) &&
            const DeepCollectionEquality()
                .equals(other._pendingLater, _pendingLater) &&
            const DeepCollectionEquality()
                .equals(other._completed, _completed) &&
            const DeepCollectionEquality()
                .equals(other._habitCompletions, _habitCompletions) &&
            const DeepCollectionEquality()
                .equals(other._completedToday, _completedToday) &&
            const DeepCollectionEquality()
                .equals(other._successfulToday, _successfulToday) &&
            const DeepCollectionEquality()
                .equals(other._selectedCategoryIds, _selectedCategoryIds) &&
            const DeepCollectionEquality().equals(other._days, _days) &&
            const DeepCollectionEquality()
                .equals(other._successfulByDay, _successfulByDay) &&
            const DeepCollectionEquality()
                .equals(other._skippedByDay, _skippedByDay) &&
            const DeepCollectionEquality()
                .equals(other._failedByDay, _failedByDay) &&
            const DeepCollectionEquality().equals(other._allByDay, _allByDay) &&
            (identical(other.successPercentage, successPercentage) ||
                other.successPercentage == successPercentage) &&
            (identical(other.skippedPercentage, skippedPercentage) ||
                other.skippedPercentage == skippedPercentage) &&
            (identical(other.failedPercentage, failedPercentage) ||
                other.failedPercentage == failedPercentage) &&
            (identical(other.selectedInfoYmd, selectedInfoYmd) ||
                other.selectedInfoYmd == selectedInfoYmd) &&
            (identical(other.shortStreakCount, shortStreakCount) ||
                other.shortStreakCount == shortStreakCount) &&
            (identical(other.longStreakCount, longStreakCount) ||
                other.longStreakCount == longStreakCount) &&
            (identical(other.timeSpanDays, timeSpanDays) ||
                other.timeSpanDays == timeSpanDays) &&
            (identical(other.minY, minY) || other.minY == minY) &&
            (identical(other.zeroBased, zeroBased) ||
                other.zeroBased == zeroBased) &&
            (identical(other.isVisible, isVisible) ||
                other.isVisible == isVisible) &&
            (identical(other.showTimeSpan, showTimeSpan) ||
                other.showTimeSpan == showTimeSpan) &&
            (identical(other.showSearch, showSearch) ||
                other.showSearch == showSearch) &&
            (identical(other.searchString, searchString) ||
                other.searchString == searchString) &&
            (identical(other.displayFilter, displayFilter) ||
                other.displayFilter == displayFilter));
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        const DeepCollectionEquality().hash(_habitDefinitions),
        const DeepCollectionEquality().hash(_openHabits),
        const DeepCollectionEquality().hash(_openNow),
        const DeepCollectionEquality().hash(_pendingLater),
        const DeepCollectionEquality().hash(_completed),
        const DeepCollectionEquality().hash(_habitCompletions),
        const DeepCollectionEquality().hash(_completedToday),
        const DeepCollectionEquality().hash(_successfulToday),
        const DeepCollectionEquality().hash(_selectedCategoryIds),
        const DeepCollectionEquality().hash(_days),
        const DeepCollectionEquality().hash(_successfulByDay),
        const DeepCollectionEquality().hash(_skippedByDay),
        const DeepCollectionEquality().hash(_failedByDay),
        const DeepCollectionEquality().hash(_allByDay),
        successPercentage,
        skippedPercentage,
        failedPercentage,
        selectedInfoYmd,
        shortStreakCount,
        longStreakCount,
        timeSpanDays,
        minY,
        zeroBased,
        isVisible,
        showTimeSpan,
        showSearch,
        searchString,
        displayFilter
      ]);

  @override
  String toString() {
    return 'HabitsState(habitDefinitions: $habitDefinitions, openHabits: $openHabits, openNow: $openNow, pendingLater: $pendingLater, completed: $completed, habitCompletions: $habitCompletions, completedToday: $completedToday, successfulToday: $successfulToday, selectedCategoryIds: $selectedCategoryIds, days: $days, successfulByDay: $successfulByDay, skippedByDay: $skippedByDay, failedByDay: $failedByDay, allByDay: $allByDay, successPercentage: $successPercentage, skippedPercentage: $skippedPercentage, failedPercentage: $failedPercentage, selectedInfoYmd: $selectedInfoYmd, shortStreakCount: $shortStreakCount, longStreakCount: $longStreakCount, timeSpanDays: $timeSpanDays, minY: $minY, zeroBased: $zeroBased, isVisible: $isVisible, showTimeSpan: $showTimeSpan, showSearch: $showSearch, searchString: $searchString, displayFilter: $displayFilter)';
  }
}

/// @nodoc
abstract mixin class _$HabitsStateSavedCopyWith<$Res>
    implements $HabitsStateCopyWith<$Res> {
  factory _$HabitsStateSavedCopyWith(
          _HabitsStateSaved value, $Res Function(_HabitsStateSaved) _then) =
      __$HabitsStateSavedCopyWithImpl;
  @override
  @useResult
  $Res call(
      {List<HabitDefinition> habitDefinitions,
      List<HabitDefinition> openHabits,
      List<HabitDefinition> openNow,
      List<HabitDefinition> pendingLater,
      List<HabitDefinition> completed,
      List<JournalEntity> habitCompletions,
      Set<String> completedToday,
      Set<String> successfulToday,
      Set<String> selectedCategoryIds,
      List<String> days,
      Map<String, Set<String>> successfulByDay,
      Map<String, Set<String>> skippedByDay,
      Map<String, Set<String>> failedByDay,
      Map<String, Set<String>> allByDay,
      int successPercentage,
      int skippedPercentage,
      int failedPercentage,
      String selectedInfoYmd,
      int shortStreakCount,
      int longStreakCount,
      int timeSpanDays,
      double minY,
      bool zeroBased,
      bool isVisible,
      bool showTimeSpan,
      bool showSearch,
      String searchString,
      HabitDisplayFilter displayFilter});
}

/// @nodoc
class __$HabitsStateSavedCopyWithImpl<$Res>
    implements _$HabitsStateSavedCopyWith<$Res> {
  __$HabitsStateSavedCopyWithImpl(this._self, this._then);

  final _HabitsStateSaved _self;
  final $Res Function(_HabitsStateSaved) _then;

  /// Create a copy of HabitsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? habitDefinitions = null,
    Object? openHabits = null,
    Object? openNow = null,
    Object? pendingLater = null,
    Object? completed = null,
    Object? habitCompletions = null,
    Object? completedToday = null,
    Object? successfulToday = null,
    Object? selectedCategoryIds = null,
    Object? days = null,
    Object? successfulByDay = null,
    Object? skippedByDay = null,
    Object? failedByDay = null,
    Object? allByDay = null,
    Object? successPercentage = null,
    Object? skippedPercentage = null,
    Object? failedPercentage = null,
    Object? selectedInfoYmd = null,
    Object? shortStreakCount = null,
    Object? longStreakCount = null,
    Object? timeSpanDays = null,
    Object? minY = null,
    Object? zeroBased = null,
    Object? isVisible = null,
    Object? showTimeSpan = null,
    Object? showSearch = null,
    Object? searchString = null,
    Object? displayFilter = null,
  }) {
    return _then(_HabitsStateSaved(
      habitDefinitions: null == habitDefinitions
          ? _self._habitDefinitions
          : habitDefinitions // ignore: cast_nullable_to_non_nullable
              as List<HabitDefinition>,
      openHabits: null == openHabits
          ? _self._openHabits
          : openHabits // ignore: cast_nullable_to_non_nullable
              as List<HabitDefinition>,
      openNow: null == openNow
          ? _self._openNow
          : openNow // ignore: cast_nullable_to_non_nullable
              as List<HabitDefinition>,
      pendingLater: null == pendingLater
          ? _self._pendingLater
          : pendingLater // ignore: cast_nullable_to_non_nullable
              as List<HabitDefinition>,
      completed: null == completed
          ? _self._completed
          : completed // ignore: cast_nullable_to_non_nullable
              as List<HabitDefinition>,
      habitCompletions: null == habitCompletions
          ? _self._habitCompletions
          : habitCompletions // ignore: cast_nullable_to_non_nullable
              as List<JournalEntity>,
      completedToday: null == completedToday
          ? _self._completedToday
          : completedToday // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      successfulToday: null == successfulToday
          ? _self._successfulToday
          : successfulToday // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      selectedCategoryIds: null == selectedCategoryIds
          ? _self._selectedCategoryIds
          : selectedCategoryIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      days: null == days
          ? _self._days
          : days // ignore: cast_nullable_to_non_nullable
              as List<String>,
      successfulByDay: null == successfulByDay
          ? _self._successfulByDay
          : successfulByDay // ignore: cast_nullable_to_non_nullable
              as Map<String, Set<String>>,
      skippedByDay: null == skippedByDay
          ? _self._skippedByDay
          : skippedByDay // ignore: cast_nullable_to_non_nullable
              as Map<String, Set<String>>,
      failedByDay: null == failedByDay
          ? _self._failedByDay
          : failedByDay // ignore: cast_nullable_to_non_nullable
              as Map<String, Set<String>>,
      allByDay: null == allByDay
          ? _self._allByDay
          : allByDay // ignore: cast_nullable_to_non_nullable
              as Map<String, Set<String>>,
      successPercentage: null == successPercentage
          ? _self.successPercentage
          : successPercentage // ignore: cast_nullable_to_non_nullable
              as int,
      skippedPercentage: null == skippedPercentage
          ? _self.skippedPercentage
          : skippedPercentage // ignore: cast_nullable_to_non_nullable
              as int,
      failedPercentage: null == failedPercentage
          ? _self.failedPercentage
          : failedPercentage // ignore: cast_nullable_to_non_nullable
              as int,
      selectedInfoYmd: null == selectedInfoYmd
          ? _self.selectedInfoYmd
          : selectedInfoYmd // ignore: cast_nullable_to_non_nullable
              as String,
      shortStreakCount: null == shortStreakCount
          ? _self.shortStreakCount
          : shortStreakCount // ignore: cast_nullable_to_non_nullable
              as int,
      longStreakCount: null == longStreakCount
          ? _self.longStreakCount
          : longStreakCount // ignore: cast_nullable_to_non_nullable
              as int,
      timeSpanDays: null == timeSpanDays
          ? _self.timeSpanDays
          : timeSpanDays // ignore: cast_nullable_to_non_nullable
              as int,
      minY: null == minY
          ? _self.minY
          : minY // ignore: cast_nullable_to_non_nullable
              as double,
      zeroBased: null == zeroBased
          ? _self.zeroBased
          : zeroBased // ignore: cast_nullable_to_non_nullable
              as bool,
      isVisible: null == isVisible
          ? _self.isVisible
          : isVisible // ignore: cast_nullable_to_non_nullable
              as bool,
      showTimeSpan: null == showTimeSpan
          ? _self.showTimeSpan
          : showTimeSpan // ignore: cast_nullable_to_non_nullable
              as bool,
      showSearch: null == showSearch
          ? _self.showSearch
          : showSearch // ignore: cast_nullable_to_non_nullable
              as bool,
      searchString: null == searchString
          ? _self.searchString
          : searchString // ignore: cast_nullable_to_non_nullable
              as String,
      displayFilter: null == displayFilter
          ? _self.displayFilter
          : displayFilter // ignore: cast_nullable_to_non_nullable
              as HabitDisplayFilter,
    ));
  }
}

// dart format on
