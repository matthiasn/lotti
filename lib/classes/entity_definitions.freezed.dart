// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'entity_definitions.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
HabitSchedule _$HabitScheduleFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'daily':
      return DailyHabitSchedule.fromJson(json);
    case 'weekly':
      return WeeklyHabitSchedule.fromJson(json);
    case 'monthly':
      return MonthlyHabitSchedule.fromJson(json);

    default:
      throw CheckedFromJsonException(json, 'runtimeType', 'HabitSchedule',
          'Invalid union type "${json['runtimeType']}"!');
  }
}

/// @nodoc
mixin _$HabitSchedule {
  int get requiredCompletions;

  /// Create a copy of HabitSchedule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HabitScheduleCopyWith<HabitSchedule> get copyWith =>
      _$HabitScheduleCopyWithImpl<HabitSchedule>(
          this as HabitSchedule, _$identity);

  /// Serializes this HabitSchedule to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is HabitSchedule &&
            (identical(other.requiredCompletions, requiredCompletions) ||
                other.requiredCompletions == requiredCompletions));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, requiredCompletions);

  @override
  String toString() {
    return 'HabitSchedule(requiredCompletions: $requiredCompletions)';
  }
}

/// @nodoc
abstract mixin class $HabitScheduleCopyWith<$Res> {
  factory $HabitScheduleCopyWith(
          HabitSchedule value, $Res Function(HabitSchedule) _then) =
      _$HabitScheduleCopyWithImpl;
  @useResult
  $Res call({int requiredCompletions});
}

/// @nodoc
class _$HabitScheduleCopyWithImpl<$Res>
    implements $HabitScheduleCopyWith<$Res> {
  _$HabitScheduleCopyWithImpl(this._self, this._then);

  final HabitSchedule _self;
  final $Res Function(HabitSchedule) _then;

  /// Create a copy of HabitSchedule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? requiredCompletions = null,
  }) {
    return _then(_self.copyWith(
      requiredCompletions: null == requiredCompletions
          ? _self.requiredCompletions
          : requiredCompletions // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [HabitSchedule].
extension HabitSchedulePatterns on HabitSchedule {
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
  TResult maybeMap<TResult extends Object?>({
    TResult Function(DailyHabitSchedule value)? daily,
    TResult Function(WeeklyHabitSchedule value)? weekly,
    TResult Function(MonthlyHabitSchedule value)? monthly,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case DailyHabitSchedule() when daily != null:
        return daily(_that);
      case WeeklyHabitSchedule() when weekly != null:
        return weekly(_that);
      case MonthlyHabitSchedule() when monthly != null:
        return monthly(_that);
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
  TResult map<TResult extends Object?>({
    required TResult Function(DailyHabitSchedule value) daily,
    required TResult Function(WeeklyHabitSchedule value) weekly,
    required TResult Function(MonthlyHabitSchedule value) monthly,
  }) {
    final _that = this;
    switch (_that) {
      case DailyHabitSchedule():
        return daily(_that);
      case WeeklyHabitSchedule():
        return weekly(_that);
      case MonthlyHabitSchedule():
        return monthly(_that);
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
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(DailyHabitSchedule value)? daily,
    TResult? Function(WeeklyHabitSchedule value)? weekly,
    TResult? Function(MonthlyHabitSchedule value)? monthly,
  }) {
    final _that = this;
    switch (_that) {
      case DailyHabitSchedule() when daily != null:
        return daily(_that);
      case WeeklyHabitSchedule() when weekly != null:
        return weekly(_that);
      case MonthlyHabitSchedule() when monthly != null:
        return monthly(_that);
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
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            int requiredCompletions, DateTime? showFrom, DateTime? alertAtTime)?
        daily,
    TResult Function(int requiredCompletions)? weekly,
    TResult Function(int requiredCompletions)? monthly,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case DailyHabitSchedule() when daily != null:
        return daily(
            _that.requiredCompletions, _that.showFrom, _that.alertAtTime);
      case WeeklyHabitSchedule() when weekly != null:
        return weekly(_that.requiredCompletions);
      case MonthlyHabitSchedule() when monthly != null:
        return monthly(_that.requiredCompletions);
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
  TResult when<TResult extends Object?>({
    required TResult Function(
            int requiredCompletions, DateTime? showFrom, DateTime? alertAtTime)
        daily,
    required TResult Function(int requiredCompletions) weekly,
    required TResult Function(int requiredCompletions) monthly,
  }) {
    final _that = this;
    switch (_that) {
      case DailyHabitSchedule():
        return daily(
            _that.requiredCompletions, _that.showFrom, _that.alertAtTime);
      case WeeklyHabitSchedule():
        return weekly(_that.requiredCompletions);
      case MonthlyHabitSchedule():
        return monthly(_that.requiredCompletions);
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
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            int requiredCompletions, DateTime? showFrom, DateTime? alertAtTime)?
        daily,
    TResult? Function(int requiredCompletions)? weekly,
    TResult? Function(int requiredCompletions)? monthly,
  }) {
    final _that = this;
    switch (_that) {
      case DailyHabitSchedule() when daily != null:
        return daily(
            _that.requiredCompletions, _that.showFrom, _that.alertAtTime);
      case WeeklyHabitSchedule() when weekly != null:
        return weekly(_that.requiredCompletions);
      case MonthlyHabitSchedule() when monthly != null:
        return monthly(_that.requiredCompletions);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class DailyHabitSchedule implements HabitSchedule {
  const DailyHabitSchedule(
      {required this.requiredCompletions,
      this.showFrom,
      this.alertAtTime,
      final String? $type})
      : $type = $type ?? 'daily';
  factory DailyHabitSchedule.fromJson(Map<String, dynamic> json) =>
      _$DailyHabitScheduleFromJson(json);

  @override
  final int requiredCompletions;
  final DateTime? showFrom;
  final DateTime? alertAtTime;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of HabitSchedule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DailyHabitScheduleCopyWith<DailyHabitSchedule> get copyWith =>
      _$DailyHabitScheduleCopyWithImpl<DailyHabitSchedule>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$DailyHabitScheduleToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DailyHabitSchedule &&
            (identical(other.requiredCompletions, requiredCompletions) ||
                other.requiredCompletions == requiredCompletions) &&
            (identical(other.showFrom, showFrom) ||
                other.showFrom == showFrom) &&
            (identical(other.alertAtTime, alertAtTime) ||
                other.alertAtTime == alertAtTime));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, requiredCompletions, showFrom, alertAtTime);

  @override
  String toString() {
    return 'HabitSchedule.daily(requiredCompletions: $requiredCompletions, showFrom: $showFrom, alertAtTime: $alertAtTime)';
  }
}

/// @nodoc
abstract mixin class $DailyHabitScheduleCopyWith<$Res>
    implements $HabitScheduleCopyWith<$Res> {
  factory $DailyHabitScheduleCopyWith(
          DailyHabitSchedule value, $Res Function(DailyHabitSchedule) _then) =
      _$DailyHabitScheduleCopyWithImpl;
  @override
  @useResult
  $Res call(
      {int requiredCompletions, DateTime? showFrom, DateTime? alertAtTime});
}

/// @nodoc
class _$DailyHabitScheduleCopyWithImpl<$Res>
    implements $DailyHabitScheduleCopyWith<$Res> {
  _$DailyHabitScheduleCopyWithImpl(this._self, this._then);

  final DailyHabitSchedule _self;
  final $Res Function(DailyHabitSchedule) _then;

  /// Create a copy of HabitSchedule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? requiredCompletions = null,
    Object? showFrom = freezed,
    Object? alertAtTime = freezed,
  }) {
    return _then(DailyHabitSchedule(
      requiredCompletions: null == requiredCompletions
          ? _self.requiredCompletions
          : requiredCompletions // ignore: cast_nullable_to_non_nullable
              as int,
      showFrom: freezed == showFrom
          ? _self.showFrom
          : showFrom // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      alertAtTime: freezed == alertAtTime
          ? _self.alertAtTime
          : alertAtTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class WeeklyHabitSchedule implements HabitSchedule {
  const WeeklyHabitSchedule(
      {required this.requiredCompletions, final String? $type})
      : $type = $type ?? 'weekly';
  factory WeeklyHabitSchedule.fromJson(Map<String, dynamic> json) =>
      _$WeeklyHabitScheduleFromJson(json);

  @override
  final int requiredCompletions;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of HabitSchedule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $WeeklyHabitScheduleCopyWith<WeeklyHabitSchedule> get copyWith =>
      _$WeeklyHabitScheduleCopyWithImpl<WeeklyHabitSchedule>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$WeeklyHabitScheduleToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is WeeklyHabitSchedule &&
            (identical(other.requiredCompletions, requiredCompletions) ||
                other.requiredCompletions == requiredCompletions));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, requiredCompletions);

  @override
  String toString() {
    return 'HabitSchedule.weekly(requiredCompletions: $requiredCompletions)';
  }
}

/// @nodoc
abstract mixin class $WeeklyHabitScheduleCopyWith<$Res>
    implements $HabitScheduleCopyWith<$Res> {
  factory $WeeklyHabitScheduleCopyWith(
          WeeklyHabitSchedule value, $Res Function(WeeklyHabitSchedule) _then) =
      _$WeeklyHabitScheduleCopyWithImpl;
  @override
  @useResult
  $Res call({int requiredCompletions});
}

/// @nodoc
class _$WeeklyHabitScheduleCopyWithImpl<$Res>
    implements $WeeklyHabitScheduleCopyWith<$Res> {
  _$WeeklyHabitScheduleCopyWithImpl(this._self, this._then);

  final WeeklyHabitSchedule _self;
  final $Res Function(WeeklyHabitSchedule) _then;

  /// Create a copy of HabitSchedule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? requiredCompletions = null,
  }) {
    return _then(WeeklyHabitSchedule(
      requiredCompletions: null == requiredCompletions
          ? _self.requiredCompletions
          : requiredCompletions // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class MonthlyHabitSchedule implements HabitSchedule {
  const MonthlyHabitSchedule(
      {required this.requiredCompletions, final String? $type})
      : $type = $type ?? 'monthly';
  factory MonthlyHabitSchedule.fromJson(Map<String, dynamic> json) =>
      _$MonthlyHabitScheduleFromJson(json);

  @override
  final int requiredCompletions;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of HabitSchedule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MonthlyHabitScheduleCopyWith<MonthlyHabitSchedule> get copyWith =>
      _$MonthlyHabitScheduleCopyWithImpl<MonthlyHabitSchedule>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$MonthlyHabitScheduleToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MonthlyHabitSchedule &&
            (identical(other.requiredCompletions, requiredCompletions) ||
                other.requiredCompletions == requiredCompletions));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, requiredCompletions);

  @override
  String toString() {
    return 'HabitSchedule.monthly(requiredCompletions: $requiredCompletions)';
  }
}

/// @nodoc
abstract mixin class $MonthlyHabitScheduleCopyWith<$Res>
    implements $HabitScheduleCopyWith<$Res> {
  factory $MonthlyHabitScheduleCopyWith(MonthlyHabitSchedule value,
          $Res Function(MonthlyHabitSchedule) _then) =
      _$MonthlyHabitScheduleCopyWithImpl;
  @override
  @useResult
  $Res call({int requiredCompletions});
}

/// @nodoc
class _$MonthlyHabitScheduleCopyWithImpl<$Res>
    implements $MonthlyHabitScheduleCopyWith<$Res> {
  _$MonthlyHabitScheduleCopyWithImpl(this._self, this._then);

  final MonthlyHabitSchedule _self;
  final $Res Function(MonthlyHabitSchedule) _then;

  /// Create a copy of HabitSchedule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? requiredCompletions = null,
  }) {
    return _then(MonthlyHabitSchedule(
      requiredCompletions: null == requiredCompletions
          ? _self.requiredCompletions
          : requiredCompletions // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

AutoCompleteRule _$AutoCompleteRuleFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'health':
      return AutoCompleteRuleHealth.fromJson(json);
    case 'workout':
      return AutoCompleteRuleWorkout.fromJson(json);
    case 'measurable':
      return AutoCompleteRuleMeasurable.fromJson(json);
    case 'habit':
      return AutoCompleteRuleHabit.fromJson(json);
    case 'and':
      return AutoCompleteRuleAnd.fromJson(json);
    case 'or':
      return AutoCompleteRuleOr.fromJson(json);
    case 'multiple':
      return AutoCompleteRuleMultiple.fromJson(json);

    default:
      throw CheckedFromJsonException(json, 'runtimeType', 'AutoCompleteRule',
          'Invalid union type "${json['runtimeType']}"!');
  }
}

/// @nodoc
mixin _$AutoCompleteRule {
  String? get title;

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AutoCompleteRuleCopyWith<AutoCompleteRule> get copyWith =>
      _$AutoCompleteRuleCopyWithImpl<AutoCompleteRule>(
          this as AutoCompleteRule, _$identity);

  /// Serializes this AutoCompleteRule to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AutoCompleteRule &&
            (identical(other.title, title) || other.title == title));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, title);

  @override
  String toString() {
    return 'AutoCompleteRule(title: $title)';
  }
}

/// @nodoc
abstract mixin class $AutoCompleteRuleCopyWith<$Res> {
  factory $AutoCompleteRuleCopyWith(
          AutoCompleteRule value, $Res Function(AutoCompleteRule) _then) =
      _$AutoCompleteRuleCopyWithImpl;
  @useResult
  $Res call({String? title});
}

/// @nodoc
class _$AutoCompleteRuleCopyWithImpl<$Res>
    implements $AutoCompleteRuleCopyWith<$Res> {
  _$AutoCompleteRuleCopyWithImpl(this._self, this._then);

  final AutoCompleteRule _self;
  final $Res Function(AutoCompleteRule) _then;

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = freezed,
  }) {
    return _then(_self.copyWith(
      title: freezed == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [AutoCompleteRule].
extension AutoCompleteRulePatterns on AutoCompleteRule {
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
  TResult maybeMap<TResult extends Object?>({
    TResult Function(AutoCompleteRuleHealth value)? health,
    TResult Function(AutoCompleteRuleWorkout value)? workout,
    TResult Function(AutoCompleteRuleMeasurable value)? measurable,
    TResult Function(AutoCompleteRuleHabit value)? habit,
    TResult Function(AutoCompleteRuleAnd value)? and,
    TResult Function(AutoCompleteRuleOr value)? or,
    TResult Function(AutoCompleteRuleMultiple value)? multiple,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case AutoCompleteRuleHealth() when health != null:
        return health(_that);
      case AutoCompleteRuleWorkout() when workout != null:
        return workout(_that);
      case AutoCompleteRuleMeasurable() when measurable != null:
        return measurable(_that);
      case AutoCompleteRuleHabit() when habit != null:
        return habit(_that);
      case AutoCompleteRuleAnd() when and != null:
        return and(_that);
      case AutoCompleteRuleOr() when or != null:
        return or(_that);
      case AutoCompleteRuleMultiple() when multiple != null:
        return multiple(_that);
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
  TResult map<TResult extends Object?>({
    required TResult Function(AutoCompleteRuleHealth value) health,
    required TResult Function(AutoCompleteRuleWorkout value) workout,
    required TResult Function(AutoCompleteRuleMeasurable value) measurable,
    required TResult Function(AutoCompleteRuleHabit value) habit,
    required TResult Function(AutoCompleteRuleAnd value) and,
    required TResult Function(AutoCompleteRuleOr value) or,
    required TResult Function(AutoCompleteRuleMultiple value) multiple,
  }) {
    final _that = this;
    switch (_that) {
      case AutoCompleteRuleHealth():
        return health(_that);
      case AutoCompleteRuleWorkout():
        return workout(_that);
      case AutoCompleteRuleMeasurable():
        return measurable(_that);
      case AutoCompleteRuleHabit():
        return habit(_that);
      case AutoCompleteRuleAnd():
        return and(_that);
      case AutoCompleteRuleOr():
        return or(_that);
      case AutoCompleteRuleMultiple():
        return multiple(_that);
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
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(AutoCompleteRuleHealth value)? health,
    TResult? Function(AutoCompleteRuleWorkout value)? workout,
    TResult? Function(AutoCompleteRuleMeasurable value)? measurable,
    TResult? Function(AutoCompleteRuleHabit value)? habit,
    TResult? Function(AutoCompleteRuleAnd value)? and,
    TResult? Function(AutoCompleteRuleOr value)? or,
    TResult? Function(AutoCompleteRuleMultiple value)? multiple,
  }) {
    final _that = this;
    switch (_that) {
      case AutoCompleteRuleHealth() when health != null:
        return health(_that);
      case AutoCompleteRuleWorkout() when workout != null:
        return workout(_that);
      case AutoCompleteRuleMeasurable() when measurable != null:
        return measurable(_that);
      case AutoCompleteRuleHabit() when habit != null:
        return habit(_that);
      case AutoCompleteRuleAnd() when and != null:
        return and(_that);
      case AutoCompleteRuleOr() when or != null:
        return or(_that);
      case AutoCompleteRuleMultiple() when multiple != null:
        return multiple(_that);
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
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            String dataType, num? minimum, num? maximum, String? title)?
        health,
    TResult Function(
            String dataType, num? minimum, num? maximum, String? title)?
        workout,
    TResult Function(
            String dataTypeId, num? minimum, num? maximum, String? title)?
        measurable,
    TResult Function(String habitId, String? title)? habit,
    TResult Function(List<AutoCompleteRule> rules, String? title)? and,
    TResult Function(List<AutoCompleteRule> rules, String? title)? or,
    TResult Function(
            List<AutoCompleteRule> rules, int successes, String? title)?
        multiple,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case AutoCompleteRuleHealth() when health != null:
        return health(
            _that.dataType, _that.minimum, _that.maximum, _that.title);
      case AutoCompleteRuleWorkout() when workout != null:
        return workout(
            _that.dataType, _that.minimum, _that.maximum, _that.title);
      case AutoCompleteRuleMeasurable() when measurable != null:
        return measurable(
            _that.dataTypeId, _that.minimum, _that.maximum, _that.title);
      case AutoCompleteRuleHabit() when habit != null:
        return habit(_that.habitId, _that.title);
      case AutoCompleteRuleAnd() when and != null:
        return and(_that.rules, _that.title);
      case AutoCompleteRuleOr() when or != null:
        return or(_that.rules, _that.title);
      case AutoCompleteRuleMultiple() when multiple != null:
        return multiple(_that.rules, _that.successes, _that.title);
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
  TResult when<TResult extends Object?>({
    required TResult Function(
            String dataType, num? minimum, num? maximum, String? title)
        health,
    required TResult Function(
            String dataType, num? minimum, num? maximum, String? title)
        workout,
    required TResult Function(
            String dataTypeId, num? minimum, num? maximum, String? title)
        measurable,
    required TResult Function(String habitId, String? title) habit,
    required TResult Function(List<AutoCompleteRule> rules, String? title) and,
    required TResult Function(List<AutoCompleteRule> rules, String? title) or,
    required TResult Function(
            List<AutoCompleteRule> rules, int successes, String? title)
        multiple,
  }) {
    final _that = this;
    switch (_that) {
      case AutoCompleteRuleHealth():
        return health(
            _that.dataType, _that.minimum, _that.maximum, _that.title);
      case AutoCompleteRuleWorkout():
        return workout(
            _that.dataType, _that.minimum, _that.maximum, _that.title);
      case AutoCompleteRuleMeasurable():
        return measurable(
            _that.dataTypeId, _that.minimum, _that.maximum, _that.title);
      case AutoCompleteRuleHabit():
        return habit(_that.habitId, _that.title);
      case AutoCompleteRuleAnd():
        return and(_that.rules, _that.title);
      case AutoCompleteRuleOr():
        return or(_that.rules, _that.title);
      case AutoCompleteRuleMultiple():
        return multiple(_that.rules, _that.successes, _that.title);
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
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            String dataType, num? minimum, num? maximum, String? title)?
        health,
    TResult? Function(
            String dataType, num? minimum, num? maximum, String? title)?
        workout,
    TResult? Function(
            String dataTypeId, num? minimum, num? maximum, String? title)?
        measurable,
    TResult? Function(String habitId, String? title)? habit,
    TResult? Function(List<AutoCompleteRule> rules, String? title)? and,
    TResult? Function(List<AutoCompleteRule> rules, String? title)? or,
    TResult? Function(
            List<AutoCompleteRule> rules, int successes, String? title)?
        multiple,
  }) {
    final _that = this;
    switch (_that) {
      case AutoCompleteRuleHealth() when health != null:
        return health(
            _that.dataType, _that.minimum, _that.maximum, _that.title);
      case AutoCompleteRuleWorkout() when workout != null:
        return workout(
            _that.dataType, _that.minimum, _that.maximum, _that.title);
      case AutoCompleteRuleMeasurable() when measurable != null:
        return measurable(
            _that.dataTypeId, _that.minimum, _that.maximum, _that.title);
      case AutoCompleteRuleHabit() when habit != null:
        return habit(_that.habitId, _that.title);
      case AutoCompleteRuleAnd() when and != null:
        return and(_that.rules, _that.title);
      case AutoCompleteRuleOr() when or != null:
        return or(_that.rules, _that.title);
      case AutoCompleteRuleMultiple() when multiple != null:
        return multiple(_that.rules, _that.successes, _that.title);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class AutoCompleteRuleHealth implements AutoCompleteRule {
  const AutoCompleteRuleHealth(
      {required this.dataType,
      this.minimum,
      this.maximum,
      this.title,
      final String? $type})
      : $type = $type ?? 'health';
  factory AutoCompleteRuleHealth.fromJson(Map<String, dynamic> json) =>
      _$AutoCompleteRuleHealthFromJson(json);

  final String dataType;
  final num? minimum;
  final num? maximum;
  @override
  final String? title;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AutoCompleteRuleHealthCopyWith<AutoCompleteRuleHealth> get copyWith =>
      _$AutoCompleteRuleHealthCopyWithImpl<AutoCompleteRuleHealth>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AutoCompleteRuleHealthToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AutoCompleteRuleHealth &&
            (identical(other.dataType, dataType) ||
                other.dataType == dataType) &&
            (identical(other.minimum, minimum) || other.minimum == minimum) &&
            (identical(other.maximum, maximum) || other.maximum == maximum) &&
            (identical(other.title, title) || other.title == title));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, dataType, minimum, maximum, title);

  @override
  String toString() {
    return 'AutoCompleteRule.health(dataType: $dataType, minimum: $minimum, maximum: $maximum, title: $title)';
  }
}

/// @nodoc
abstract mixin class $AutoCompleteRuleHealthCopyWith<$Res>
    implements $AutoCompleteRuleCopyWith<$Res> {
  factory $AutoCompleteRuleHealthCopyWith(AutoCompleteRuleHealth value,
          $Res Function(AutoCompleteRuleHealth) _then) =
      _$AutoCompleteRuleHealthCopyWithImpl;
  @override
  @useResult
  $Res call({String dataType, num? minimum, num? maximum, String? title});
}

/// @nodoc
class _$AutoCompleteRuleHealthCopyWithImpl<$Res>
    implements $AutoCompleteRuleHealthCopyWith<$Res> {
  _$AutoCompleteRuleHealthCopyWithImpl(this._self, this._then);

  final AutoCompleteRuleHealth _self;
  final $Res Function(AutoCompleteRuleHealth) _then;

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? dataType = null,
    Object? minimum = freezed,
    Object? maximum = freezed,
    Object? title = freezed,
  }) {
    return _then(AutoCompleteRuleHealth(
      dataType: null == dataType
          ? _self.dataType
          : dataType // ignore: cast_nullable_to_non_nullable
              as String,
      minimum: freezed == minimum
          ? _self.minimum
          : minimum // ignore: cast_nullable_to_non_nullable
              as num?,
      maximum: freezed == maximum
          ? _self.maximum
          : maximum // ignore: cast_nullable_to_non_nullable
              as num?,
      title: freezed == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class AutoCompleteRuleWorkout implements AutoCompleteRule {
  const AutoCompleteRuleWorkout(
      {required this.dataType,
      this.minimum,
      this.maximum,
      this.title,
      final String? $type})
      : $type = $type ?? 'workout';
  factory AutoCompleteRuleWorkout.fromJson(Map<String, dynamic> json) =>
      _$AutoCompleteRuleWorkoutFromJson(json);

  final String dataType;
  final num? minimum;
  final num? maximum;
  @override
  final String? title;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AutoCompleteRuleWorkoutCopyWith<AutoCompleteRuleWorkout> get copyWith =>
      _$AutoCompleteRuleWorkoutCopyWithImpl<AutoCompleteRuleWorkout>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AutoCompleteRuleWorkoutToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AutoCompleteRuleWorkout &&
            (identical(other.dataType, dataType) ||
                other.dataType == dataType) &&
            (identical(other.minimum, minimum) || other.minimum == minimum) &&
            (identical(other.maximum, maximum) || other.maximum == maximum) &&
            (identical(other.title, title) || other.title == title));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, dataType, minimum, maximum, title);

  @override
  String toString() {
    return 'AutoCompleteRule.workout(dataType: $dataType, minimum: $minimum, maximum: $maximum, title: $title)';
  }
}

/// @nodoc
abstract mixin class $AutoCompleteRuleWorkoutCopyWith<$Res>
    implements $AutoCompleteRuleCopyWith<$Res> {
  factory $AutoCompleteRuleWorkoutCopyWith(AutoCompleteRuleWorkout value,
          $Res Function(AutoCompleteRuleWorkout) _then) =
      _$AutoCompleteRuleWorkoutCopyWithImpl;
  @override
  @useResult
  $Res call({String dataType, num? minimum, num? maximum, String? title});
}

/// @nodoc
class _$AutoCompleteRuleWorkoutCopyWithImpl<$Res>
    implements $AutoCompleteRuleWorkoutCopyWith<$Res> {
  _$AutoCompleteRuleWorkoutCopyWithImpl(this._self, this._then);

  final AutoCompleteRuleWorkout _self;
  final $Res Function(AutoCompleteRuleWorkout) _then;

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? dataType = null,
    Object? minimum = freezed,
    Object? maximum = freezed,
    Object? title = freezed,
  }) {
    return _then(AutoCompleteRuleWorkout(
      dataType: null == dataType
          ? _self.dataType
          : dataType // ignore: cast_nullable_to_non_nullable
              as String,
      minimum: freezed == minimum
          ? _self.minimum
          : minimum // ignore: cast_nullable_to_non_nullable
              as num?,
      maximum: freezed == maximum
          ? _self.maximum
          : maximum // ignore: cast_nullable_to_non_nullable
              as num?,
      title: freezed == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class AutoCompleteRuleMeasurable implements AutoCompleteRule {
  const AutoCompleteRuleMeasurable(
      {required this.dataTypeId,
      this.minimum,
      this.maximum,
      this.title,
      final String? $type})
      : $type = $type ?? 'measurable';
  factory AutoCompleteRuleMeasurable.fromJson(Map<String, dynamic> json) =>
      _$AutoCompleteRuleMeasurableFromJson(json);

  final String dataTypeId;
  final num? minimum;
  final num? maximum;
  @override
  final String? title;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AutoCompleteRuleMeasurableCopyWith<AutoCompleteRuleMeasurable>
      get copyWith =>
          _$AutoCompleteRuleMeasurableCopyWithImpl<AutoCompleteRuleMeasurable>(
              this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AutoCompleteRuleMeasurableToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AutoCompleteRuleMeasurable &&
            (identical(other.dataTypeId, dataTypeId) ||
                other.dataTypeId == dataTypeId) &&
            (identical(other.minimum, minimum) || other.minimum == minimum) &&
            (identical(other.maximum, maximum) || other.maximum == maximum) &&
            (identical(other.title, title) || other.title == title));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, dataTypeId, minimum, maximum, title);

  @override
  String toString() {
    return 'AutoCompleteRule.measurable(dataTypeId: $dataTypeId, minimum: $minimum, maximum: $maximum, title: $title)';
  }
}

/// @nodoc
abstract mixin class $AutoCompleteRuleMeasurableCopyWith<$Res>
    implements $AutoCompleteRuleCopyWith<$Res> {
  factory $AutoCompleteRuleMeasurableCopyWith(AutoCompleteRuleMeasurable value,
          $Res Function(AutoCompleteRuleMeasurable) _then) =
      _$AutoCompleteRuleMeasurableCopyWithImpl;
  @override
  @useResult
  $Res call({String dataTypeId, num? minimum, num? maximum, String? title});
}

/// @nodoc
class _$AutoCompleteRuleMeasurableCopyWithImpl<$Res>
    implements $AutoCompleteRuleMeasurableCopyWith<$Res> {
  _$AutoCompleteRuleMeasurableCopyWithImpl(this._self, this._then);

  final AutoCompleteRuleMeasurable _self;
  final $Res Function(AutoCompleteRuleMeasurable) _then;

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? dataTypeId = null,
    Object? minimum = freezed,
    Object? maximum = freezed,
    Object? title = freezed,
  }) {
    return _then(AutoCompleteRuleMeasurable(
      dataTypeId: null == dataTypeId
          ? _self.dataTypeId
          : dataTypeId // ignore: cast_nullable_to_non_nullable
              as String,
      minimum: freezed == minimum
          ? _self.minimum
          : minimum // ignore: cast_nullable_to_non_nullable
              as num?,
      maximum: freezed == maximum
          ? _self.maximum
          : maximum // ignore: cast_nullable_to_non_nullable
              as num?,
      title: freezed == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class AutoCompleteRuleHabit implements AutoCompleteRule {
  const AutoCompleteRuleHabit(
      {required this.habitId, this.title, final String? $type})
      : $type = $type ?? 'habit';
  factory AutoCompleteRuleHabit.fromJson(Map<String, dynamic> json) =>
      _$AutoCompleteRuleHabitFromJson(json);

  final String habitId;
  @override
  final String? title;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AutoCompleteRuleHabitCopyWith<AutoCompleteRuleHabit> get copyWith =>
      _$AutoCompleteRuleHabitCopyWithImpl<AutoCompleteRuleHabit>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AutoCompleteRuleHabitToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AutoCompleteRuleHabit &&
            (identical(other.habitId, habitId) || other.habitId == habitId) &&
            (identical(other.title, title) || other.title == title));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, habitId, title);

  @override
  String toString() {
    return 'AutoCompleteRule.habit(habitId: $habitId, title: $title)';
  }
}

/// @nodoc
abstract mixin class $AutoCompleteRuleHabitCopyWith<$Res>
    implements $AutoCompleteRuleCopyWith<$Res> {
  factory $AutoCompleteRuleHabitCopyWith(AutoCompleteRuleHabit value,
          $Res Function(AutoCompleteRuleHabit) _then) =
      _$AutoCompleteRuleHabitCopyWithImpl;
  @override
  @useResult
  $Res call({String habitId, String? title});
}

/// @nodoc
class _$AutoCompleteRuleHabitCopyWithImpl<$Res>
    implements $AutoCompleteRuleHabitCopyWith<$Res> {
  _$AutoCompleteRuleHabitCopyWithImpl(this._self, this._then);

  final AutoCompleteRuleHabit _self;
  final $Res Function(AutoCompleteRuleHabit) _then;

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? habitId = null,
    Object? title = freezed,
  }) {
    return _then(AutoCompleteRuleHabit(
      habitId: null == habitId
          ? _self.habitId
          : habitId // ignore: cast_nullable_to_non_nullable
              as String,
      title: freezed == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class AutoCompleteRuleAnd implements AutoCompleteRule {
  const AutoCompleteRuleAnd(
      {required final List<AutoCompleteRule> rules,
      this.title,
      final String? $type})
      : _rules = rules,
        $type = $type ?? 'and';
  factory AutoCompleteRuleAnd.fromJson(Map<String, dynamic> json) =>
      _$AutoCompleteRuleAndFromJson(json);

  final List<AutoCompleteRule> _rules;
  List<AutoCompleteRule> get rules {
    if (_rules is EqualUnmodifiableListView) return _rules;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_rules);
  }

  @override
  final String? title;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AutoCompleteRuleAndCopyWith<AutoCompleteRuleAnd> get copyWith =>
      _$AutoCompleteRuleAndCopyWithImpl<AutoCompleteRuleAnd>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AutoCompleteRuleAndToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AutoCompleteRuleAnd &&
            const DeepCollectionEquality().equals(other._rules, _rules) &&
            (identical(other.title, title) || other.title == title));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(_rules), title);

  @override
  String toString() {
    return 'AutoCompleteRule.and(rules: $rules, title: $title)';
  }
}

/// @nodoc
abstract mixin class $AutoCompleteRuleAndCopyWith<$Res>
    implements $AutoCompleteRuleCopyWith<$Res> {
  factory $AutoCompleteRuleAndCopyWith(
          AutoCompleteRuleAnd value, $Res Function(AutoCompleteRuleAnd) _then) =
      _$AutoCompleteRuleAndCopyWithImpl;
  @override
  @useResult
  $Res call({List<AutoCompleteRule> rules, String? title});
}

/// @nodoc
class _$AutoCompleteRuleAndCopyWithImpl<$Res>
    implements $AutoCompleteRuleAndCopyWith<$Res> {
  _$AutoCompleteRuleAndCopyWithImpl(this._self, this._then);

  final AutoCompleteRuleAnd _self;
  final $Res Function(AutoCompleteRuleAnd) _then;

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? rules = null,
    Object? title = freezed,
  }) {
    return _then(AutoCompleteRuleAnd(
      rules: null == rules
          ? _self._rules
          : rules // ignore: cast_nullable_to_non_nullable
              as List<AutoCompleteRule>,
      title: freezed == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class AutoCompleteRuleOr implements AutoCompleteRule {
  const AutoCompleteRuleOr(
      {required final List<AutoCompleteRule> rules,
      this.title,
      final String? $type})
      : _rules = rules,
        $type = $type ?? 'or';
  factory AutoCompleteRuleOr.fromJson(Map<String, dynamic> json) =>
      _$AutoCompleteRuleOrFromJson(json);

  final List<AutoCompleteRule> _rules;
  List<AutoCompleteRule> get rules {
    if (_rules is EqualUnmodifiableListView) return _rules;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_rules);
  }

  @override
  final String? title;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AutoCompleteRuleOrCopyWith<AutoCompleteRuleOr> get copyWith =>
      _$AutoCompleteRuleOrCopyWithImpl<AutoCompleteRuleOr>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AutoCompleteRuleOrToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AutoCompleteRuleOr &&
            const DeepCollectionEquality().equals(other._rules, _rules) &&
            (identical(other.title, title) || other.title == title));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(_rules), title);

  @override
  String toString() {
    return 'AutoCompleteRule.or(rules: $rules, title: $title)';
  }
}

/// @nodoc
abstract mixin class $AutoCompleteRuleOrCopyWith<$Res>
    implements $AutoCompleteRuleCopyWith<$Res> {
  factory $AutoCompleteRuleOrCopyWith(
          AutoCompleteRuleOr value, $Res Function(AutoCompleteRuleOr) _then) =
      _$AutoCompleteRuleOrCopyWithImpl;
  @override
  @useResult
  $Res call({List<AutoCompleteRule> rules, String? title});
}

/// @nodoc
class _$AutoCompleteRuleOrCopyWithImpl<$Res>
    implements $AutoCompleteRuleOrCopyWith<$Res> {
  _$AutoCompleteRuleOrCopyWithImpl(this._self, this._then);

  final AutoCompleteRuleOr _self;
  final $Res Function(AutoCompleteRuleOr) _then;

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? rules = null,
    Object? title = freezed,
  }) {
    return _then(AutoCompleteRuleOr(
      rules: null == rules
          ? _self._rules
          : rules // ignore: cast_nullable_to_non_nullable
              as List<AutoCompleteRule>,
      title: freezed == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class AutoCompleteRuleMultiple implements AutoCompleteRule {
  const AutoCompleteRuleMultiple(
      {required final List<AutoCompleteRule> rules,
      required this.successes,
      this.title,
      final String? $type})
      : _rules = rules,
        $type = $type ?? 'multiple';
  factory AutoCompleteRuleMultiple.fromJson(Map<String, dynamic> json) =>
      _$AutoCompleteRuleMultipleFromJson(json);

  final List<AutoCompleteRule> _rules;
  List<AutoCompleteRule> get rules {
    if (_rules is EqualUnmodifiableListView) return _rules;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_rules);
  }

  final int successes;
  @override
  final String? title;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AutoCompleteRuleMultipleCopyWith<AutoCompleteRuleMultiple> get copyWith =>
      _$AutoCompleteRuleMultipleCopyWithImpl<AutoCompleteRuleMultiple>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AutoCompleteRuleMultipleToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AutoCompleteRuleMultiple &&
            const DeepCollectionEquality().equals(other._rules, _rules) &&
            (identical(other.successes, successes) ||
                other.successes == successes) &&
            (identical(other.title, title) || other.title == title));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType,
      const DeepCollectionEquality().hash(_rules), successes, title);

  @override
  String toString() {
    return 'AutoCompleteRule.multiple(rules: $rules, successes: $successes, title: $title)';
  }
}

/// @nodoc
abstract mixin class $AutoCompleteRuleMultipleCopyWith<$Res>
    implements $AutoCompleteRuleCopyWith<$Res> {
  factory $AutoCompleteRuleMultipleCopyWith(AutoCompleteRuleMultiple value,
          $Res Function(AutoCompleteRuleMultiple) _then) =
      _$AutoCompleteRuleMultipleCopyWithImpl;
  @override
  @useResult
  $Res call({List<AutoCompleteRule> rules, int successes, String? title});
}

/// @nodoc
class _$AutoCompleteRuleMultipleCopyWithImpl<$Res>
    implements $AutoCompleteRuleMultipleCopyWith<$Res> {
  _$AutoCompleteRuleMultipleCopyWithImpl(this._self, this._then);

  final AutoCompleteRuleMultiple _self;
  final $Res Function(AutoCompleteRuleMultiple) _then;

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? rules = null,
    Object? successes = null,
    Object? title = freezed,
  }) {
    return _then(AutoCompleteRuleMultiple(
      rules: null == rules
          ? _self._rules
          : rules // ignore: cast_nullable_to_non_nullable
              as List<AutoCompleteRule>,
      successes: null == successes
          ? _self.successes
          : successes // ignore: cast_nullable_to_non_nullable
              as int,
      title: freezed == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

EntityDefinition _$EntityDefinitionFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'measurableDataType':
      return MeasurableDataType.fromJson(json);
    case 'categoryDefinition':
      return CategoryDefinition.fromJson(json);
    case 'labelDefinition':
      return LabelDefinition.fromJson(json);
    case 'habit':
      return HabitDefinition.fromJson(json);
    case 'dashboard':
      return DashboardDefinition.fromJson(json);

    default:
      throw CheckedFromJsonException(json, 'runtimeType', 'EntityDefinition',
          'Invalid union type "${json['runtimeType']}"!');
  }
}

/// @nodoc
mixin _$EntityDefinition {
  String get id;
  DateTime get createdAt;
  DateTime get updatedAt;
  VectorClock? get vectorClock;
  DateTime? get deletedAt;
  bool? get private;

  /// Create a copy of EntityDefinition
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $EntityDefinitionCopyWith<EntityDefinition> get copyWith =>
      _$EntityDefinitionCopyWithImpl<EntityDefinition>(
          this as EntityDefinition, _$identity);

  /// Serializes this EntityDefinition to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is EntityDefinition &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.vectorClock, vectorClock) ||
                other.vectorClock == vectorClock) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt) &&
            (identical(other.private, private) || other.private == private));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, createdAt, updatedAt, vectorClock, deletedAt, private);

  @override
  String toString() {
    return 'EntityDefinition(id: $id, createdAt: $createdAt, updatedAt: $updatedAt, vectorClock: $vectorClock, deletedAt: $deletedAt, private: $private)';
  }
}

/// @nodoc
abstract mixin class $EntityDefinitionCopyWith<$Res> {
  factory $EntityDefinitionCopyWith(
          EntityDefinition value, $Res Function(EntityDefinition) _then) =
      _$EntityDefinitionCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      DateTime createdAt,
      DateTime updatedAt,
      VectorClock? vectorClock,
      DateTime? deletedAt,
      bool private});
}

/// @nodoc
class _$EntityDefinitionCopyWithImpl<$Res>
    implements $EntityDefinitionCopyWith<$Res> {
  _$EntityDefinitionCopyWithImpl(this._self, this._then);

  final EntityDefinition _self;
  final $Res Function(EntityDefinition) _then;

  /// Create a copy of EntityDefinition
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? vectorClock = freezed,
    Object? deletedAt = freezed,
    Object? private = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      vectorClock: freezed == vectorClock
          ? _self.vectorClock
          : vectorClock // ignore: cast_nullable_to_non_nullable
              as VectorClock?,
      deletedAt: freezed == deletedAt
          ? _self.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      private: null == private
          ? _self.private!
          : private // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [EntityDefinition].
extension EntityDefinitionPatterns on EntityDefinition {
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
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MeasurableDataType value)? measurableDataType,
    TResult Function(CategoryDefinition value)? categoryDefinition,
    TResult Function(LabelDefinition value)? labelDefinition,
    TResult Function(HabitDefinition value)? habit,
    TResult Function(DashboardDefinition value)? dashboard,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case MeasurableDataType() when measurableDataType != null:
        return measurableDataType(_that);
      case CategoryDefinition() when categoryDefinition != null:
        return categoryDefinition(_that);
      case LabelDefinition() when labelDefinition != null:
        return labelDefinition(_that);
      case HabitDefinition() when habit != null:
        return habit(_that);
      case DashboardDefinition() when dashboard != null:
        return dashboard(_that);
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
  TResult map<TResult extends Object?>({
    required TResult Function(MeasurableDataType value) measurableDataType,
    required TResult Function(CategoryDefinition value) categoryDefinition,
    required TResult Function(LabelDefinition value) labelDefinition,
    required TResult Function(HabitDefinition value) habit,
    required TResult Function(DashboardDefinition value) dashboard,
  }) {
    final _that = this;
    switch (_that) {
      case MeasurableDataType():
        return measurableDataType(_that);
      case CategoryDefinition():
        return categoryDefinition(_that);
      case LabelDefinition():
        return labelDefinition(_that);
      case HabitDefinition():
        return habit(_that);
      case DashboardDefinition():
        return dashboard(_that);
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
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MeasurableDataType value)? measurableDataType,
    TResult? Function(CategoryDefinition value)? categoryDefinition,
    TResult? Function(LabelDefinition value)? labelDefinition,
    TResult? Function(HabitDefinition value)? habit,
    TResult? Function(DashboardDefinition value)? dashboard,
  }) {
    final _that = this;
    switch (_that) {
      case MeasurableDataType() when measurableDataType != null:
        return measurableDataType(_that);
      case CategoryDefinition() when categoryDefinition != null:
        return categoryDefinition(_that);
      case LabelDefinition() when labelDefinition != null:
        return labelDefinition(_that);
      case HabitDefinition() when habit != null:
        return habit(_that);
      case DashboardDefinition() when dashboard != null:
        return dashboard(_that);
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
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            String id,
            DateTime createdAt,
            DateTime updatedAt,
            String displayName,
            String description,
            String unitName,
            int version,
            VectorClock? vectorClock,
            DateTime? deletedAt,
            bool? private,
            bool? favorite,
            String? categoryId,
            AggregationType? aggregationType)?
        measurableDataType,
    TResult Function(
            String id,
            DateTime createdAt,
            DateTime updatedAt,
            String name,
            VectorClock? vectorClock,
            bool private,
            bool active,
            bool? favorite,
            String? color,
            String? categoryId,
            DateTime? deletedAt,
            String? defaultLanguageCode,
            List<String>? allowedPromptIds,
            Map<AiResponseType, List<String>>? automaticPrompts,
            @CategoryIconConverter() CategoryIcon? icon)?
        categoryDefinition,
    TResult Function(
            String id,
            DateTime createdAt,
            DateTime updatedAt,
            String name,
            String color,
            VectorClock? vectorClock,
            String? description,
            int? sortOrder,
            DateTime? deletedAt,
            bool? private)?
        labelDefinition,
    TResult Function(
            String id,
            DateTime createdAt,
            DateTime updatedAt,
            String name,
            String description,
            HabitSchedule habitSchedule,
            VectorClock? vectorClock,
            bool active,
            bool private,
            AutoCompleteRule? autoCompleteRule,
            String? version,
            DateTime? activeFrom,
            DateTime? activeUntil,
            DateTime? deletedAt,
            String? defaultStoryId,
            String? categoryId,
            String? dashboardId,
            bool? priority)?
        habit,
    TResult Function(
            String id,
            DateTime createdAt,
            DateTime updatedAt,
            DateTime lastReviewed,
            String name,
            String description,
            List<DashboardItem> items,
            String version,
            VectorClock? vectorClock,
            bool active,
            bool private,
            DateTime? reviewAt,
            int days,
            DateTime? deletedAt,
            String? categoryId)?
        dashboard,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case MeasurableDataType() when measurableDataType != null:
        return measurableDataType(
            _that.id,
            _that.createdAt,
            _that.updatedAt,
            _that.displayName,
            _that.description,
            _that.unitName,
            _that.version,
            _that.vectorClock,
            _that.deletedAt,
            _that.private,
            _that.favorite,
            _that.categoryId,
            _that.aggregationType);
      case CategoryDefinition() when categoryDefinition != null:
        return categoryDefinition(
            _that.id,
            _that.createdAt,
            _that.updatedAt,
            _that.name,
            _that.vectorClock,
            _that.private,
            _that.active,
            _that.favorite,
            _that.color,
            _that.categoryId,
            _that.deletedAt,
            _that.defaultLanguageCode,
            _that.allowedPromptIds,
            _that.automaticPrompts,
            _that.icon);
      case LabelDefinition() when labelDefinition != null:
        return labelDefinition(
            _that.id,
            _that.createdAt,
            _that.updatedAt,
            _that.name,
            _that.color,
            _that.vectorClock,
            _that.description,
            _that.sortOrder,
            _that.deletedAt,
            _that.private);
      case HabitDefinition() when habit != null:
        return habit(
            _that.id,
            _that.createdAt,
            _that.updatedAt,
            _that.name,
            _that.description,
            _that.habitSchedule,
            _that.vectorClock,
            _that.active,
            _that.private,
            _that.autoCompleteRule,
            _that.version,
            _that.activeFrom,
            _that.activeUntil,
            _that.deletedAt,
            _that.defaultStoryId,
            _that.categoryId,
            _that.dashboardId,
            _that.priority);
      case DashboardDefinition() when dashboard != null:
        return dashboard(
            _that.id,
            _that.createdAt,
            _that.updatedAt,
            _that.lastReviewed,
            _that.name,
            _that.description,
            _that.items,
            _that.version,
            _that.vectorClock,
            _that.active,
            _that.private,
            _that.reviewAt,
            _that.days,
            _that.deletedAt,
            _that.categoryId);
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
  TResult when<TResult extends Object?>({
    required TResult Function(
            String id,
            DateTime createdAt,
            DateTime updatedAt,
            String displayName,
            String description,
            String unitName,
            int version,
            VectorClock? vectorClock,
            DateTime? deletedAt,
            bool? private,
            bool? favorite,
            String? categoryId,
            AggregationType? aggregationType)
        measurableDataType,
    required TResult Function(
            String id,
            DateTime createdAt,
            DateTime updatedAt,
            String name,
            VectorClock? vectorClock,
            bool private,
            bool active,
            bool? favorite,
            String? color,
            String? categoryId,
            DateTime? deletedAt,
            String? defaultLanguageCode,
            List<String>? allowedPromptIds,
            Map<AiResponseType, List<String>>? automaticPrompts,
            @CategoryIconConverter() CategoryIcon? icon)
        categoryDefinition,
    required TResult Function(
            String id,
            DateTime createdAt,
            DateTime updatedAt,
            String name,
            String color,
            VectorClock? vectorClock,
            String? description,
            int? sortOrder,
            DateTime? deletedAt,
            bool? private)
        labelDefinition,
    required TResult Function(
            String id,
            DateTime createdAt,
            DateTime updatedAt,
            String name,
            String description,
            HabitSchedule habitSchedule,
            VectorClock? vectorClock,
            bool active,
            bool private,
            AutoCompleteRule? autoCompleteRule,
            String? version,
            DateTime? activeFrom,
            DateTime? activeUntil,
            DateTime? deletedAt,
            String? defaultStoryId,
            String? categoryId,
            String? dashboardId,
            bool? priority)
        habit,
    required TResult Function(
            String id,
            DateTime createdAt,
            DateTime updatedAt,
            DateTime lastReviewed,
            String name,
            String description,
            List<DashboardItem> items,
            String version,
            VectorClock? vectorClock,
            bool active,
            bool private,
            DateTime? reviewAt,
            int days,
            DateTime? deletedAt,
            String? categoryId)
        dashboard,
  }) {
    final _that = this;
    switch (_that) {
      case MeasurableDataType():
        return measurableDataType(
            _that.id,
            _that.createdAt,
            _that.updatedAt,
            _that.displayName,
            _that.description,
            _that.unitName,
            _that.version,
            _that.vectorClock,
            _that.deletedAt,
            _that.private,
            _that.favorite,
            _that.categoryId,
            _that.aggregationType);
      case CategoryDefinition():
        return categoryDefinition(
            _that.id,
            _that.createdAt,
            _that.updatedAt,
            _that.name,
            _that.vectorClock,
            _that.private,
            _that.active,
            _that.favorite,
            _that.color,
            _that.categoryId,
            _that.deletedAt,
            _that.defaultLanguageCode,
            _that.allowedPromptIds,
            _that.automaticPrompts,
            _that.icon);
      case LabelDefinition():
        return labelDefinition(
            _that.id,
            _that.createdAt,
            _that.updatedAt,
            _that.name,
            _that.color,
            _that.vectorClock,
            _that.description,
            _that.sortOrder,
            _that.deletedAt,
            _that.private);
      case HabitDefinition():
        return habit(
            _that.id,
            _that.createdAt,
            _that.updatedAt,
            _that.name,
            _that.description,
            _that.habitSchedule,
            _that.vectorClock,
            _that.active,
            _that.private,
            _that.autoCompleteRule,
            _that.version,
            _that.activeFrom,
            _that.activeUntil,
            _that.deletedAt,
            _that.defaultStoryId,
            _that.categoryId,
            _that.dashboardId,
            _that.priority);
      case DashboardDefinition():
        return dashboard(
            _that.id,
            _that.createdAt,
            _that.updatedAt,
            _that.lastReviewed,
            _that.name,
            _that.description,
            _that.items,
            _that.version,
            _that.vectorClock,
            _that.active,
            _that.private,
            _that.reviewAt,
            _that.days,
            _that.deletedAt,
            _that.categoryId);
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
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            String id,
            DateTime createdAt,
            DateTime updatedAt,
            String displayName,
            String description,
            String unitName,
            int version,
            VectorClock? vectorClock,
            DateTime? deletedAt,
            bool? private,
            bool? favorite,
            String? categoryId,
            AggregationType? aggregationType)?
        measurableDataType,
    TResult? Function(
            String id,
            DateTime createdAt,
            DateTime updatedAt,
            String name,
            VectorClock? vectorClock,
            bool private,
            bool active,
            bool? favorite,
            String? color,
            String? categoryId,
            DateTime? deletedAt,
            String? defaultLanguageCode,
            List<String>? allowedPromptIds,
            Map<AiResponseType, List<String>>? automaticPrompts,
            @CategoryIconConverter() CategoryIcon? icon)?
        categoryDefinition,
    TResult? Function(
            String id,
            DateTime createdAt,
            DateTime updatedAt,
            String name,
            String color,
            VectorClock? vectorClock,
            String? description,
            int? sortOrder,
            DateTime? deletedAt,
            bool? private)?
        labelDefinition,
    TResult? Function(
            String id,
            DateTime createdAt,
            DateTime updatedAt,
            String name,
            String description,
            HabitSchedule habitSchedule,
            VectorClock? vectorClock,
            bool active,
            bool private,
            AutoCompleteRule? autoCompleteRule,
            String? version,
            DateTime? activeFrom,
            DateTime? activeUntil,
            DateTime? deletedAt,
            String? defaultStoryId,
            String? categoryId,
            String? dashboardId,
            bool? priority)?
        habit,
    TResult? Function(
            String id,
            DateTime createdAt,
            DateTime updatedAt,
            DateTime lastReviewed,
            String name,
            String description,
            List<DashboardItem> items,
            String version,
            VectorClock? vectorClock,
            bool active,
            bool private,
            DateTime? reviewAt,
            int days,
            DateTime? deletedAt,
            String? categoryId)?
        dashboard,
  }) {
    final _that = this;
    switch (_that) {
      case MeasurableDataType() when measurableDataType != null:
        return measurableDataType(
            _that.id,
            _that.createdAt,
            _that.updatedAt,
            _that.displayName,
            _that.description,
            _that.unitName,
            _that.version,
            _that.vectorClock,
            _that.deletedAt,
            _that.private,
            _that.favorite,
            _that.categoryId,
            _that.aggregationType);
      case CategoryDefinition() when categoryDefinition != null:
        return categoryDefinition(
            _that.id,
            _that.createdAt,
            _that.updatedAt,
            _that.name,
            _that.vectorClock,
            _that.private,
            _that.active,
            _that.favorite,
            _that.color,
            _that.categoryId,
            _that.deletedAt,
            _that.defaultLanguageCode,
            _that.allowedPromptIds,
            _that.automaticPrompts,
            _that.icon);
      case LabelDefinition() when labelDefinition != null:
        return labelDefinition(
            _that.id,
            _that.createdAt,
            _that.updatedAt,
            _that.name,
            _that.color,
            _that.vectorClock,
            _that.description,
            _that.sortOrder,
            _that.deletedAt,
            _that.private);
      case HabitDefinition() when habit != null:
        return habit(
            _that.id,
            _that.createdAt,
            _that.updatedAt,
            _that.name,
            _that.description,
            _that.habitSchedule,
            _that.vectorClock,
            _that.active,
            _that.private,
            _that.autoCompleteRule,
            _that.version,
            _that.activeFrom,
            _that.activeUntil,
            _that.deletedAt,
            _that.defaultStoryId,
            _that.categoryId,
            _that.dashboardId,
            _that.priority);
      case DashboardDefinition() when dashboard != null:
        return dashboard(
            _that.id,
            _that.createdAt,
            _that.updatedAt,
            _that.lastReviewed,
            _that.name,
            _that.description,
            _that.items,
            _that.version,
            _that.vectorClock,
            _that.active,
            _that.private,
            _that.reviewAt,
            _that.days,
            _that.deletedAt,
            _that.categoryId);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class MeasurableDataType implements EntityDefinition {
  const MeasurableDataType(
      {required this.id,
      required this.createdAt,
      required this.updatedAt,
      required this.displayName,
      required this.description,
      required this.unitName,
      required this.version,
      required this.vectorClock,
      this.deletedAt,
      this.private,
      this.favorite,
      this.categoryId,
      this.aggregationType,
      final String? $type})
      : $type = $type ?? 'measurableDataType';
  factory MeasurableDataType.fromJson(Map<String, dynamic> json) =>
      _$MeasurableDataTypeFromJson(json);

  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final String displayName;
  final String description;
  final String unitName;
  final int version;
  @override
  final VectorClock? vectorClock;
  @override
  final DateTime? deletedAt;
  @override
  final bool? private;
  final bool? favorite;
  final String? categoryId;
  final AggregationType? aggregationType;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of EntityDefinition
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MeasurableDataTypeCopyWith<MeasurableDataType> get copyWith =>
      _$MeasurableDataTypeCopyWithImpl<MeasurableDataType>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$MeasurableDataTypeToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MeasurableDataType &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.unitName, unitName) ||
                other.unitName == unitName) &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.vectorClock, vectorClock) ||
                other.vectorClock == vectorClock) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt) &&
            (identical(other.private, private) || other.private == private) &&
            (identical(other.favorite, favorite) ||
                other.favorite == favorite) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.aggregationType, aggregationType) ||
                other.aggregationType == aggregationType));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      createdAt,
      updatedAt,
      displayName,
      description,
      unitName,
      version,
      vectorClock,
      deletedAt,
      private,
      favorite,
      categoryId,
      aggregationType);

  @override
  String toString() {
    return 'EntityDefinition.measurableDataType(id: $id, createdAt: $createdAt, updatedAt: $updatedAt, displayName: $displayName, description: $description, unitName: $unitName, version: $version, vectorClock: $vectorClock, deletedAt: $deletedAt, private: $private, favorite: $favorite, categoryId: $categoryId, aggregationType: $aggregationType)';
  }
}

/// @nodoc
abstract mixin class $MeasurableDataTypeCopyWith<$Res>
    implements $EntityDefinitionCopyWith<$Res> {
  factory $MeasurableDataTypeCopyWith(
          MeasurableDataType value, $Res Function(MeasurableDataType) _then) =
      _$MeasurableDataTypeCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      DateTime createdAt,
      DateTime updatedAt,
      String displayName,
      String description,
      String unitName,
      int version,
      VectorClock? vectorClock,
      DateTime? deletedAt,
      bool? private,
      bool? favorite,
      String? categoryId,
      AggregationType? aggregationType});
}

/// @nodoc
class _$MeasurableDataTypeCopyWithImpl<$Res>
    implements $MeasurableDataTypeCopyWith<$Res> {
  _$MeasurableDataTypeCopyWithImpl(this._self, this._then);

  final MeasurableDataType _self;
  final $Res Function(MeasurableDataType) _then;

  /// Create a copy of EntityDefinition
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? displayName = null,
    Object? description = null,
    Object? unitName = null,
    Object? version = null,
    Object? vectorClock = freezed,
    Object? deletedAt = freezed,
    Object? private = freezed,
    Object? favorite = freezed,
    Object? categoryId = freezed,
    Object? aggregationType = freezed,
  }) {
    return _then(MeasurableDataType(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      displayName: null == displayName
          ? _self.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      unitName: null == unitName
          ? _self.unitName
          : unitName // ignore: cast_nullable_to_non_nullable
              as String,
      version: null == version
          ? _self.version
          : version // ignore: cast_nullable_to_non_nullable
              as int,
      vectorClock: freezed == vectorClock
          ? _self.vectorClock
          : vectorClock // ignore: cast_nullable_to_non_nullable
              as VectorClock?,
      deletedAt: freezed == deletedAt
          ? _self.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      private: freezed == private
          ? _self.private
          : private // ignore: cast_nullable_to_non_nullable
              as bool?,
      favorite: freezed == favorite
          ? _self.favorite
          : favorite // ignore: cast_nullable_to_non_nullable
              as bool?,
      categoryId: freezed == categoryId
          ? _self.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String?,
      aggregationType: freezed == aggregationType
          ? _self.aggregationType
          : aggregationType // ignore: cast_nullable_to_non_nullable
              as AggregationType?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class CategoryDefinition implements EntityDefinition {
  const CategoryDefinition(
      {required this.id,
      required this.createdAt,
      required this.updatedAt,
      required this.name,
      required this.vectorClock,
      required this.private,
      required this.active,
      this.favorite,
      this.color,
      this.categoryId,
      this.deletedAt,
      this.defaultLanguageCode,
      final List<String>? allowedPromptIds,
      final Map<AiResponseType, List<String>>? automaticPrompts,
      @CategoryIconConverter() this.icon,
      final String? $type})
      : _allowedPromptIds = allowedPromptIds,
        _automaticPrompts = automaticPrompts,
        $type = $type ?? 'categoryDefinition';
  factory CategoryDefinition.fromJson(Map<String, dynamic> json) =>
      _$CategoryDefinitionFromJson(json);

  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final String name;
  @override
  final VectorClock? vectorClock;
  @override
  final bool private;
  final bool active;
  final bool? favorite;
  final String? color;
  final String? categoryId;
  @override
  final DateTime? deletedAt;
  final String? defaultLanguageCode;
  final List<String>? _allowedPromptIds;
  List<String>? get allowedPromptIds {
    final value = _allowedPromptIds;
    if (value == null) return null;
    if (_allowedPromptIds is EqualUnmodifiableListView)
      return _allowedPromptIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final Map<AiResponseType, List<String>>? _automaticPrompts;
  Map<AiResponseType, List<String>>? get automaticPrompts {
    final value = _automaticPrompts;
    if (value == null) return null;
    if (_automaticPrompts is EqualUnmodifiableMapView) return _automaticPrompts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @CategoryIconConverter()
  final CategoryIcon? icon;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of EntityDefinition
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CategoryDefinitionCopyWith<CategoryDefinition> get copyWith =>
      _$CategoryDefinitionCopyWithImpl<CategoryDefinition>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$CategoryDefinitionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CategoryDefinition &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.vectorClock, vectorClock) ||
                other.vectorClock == vectorClock) &&
            (identical(other.private, private) || other.private == private) &&
            (identical(other.active, active) || other.active == active) &&
            (identical(other.favorite, favorite) ||
                other.favorite == favorite) &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt) &&
            (identical(other.defaultLanguageCode, defaultLanguageCode) ||
                other.defaultLanguageCode == defaultLanguageCode) &&
            const DeepCollectionEquality()
                .equals(other._allowedPromptIds, _allowedPromptIds) &&
            const DeepCollectionEquality()
                .equals(other._automaticPrompts, _automaticPrompts) &&
            (identical(other.icon, icon) || other.icon == icon));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      createdAt,
      updatedAt,
      name,
      vectorClock,
      private,
      active,
      favorite,
      color,
      categoryId,
      deletedAt,
      defaultLanguageCode,
      const DeepCollectionEquality().hash(_allowedPromptIds),
      const DeepCollectionEquality().hash(_automaticPrompts),
      icon);

  @override
  String toString() {
    return 'EntityDefinition.categoryDefinition(id: $id, createdAt: $createdAt, updatedAt: $updatedAt, name: $name, vectorClock: $vectorClock, private: $private, active: $active, favorite: $favorite, color: $color, categoryId: $categoryId, deletedAt: $deletedAt, defaultLanguageCode: $defaultLanguageCode, allowedPromptIds: $allowedPromptIds, automaticPrompts: $automaticPrompts, icon: $icon)';
  }
}

/// @nodoc
abstract mixin class $CategoryDefinitionCopyWith<$Res>
    implements $EntityDefinitionCopyWith<$Res> {
  factory $CategoryDefinitionCopyWith(
          CategoryDefinition value, $Res Function(CategoryDefinition) _then) =
      _$CategoryDefinitionCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      DateTime createdAt,
      DateTime updatedAt,
      String name,
      VectorClock? vectorClock,
      bool private,
      bool active,
      bool? favorite,
      String? color,
      String? categoryId,
      DateTime? deletedAt,
      String? defaultLanguageCode,
      List<String>? allowedPromptIds,
      Map<AiResponseType, List<String>>? automaticPrompts,
      @CategoryIconConverter() CategoryIcon? icon});
}

/// @nodoc
class _$CategoryDefinitionCopyWithImpl<$Res>
    implements $CategoryDefinitionCopyWith<$Res> {
  _$CategoryDefinitionCopyWithImpl(this._self, this._then);

  final CategoryDefinition _self;
  final $Res Function(CategoryDefinition) _then;

  /// Create a copy of EntityDefinition
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? name = null,
    Object? vectorClock = freezed,
    Object? private = null,
    Object? active = null,
    Object? favorite = freezed,
    Object? color = freezed,
    Object? categoryId = freezed,
    Object? deletedAt = freezed,
    Object? defaultLanguageCode = freezed,
    Object? allowedPromptIds = freezed,
    Object? automaticPrompts = freezed,
    Object? icon = freezed,
  }) {
    return _then(CategoryDefinition(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      vectorClock: freezed == vectorClock
          ? _self.vectorClock
          : vectorClock // ignore: cast_nullable_to_non_nullable
              as VectorClock?,
      private: null == private
          ? _self.private
          : private // ignore: cast_nullable_to_non_nullable
              as bool,
      active: null == active
          ? _self.active
          : active // ignore: cast_nullable_to_non_nullable
              as bool,
      favorite: freezed == favorite
          ? _self.favorite
          : favorite // ignore: cast_nullable_to_non_nullable
              as bool?,
      color: freezed == color
          ? _self.color
          : color // ignore: cast_nullable_to_non_nullable
              as String?,
      categoryId: freezed == categoryId
          ? _self.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String?,
      deletedAt: freezed == deletedAt
          ? _self.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      defaultLanguageCode: freezed == defaultLanguageCode
          ? _self.defaultLanguageCode
          : defaultLanguageCode // ignore: cast_nullable_to_non_nullable
              as String?,
      allowedPromptIds: freezed == allowedPromptIds
          ? _self._allowedPromptIds
          : allowedPromptIds // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      automaticPrompts: freezed == automaticPrompts
          ? _self._automaticPrompts
          : automaticPrompts // ignore: cast_nullable_to_non_nullable
              as Map<AiResponseType, List<String>>?,
      icon: freezed == icon
          ? _self.icon
          : icon // ignore: cast_nullable_to_non_nullable
              as CategoryIcon?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class LabelDefinition implements EntityDefinition {
  const LabelDefinition(
      {required this.id,
      required this.createdAt,
      required this.updatedAt,
      required this.name,
      required this.color,
      required this.vectorClock,
      this.description,
      this.sortOrder,
      this.deletedAt,
      this.private,
      final String? $type})
      : $type = $type ?? 'labelDefinition';
  factory LabelDefinition.fromJson(Map<String, dynamic> json) =>
      _$LabelDefinitionFromJson(json);

  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final String name;
  final String color;
  @override
  final VectorClock? vectorClock;
  final String? description;
  final int? sortOrder;
  @override
  final DateTime? deletedAt;
  @override
  final bool? private;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of EntityDefinition
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $LabelDefinitionCopyWith<LabelDefinition> get copyWith =>
      _$LabelDefinitionCopyWithImpl<LabelDefinition>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$LabelDefinitionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is LabelDefinition &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.vectorClock, vectorClock) ||
                other.vectorClock == vectorClock) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.sortOrder, sortOrder) ||
                other.sortOrder == sortOrder) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt) &&
            (identical(other.private, private) || other.private == private));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, createdAt, updatedAt, name,
      color, vectorClock, description, sortOrder, deletedAt, private);

  @override
  String toString() {
    return 'EntityDefinition.labelDefinition(id: $id, createdAt: $createdAt, updatedAt: $updatedAt, name: $name, color: $color, vectorClock: $vectorClock, description: $description, sortOrder: $sortOrder, deletedAt: $deletedAt, private: $private)';
  }
}

/// @nodoc
abstract mixin class $LabelDefinitionCopyWith<$Res>
    implements $EntityDefinitionCopyWith<$Res> {
  factory $LabelDefinitionCopyWith(
          LabelDefinition value, $Res Function(LabelDefinition) _then) =
      _$LabelDefinitionCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      DateTime createdAt,
      DateTime updatedAt,
      String name,
      String color,
      VectorClock? vectorClock,
      String? description,
      int? sortOrder,
      DateTime? deletedAt,
      bool? private});
}

/// @nodoc
class _$LabelDefinitionCopyWithImpl<$Res>
    implements $LabelDefinitionCopyWith<$Res> {
  _$LabelDefinitionCopyWithImpl(this._self, this._then);

  final LabelDefinition _self;
  final $Res Function(LabelDefinition) _then;

  /// Create a copy of EntityDefinition
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? name = null,
    Object? color = null,
    Object? vectorClock = freezed,
    Object? description = freezed,
    Object? sortOrder = freezed,
    Object? deletedAt = freezed,
    Object? private = freezed,
  }) {
    return _then(LabelDefinition(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      color: null == color
          ? _self.color
          : color // ignore: cast_nullable_to_non_nullable
              as String,
      vectorClock: freezed == vectorClock
          ? _self.vectorClock
          : vectorClock // ignore: cast_nullable_to_non_nullable
              as VectorClock?,
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      sortOrder: freezed == sortOrder
          ? _self.sortOrder
          : sortOrder // ignore: cast_nullable_to_non_nullable
              as int?,
      deletedAt: freezed == deletedAt
          ? _self.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      private: freezed == private
          ? _self.private
          : private // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class HabitDefinition implements EntityDefinition {
  const HabitDefinition(
      {required this.id,
      required this.createdAt,
      required this.updatedAt,
      required this.name,
      required this.description,
      required this.habitSchedule,
      required this.vectorClock,
      required this.active,
      required this.private,
      this.autoCompleteRule,
      this.version,
      this.activeFrom,
      this.activeUntil,
      this.deletedAt,
      this.defaultStoryId,
      this.categoryId,
      this.dashboardId,
      this.priority,
      final String? $type})
      : $type = $type ?? 'habit';
  factory HabitDefinition.fromJson(Map<String, dynamic> json) =>
      _$HabitDefinitionFromJson(json);

  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final String name;
  final String description;
  final HabitSchedule habitSchedule;
  @override
  final VectorClock? vectorClock;
  final bool active;
  @override
  final bool private;
  final AutoCompleteRule? autoCompleteRule;
  final String? version;
  final DateTime? activeFrom;
  final DateTime? activeUntil;
  @override
  final DateTime? deletedAt;
  final String? defaultStoryId;
  final String? categoryId;
  final String? dashboardId;
  final bool? priority;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of EntityDefinition
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HabitDefinitionCopyWith<HabitDefinition> get copyWith =>
      _$HabitDefinitionCopyWithImpl<HabitDefinition>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$HabitDefinitionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is HabitDefinition &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.habitSchedule, habitSchedule) ||
                other.habitSchedule == habitSchedule) &&
            (identical(other.vectorClock, vectorClock) ||
                other.vectorClock == vectorClock) &&
            (identical(other.active, active) || other.active == active) &&
            (identical(other.private, private) || other.private == private) &&
            (identical(other.autoCompleteRule, autoCompleteRule) ||
                other.autoCompleteRule == autoCompleteRule) &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.activeFrom, activeFrom) ||
                other.activeFrom == activeFrom) &&
            (identical(other.activeUntil, activeUntil) ||
                other.activeUntil == activeUntil) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt) &&
            (identical(other.defaultStoryId, defaultStoryId) ||
                other.defaultStoryId == defaultStoryId) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.dashboardId, dashboardId) ||
                other.dashboardId == dashboardId) &&
            (identical(other.priority, priority) ||
                other.priority == priority));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      createdAt,
      updatedAt,
      name,
      description,
      habitSchedule,
      vectorClock,
      active,
      private,
      autoCompleteRule,
      version,
      activeFrom,
      activeUntil,
      deletedAt,
      defaultStoryId,
      categoryId,
      dashboardId,
      priority);

  @override
  String toString() {
    return 'EntityDefinition.habit(id: $id, createdAt: $createdAt, updatedAt: $updatedAt, name: $name, description: $description, habitSchedule: $habitSchedule, vectorClock: $vectorClock, active: $active, private: $private, autoCompleteRule: $autoCompleteRule, version: $version, activeFrom: $activeFrom, activeUntil: $activeUntil, deletedAt: $deletedAt, defaultStoryId: $defaultStoryId, categoryId: $categoryId, dashboardId: $dashboardId, priority: $priority)';
  }
}

/// @nodoc
abstract mixin class $HabitDefinitionCopyWith<$Res>
    implements $EntityDefinitionCopyWith<$Res> {
  factory $HabitDefinitionCopyWith(
          HabitDefinition value, $Res Function(HabitDefinition) _then) =
      _$HabitDefinitionCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      DateTime createdAt,
      DateTime updatedAt,
      String name,
      String description,
      HabitSchedule habitSchedule,
      VectorClock? vectorClock,
      bool active,
      bool private,
      AutoCompleteRule? autoCompleteRule,
      String? version,
      DateTime? activeFrom,
      DateTime? activeUntil,
      DateTime? deletedAt,
      String? defaultStoryId,
      String? categoryId,
      String? dashboardId,
      bool? priority});

  $HabitScheduleCopyWith<$Res> get habitSchedule;
  $AutoCompleteRuleCopyWith<$Res>? get autoCompleteRule;
}

/// @nodoc
class _$HabitDefinitionCopyWithImpl<$Res>
    implements $HabitDefinitionCopyWith<$Res> {
  _$HabitDefinitionCopyWithImpl(this._self, this._then);

  final HabitDefinition _self;
  final $Res Function(HabitDefinition) _then;

  /// Create a copy of EntityDefinition
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? name = null,
    Object? description = null,
    Object? habitSchedule = null,
    Object? vectorClock = freezed,
    Object? active = null,
    Object? private = null,
    Object? autoCompleteRule = freezed,
    Object? version = freezed,
    Object? activeFrom = freezed,
    Object? activeUntil = freezed,
    Object? deletedAt = freezed,
    Object? defaultStoryId = freezed,
    Object? categoryId = freezed,
    Object? dashboardId = freezed,
    Object? priority = freezed,
  }) {
    return _then(HabitDefinition(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      habitSchedule: null == habitSchedule
          ? _self.habitSchedule
          : habitSchedule // ignore: cast_nullable_to_non_nullable
              as HabitSchedule,
      vectorClock: freezed == vectorClock
          ? _self.vectorClock
          : vectorClock // ignore: cast_nullable_to_non_nullable
              as VectorClock?,
      active: null == active
          ? _self.active
          : active // ignore: cast_nullable_to_non_nullable
              as bool,
      private: null == private
          ? _self.private
          : private // ignore: cast_nullable_to_non_nullable
              as bool,
      autoCompleteRule: freezed == autoCompleteRule
          ? _self.autoCompleteRule
          : autoCompleteRule // ignore: cast_nullable_to_non_nullable
              as AutoCompleteRule?,
      version: freezed == version
          ? _self.version
          : version // ignore: cast_nullable_to_non_nullable
              as String?,
      activeFrom: freezed == activeFrom
          ? _self.activeFrom
          : activeFrom // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      activeUntil: freezed == activeUntil
          ? _self.activeUntil
          : activeUntil // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      deletedAt: freezed == deletedAt
          ? _self.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      defaultStoryId: freezed == defaultStoryId
          ? _self.defaultStoryId
          : defaultStoryId // ignore: cast_nullable_to_non_nullable
              as String?,
      categoryId: freezed == categoryId
          ? _self.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String?,
      dashboardId: freezed == dashboardId
          ? _self.dashboardId
          : dashboardId // ignore: cast_nullable_to_non_nullable
              as String?,
      priority: freezed == priority
          ? _self.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }

  /// Create a copy of EntityDefinition
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $HabitScheduleCopyWith<$Res> get habitSchedule {
    return $HabitScheduleCopyWith<$Res>(_self.habitSchedule, (value) {
      return _then(_self.copyWith(habitSchedule: value));
    });
  }

  /// Create a copy of EntityDefinition
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

/// @nodoc
@JsonSerializable()
class DashboardDefinition implements EntityDefinition {
  const DashboardDefinition(
      {required this.id,
      required this.createdAt,
      required this.updatedAt,
      required this.lastReviewed,
      required this.name,
      required this.description,
      required final List<DashboardItem> items,
      required this.version,
      required this.vectorClock,
      required this.active,
      required this.private,
      this.reviewAt,
      this.days = 30,
      this.deletedAt,
      this.categoryId,
      final String? $type})
      : _items = items,
        $type = $type ?? 'dashboard';
  factory DashboardDefinition.fromJson(Map<String, dynamic> json) =>
      _$DashboardDefinitionFromJson(json);

  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final DateTime lastReviewed;
  final String name;
  final String description;
  final List<DashboardItem> _items;
  List<DashboardItem> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  final String version;
  @override
  final VectorClock? vectorClock;
  final bool active;
  @override
  final bool private;
  final DateTime? reviewAt;
  @JsonKey()
  final int days;
  @override
  final DateTime? deletedAt;
  final String? categoryId;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of EntityDefinition
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DashboardDefinitionCopyWith<DashboardDefinition> get copyWith =>
      _$DashboardDefinitionCopyWithImpl<DashboardDefinition>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$DashboardDefinitionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DashboardDefinition &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.lastReviewed, lastReviewed) ||
                other.lastReviewed == lastReviewed) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.vectorClock, vectorClock) ||
                other.vectorClock == vectorClock) &&
            (identical(other.active, active) || other.active == active) &&
            (identical(other.private, private) || other.private == private) &&
            (identical(other.reviewAt, reviewAt) ||
                other.reviewAt == reviewAt) &&
            (identical(other.days, days) || other.days == days) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      createdAt,
      updatedAt,
      lastReviewed,
      name,
      description,
      const DeepCollectionEquality().hash(_items),
      version,
      vectorClock,
      active,
      private,
      reviewAt,
      days,
      deletedAt,
      categoryId);

  @override
  String toString() {
    return 'EntityDefinition.dashboard(id: $id, createdAt: $createdAt, updatedAt: $updatedAt, lastReviewed: $lastReviewed, name: $name, description: $description, items: $items, version: $version, vectorClock: $vectorClock, active: $active, private: $private, reviewAt: $reviewAt, days: $days, deletedAt: $deletedAt, categoryId: $categoryId)';
  }
}

/// @nodoc
abstract mixin class $DashboardDefinitionCopyWith<$Res>
    implements $EntityDefinitionCopyWith<$Res> {
  factory $DashboardDefinitionCopyWith(
          DashboardDefinition value, $Res Function(DashboardDefinition) _then) =
      _$DashboardDefinitionCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      DateTime createdAt,
      DateTime updatedAt,
      DateTime lastReviewed,
      String name,
      String description,
      List<DashboardItem> items,
      String version,
      VectorClock? vectorClock,
      bool active,
      bool private,
      DateTime? reviewAt,
      int days,
      DateTime? deletedAt,
      String? categoryId});
}

/// @nodoc
class _$DashboardDefinitionCopyWithImpl<$Res>
    implements $DashboardDefinitionCopyWith<$Res> {
  _$DashboardDefinitionCopyWithImpl(this._self, this._then);

  final DashboardDefinition _self;
  final $Res Function(DashboardDefinition) _then;

  /// Create a copy of EntityDefinition
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? lastReviewed = null,
    Object? name = null,
    Object? description = null,
    Object? items = null,
    Object? version = null,
    Object? vectorClock = freezed,
    Object? active = null,
    Object? private = null,
    Object? reviewAt = freezed,
    Object? days = null,
    Object? deletedAt = freezed,
    Object? categoryId = freezed,
  }) {
    return _then(DashboardDefinition(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      lastReviewed: null == lastReviewed
          ? _self.lastReviewed
          : lastReviewed // ignore: cast_nullable_to_non_nullable
              as DateTime,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      items: null == items
          ? _self._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<DashboardItem>,
      version: null == version
          ? _self.version
          : version // ignore: cast_nullable_to_non_nullable
              as String,
      vectorClock: freezed == vectorClock
          ? _self.vectorClock
          : vectorClock // ignore: cast_nullable_to_non_nullable
              as VectorClock?,
      active: null == active
          ? _self.active
          : active // ignore: cast_nullable_to_non_nullable
              as bool,
      private: null == private
          ? _self.private
          : private // ignore: cast_nullable_to_non_nullable
              as bool,
      reviewAt: freezed == reviewAt
          ? _self.reviewAt
          : reviewAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      days: null == days
          ? _self.days
          : days // ignore: cast_nullable_to_non_nullable
              as int,
      deletedAt: freezed == deletedAt
          ? _self.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      categoryId: freezed == categoryId
          ? _self.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
mixin _$MeasurementData {
  DateTime get dateFrom;
  DateTime get dateTo;
  num get value;
  String get dataTypeId;

  /// Create a copy of MeasurementData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MeasurementDataCopyWith<MeasurementData> get copyWith =>
      _$MeasurementDataCopyWithImpl<MeasurementData>(
          this as MeasurementData, _$identity);

  /// Serializes this MeasurementData to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MeasurementData &&
            (identical(other.dateFrom, dateFrom) ||
                other.dateFrom == dateFrom) &&
            (identical(other.dateTo, dateTo) || other.dateTo == dateTo) &&
            (identical(other.value, value) || other.value == value) &&
            (identical(other.dataTypeId, dataTypeId) ||
                other.dataTypeId == dataTypeId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, dateFrom, dateTo, value, dataTypeId);

  @override
  String toString() {
    return 'MeasurementData(dateFrom: $dateFrom, dateTo: $dateTo, value: $value, dataTypeId: $dataTypeId)';
  }
}

/// @nodoc
abstract mixin class $MeasurementDataCopyWith<$Res> {
  factory $MeasurementDataCopyWith(
          MeasurementData value, $Res Function(MeasurementData) _then) =
      _$MeasurementDataCopyWithImpl;
  @useResult
  $Res call({DateTime dateFrom, DateTime dateTo, num value, String dataTypeId});
}

/// @nodoc
class _$MeasurementDataCopyWithImpl<$Res>
    implements $MeasurementDataCopyWith<$Res> {
  _$MeasurementDataCopyWithImpl(this._self, this._then);

  final MeasurementData _self;
  final $Res Function(MeasurementData) _then;

  /// Create a copy of MeasurementData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dateFrom = null,
    Object? dateTo = null,
    Object? value = null,
    Object? dataTypeId = null,
  }) {
    return _then(_self.copyWith(
      dateFrom: null == dateFrom
          ? _self.dateFrom
          : dateFrom // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateTo: null == dateTo
          ? _self.dateTo
          : dateTo // ignore: cast_nullable_to_non_nullable
              as DateTime,
      value: null == value
          ? _self.value
          : value // ignore: cast_nullable_to_non_nullable
              as num,
      dataTypeId: null == dataTypeId
          ? _self.dataTypeId
          : dataTypeId // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [MeasurementData].
extension MeasurementDataPatterns on MeasurementData {
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
    TResult Function(_MeasurementData value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MeasurementData() when $default != null:
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
    TResult Function(_MeasurementData value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MeasurementData():
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
    TResult? Function(_MeasurementData value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MeasurementData() when $default != null:
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
            DateTime dateFrom, DateTime dateTo, num value, String dataTypeId)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MeasurementData() when $default != null:
        return $default(
            _that.dateFrom, _that.dateTo, _that.value, _that.dataTypeId);
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
            DateTime dateFrom, DateTime dateTo, num value, String dataTypeId)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MeasurementData():
        return $default(
            _that.dateFrom, _that.dateTo, _that.value, _that.dataTypeId);
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
            DateTime dateFrom, DateTime dateTo, num value, String dataTypeId)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MeasurementData() when $default != null:
        return $default(
            _that.dateFrom, _that.dateTo, _that.value, _that.dataTypeId);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _MeasurementData implements MeasurementData {
  const _MeasurementData(
      {required this.dateFrom,
      required this.dateTo,
      required this.value,
      required this.dataTypeId});
  factory _MeasurementData.fromJson(Map<String, dynamic> json) =>
      _$MeasurementDataFromJson(json);

  @override
  final DateTime dateFrom;
  @override
  final DateTime dateTo;
  @override
  final num value;
  @override
  final String dataTypeId;

  /// Create a copy of MeasurementData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$MeasurementDataCopyWith<_MeasurementData> get copyWith =>
      __$MeasurementDataCopyWithImpl<_MeasurementData>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$MeasurementDataToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _MeasurementData &&
            (identical(other.dateFrom, dateFrom) ||
                other.dateFrom == dateFrom) &&
            (identical(other.dateTo, dateTo) || other.dateTo == dateTo) &&
            (identical(other.value, value) || other.value == value) &&
            (identical(other.dataTypeId, dataTypeId) ||
                other.dataTypeId == dataTypeId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, dateFrom, dateTo, value, dataTypeId);

  @override
  String toString() {
    return 'MeasurementData(dateFrom: $dateFrom, dateTo: $dateTo, value: $value, dataTypeId: $dataTypeId)';
  }
}

/// @nodoc
abstract mixin class _$MeasurementDataCopyWith<$Res>
    implements $MeasurementDataCopyWith<$Res> {
  factory _$MeasurementDataCopyWith(
          _MeasurementData value, $Res Function(_MeasurementData) _then) =
      __$MeasurementDataCopyWithImpl;
  @override
  @useResult
  $Res call({DateTime dateFrom, DateTime dateTo, num value, String dataTypeId});
}

/// @nodoc
class __$MeasurementDataCopyWithImpl<$Res>
    implements _$MeasurementDataCopyWith<$Res> {
  __$MeasurementDataCopyWithImpl(this._self, this._then);

  final _MeasurementData _self;
  final $Res Function(_MeasurementData) _then;

  /// Create a copy of MeasurementData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? dateFrom = null,
    Object? dateTo = null,
    Object? value = null,
    Object? dataTypeId = null,
  }) {
    return _then(_MeasurementData(
      dateFrom: null == dateFrom
          ? _self.dateFrom
          : dateFrom // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateTo: null == dateTo
          ? _self.dateTo
          : dateTo // ignore: cast_nullable_to_non_nullable
              as DateTime,
      value: null == value
          ? _self.value
          : value // ignore: cast_nullable_to_non_nullable
              as num,
      dataTypeId: null == dataTypeId
          ? _self.dataTypeId
          : dataTypeId // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
mixin _$AiResponseData {
  String get model;
  String get systemMessage;
  String get prompt;
  String get thoughts;
  String get response;
  String? get promptId;
  List<AiActionItem>? get suggestedActionItems;
  AiResponseType? get type;
  double? get temperature;

  /// Create a copy of AiResponseData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AiResponseDataCopyWith<AiResponseData> get copyWith =>
      _$AiResponseDataCopyWithImpl<AiResponseData>(
          this as AiResponseData, _$identity);

  /// Serializes this AiResponseData to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AiResponseData &&
            (identical(other.model, model) || other.model == model) &&
            (identical(other.systemMessage, systemMessage) ||
                other.systemMessage == systemMessage) &&
            (identical(other.prompt, prompt) || other.prompt == prompt) &&
            (identical(other.thoughts, thoughts) ||
                other.thoughts == thoughts) &&
            (identical(other.response, response) ||
                other.response == response) &&
            (identical(other.promptId, promptId) ||
                other.promptId == promptId) &&
            const DeepCollectionEquality()
                .equals(other.suggestedActionItems, suggestedActionItems) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.temperature, temperature) ||
                other.temperature == temperature));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      model,
      systemMessage,
      prompt,
      thoughts,
      response,
      promptId,
      const DeepCollectionEquality().hash(suggestedActionItems),
      type,
      temperature);

  @override
  String toString() {
    return 'AiResponseData(model: $model, systemMessage: $systemMessage, prompt: $prompt, thoughts: $thoughts, response: $response, promptId: $promptId, suggestedActionItems: $suggestedActionItems, type: $type, temperature: $temperature)';
  }
}

/// @nodoc
abstract mixin class $AiResponseDataCopyWith<$Res> {
  factory $AiResponseDataCopyWith(
          AiResponseData value, $Res Function(AiResponseData) _then) =
      _$AiResponseDataCopyWithImpl;
  @useResult
  $Res call(
      {String model,
      String systemMessage,
      String prompt,
      String thoughts,
      String response,
      String? promptId,
      List<AiActionItem>? suggestedActionItems,
      AiResponseType? type,
      double? temperature});
}

/// @nodoc
class _$AiResponseDataCopyWithImpl<$Res>
    implements $AiResponseDataCopyWith<$Res> {
  _$AiResponseDataCopyWithImpl(this._self, this._then);

  final AiResponseData _self;
  final $Res Function(AiResponseData) _then;

  /// Create a copy of AiResponseData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? model = null,
    Object? systemMessage = null,
    Object? prompt = null,
    Object? thoughts = null,
    Object? response = null,
    Object? promptId = freezed,
    Object? suggestedActionItems = freezed,
    Object? type = freezed,
    Object? temperature = freezed,
  }) {
    return _then(_self.copyWith(
      model: null == model
          ? _self.model
          : model // ignore: cast_nullable_to_non_nullable
              as String,
      systemMessage: null == systemMessage
          ? _self.systemMessage
          : systemMessage // ignore: cast_nullable_to_non_nullable
              as String,
      prompt: null == prompt
          ? _self.prompt
          : prompt // ignore: cast_nullable_to_non_nullable
              as String,
      thoughts: null == thoughts
          ? _self.thoughts
          : thoughts // ignore: cast_nullable_to_non_nullable
              as String,
      response: null == response
          ? _self.response
          : response // ignore: cast_nullable_to_non_nullable
              as String,
      promptId: freezed == promptId
          ? _self.promptId
          : promptId // ignore: cast_nullable_to_non_nullable
              as String?,
      suggestedActionItems: freezed == suggestedActionItems
          ? _self.suggestedActionItems
          : suggestedActionItems // ignore: cast_nullable_to_non_nullable
              as List<AiActionItem>?,
      type: freezed == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as AiResponseType?,
      temperature: freezed == temperature
          ? _self.temperature
          : temperature // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

/// Adds pattern-matching-related methods to [AiResponseData].
extension AiResponseDataPatterns on AiResponseData {
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
    TResult Function(_AiResponseData value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AiResponseData() when $default != null:
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
    TResult Function(_AiResponseData value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiResponseData():
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
    TResult? Function(_AiResponseData value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiResponseData() when $default != null:
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
            String model,
            String systemMessage,
            String prompt,
            String thoughts,
            String response,
            String? promptId,
            List<AiActionItem>? suggestedActionItems,
            AiResponseType? type,
            double? temperature)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AiResponseData() when $default != null:
        return $default(
            _that.model,
            _that.systemMessage,
            _that.prompt,
            _that.thoughts,
            _that.response,
            _that.promptId,
            _that.suggestedActionItems,
            _that.type,
            _that.temperature);
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
            String model,
            String systemMessage,
            String prompt,
            String thoughts,
            String response,
            String? promptId,
            List<AiActionItem>? suggestedActionItems,
            AiResponseType? type,
            double? temperature)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiResponseData():
        return $default(
            _that.model,
            _that.systemMessage,
            _that.prompt,
            _that.thoughts,
            _that.response,
            _that.promptId,
            _that.suggestedActionItems,
            _that.type,
            _that.temperature);
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
            String model,
            String systemMessage,
            String prompt,
            String thoughts,
            String response,
            String? promptId,
            List<AiActionItem>? suggestedActionItems,
            AiResponseType? type,
            double? temperature)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiResponseData() when $default != null:
        return $default(
            _that.model,
            _that.systemMessage,
            _that.prompt,
            _that.thoughts,
            _that.response,
            _that.promptId,
            _that.suggestedActionItems,
            _that.type,
            _that.temperature);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AiResponseData implements AiResponseData {
  const _AiResponseData(
      {required this.model,
      required this.systemMessage,
      required this.prompt,
      required this.thoughts,
      required this.response,
      this.promptId,
      final List<AiActionItem>? suggestedActionItems,
      this.type,
      this.temperature})
      : _suggestedActionItems = suggestedActionItems;
  factory _AiResponseData.fromJson(Map<String, dynamic> json) =>
      _$AiResponseDataFromJson(json);

  @override
  final String model;
  @override
  final String systemMessage;
  @override
  final String prompt;
  @override
  final String thoughts;
  @override
  final String response;
  @override
  final String? promptId;
  final List<AiActionItem>? _suggestedActionItems;
  @override
  List<AiActionItem>? get suggestedActionItems {
    final value = _suggestedActionItems;
    if (value == null) return null;
    if (_suggestedActionItems is EqualUnmodifiableListView)
      return _suggestedActionItems;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final AiResponseType? type;
  @override
  final double? temperature;

  /// Create a copy of AiResponseData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AiResponseDataCopyWith<_AiResponseData> get copyWith =>
      __$AiResponseDataCopyWithImpl<_AiResponseData>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AiResponseDataToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AiResponseData &&
            (identical(other.model, model) || other.model == model) &&
            (identical(other.systemMessage, systemMessage) ||
                other.systemMessage == systemMessage) &&
            (identical(other.prompt, prompt) || other.prompt == prompt) &&
            (identical(other.thoughts, thoughts) ||
                other.thoughts == thoughts) &&
            (identical(other.response, response) ||
                other.response == response) &&
            (identical(other.promptId, promptId) ||
                other.promptId == promptId) &&
            const DeepCollectionEquality()
                .equals(other._suggestedActionItems, _suggestedActionItems) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.temperature, temperature) ||
                other.temperature == temperature));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      model,
      systemMessage,
      prompt,
      thoughts,
      response,
      promptId,
      const DeepCollectionEquality().hash(_suggestedActionItems),
      type,
      temperature);

  @override
  String toString() {
    return 'AiResponseData(model: $model, systemMessage: $systemMessage, prompt: $prompt, thoughts: $thoughts, response: $response, promptId: $promptId, suggestedActionItems: $suggestedActionItems, type: $type, temperature: $temperature)';
  }
}

/// @nodoc
abstract mixin class _$AiResponseDataCopyWith<$Res>
    implements $AiResponseDataCopyWith<$Res> {
  factory _$AiResponseDataCopyWith(
          _AiResponseData value, $Res Function(_AiResponseData) _then) =
      __$AiResponseDataCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String model,
      String systemMessage,
      String prompt,
      String thoughts,
      String response,
      String? promptId,
      List<AiActionItem>? suggestedActionItems,
      AiResponseType? type,
      double? temperature});
}

/// @nodoc
class __$AiResponseDataCopyWithImpl<$Res>
    implements _$AiResponseDataCopyWith<$Res> {
  __$AiResponseDataCopyWithImpl(this._self, this._then);

  final _AiResponseData _self;
  final $Res Function(_AiResponseData) _then;

  /// Create a copy of AiResponseData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? model = null,
    Object? systemMessage = null,
    Object? prompt = null,
    Object? thoughts = null,
    Object? response = null,
    Object? promptId = freezed,
    Object? suggestedActionItems = freezed,
    Object? type = freezed,
    Object? temperature = freezed,
  }) {
    return _then(_AiResponseData(
      model: null == model
          ? _self.model
          : model // ignore: cast_nullable_to_non_nullable
              as String,
      systemMessage: null == systemMessage
          ? _self.systemMessage
          : systemMessage // ignore: cast_nullable_to_non_nullable
              as String,
      prompt: null == prompt
          ? _self.prompt
          : prompt // ignore: cast_nullable_to_non_nullable
              as String,
      thoughts: null == thoughts
          ? _self.thoughts
          : thoughts // ignore: cast_nullable_to_non_nullable
              as String,
      response: null == response
          ? _self.response
          : response // ignore: cast_nullable_to_non_nullable
              as String,
      promptId: freezed == promptId
          ? _self.promptId
          : promptId // ignore: cast_nullable_to_non_nullable
              as String?,
      suggestedActionItems: freezed == suggestedActionItems
          ? _self._suggestedActionItems
          : suggestedActionItems // ignore: cast_nullable_to_non_nullable
              as List<AiActionItem>?,
      type: freezed == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as AiResponseType?,
      temperature: freezed == temperature
          ? _self.temperature
          : temperature // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

/// @nodoc
mixin _$WorkoutData {
  DateTime get dateFrom;
  DateTime get dateTo;
  String get id;
  String get workoutType;
  num? get energy;
  num? get distance;
  String? get source;

  /// Create a copy of WorkoutData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $WorkoutDataCopyWith<WorkoutData> get copyWith =>
      _$WorkoutDataCopyWithImpl<WorkoutData>(this as WorkoutData, _$identity);

  /// Serializes this WorkoutData to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is WorkoutData &&
            (identical(other.dateFrom, dateFrom) ||
                other.dateFrom == dateFrom) &&
            (identical(other.dateTo, dateTo) || other.dateTo == dateTo) &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.workoutType, workoutType) ||
                other.workoutType == workoutType) &&
            (identical(other.energy, energy) || other.energy == energy) &&
            (identical(other.distance, distance) ||
                other.distance == distance) &&
            (identical(other.source, source) || other.source == source));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, dateFrom, dateTo, id, workoutType, energy, distance, source);

  @override
  String toString() {
    return 'WorkoutData(dateFrom: $dateFrom, dateTo: $dateTo, id: $id, workoutType: $workoutType, energy: $energy, distance: $distance, source: $source)';
  }
}

/// @nodoc
abstract mixin class $WorkoutDataCopyWith<$Res> {
  factory $WorkoutDataCopyWith(
          WorkoutData value, $Res Function(WorkoutData) _then) =
      _$WorkoutDataCopyWithImpl;
  @useResult
  $Res call(
      {DateTime dateFrom,
      DateTime dateTo,
      String id,
      String workoutType,
      num? energy,
      num? distance,
      String? source});
}

/// @nodoc
class _$WorkoutDataCopyWithImpl<$Res> implements $WorkoutDataCopyWith<$Res> {
  _$WorkoutDataCopyWithImpl(this._self, this._then);

  final WorkoutData _self;
  final $Res Function(WorkoutData) _then;

  /// Create a copy of WorkoutData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dateFrom = null,
    Object? dateTo = null,
    Object? id = null,
    Object? workoutType = null,
    Object? energy = freezed,
    Object? distance = freezed,
    Object? source = freezed,
  }) {
    return _then(_self.copyWith(
      dateFrom: null == dateFrom
          ? _self.dateFrom
          : dateFrom // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateTo: null == dateTo
          ? _self.dateTo
          : dateTo // ignore: cast_nullable_to_non_nullable
              as DateTime,
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      workoutType: null == workoutType
          ? _self.workoutType
          : workoutType // ignore: cast_nullable_to_non_nullable
              as String,
      energy: freezed == energy
          ? _self.energy
          : energy // ignore: cast_nullable_to_non_nullable
              as num?,
      distance: freezed == distance
          ? _self.distance
          : distance // ignore: cast_nullable_to_non_nullable
              as num?,
      source: freezed == source
          ? _self.source
          : source // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [WorkoutData].
extension WorkoutDataPatterns on WorkoutData {
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
    TResult Function(_WorkoutData value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _WorkoutData() when $default != null:
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
    TResult Function(_WorkoutData value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WorkoutData():
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
    TResult? Function(_WorkoutData value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WorkoutData() when $default != null:
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
    TResult Function(DateTime dateFrom, DateTime dateTo, String id,
            String workoutType, num? energy, num? distance, String? source)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _WorkoutData() when $default != null:
        return $default(_that.dateFrom, _that.dateTo, _that.id,
            _that.workoutType, _that.energy, _that.distance, _that.source);
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
    TResult Function(DateTime dateFrom, DateTime dateTo, String id,
            String workoutType, num? energy, num? distance, String? source)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WorkoutData():
        return $default(_that.dateFrom, _that.dateTo, _that.id,
            _that.workoutType, _that.energy, _that.distance, _that.source);
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
    TResult? Function(DateTime dateFrom, DateTime dateTo, String id,
            String workoutType, num? energy, num? distance, String? source)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WorkoutData() when $default != null:
        return $default(_that.dateFrom, _that.dateTo, _that.id,
            _that.workoutType, _that.energy, _that.distance, _that.source);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _WorkoutData implements WorkoutData {
  const _WorkoutData(
      {required this.dateFrom,
      required this.dateTo,
      required this.id,
      required this.workoutType,
      required this.energy,
      required this.distance,
      required this.source});
  factory _WorkoutData.fromJson(Map<String, dynamic> json) =>
      _$WorkoutDataFromJson(json);

  @override
  final DateTime dateFrom;
  @override
  final DateTime dateTo;
  @override
  final String id;
  @override
  final String workoutType;
  @override
  final num? energy;
  @override
  final num? distance;
  @override
  final String? source;

  /// Create a copy of WorkoutData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$WorkoutDataCopyWith<_WorkoutData> get copyWith =>
      __$WorkoutDataCopyWithImpl<_WorkoutData>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$WorkoutDataToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _WorkoutData &&
            (identical(other.dateFrom, dateFrom) ||
                other.dateFrom == dateFrom) &&
            (identical(other.dateTo, dateTo) || other.dateTo == dateTo) &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.workoutType, workoutType) ||
                other.workoutType == workoutType) &&
            (identical(other.energy, energy) || other.energy == energy) &&
            (identical(other.distance, distance) ||
                other.distance == distance) &&
            (identical(other.source, source) || other.source == source));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, dateFrom, dateTo, id, workoutType, energy, distance, source);

  @override
  String toString() {
    return 'WorkoutData(dateFrom: $dateFrom, dateTo: $dateTo, id: $id, workoutType: $workoutType, energy: $energy, distance: $distance, source: $source)';
  }
}

/// @nodoc
abstract mixin class _$WorkoutDataCopyWith<$Res>
    implements $WorkoutDataCopyWith<$Res> {
  factory _$WorkoutDataCopyWith(
          _WorkoutData value, $Res Function(_WorkoutData) _then) =
      __$WorkoutDataCopyWithImpl;
  @override
  @useResult
  $Res call(
      {DateTime dateFrom,
      DateTime dateTo,
      String id,
      String workoutType,
      num? energy,
      num? distance,
      String? source});
}

/// @nodoc
class __$WorkoutDataCopyWithImpl<$Res> implements _$WorkoutDataCopyWith<$Res> {
  __$WorkoutDataCopyWithImpl(this._self, this._then);

  final _WorkoutData _self;
  final $Res Function(_WorkoutData) _then;

  /// Create a copy of WorkoutData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? dateFrom = null,
    Object? dateTo = null,
    Object? id = null,
    Object? workoutType = null,
    Object? energy = freezed,
    Object? distance = freezed,
    Object? source = freezed,
  }) {
    return _then(_WorkoutData(
      dateFrom: null == dateFrom
          ? _self.dateFrom
          : dateFrom // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateTo: null == dateTo
          ? _self.dateTo
          : dateTo // ignore: cast_nullable_to_non_nullable
              as DateTime,
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      workoutType: null == workoutType
          ? _self.workoutType
          : workoutType // ignore: cast_nullable_to_non_nullable
              as String,
      energy: freezed == energy
          ? _self.energy
          : energy // ignore: cast_nullable_to_non_nullable
              as num?,
      distance: freezed == distance
          ? _self.distance
          : distance // ignore: cast_nullable_to_non_nullable
              as num?,
      source: freezed == source
          ? _self.source
          : source // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
mixin _$HabitCompletionData {
  DateTime get dateFrom;
  DateTime get dateTo;
  String get habitId;
  HabitCompletionType? get completionType;

  /// Create a copy of HabitCompletionData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HabitCompletionDataCopyWith<HabitCompletionData> get copyWith =>
      _$HabitCompletionDataCopyWithImpl<HabitCompletionData>(
          this as HabitCompletionData, _$identity);

  /// Serializes this HabitCompletionData to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is HabitCompletionData &&
            (identical(other.dateFrom, dateFrom) ||
                other.dateFrom == dateFrom) &&
            (identical(other.dateTo, dateTo) || other.dateTo == dateTo) &&
            (identical(other.habitId, habitId) || other.habitId == habitId) &&
            (identical(other.completionType, completionType) ||
                other.completionType == completionType));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, dateFrom, dateTo, habitId, completionType);

  @override
  String toString() {
    return 'HabitCompletionData(dateFrom: $dateFrom, dateTo: $dateTo, habitId: $habitId, completionType: $completionType)';
  }
}

/// @nodoc
abstract mixin class $HabitCompletionDataCopyWith<$Res> {
  factory $HabitCompletionDataCopyWith(
          HabitCompletionData value, $Res Function(HabitCompletionData) _then) =
      _$HabitCompletionDataCopyWithImpl;
  @useResult
  $Res call(
      {DateTime dateFrom,
      DateTime dateTo,
      String habitId,
      HabitCompletionType? completionType});
}

/// @nodoc
class _$HabitCompletionDataCopyWithImpl<$Res>
    implements $HabitCompletionDataCopyWith<$Res> {
  _$HabitCompletionDataCopyWithImpl(this._self, this._then);

  final HabitCompletionData _self;
  final $Res Function(HabitCompletionData) _then;

  /// Create a copy of HabitCompletionData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dateFrom = null,
    Object? dateTo = null,
    Object? habitId = null,
    Object? completionType = freezed,
  }) {
    return _then(_self.copyWith(
      dateFrom: null == dateFrom
          ? _self.dateFrom
          : dateFrom // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateTo: null == dateTo
          ? _self.dateTo
          : dateTo // ignore: cast_nullable_to_non_nullable
              as DateTime,
      habitId: null == habitId
          ? _self.habitId
          : habitId // ignore: cast_nullable_to_non_nullable
              as String,
      completionType: freezed == completionType
          ? _self.completionType
          : completionType // ignore: cast_nullable_to_non_nullable
              as HabitCompletionType?,
    ));
  }
}

/// Adds pattern-matching-related methods to [HabitCompletionData].
extension HabitCompletionDataPatterns on HabitCompletionData {
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
    TResult Function(_HabitCompletionData value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HabitCompletionData() when $default != null:
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
    TResult Function(_HabitCompletionData value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HabitCompletionData():
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
    TResult? Function(_HabitCompletionData value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HabitCompletionData() when $default != null:
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
    TResult Function(DateTime dateFrom, DateTime dateTo, String habitId,
            HabitCompletionType? completionType)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HabitCompletionData() when $default != null:
        return $default(
            _that.dateFrom, _that.dateTo, _that.habitId, _that.completionType);
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
    TResult Function(DateTime dateFrom, DateTime dateTo, String habitId,
            HabitCompletionType? completionType)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HabitCompletionData():
        return $default(
            _that.dateFrom, _that.dateTo, _that.habitId, _that.completionType);
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
    TResult? Function(DateTime dateFrom, DateTime dateTo, String habitId,
            HabitCompletionType? completionType)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HabitCompletionData() when $default != null:
        return $default(
            _that.dateFrom, _that.dateTo, _that.habitId, _that.completionType);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _HabitCompletionData implements HabitCompletionData {
  const _HabitCompletionData(
      {required this.dateFrom,
      required this.dateTo,
      required this.habitId,
      this.completionType});
  factory _HabitCompletionData.fromJson(Map<String, dynamic> json) =>
      _$HabitCompletionDataFromJson(json);

  @override
  final DateTime dateFrom;
  @override
  final DateTime dateTo;
  @override
  final String habitId;
  @override
  final HabitCompletionType? completionType;

  /// Create a copy of HabitCompletionData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$HabitCompletionDataCopyWith<_HabitCompletionData> get copyWith =>
      __$HabitCompletionDataCopyWithImpl<_HabitCompletionData>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$HabitCompletionDataToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _HabitCompletionData &&
            (identical(other.dateFrom, dateFrom) ||
                other.dateFrom == dateFrom) &&
            (identical(other.dateTo, dateTo) || other.dateTo == dateTo) &&
            (identical(other.habitId, habitId) || other.habitId == habitId) &&
            (identical(other.completionType, completionType) ||
                other.completionType == completionType));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, dateFrom, dateTo, habitId, completionType);

  @override
  String toString() {
    return 'HabitCompletionData(dateFrom: $dateFrom, dateTo: $dateTo, habitId: $habitId, completionType: $completionType)';
  }
}

/// @nodoc
abstract mixin class _$HabitCompletionDataCopyWith<$Res>
    implements $HabitCompletionDataCopyWith<$Res> {
  factory _$HabitCompletionDataCopyWith(_HabitCompletionData value,
          $Res Function(_HabitCompletionData) _then) =
      __$HabitCompletionDataCopyWithImpl;
  @override
  @useResult
  $Res call(
      {DateTime dateFrom,
      DateTime dateTo,
      String habitId,
      HabitCompletionType? completionType});
}

/// @nodoc
class __$HabitCompletionDataCopyWithImpl<$Res>
    implements _$HabitCompletionDataCopyWith<$Res> {
  __$HabitCompletionDataCopyWithImpl(this._self, this._then);

  final _HabitCompletionData _self;
  final $Res Function(_HabitCompletionData) _then;

  /// Create a copy of HabitCompletionData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? dateFrom = null,
    Object? dateTo = null,
    Object? habitId = null,
    Object? completionType = freezed,
  }) {
    return _then(_HabitCompletionData(
      dateFrom: null == dateFrom
          ? _self.dateFrom
          : dateFrom // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateTo: null == dateTo
          ? _self.dateTo
          : dateTo // ignore: cast_nullable_to_non_nullable
              as DateTime,
      habitId: null == habitId
          ? _self.habitId
          : habitId // ignore: cast_nullable_to_non_nullable
              as String,
      completionType: freezed == completionType
          ? _self.completionType
          : completionType // ignore: cast_nullable_to_non_nullable
              as HabitCompletionType?,
    ));
  }
}

DashboardItem _$DashboardItemFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'measurement':
      return DashboardMeasurementItem.fromJson(json);
    case 'healthChart':
      return DashboardHealthItem.fromJson(json);
    case 'workoutChart':
      return DashboardWorkoutItem.fromJson(json);
    case 'habitChart':
      return DashboardHabitItem.fromJson(json);
    case 'surveyChart':
      return DashboardSurveyItem.fromJson(json);
    case 'storyTimeChart':
      return DashboardStoryTimeItem.fromJson(json);
    case 'wildcardStoryTimeChart':
      return WildcardStoryTimeItem.fromJson(json);

    default:
      throw CheckedFromJsonException(json, 'runtimeType', 'DashboardItem',
          'Invalid union type "${json['runtimeType']}"!');
  }
}

/// @nodoc
mixin _$DashboardItem {
  /// Serializes this DashboardItem to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is DashboardItem);
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'DashboardItem()';
  }
}

/// @nodoc
class $DashboardItemCopyWith<$Res> {
  $DashboardItemCopyWith(DashboardItem _, $Res Function(DashboardItem) __);
}

/// Adds pattern-matching-related methods to [DashboardItem].
extension DashboardItemPatterns on DashboardItem {
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
  TResult maybeMap<TResult extends Object?>({
    TResult Function(DashboardMeasurementItem value)? measurement,
    TResult Function(DashboardHealthItem value)? healthChart,
    TResult Function(DashboardWorkoutItem value)? workoutChart,
    TResult Function(DashboardHabitItem value)? habitChart,
    TResult Function(DashboardSurveyItem value)? surveyChart,
    TResult Function(DashboardStoryTimeItem value)? storyTimeChart,
    TResult Function(WildcardStoryTimeItem value)? wildcardStoryTimeChart,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case DashboardMeasurementItem() when measurement != null:
        return measurement(_that);
      case DashboardHealthItem() when healthChart != null:
        return healthChart(_that);
      case DashboardWorkoutItem() when workoutChart != null:
        return workoutChart(_that);
      case DashboardHabitItem() when habitChart != null:
        return habitChart(_that);
      case DashboardSurveyItem() when surveyChart != null:
        return surveyChart(_that);
      case DashboardStoryTimeItem() when storyTimeChart != null:
        return storyTimeChart(_that);
      case WildcardStoryTimeItem() when wildcardStoryTimeChart != null:
        return wildcardStoryTimeChart(_that);
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
  TResult map<TResult extends Object?>({
    required TResult Function(DashboardMeasurementItem value) measurement,
    required TResult Function(DashboardHealthItem value) healthChart,
    required TResult Function(DashboardWorkoutItem value) workoutChart,
    required TResult Function(DashboardHabitItem value) habitChart,
    required TResult Function(DashboardSurveyItem value) surveyChart,
    required TResult Function(DashboardStoryTimeItem value) storyTimeChart,
    required TResult Function(WildcardStoryTimeItem value)
        wildcardStoryTimeChart,
  }) {
    final _that = this;
    switch (_that) {
      case DashboardMeasurementItem():
        return measurement(_that);
      case DashboardHealthItem():
        return healthChart(_that);
      case DashboardWorkoutItem():
        return workoutChart(_that);
      case DashboardHabitItem():
        return habitChart(_that);
      case DashboardSurveyItem():
        return surveyChart(_that);
      case DashboardStoryTimeItem():
        return storyTimeChart(_that);
      case WildcardStoryTimeItem():
        return wildcardStoryTimeChart(_that);
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
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(DashboardMeasurementItem value)? measurement,
    TResult? Function(DashboardHealthItem value)? healthChart,
    TResult? Function(DashboardWorkoutItem value)? workoutChart,
    TResult? Function(DashboardHabitItem value)? habitChart,
    TResult? Function(DashboardSurveyItem value)? surveyChart,
    TResult? Function(DashboardStoryTimeItem value)? storyTimeChart,
    TResult? Function(WildcardStoryTimeItem value)? wildcardStoryTimeChart,
  }) {
    final _that = this;
    switch (_that) {
      case DashboardMeasurementItem() when measurement != null:
        return measurement(_that);
      case DashboardHealthItem() when healthChart != null:
        return healthChart(_that);
      case DashboardWorkoutItem() when workoutChart != null:
        return workoutChart(_that);
      case DashboardHabitItem() when habitChart != null:
        return habitChart(_that);
      case DashboardSurveyItem() when surveyChart != null:
        return surveyChart(_that);
      case DashboardStoryTimeItem() when storyTimeChart != null:
        return storyTimeChart(_that);
      case WildcardStoryTimeItem() when wildcardStoryTimeChart != null:
        return wildcardStoryTimeChart(_that);
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
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, AggregationType? aggregationType)? measurement,
    TResult Function(String color, String healthType)? healthChart,
    TResult Function(String workoutType, String displayName, String color,
            WorkoutValueType valueType)?
        workoutChart,
    TResult Function(String habitId)? habitChart,
    TResult Function(Map<String, String> colorsByScoreKey, String surveyType,
            String surveyName)?
        surveyChart,
    TResult Function(String storyTagId, String color)? storyTimeChart,
    TResult Function(String storySubstring, String color)?
        wildcardStoryTimeChart,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case DashboardMeasurementItem() when measurement != null:
        return measurement(_that.id, _that.aggregationType);
      case DashboardHealthItem() when healthChart != null:
        return healthChart(_that.color, _that.healthType);
      case DashboardWorkoutItem() when workoutChart != null:
        return workoutChart(
            _that.workoutType, _that.displayName, _that.color, _that.valueType);
      case DashboardHabitItem() when habitChart != null:
        return habitChart(_that.habitId);
      case DashboardSurveyItem() when surveyChart != null:
        return surveyChart(
            _that.colorsByScoreKey, _that.surveyType, _that.surveyName);
      case DashboardStoryTimeItem() when storyTimeChart != null:
        return storyTimeChart(_that.storyTagId, _that.color);
      case WildcardStoryTimeItem() when wildcardStoryTimeChart != null:
        return wildcardStoryTimeChart(_that.storySubstring, _that.color);
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
  TResult when<TResult extends Object?>({
    required TResult Function(String id, AggregationType? aggregationType)
        measurement,
    required TResult Function(String color, String healthType) healthChart,
    required TResult Function(String workoutType, String displayName,
            String color, WorkoutValueType valueType)
        workoutChart,
    required TResult Function(String habitId) habitChart,
    required TResult Function(Map<String, String> colorsByScoreKey,
            String surveyType, String surveyName)
        surveyChart,
    required TResult Function(String storyTagId, String color) storyTimeChart,
    required TResult Function(String storySubstring, String color)
        wildcardStoryTimeChart,
  }) {
    final _that = this;
    switch (_that) {
      case DashboardMeasurementItem():
        return measurement(_that.id, _that.aggregationType);
      case DashboardHealthItem():
        return healthChart(_that.color, _that.healthType);
      case DashboardWorkoutItem():
        return workoutChart(
            _that.workoutType, _that.displayName, _that.color, _that.valueType);
      case DashboardHabitItem():
        return habitChart(_that.habitId);
      case DashboardSurveyItem():
        return surveyChart(
            _that.colorsByScoreKey, _that.surveyType, _that.surveyName);
      case DashboardStoryTimeItem():
        return storyTimeChart(_that.storyTagId, _that.color);
      case WildcardStoryTimeItem():
        return wildcardStoryTimeChart(_that.storySubstring, _that.color);
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
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, AggregationType? aggregationType)? measurement,
    TResult? Function(String color, String healthType)? healthChart,
    TResult? Function(String workoutType, String displayName, String color,
            WorkoutValueType valueType)?
        workoutChart,
    TResult? Function(String habitId)? habitChart,
    TResult? Function(Map<String, String> colorsByScoreKey, String surveyType,
            String surveyName)?
        surveyChart,
    TResult? Function(String storyTagId, String color)? storyTimeChart,
    TResult? Function(String storySubstring, String color)?
        wildcardStoryTimeChart,
  }) {
    final _that = this;
    switch (_that) {
      case DashboardMeasurementItem() when measurement != null:
        return measurement(_that.id, _that.aggregationType);
      case DashboardHealthItem() when healthChart != null:
        return healthChart(_that.color, _that.healthType);
      case DashboardWorkoutItem() when workoutChart != null:
        return workoutChart(
            _that.workoutType, _that.displayName, _that.color, _that.valueType);
      case DashboardHabitItem() when habitChart != null:
        return habitChart(_that.habitId);
      case DashboardSurveyItem() when surveyChart != null:
        return surveyChart(
            _that.colorsByScoreKey, _that.surveyType, _that.surveyName);
      case DashboardStoryTimeItem() when storyTimeChart != null:
        return storyTimeChart(_that.storyTagId, _that.color);
      case WildcardStoryTimeItem() when wildcardStoryTimeChart != null:
        return wildcardStoryTimeChart(_that.storySubstring, _that.color);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class DashboardMeasurementItem implements DashboardItem {
  const DashboardMeasurementItem(
      {required this.id, this.aggregationType, final String? $type})
      : $type = $type ?? 'measurement';
  factory DashboardMeasurementItem.fromJson(Map<String, dynamic> json) =>
      _$DashboardMeasurementItemFromJson(json);

  final String id;
  final AggregationType? aggregationType;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DashboardMeasurementItemCopyWith<DashboardMeasurementItem> get copyWith =>
      _$DashboardMeasurementItemCopyWithImpl<DashboardMeasurementItem>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$DashboardMeasurementItemToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DashboardMeasurementItem &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.aggregationType, aggregationType) ||
                other.aggregationType == aggregationType));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, aggregationType);

  @override
  String toString() {
    return 'DashboardItem.measurement(id: $id, aggregationType: $aggregationType)';
  }
}

/// @nodoc
abstract mixin class $DashboardMeasurementItemCopyWith<$Res>
    implements $DashboardItemCopyWith<$Res> {
  factory $DashboardMeasurementItemCopyWith(DashboardMeasurementItem value,
          $Res Function(DashboardMeasurementItem) _then) =
      _$DashboardMeasurementItemCopyWithImpl;
  @useResult
  $Res call({String id, AggregationType? aggregationType});
}

/// @nodoc
class _$DashboardMeasurementItemCopyWithImpl<$Res>
    implements $DashboardMeasurementItemCopyWith<$Res> {
  _$DashboardMeasurementItemCopyWithImpl(this._self, this._then);

  final DashboardMeasurementItem _self;
  final $Res Function(DashboardMeasurementItem) _then;

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? aggregationType = freezed,
  }) {
    return _then(DashboardMeasurementItem(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      aggregationType: freezed == aggregationType
          ? _self.aggregationType
          : aggregationType // ignore: cast_nullable_to_non_nullable
              as AggregationType?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class DashboardHealthItem implements DashboardItem {
  const DashboardHealthItem(
      {required this.color, required this.healthType, final String? $type})
      : $type = $type ?? 'healthChart';
  factory DashboardHealthItem.fromJson(Map<String, dynamic> json) =>
      _$DashboardHealthItemFromJson(json);

  final String color;
  final String healthType;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DashboardHealthItemCopyWith<DashboardHealthItem> get copyWith =>
      _$DashboardHealthItemCopyWithImpl<DashboardHealthItem>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$DashboardHealthItemToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DashboardHealthItem &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.healthType, healthType) ||
                other.healthType == healthType));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, color, healthType);

  @override
  String toString() {
    return 'DashboardItem.healthChart(color: $color, healthType: $healthType)';
  }
}

/// @nodoc
abstract mixin class $DashboardHealthItemCopyWith<$Res>
    implements $DashboardItemCopyWith<$Res> {
  factory $DashboardHealthItemCopyWith(
          DashboardHealthItem value, $Res Function(DashboardHealthItem) _then) =
      _$DashboardHealthItemCopyWithImpl;
  @useResult
  $Res call({String color, String healthType});
}

/// @nodoc
class _$DashboardHealthItemCopyWithImpl<$Res>
    implements $DashboardHealthItemCopyWith<$Res> {
  _$DashboardHealthItemCopyWithImpl(this._self, this._then);

  final DashboardHealthItem _self;
  final $Res Function(DashboardHealthItem) _then;

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? color = null,
    Object? healthType = null,
  }) {
    return _then(DashboardHealthItem(
      color: null == color
          ? _self.color
          : color // ignore: cast_nullable_to_non_nullable
              as String,
      healthType: null == healthType
          ? _self.healthType
          : healthType // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class DashboardWorkoutItem implements DashboardItem {
  const DashboardWorkoutItem(
      {required this.workoutType,
      required this.displayName,
      required this.color,
      required this.valueType,
      final String? $type})
      : $type = $type ?? 'workoutChart';
  factory DashboardWorkoutItem.fromJson(Map<String, dynamic> json) =>
      _$DashboardWorkoutItemFromJson(json);

  final String workoutType;
  final String displayName;
  final String color;
  final WorkoutValueType valueType;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DashboardWorkoutItemCopyWith<DashboardWorkoutItem> get copyWith =>
      _$DashboardWorkoutItemCopyWithImpl<DashboardWorkoutItem>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$DashboardWorkoutItemToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DashboardWorkoutItem &&
            (identical(other.workoutType, workoutType) ||
                other.workoutType == workoutType) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.valueType, valueType) ||
                other.valueType == valueType));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, workoutType, displayName, color, valueType);

  @override
  String toString() {
    return 'DashboardItem.workoutChart(workoutType: $workoutType, displayName: $displayName, color: $color, valueType: $valueType)';
  }
}

/// @nodoc
abstract mixin class $DashboardWorkoutItemCopyWith<$Res>
    implements $DashboardItemCopyWith<$Res> {
  factory $DashboardWorkoutItemCopyWith(DashboardWorkoutItem value,
          $Res Function(DashboardWorkoutItem) _then) =
      _$DashboardWorkoutItemCopyWithImpl;
  @useResult
  $Res call(
      {String workoutType,
      String displayName,
      String color,
      WorkoutValueType valueType});
}

/// @nodoc
class _$DashboardWorkoutItemCopyWithImpl<$Res>
    implements $DashboardWorkoutItemCopyWith<$Res> {
  _$DashboardWorkoutItemCopyWithImpl(this._self, this._then);

  final DashboardWorkoutItem _self;
  final $Res Function(DashboardWorkoutItem) _then;

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? workoutType = null,
    Object? displayName = null,
    Object? color = null,
    Object? valueType = null,
  }) {
    return _then(DashboardWorkoutItem(
      workoutType: null == workoutType
          ? _self.workoutType
          : workoutType // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _self.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      color: null == color
          ? _self.color
          : color // ignore: cast_nullable_to_non_nullable
              as String,
      valueType: null == valueType
          ? _self.valueType
          : valueType // ignore: cast_nullable_to_non_nullable
              as WorkoutValueType,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class DashboardHabitItem implements DashboardItem {
  const DashboardHabitItem({required this.habitId, final String? $type})
      : $type = $type ?? 'habitChart';
  factory DashboardHabitItem.fromJson(Map<String, dynamic> json) =>
      _$DashboardHabitItemFromJson(json);

  final String habitId;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DashboardHabitItemCopyWith<DashboardHabitItem> get copyWith =>
      _$DashboardHabitItemCopyWithImpl<DashboardHabitItem>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$DashboardHabitItemToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DashboardHabitItem &&
            (identical(other.habitId, habitId) || other.habitId == habitId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, habitId);

  @override
  String toString() {
    return 'DashboardItem.habitChart(habitId: $habitId)';
  }
}

/// @nodoc
abstract mixin class $DashboardHabitItemCopyWith<$Res>
    implements $DashboardItemCopyWith<$Res> {
  factory $DashboardHabitItemCopyWith(
          DashboardHabitItem value, $Res Function(DashboardHabitItem) _then) =
      _$DashboardHabitItemCopyWithImpl;
  @useResult
  $Res call({String habitId});
}

/// @nodoc
class _$DashboardHabitItemCopyWithImpl<$Res>
    implements $DashboardHabitItemCopyWith<$Res> {
  _$DashboardHabitItemCopyWithImpl(this._self, this._then);

  final DashboardHabitItem _self;
  final $Res Function(DashboardHabitItem) _then;

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? habitId = null,
  }) {
    return _then(DashboardHabitItem(
      habitId: null == habitId
          ? _self.habitId
          : habitId // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class DashboardSurveyItem implements DashboardItem {
  const DashboardSurveyItem(
      {required final Map<String, String> colorsByScoreKey,
      required this.surveyType,
      required this.surveyName,
      final String? $type})
      : _colorsByScoreKey = colorsByScoreKey,
        $type = $type ?? 'surveyChart';
  factory DashboardSurveyItem.fromJson(Map<String, dynamic> json) =>
      _$DashboardSurveyItemFromJson(json);

  final Map<String, String> _colorsByScoreKey;
  Map<String, String> get colorsByScoreKey {
    if (_colorsByScoreKey is EqualUnmodifiableMapView) return _colorsByScoreKey;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_colorsByScoreKey);
  }

  final String surveyType;
  final String surveyName;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DashboardSurveyItemCopyWith<DashboardSurveyItem> get copyWith =>
      _$DashboardSurveyItemCopyWithImpl<DashboardSurveyItem>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$DashboardSurveyItemToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DashboardSurveyItem &&
            const DeepCollectionEquality()
                .equals(other._colorsByScoreKey, _colorsByScoreKey) &&
            (identical(other.surveyType, surveyType) ||
                other.surveyType == surveyType) &&
            (identical(other.surveyName, surveyName) ||
                other.surveyName == surveyName));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_colorsByScoreKey),
      surveyType,
      surveyName);

  @override
  String toString() {
    return 'DashboardItem.surveyChart(colorsByScoreKey: $colorsByScoreKey, surveyType: $surveyType, surveyName: $surveyName)';
  }
}

/// @nodoc
abstract mixin class $DashboardSurveyItemCopyWith<$Res>
    implements $DashboardItemCopyWith<$Res> {
  factory $DashboardSurveyItemCopyWith(
          DashboardSurveyItem value, $Res Function(DashboardSurveyItem) _then) =
      _$DashboardSurveyItemCopyWithImpl;
  @useResult
  $Res call(
      {Map<String, String> colorsByScoreKey,
      String surveyType,
      String surveyName});
}

/// @nodoc
class _$DashboardSurveyItemCopyWithImpl<$Res>
    implements $DashboardSurveyItemCopyWith<$Res> {
  _$DashboardSurveyItemCopyWithImpl(this._self, this._then);

  final DashboardSurveyItem _self;
  final $Res Function(DashboardSurveyItem) _then;

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? colorsByScoreKey = null,
    Object? surveyType = null,
    Object? surveyName = null,
  }) {
    return _then(DashboardSurveyItem(
      colorsByScoreKey: null == colorsByScoreKey
          ? _self._colorsByScoreKey
          : colorsByScoreKey // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      surveyType: null == surveyType
          ? _self.surveyType
          : surveyType // ignore: cast_nullable_to_non_nullable
              as String,
      surveyName: null == surveyName
          ? _self.surveyName
          : surveyName // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class DashboardStoryTimeItem implements DashboardItem {
  const DashboardStoryTimeItem(
      {required this.storyTagId, required this.color, final String? $type})
      : $type = $type ?? 'storyTimeChart';
  factory DashboardStoryTimeItem.fromJson(Map<String, dynamic> json) =>
      _$DashboardStoryTimeItemFromJson(json);

  final String storyTagId;
  final String color;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DashboardStoryTimeItemCopyWith<DashboardStoryTimeItem> get copyWith =>
      _$DashboardStoryTimeItemCopyWithImpl<DashboardStoryTimeItem>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$DashboardStoryTimeItemToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DashboardStoryTimeItem &&
            (identical(other.storyTagId, storyTagId) ||
                other.storyTagId == storyTagId) &&
            (identical(other.color, color) || other.color == color));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, storyTagId, color);

  @override
  String toString() {
    return 'DashboardItem.storyTimeChart(storyTagId: $storyTagId, color: $color)';
  }
}

/// @nodoc
abstract mixin class $DashboardStoryTimeItemCopyWith<$Res>
    implements $DashboardItemCopyWith<$Res> {
  factory $DashboardStoryTimeItemCopyWith(DashboardStoryTimeItem value,
          $Res Function(DashboardStoryTimeItem) _then) =
      _$DashboardStoryTimeItemCopyWithImpl;
  @useResult
  $Res call({String storyTagId, String color});
}

/// @nodoc
class _$DashboardStoryTimeItemCopyWithImpl<$Res>
    implements $DashboardStoryTimeItemCopyWith<$Res> {
  _$DashboardStoryTimeItemCopyWithImpl(this._self, this._then);

  final DashboardStoryTimeItem _self;
  final $Res Function(DashboardStoryTimeItem) _then;

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? storyTagId = null,
    Object? color = null,
  }) {
    return _then(DashboardStoryTimeItem(
      storyTagId: null == storyTagId
          ? _self.storyTagId
          : storyTagId // ignore: cast_nullable_to_non_nullable
              as String,
      color: null == color
          ? _self.color
          : color // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class WildcardStoryTimeItem implements DashboardItem {
  const WildcardStoryTimeItem(
      {required this.storySubstring, required this.color, final String? $type})
      : $type = $type ?? 'wildcardStoryTimeChart';
  factory WildcardStoryTimeItem.fromJson(Map<String, dynamic> json) =>
      _$WildcardStoryTimeItemFromJson(json);

  final String storySubstring;
  final String color;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $WildcardStoryTimeItemCopyWith<WildcardStoryTimeItem> get copyWith =>
      _$WildcardStoryTimeItemCopyWithImpl<WildcardStoryTimeItem>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$WildcardStoryTimeItemToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is WildcardStoryTimeItem &&
            (identical(other.storySubstring, storySubstring) ||
                other.storySubstring == storySubstring) &&
            (identical(other.color, color) || other.color == color));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, storySubstring, color);

  @override
  String toString() {
    return 'DashboardItem.wildcardStoryTimeChart(storySubstring: $storySubstring, color: $color)';
  }
}

/// @nodoc
abstract mixin class $WildcardStoryTimeItemCopyWith<$Res>
    implements $DashboardItemCopyWith<$Res> {
  factory $WildcardStoryTimeItemCopyWith(WildcardStoryTimeItem value,
          $Res Function(WildcardStoryTimeItem) _then) =
      _$WildcardStoryTimeItemCopyWithImpl;
  @useResult
  $Res call({String storySubstring, String color});
}

/// @nodoc
class _$WildcardStoryTimeItemCopyWithImpl<$Res>
    implements $WildcardStoryTimeItemCopyWith<$Res> {
  _$WildcardStoryTimeItemCopyWithImpl(this._self, this._then);

  final WildcardStoryTimeItem _self;
  final $Res Function(WildcardStoryTimeItem) _then;

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? storySubstring = null,
    Object? color = null,
  }) {
    return _then(WildcardStoryTimeItem(
      storySubstring: null == storySubstring
          ? _self.storySubstring
          : storySubstring // ignore: cast_nullable_to_non_nullable
              as String,
      color: null == color
          ? _self.color
          : color // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

// dart format on
