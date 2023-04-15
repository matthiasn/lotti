// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'entity_definitions.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

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
  int get requiredCompletions => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int requiredCompletions, DateTime? showFrom)
        daily,
    required TResult Function(int requiredCompletions) weekly,
    required TResult Function(int requiredCompletions) monthly,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int requiredCompletions, DateTime? showFrom)? daily,
    TResult? Function(int requiredCompletions)? weekly,
    TResult? Function(int requiredCompletions)? monthly,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int requiredCompletions, DateTime? showFrom)? daily,
    TResult Function(int requiredCompletions)? weekly,
    TResult Function(int requiredCompletions)? monthly,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(DailyHabitSchedule value) daily,
    required TResult Function(WeeklyHabitSchedule value) weekly,
    required TResult Function(MonthlyHabitSchedule value) monthly,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(DailyHabitSchedule value)? daily,
    TResult? Function(WeeklyHabitSchedule value)? weekly,
    TResult? Function(MonthlyHabitSchedule value)? monthly,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(DailyHabitSchedule value)? daily,
    TResult Function(WeeklyHabitSchedule value)? weekly,
    TResult Function(MonthlyHabitSchedule value)? monthly,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $HabitScheduleCopyWith<HabitSchedule> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HabitScheduleCopyWith<$Res> {
  factory $HabitScheduleCopyWith(
          HabitSchedule value, $Res Function(HabitSchedule) then) =
      _$HabitScheduleCopyWithImpl<$Res, HabitSchedule>;
  @useResult
  $Res call({int requiredCompletions});
}

/// @nodoc
class _$HabitScheduleCopyWithImpl<$Res, $Val extends HabitSchedule>
    implements $HabitScheduleCopyWith<$Res> {
  _$HabitScheduleCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? requiredCompletions = null,
  }) {
    return _then(_value.copyWith(
      requiredCompletions: null == requiredCompletions
          ? _value.requiredCompletions
          : requiredCompletions // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DailyHabitScheduleCopyWith<$Res>
    implements $HabitScheduleCopyWith<$Res> {
  factory _$$DailyHabitScheduleCopyWith(_$DailyHabitSchedule value,
          $Res Function(_$DailyHabitSchedule) then) =
      __$$DailyHabitScheduleCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int requiredCompletions, DateTime? showFrom});
}

/// @nodoc
class __$$DailyHabitScheduleCopyWithImpl<$Res>
    extends _$HabitScheduleCopyWithImpl<$Res, _$DailyHabitSchedule>
    implements _$$DailyHabitScheduleCopyWith<$Res> {
  __$$DailyHabitScheduleCopyWithImpl(
      _$DailyHabitSchedule _value, $Res Function(_$DailyHabitSchedule) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? requiredCompletions = null,
    Object? showFrom = freezed,
  }) {
    return _then(_$DailyHabitSchedule(
      requiredCompletions: null == requiredCompletions
          ? _value.requiredCompletions
          : requiredCompletions // ignore: cast_nullable_to_non_nullable
              as int,
      showFrom: freezed == showFrom
          ? _value.showFrom
          : showFrom // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DailyHabitSchedule implements DailyHabitSchedule {
  _$DailyHabitSchedule(
      {required this.requiredCompletions, this.showFrom, final String? $type})
      : $type = $type ?? 'daily';

  factory _$DailyHabitSchedule.fromJson(Map<String, dynamic> json) =>
      _$$DailyHabitScheduleFromJson(json);

  @override
  final int requiredCompletions;
  @override
  final DateTime? showFrom;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'HabitSchedule.daily(requiredCompletions: $requiredCompletions, showFrom: $showFrom)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DailyHabitSchedule &&
            (identical(other.requiredCompletions, requiredCompletions) ||
                other.requiredCompletions == requiredCompletions) &&
            (identical(other.showFrom, showFrom) ||
                other.showFrom == showFrom));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, requiredCompletions, showFrom);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$DailyHabitScheduleCopyWith<_$DailyHabitSchedule> get copyWith =>
      __$$DailyHabitScheduleCopyWithImpl<_$DailyHabitSchedule>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int requiredCompletions, DateTime? showFrom)
        daily,
    required TResult Function(int requiredCompletions) weekly,
    required TResult Function(int requiredCompletions) monthly,
  }) {
    return daily(requiredCompletions, showFrom);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int requiredCompletions, DateTime? showFrom)? daily,
    TResult? Function(int requiredCompletions)? weekly,
    TResult? Function(int requiredCompletions)? monthly,
  }) {
    return daily?.call(requiredCompletions, showFrom);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int requiredCompletions, DateTime? showFrom)? daily,
    TResult Function(int requiredCompletions)? weekly,
    TResult Function(int requiredCompletions)? monthly,
    required TResult orElse(),
  }) {
    if (daily != null) {
      return daily(requiredCompletions, showFrom);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(DailyHabitSchedule value) daily,
    required TResult Function(WeeklyHabitSchedule value) weekly,
    required TResult Function(MonthlyHabitSchedule value) monthly,
  }) {
    return daily(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(DailyHabitSchedule value)? daily,
    TResult? Function(WeeklyHabitSchedule value)? weekly,
    TResult? Function(MonthlyHabitSchedule value)? monthly,
  }) {
    return daily?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(DailyHabitSchedule value)? daily,
    TResult Function(WeeklyHabitSchedule value)? weekly,
    TResult Function(MonthlyHabitSchedule value)? monthly,
    required TResult orElse(),
  }) {
    if (daily != null) {
      return daily(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$DailyHabitScheduleToJson(
      this,
    );
  }
}

abstract class DailyHabitSchedule implements HabitSchedule {
  factory DailyHabitSchedule(
      {required final int requiredCompletions,
      final DateTime? showFrom}) = _$DailyHabitSchedule;

  factory DailyHabitSchedule.fromJson(Map<String, dynamic> json) =
      _$DailyHabitSchedule.fromJson;

  @override
  int get requiredCompletions;
  DateTime? get showFrom;
  @override
  @JsonKey(ignore: true)
  _$$DailyHabitScheduleCopyWith<_$DailyHabitSchedule> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$WeeklyHabitScheduleCopyWith<$Res>
    implements $HabitScheduleCopyWith<$Res> {
  factory _$$WeeklyHabitScheduleCopyWith(_$WeeklyHabitSchedule value,
          $Res Function(_$WeeklyHabitSchedule) then) =
      __$$WeeklyHabitScheduleCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int requiredCompletions});
}

/// @nodoc
class __$$WeeklyHabitScheduleCopyWithImpl<$Res>
    extends _$HabitScheduleCopyWithImpl<$Res, _$WeeklyHabitSchedule>
    implements _$$WeeklyHabitScheduleCopyWith<$Res> {
  __$$WeeklyHabitScheduleCopyWithImpl(
      _$WeeklyHabitSchedule _value, $Res Function(_$WeeklyHabitSchedule) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? requiredCompletions = null,
  }) {
    return _then(_$WeeklyHabitSchedule(
      requiredCompletions: null == requiredCompletions
          ? _value.requiredCompletions
          : requiredCompletions // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$WeeklyHabitSchedule implements WeeklyHabitSchedule {
  _$WeeklyHabitSchedule(
      {required this.requiredCompletions, final String? $type})
      : $type = $type ?? 'weekly';

  factory _$WeeklyHabitSchedule.fromJson(Map<String, dynamic> json) =>
      _$$WeeklyHabitScheduleFromJson(json);

  @override
  final int requiredCompletions;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'HabitSchedule.weekly(requiredCompletions: $requiredCompletions)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WeeklyHabitSchedule &&
            (identical(other.requiredCompletions, requiredCompletions) ||
                other.requiredCompletions == requiredCompletions));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, requiredCompletions);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$WeeklyHabitScheduleCopyWith<_$WeeklyHabitSchedule> get copyWith =>
      __$$WeeklyHabitScheduleCopyWithImpl<_$WeeklyHabitSchedule>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int requiredCompletions, DateTime? showFrom)
        daily,
    required TResult Function(int requiredCompletions) weekly,
    required TResult Function(int requiredCompletions) monthly,
  }) {
    return weekly(requiredCompletions);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int requiredCompletions, DateTime? showFrom)? daily,
    TResult? Function(int requiredCompletions)? weekly,
    TResult? Function(int requiredCompletions)? monthly,
  }) {
    return weekly?.call(requiredCompletions);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int requiredCompletions, DateTime? showFrom)? daily,
    TResult Function(int requiredCompletions)? weekly,
    TResult Function(int requiredCompletions)? monthly,
    required TResult orElse(),
  }) {
    if (weekly != null) {
      return weekly(requiredCompletions);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(DailyHabitSchedule value) daily,
    required TResult Function(WeeklyHabitSchedule value) weekly,
    required TResult Function(MonthlyHabitSchedule value) monthly,
  }) {
    return weekly(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(DailyHabitSchedule value)? daily,
    TResult? Function(WeeklyHabitSchedule value)? weekly,
    TResult? Function(MonthlyHabitSchedule value)? monthly,
  }) {
    return weekly?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(DailyHabitSchedule value)? daily,
    TResult Function(WeeklyHabitSchedule value)? weekly,
    TResult Function(MonthlyHabitSchedule value)? monthly,
    required TResult orElse(),
  }) {
    if (weekly != null) {
      return weekly(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$WeeklyHabitScheduleToJson(
      this,
    );
  }
}

abstract class WeeklyHabitSchedule implements HabitSchedule {
  factory WeeklyHabitSchedule({required final int requiredCompletions}) =
      _$WeeklyHabitSchedule;

  factory WeeklyHabitSchedule.fromJson(Map<String, dynamic> json) =
      _$WeeklyHabitSchedule.fromJson;

  @override
  int get requiredCompletions;
  @override
  @JsonKey(ignore: true)
  _$$WeeklyHabitScheduleCopyWith<_$WeeklyHabitSchedule> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$MonthlyHabitScheduleCopyWith<$Res>
    implements $HabitScheduleCopyWith<$Res> {
  factory _$$MonthlyHabitScheduleCopyWith(_$MonthlyHabitSchedule value,
          $Res Function(_$MonthlyHabitSchedule) then) =
      __$$MonthlyHabitScheduleCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int requiredCompletions});
}

/// @nodoc
class __$$MonthlyHabitScheduleCopyWithImpl<$Res>
    extends _$HabitScheduleCopyWithImpl<$Res, _$MonthlyHabitSchedule>
    implements _$$MonthlyHabitScheduleCopyWith<$Res> {
  __$$MonthlyHabitScheduleCopyWithImpl(_$MonthlyHabitSchedule _value,
      $Res Function(_$MonthlyHabitSchedule) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? requiredCompletions = null,
  }) {
    return _then(_$MonthlyHabitSchedule(
      requiredCompletions: null == requiredCompletions
          ? _value.requiredCompletions
          : requiredCompletions // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MonthlyHabitSchedule implements MonthlyHabitSchedule {
  _$MonthlyHabitSchedule(
      {required this.requiredCompletions, final String? $type})
      : $type = $type ?? 'monthly';

  factory _$MonthlyHabitSchedule.fromJson(Map<String, dynamic> json) =>
      _$$MonthlyHabitScheduleFromJson(json);

  @override
  final int requiredCompletions;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'HabitSchedule.monthly(requiredCompletions: $requiredCompletions)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MonthlyHabitSchedule &&
            (identical(other.requiredCompletions, requiredCompletions) ||
                other.requiredCompletions == requiredCompletions));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, requiredCompletions);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MonthlyHabitScheduleCopyWith<_$MonthlyHabitSchedule> get copyWith =>
      __$$MonthlyHabitScheduleCopyWithImpl<_$MonthlyHabitSchedule>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int requiredCompletions, DateTime? showFrom)
        daily,
    required TResult Function(int requiredCompletions) weekly,
    required TResult Function(int requiredCompletions) monthly,
  }) {
    return monthly(requiredCompletions);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int requiredCompletions, DateTime? showFrom)? daily,
    TResult? Function(int requiredCompletions)? weekly,
    TResult? Function(int requiredCompletions)? monthly,
  }) {
    return monthly?.call(requiredCompletions);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int requiredCompletions, DateTime? showFrom)? daily,
    TResult Function(int requiredCompletions)? weekly,
    TResult Function(int requiredCompletions)? monthly,
    required TResult orElse(),
  }) {
    if (monthly != null) {
      return monthly(requiredCompletions);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(DailyHabitSchedule value) daily,
    required TResult Function(WeeklyHabitSchedule value) weekly,
    required TResult Function(MonthlyHabitSchedule value) monthly,
  }) {
    return monthly(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(DailyHabitSchedule value)? daily,
    TResult? Function(WeeklyHabitSchedule value)? weekly,
    TResult? Function(MonthlyHabitSchedule value)? monthly,
  }) {
    return monthly?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(DailyHabitSchedule value)? daily,
    TResult Function(WeeklyHabitSchedule value)? weekly,
    TResult Function(MonthlyHabitSchedule value)? monthly,
    required TResult orElse(),
  }) {
    if (monthly != null) {
      return monthly(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$MonthlyHabitScheduleToJson(
      this,
    );
  }
}

abstract class MonthlyHabitSchedule implements HabitSchedule {
  factory MonthlyHabitSchedule({required final int requiredCompletions}) =
      _$MonthlyHabitSchedule;

  factory MonthlyHabitSchedule.fromJson(Map<String, dynamic> json) =
      _$MonthlyHabitSchedule.fromJson;

  @override
  int get requiredCompletions;
  @override
  @JsonKey(ignore: true)
  _$$MonthlyHabitScheduleCopyWith<_$MonthlyHabitSchedule> get copyWith =>
      throw _privateConstructorUsedError;
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
  String? get title => throw _privateConstructorUsedError;
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
  }) =>
      throw _privateConstructorUsedError;
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
  }) =>
      throw _privateConstructorUsedError;
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
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(AutoCompleteRuleHealth value) health,
    required TResult Function(AutoCompleteRuleWorkout value) workout,
    required TResult Function(AutoCompleteRuleMeasurable value) measurable,
    required TResult Function(AutoCompleteRuleHabit value) habit,
    required TResult Function(AutoCompleteRuleAnd value) and,
    required TResult Function(AutoCompleteRuleOr value) or,
    required TResult Function(AutoCompleteRuleMultiple value) multiple,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(AutoCompleteRuleHealth value)? health,
    TResult? Function(AutoCompleteRuleWorkout value)? workout,
    TResult? Function(AutoCompleteRuleMeasurable value)? measurable,
    TResult? Function(AutoCompleteRuleHabit value)? habit,
    TResult? Function(AutoCompleteRuleAnd value)? and,
    TResult? Function(AutoCompleteRuleOr value)? or,
    TResult? Function(AutoCompleteRuleMultiple value)? multiple,
  }) =>
      throw _privateConstructorUsedError;
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
  }) =>
      throw _privateConstructorUsedError;
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $AutoCompleteRuleCopyWith<AutoCompleteRule> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AutoCompleteRuleCopyWith<$Res> {
  factory $AutoCompleteRuleCopyWith(
          AutoCompleteRule value, $Res Function(AutoCompleteRule) then) =
      _$AutoCompleteRuleCopyWithImpl<$Res, AutoCompleteRule>;
  @useResult
  $Res call({String? title});
}

/// @nodoc
class _$AutoCompleteRuleCopyWithImpl<$Res, $Val extends AutoCompleteRule>
    implements $AutoCompleteRuleCopyWith<$Res> {
  _$AutoCompleteRuleCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = freezed,
  }) {
    return _then(_value.copyWith(
      title: freezed == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AutoCompleteRuleHealthCopyWith<$Res>
    implements $AutoCompleteRuleCopyWith<$Res> {
  factory _$$AutoCompleteRuleHealthCopyWith(_$AutoCompleteRuleHealth value,
          $Res Function(_$AutoCompleteRuleHealth) then) =
      __$$AutoCompleteRuleHealthCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String dataType, num? minimum, num? maximum, String? title});
}

/// @nodoc
class __$$AutoCompleteRuleHealthCopyWithImpl<$Res>
    extends _$AutoCompleteRuleCopyWithImpl<$Res, _$AutoCompleteRuleHealth>
    implements _$$AutoCompleteRuleHealthCopyWith<$Res> {
  __$$AutoCompleteRuleHealthCopyWithImpl(_$AutoCompleteRuleHealth _value,
      $Res Function(_$AutoCompleteRuleHealth) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dataType = null,
    Object? minimum = freezed,
    Object? maximum = freezed,
    Object? title = freezed,
  }) {
    return _then(_$AutoCompleteRuleHealth(
      dataType: null == dataType
          ? _value.dataType
          : dataType // ignore: cast_nullable_to_non_nullable
              as String,
      minimum: freezed == minimum
          ? _value.minimum
          : minimum // ignore: cast_nullable_to_non_nullable
              as num?,
      maximum: freezed == maximum
          ? _value.maximum
          : maximum // ignore: cast_nullable_to_non_nullable
              as num?,
      title: freezed == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AutoCompleteRuleHealth implements AutoCompleteRuleHealth {
  _$AutoCompleteRuleHealth(
      {required this.dataType,
      this.minimum,
      this.maximum,
      this.title,
      final String? $type})
      : $type = $type ?? 'health';

  factory _$AutoCompleteRuleHealth.fromJson(Map<String, dynamic> json) =>
      _$$AutoCompleteRuleHealthFromJson(json);

  @override
  final String dataType;
  @override
  final num? minimum;
  @override
  final num? maximum;
  @override
  final String? title;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'AutoCompleteRule.health(dataType: $dataType, minimum: $minimum, maximum: $maximum, title: $title)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AutoCompleteRuleHealth &&
            (identical(other.dataType, dataType) ||
                other.dataType == dataType) &&
            (identical(other.minimum, minimum) || other.minimum == minimum) &&
            (identical(other.maximum, maximum) || other.maximum == maximum) &&
            (identical(other.title, title) || other.title == title));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, dataType, minimum, maximum, title);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$AutoCompleteRuleHealthCopyWith<_$AutoCompleteRuleHealth> get copyWith =>
      __$$AutoCompleteRuleHealthCopyWithImpl<_$AutoCompleteRuleHealth>(
          this, _$identity);

  @override
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
    return health(dataType, minimum, maximum, title);
  }

  @override
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
    return health?.call(dataType, minimum, maximum, title);
  }

  @override
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
    if (health != null) {
      return health(dataType, minimum, maximum, title);
    }
    return orElse();
  }

  @override
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
    return health(this);
  }

  @override
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
    return health?.call(this);
  }

  @override
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
    if (health != null) {
      return health(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$AutoCompleteRuleHealthToJson(
      this,
    );
  }
}

abstract class AutoCompleteRuleHealth implements AutoCompleteRule {
  factory AutoCompleteRuleHealth(
      {required final String dataType,
      final num? minimum,
      final num? maximum,
      final String? title}) = _$AutoCompleteRuleHealth;

  factory AutoCompleteRuleHealth.fromJson(Map<String, dynamic> json) =
      _$AutoCompleteRuleHealth.fromJson;

  String get dataType;
  num? get minimum;
  num? get maximum;
  @override
  String? get title;
  @override
  @JsonKey(ignore: true)
  _$$AutoCompleteRuleHealthCopyWith<_$AutoCompleteRuleHealth> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$AutoCompleteRuleWorkoutCopyWith<$Res>
    implements $AutoCompleteRuleCopyWith<$Res> {
  factory _$$AutoCompleteRuleWorkoutCopyWith(_$AutoCompleteRuleWorkout value,
          $Res Function(_$AutoCompleteRuleWorkout) then) =
      __$$AutoCompleteRuleWorkoutCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String dataType, num? minimum, num? maximum, String? title});
}

/// @nodoc
class __$$AutoCompleteRuleWorkoutCopyWithImpl<$Res>
    extends _$AutoCompleteRuleCopyWithImpl<$Res, _$AutoCompleteRuleWorkout>
    implements _$$AutoCompleteRuleWorkoutCopyWith<$Res> {
  __$$AutoCompleteRuleWorkoutCopyWithImpl(_$AutoCompleteRuleWorkout _value,
      $Res Function(_$AutoCompleteRuleWorkout) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dataType = null,
    Object? minimum = freezed,
    Object? maximum = freezed,
    Object? title = freezed,
  }) {
    return _then(_$AutoCompleteRuleWorkout(
      dataType: null == dataType
          ? _value.dataType
          : dataType // ignore: cast_nullable_to_non_nullable
              as String,
      minimum: freezed == minimum
          ? _value.minimum
          : minimum // ignore: cast_nullable_to_non_nullable
              as num?,
      maximum: freezed == maximum
          ? _value.maximum
          : maximum // ignore: cast_nullable_to_non_nullable
              as num?,
      title: freezed == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AutoCompleteRuleWorkout implements AutoCompleteRuleWorkout {
  _$AutoCompleteRuleWorkout(
      {required this.dataType,
      this.minimum,
      this.maximum,
      this.title,
      final String? $type})
      : $type = $type ?? 'workout';

  factory _$AutoCompleteRuleWorkout.fromJson(Map<String, dynamic> json) =>
      _$$AutoCompleteRuleWorkoutFromJson(json);

  @override
  final String dataType;
  @override
  final num? minimum;
  @override
  final num? maximum;
  @override
  final String? title;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'AutoCompleteRule.workout(dataType: $dataType, minimum: $minimum, maximum: $maximum, title: $title)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AutoCompleteRuleWorkout &&
            (identical(other.dataType, dataType) ||
                other.dataType == dataType) &&
            (identical(other.minimum, minimum) || other.minimum == minimum) &&
            (identical(other.maximum, maximum) || other.maximum == maximum) &&
            (identical(other.title, title) || other.title == title));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, dataType, minimum, maximum, title);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$AutoCompleteRuleWorkoutCopyWith<_$AutoCompleteRuleWorkout> get copyWith =>
      __$$AutoCompleteRuleWorkoutCopyWithImpl<_$AutoCompleteRuleWorkout>(
          this, _$identity);

  @override
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
    return workout(dataType, minimum, maximum, title);
  }

  @override
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
    return workout?.call(dataType, minimum, maximum, title);
  }

  @override
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
    if (workout != null) {
      return workout(dataType, minimum, maximum, title);
    }
    return orElse();
  }

  @override
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
    return workout(this);
  }

  @override
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
    return workout?.call(this);
  }

  @override
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
    if (workout != null) {
      return workout(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$AutoCompleteRuleWorkoutToJson(
      this,
    );
  }
}

abstract class AutoCompleteRuleWorkout implements AutoCompleteRule {
  factory AutoCompleteRuleWorkout(
      {required final String dataType,
      final num? minimum,
      final num? maximum,
      final String? title}) = _$AutoCompleteRuleWorkout;

  factory AutoCompleteRuleWorkout.fromJson(Map<String, dynamic> json) =
      _$AutoCompleteRuleWorkout.fromJson;

  String get dataType;
  num? get minimum;
  num? get maximum;
  @override
  String? get title;
  @override
  @JsonKey(ignore: true)
  _$$AutoCompleteRuleWorkoutCopyWith<_$AutoCompleteRuleWorkout> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$AutoCompleteRuleMeasurableCopyWith<$Res>
    implements $AutoCompleteRuleCopyWith<$Res> {
  factory _$$AutoCompleteRuleMeasurableCopyWith(
          _$AutoCompleteRuleMeasurable value,
          $Res Function(_$AutoCompleteRuleMeasurable) then) =
      __$$AutoCompleteRuleMeasurableCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String dataTypeId, num? minimum, num? maximum, String? title});
}

/// @nodoc
class __$$AutoCompleteRuleMeasurableCopyWithImpl<$Res>
    extends _$AutoCompleteRuleCopyWithImpl<$Res, _$AutoCompleteRuleMeasurable>
    implements _$$AutoCompleteRuleMeasurableCopyWith<$Res> {
  __$$AutoCompleteRuleMeasurableCopyWithImpl(
      _$AutoCompleteRuleMeasurable _value,
      $Res Function(_$AutoCompleteRuleMeasurable) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dataTypeId = null,
    Object? minimum = freezed,
    Object? maximum = freezed,
    Object? title = freezed,
  }) {
    return _then(_$AutoCompleteRuleMeasurable(
      dataTypeId: null == dataTypeId
          ? _value.dataTypeId
          : dataTypeId // ignore: cast_nullable_to_non_nullable
              as String,
      minimum: freezed == minimum
          ? _value.minimum
          : minimum // ignore: cast_nullable_to_non_nullable
              as num?,
      maximum: freezed == maximum
          ? _value.maximum
          : maximum // ignore: cast_nullable_to_non_nullable
              as num?,
      title: freezed == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AutoCompleteRuleMeasurable implements AutoCompleteRuleMeasurable {
  _$AutoCompleteRuleMeasurable(
      {required this.dataTypeId,
      this.minimum,
      this.maximum,
      this.title,
      final String? $type})
      : $type = $type ?? 'measurable';

  factory _$AutoCompleteRuleMeasurable.fromJson(Map<String, dynamic> json) =>
      _$$AutoCompleteRuleMeasurableFromJson(json);

  @override
  final String dataTypeId;
  @override
  final num? minimum;
  @override
  final num? maximum;
  @override
  final String? title;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'AutoCompleteRule.measurable(dataTypeId: $dataTypeId, minimum: $minimum, maximum: $maximum, title: $title)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AutoCompleteRuleMeasurable &&
            (identical(other.dataTypeId, dataTypeId) ||
                other.dataTypeId == dataTypeId) &&
            (identical(other.minimum, minimum) || other.minimum == minimum) &&
            (identical(other.maximum, maximum) || other.maximum == maximum) &&
            (identical(other.title, title) || other.title == title));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, dataTypeId, minimum, maximum, title);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$AutoCompleteRuleMeasurableCopyWith<_$AutoCompleteRuleMeasurable>
      get copyWith => __$$AutoCompleteRuleMeasurableCopyWithImpl<
          _$AutoCompleteRuleMeasurable>(this, _$identity);

  @override
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
    return measurable(dataTypeId, minimum, maximum, title);
  }

  @override
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
    return measurable?.call(dataTypeId, minimum, maximum, title);
  }

  @override
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
    if (measurable != null) {
      return measurable(dataTypeId, minimum, maximum, title);
    }
    return orElse();
  }

  @override
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
    return measurable(this);
  }

  @override
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
    return measurable?.call(this);
  }

  @override
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
    if (measurable != null) {
      return measurable(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$AutoCompleteRuleMeasurableToJson(
      this,
    );
  }
}

abstract class AutoCompleteRuleMeasurable implements AutoCompleteRule {
  factory AutoCompleteRuleMeasurable(
      {required final String dataTypeId,
      final num? minimum,
      final num? maximum,
      final String? title}) = _$AutoCompleteRuleMeasurable;

  factory AutoCompleteRuleMeasurable.fromJson(Map<String, dynamic> json) =
      _$AutoCompleteRuleMeasurable.fromJson;

  String get dataTypeId;
  num? get minimum;
  num? get maximum;
  @override
  String? get title;
  @override
  @JsonKey(ignore: true)
  _$$AutoCompleteRuleMeasurableCopyWith<_$AutoCompleteRuleMeasurable>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$AutoCompleteRuleHabitCopyWith<$Res>
    implements $AutoCompleteRuleCopyWith<$Res> {
  factory _$$AutoCompleteRuleHabitCopyWith(_$AutoCompleteRuleHabit value,
          $Res Function(_$AutoCompleteRuleHabit) then) =
      __$$AutoCompleteRuleHabitCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String habitId, String? title});
}

/// @nodoc
class __$$AutoCompleteRuleHabitCopyWithImpl<$Res>
    extends _$AutoCompleteRuleCopyWithImpl<$Res, _$AutoCompleteRuleHabit>
    implements _$$AutoCompleteRuleHabitCopyWith<$Res> {
  __$$AutoCompleteRuleHabitCopyWithImpl(_$AutoCompleteRuleHabit _value,
      $Res Function(_$AutoCompleteRuleHabit) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? habitId = null,
    Object? title = freezed,
  }) {
    return _then(_$AutoCompleteRuleHabit(
      habitId: null == habitId
          ? _value.habitId
          : habitId // ignore: cast_nullable_to_non_nullable
              as String,
      title: freezed == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AutoCompleteRuleHabit implements AutoCompleteRuleHabit {
  _$AutoCompleteRuleHabit(
      {required this.habitId, this.title, final String? $type})
      : $type = $type ?? 'habit';

  factory _$AutoCompleteRuleHabit.fromJson(Map<String, dynamic> json) =>
      _$$AutoCompleteRuleHabitFromJson(json);

  @override
  final String habitId;
  @override
  final String? title;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'AutoCompleteRule.habit(habitId: $habitId, title: $title)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AutoCompleteRuleHabit &&
            (identical(other.habitId, habitId) || other.habitId == habitId) &&
            (identical(other.title, title) || other.title == title));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, habitId, title);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$AutoCompleteRuleHabitCopyWith<_$AutoCompleteRuleHabit> get copyWith =>
      __$$AutoCompleteRuleHabitCopyWithImpl<_$AutoCompleteRuleHabit>(
          this, _$identity);

  @override
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
    return habit(habitId, title);
  }

  @override
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
    return habit?.call(habitId, title);
  }

  @override
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
    if (habit != null) {
      return habit(habitId, title);
    }
    return orElse();
  }

  @override
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
    return habit(this);
  }

  @override
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
    return habit?.call(this);
  }

  @override
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
    if (habit != null) {
      return habit(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$AutoCompleteRuleHabitToJson(
      this,
    );
  }
}

abstract class AutoCompleteRuleHabit implements AutoCompleteRule {
  factory AutoCompleteRuleHabit(
      {required final String habitId,
      final String? title}) = _$AutoCompleteRuleHabit;

  factory AutoCompleteRuleHabit.fromJson(Map<String, dynamic> json) =
      _$AutoCompleteRuleHabit.fromJson;

  String get habitId;
  @override
  String? get title;
  @override
  @JsonKey(ignore: true)
  _$$AutoCompleteRuleHabitCopyWith<_$AutoCompleteRuleHabit> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$AutoCompleteRuleAndCopyWith<$Res>
    implements $AutoCompleteRuleCopyWith<$Res> {
  factory _$$AutoCompleteRuleAndCopyWith(_$AutoCompleteRuleAnd value,
          $Res Function(_$AutoCompleteRuleAnd) then) =
      __$$AutoCompleteRuleAndCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<AutoCompleteRule> rules, String? title});
}

/// @nodoc
class __$$AutoCompleteRuleAndCopyWithImpl<$Res>
    extends _$AutoCompleteRuleCopyWithImpl<$Res, _$AutoCompleteRuleAnd>
    implements _$$AutoCompleteRuleAndCopyWith<$Res> {
  __$$AutoCompleteRuleAndCopyWithImpl(
      _$AutoCompleteRuleAnd _value, $Res Function(_$AutoCompleteRuleAnd) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? rules = null,
    Object? title = freezed,
  }) {
    return _then(_$AutoCompleteRuleAnd(
      rules: null == rules
          ? _value._rules
          : rules // ignore: cast_nullable_to_non_nullable
              as List<AutoCompleteRule>,
      title: freezed == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AutoCompleteRuleAnd implements AutoCompleteRuleAnd {
  _$AutoCompleteRuleAnd(
      {required final List<AutoCompleteRule> rules,
      this.title,
      final String? $type})
      : _rules = rules,
        $type = $type ?? 'and';

  factory _$AutoCompleteRuleAnd.fromJson(Map<String, dynamic> json) =>
      _$$AutoCompleteRuleAndFromJson(json);

  final List<AutoCompleteRule> _rules;
  @override
  List<AutoCompleteRule> get rules {
    if (_rules is EqualUnmodifiableListView) return _rules;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_rules);
  }

  @override
  final String? title;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'AutoCompleteRule.and(rules: $rules, title: $title)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AutoCompleteRuleAnd &&
            const DeepCollectionEquality().equals(other._rules, _rules) &&
            (identical(other.title, title) || other.title == title));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(_rules), title);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$AutoCompleteRuleAndCopyWith<_$AutoCompleteRuleAnd> get copyWith =>
      __$$AutoCompleteRuleAndCopyWithImpl<_$AutoCompleteRuleAnd>(
          this, _$identity);

  @override
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
    return and(rules, title);
  }

  @override
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
    return and?.call(rules, title);
  }

  @override
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
    if (and != null) {
      return and(rules, title);
    }
    return orElse();
  }

  @override
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
    return and(this);
  }

  @override
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
    return and?.call(this);
  }

  @override
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
    if (and != null) {
      return and(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$AutoCompleteRuleAndToJson(
      this,
    );
  }
}

abstract class AutoCompleteRuleAnd implements AutoCompleteRule {
  factory AutoCompleteRuleAnd(
      {required final List<AutoCompleteRule> rules,
      final String? title}) = _$AutoCompleteRuleAnd;

  factory AutoCompleteRuleAnd.fromJson(Map<String, dynamic> json) =
      _$AutoCompleteRuleAnd.fromJson;

  List<AutoCompleteRule> get rules;
  @override
  String? get title;
  @override
  @JsonKey(ignore: true)
  _$$AutoCompleteRuleAndCopyWith<_$AutoCompleteRuleAnd> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$AutoCompleteRuleOrCopyWith<$Res>
    implements $AutoCompleteRuleCopyWith<$Res> {
  factory _$$AutoCompleteRuleOrCopyWith(_$AutoCompleteRuleOr value,
          $Res Function(_$AutoCompleteRuleOr) then) =
      __$$AutoCompleteRuleOrCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<AutoCompleteRule> rules, String? title});
}

/// @nodoc
class __$$AutoCompleteRuleOrCopyWithImpl<$Res>
    extends _$AutoCompleteRuleCopyWithImpl<$Res, _$AutoCompleteRuleOr>
    implements _$$AutoCompleteRuleOrCopyWith<$Res> {
  __$$AutoCompleteRuleOrCopyWithImpl(
      _$AutoCompleteRuleOr _value, $Res Function(_$AutoCompleteRuleOr) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? rules = null,
    Object? title = freezed,
  }) {
    return _then(_$AutoCompleteRuleOr(
      rules: null == rules
          ? _value._rules
          : rules // ignore: cast_nullable_to_non_nullable
              as List<AutoCompleteRule>,
      title: freezed == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AutoCompleteRuleOr implements AutoCompleteRuleOr {
  _$AutoCompleteRuleOr(
      {required final List<AutoCompleteRule> rules,
      this.title,
      final String? $type})
      : _rules = rules,
        $type = $type ?? 'or';

  factory _$AutoCompleteRuleOr.fromJson(Map<String, dynamic> json) =>
      _$$AutoCompleteRuleOrFromJson(json);

  final List<AutoCompleteRule> _rules;
  @override
  List<AutoCompleteRule> get rules {
    if (_rules is EqualUnmodifiableListView) return _rules;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_rules);
  }

  @override
  final String? title;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'AutoCompleteRule.or(rules: $rules, title: $title)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AutoCompleteRuleOr &&
            const DeepCollectionEquality().equals(other._rules, _rules) &&
            (identical(other.title, title) || other.title == title));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(_rules), title);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$AutoCompleteRuleOrCopyWith<_$AutoCompleteRuleOr> get copyWith =>
      __$$AutoCompleteRuleOrCopyWithImpl<_$AutoCompleteRuleOr>(
          this, _$identity);

  @override
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
    return or(rules, title);
  }

  @override
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
    return or?.call(rules, title);
  }

  @override
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
    if (or != null) {
      return or(rules, title);
    }
    return orElse();
  }

  @override
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
    return or(this);
  }

  @override
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
    return or?.call(this);
  }

  @override
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
    if (or != null) {
      return or(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$AutoCompleteRuleOrToJson(
      this,
    );
  }
}

abstract class AutoCompleteRuleOr implements AutoCompleteRule {
  factory AutoCompleteRuleOr(
      {required final List<AutoCompleteRule> rules,
      final String? title}) = _$AutoCompleteRuleOr;

  factory AutoCompleteRuleOr.fromJson(Map<String, dynamic> json) =
      _$AutoCompleteRuleOr.fromJson;

  List<AutoCompleteRule> get rules;
  @override
  String? get title;
  @override
  @JsonKey(ignore: true)
  _$$AutoCompleteRuleOrCopyWith<_$AutoCompleteRuleOr> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$AutoCompleteRuleMultipleCopyWith<$Res>
    implements $AutoCompleteRuleCopyWith<$Res> {
  factory _$$AutoCompleteRuleMultipleCopyWith(_$AutoCompleteRuleMultiple value,
          $Res Function(_$AutoCompleteRuleMultiple) then) =
      __$$AutoCompleteRuleMultipleCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<AutoCompleteRule> rules, int successes, String? title});
}

/// @nodoc
class __$$AutoCompleteRuleMultipleCopyWithImpl<$Res>
    extends _$AutoCompleteRuleCopyWithImpl<$Res, _$AutoCompleteRuleMultiple>
    implements _$$AutoCompleteRuleMultipleCopyWith<$Res> {
  __$$AutoCompleteRuleMultipleCopyWithImpl(_$AutoCompleteRuleMultiple _value,
      $Res Function(_$AutoCompleteRuleMultiple) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? rules = null,
    Object? successes = null,
    Object? title = freezed,
  }) {
    return _then(_$AutoCompleteRuleMultiple(
      rules: null == rules
          ? _value._rules
          : rules // ignore: cast_nullable_to_non_nullable
              as List<AutoCompleteRule>,
      successes: null == successes
          ? _value.successes
          : successes // ignore: cast_nullable_to_non_nullable
              as int,
      title: freezed == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AutoCompleteRuleMultiple implements AutoCompleteRuleMultiple {
  _$AutoCompleteRuleMultiple(
      {required final List<AutoCompleteRule> rules,
      required this.successes,
      this.title,
      final String? $type})
      : _rules = rules,
        $type = $type ?? 'multiple';

  factory _$AutoCompleteRuleMultiple.fromJson(Map<String, dynamic> json) =>
      _$$AutoCompleteRuleMultipleFromJson(json);

  final List<AutoCompleteRule> _rules;
  @override
  List<AutoCompleteRule> get rules {
    if (_rules is EqualUnmodifiableListView) return _rules;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_rules);
  }

  @override
  final int successes;
  @override
  final String? title;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'AutoCompleteRule.multiple(rules: $rules, successes: $successes, title: $title)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AutoCompleteRuleMultiple &&
            const DeepCollectionEquality().equals(other._rules, _rules) &&
            (identical(other.successes, successes) ||
                other.successes == successes) &&
            (identical(other.title, title) || other.title == title));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType,
      const DeepCollectionEquality().hash(_rules), successes, title);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$AutoCompleteRuleMultipleCopyWith<_$AutoCompleteRuleMultiple>
      get copyWith =>
          __$$AutoCompleteRuleMultipleCopyWithImpl<_$AutoCompleteRuleMultiple>(
              this, _$identity);

  @override
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
    return multiple(rules, successes, title);
  }

  @override
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
    return multiple?.call(rules, successes, title);
  }

  @override
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
    if (multiple != null) {
      return multiple(rules, successes, title);
    }
    return orElse();
  }

  @override
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
    return multiple(this);
  }

  @override
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
    return multiple?.call(this);
  }

  @override
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
    if (multiple != null) {
      return multiple(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$AutoCompleteRuleMultipleToJson(
      this,
    );
  }
}

abstract class AutoCompleteRuleMultiple implements AutoCompleteRule {
  factory AutoCompleteRuleMultiple(
      {required final List<AutoCompleteRule> rules,
      required final int successes,
      final String? title}) = _$AutoCompleteRuleMultiple;

  factory AutoCompleteRuleMultiple.fromJson(Map<String, dynamic> json) =
      _$AutoCompleteRuleMultiple.fromJson;

  List<AutoCompleteRule> get rules;
  int get successes;
  @override
  String? get title;
  @override
  @JsonKey(ignore: true)
  _$$AutoCompleteRuleMultipleCopyWith<_$AutoCompleteRuleMultiple>
      get copyWith => throw _privateConstructorUsedError;
}

EntityDefinition _$EntityDefinitionFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'measurableDataType':
      return MeasurableDataType.fromJson(json);
    case 'categoryDefinition':
      return CategoryDefinition.fromJson(json);
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
  String get id => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;
  VectorClock? get vectorClock => throw _privateConstructorUsedError;
  DateTime? get deletedAt => throw _privateConstructorUsedError;
  bool? get private => throw _privateConstructorUsedError;
  String? get categoryId => throw _privateConstructorUsedError;
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
            String? color,
            String? categoryId,
            DateTime? deletedAt)
        categoryDefinition,
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
  }) =>
      throw _privateConstructorUsedError;
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
            String? color,
            String? categoryId,
            DateTime? deletedAt)?
        categoryDefinition,
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
  }) =>
      throw _privateConstructorUsedError;
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
            String? color,
            String? categoryId,
            DateTime? deletedAt)?
        categoryDefinition,
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
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MeasurableDataType value) measurableDataType,
    required TResult Function(CategoryDefinition value) categoryDefinition,
    required TResult Function(HabitDefinition value) habit,
    required TResult Function(DashboardDefinition value) dashboard,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MeasurableDataType value)? measurableDataType,
    TResult? Function(CategoryDefinition value)? categoryDefinition,
    TResult? Function(HabitDefinition value)? habit,
    TResult? Function(DashboardDefinition value)? dashboard,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MeasurableDataType value)? measurableDataType,
    TResult Function(CategoryDefinition value)? categoryDefinition,
    TResult Function(HabitDefinition value)? habit,
    TResult Function(DashboardDefinition value)? dashboard,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $EntityDefinitionCopyWith<EntityDefinition> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EntityDefinitionCopyWith<$Res> {
  factory $EntityDefinitionCopyWith(
          EntityDefinition value, $Res Function(EntityDefinition) then) =
      _$EntityDefinitionCopyWithImpl<$Res, EntityDefinition>;
  @useResult
  $Res call(
      {String id,
      DateTime createdAt,
      DateTime updatedAt,
      VectorClock? vectorClock,
      DateTime? deletedAt,
      bool private,
      String? categoryId});
}

/// @nodoc
class _$EntityDefinitionCopyWithImpl<$Res, $Val extends EntityDefinition>
    implements $EntityDefinitionCopyWith<$Res> {
  _$EntityDefinitionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? vectorClock = freezed,
    Object? deletedAt = freezed,
    Object? private = null,
    Object? categoryId = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      vectorClock: freezed == vectorClock
          ? _value.vectorClock
          : vectorClock // ignore: cast_nullable_to_non_nullable
              as VectorClock?,
      deletedAt: freezed == deletedAt
          ? _value.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      private: null == private
          ? _value.private!
          : private // ignore: cast_nullable_to_non_nullable
              as bool,
      categoryId: freezed == categoryId
          ? _value.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MeasurableDataTypeCopyWith<$Res>
    implements $EntityDefinitionCopyWith<$Res> {
  factory _$$MeasurableDataTypeCopyWith(_$MeasurableDataType value,
          $Res Function(_$MeasurableDataType) then) =
      __$$MeasurableDataTypeCopyWithImpl<$Res>;
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
class __$$MeasurableDataTypeCopyWithImpl<$Res>
    extends _$EntityDefinitionCopyWithImpl<$Res, _$MeasurableDataType>
    implements _$$MeasurableDataTypeCopyWith<$Res> {
  __$$MeasurableDataTypeCopyWithImpl(
      _$MeasurableDataType _value, $Res Function(_$MeasurableDataType) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
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
    return _then(_$MeasurableDataType(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      unitName: null == unitName
          ? _value.unitName
          : unitName // ignore: cast_nullable_to_non_nullable
              as String,
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as int,
      vectorClock: freezed == vectorClock
          ? _value.vectorClock
          : vectorClock // ignore: cast_nullable_to_non_nullable
              as VectorClock?,
      deletedAt: freezed == deletedAt
          ? _value.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      private: freezed == private
          ? _value.private
          : private // ignore: cast_nullable_to_non_nullable
              as bool?,
      favorite: freezed == favorite
          ? _value.favorite
          : favorite // ignore: cast_nullable_to_non_nullable
              as bool?,
      categoryId: freezed == categoryId
          ? _value.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String?,
      aggregationType: freezed == aggregationType
          ? _value.aggregationType
          : aggregationType // ignore: cast_nullable_to_non_nullable
              as AggregationType?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MeasurableDataType implements MeasurableDataType {
  _$MeasurableDataType(
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

  factory _$MeasurableDataType.fromJson(Map<String, dynamic> json) =>
      _$$MeasurableDataTypeFromJson(json);

  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final String displayName;
  @override
  final String description;
  @override
  final String unitName;
  @override
  final int version;
  @override
  final VectorClock? vectorClock;
  @override
  final DateTime? deletedAt;
  @override
  final bool? private;
  @override
  final bool? favorite;
  @override
  final String? categoryId;
  @override
  final AggregationType? aggregationType;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'EntityDefinition.measurableDataType(id: $id, createdAt: $createdAt, updatedAt: $updatedAt, displayName: $displayName, description: $description, unitName: $unitName, version: $version, vectorClock: $vectorClock, deletedAt: $deletedAt, private: $private, favorite: $favorite, categoryId: $categoryId, aggregationType: $aggregationType)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MeasurableDataType &&
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

  @JsonKey(ignore: true)
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

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MeasurableDataTypeCopyWith<_$MeasurableDataType> get copyWith =>
      __$$MeasurableDataTypeCopyWithImpl<_$MeasurableDataType>(
          this, _$identity);

  @override
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
            String? color,
            String? categoryId,
            DateTime? deletedAt)
        categoryDefinition,
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
    return measurableDataType(
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
  }

  @override
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
            String? color,
            String? categoryId,
            DateTime? deletedAt)?
        categoryDefinition,
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
    return measurableDataType?.call(
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
  }

  @override
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
            String? color,
            String? categoryId,
            DateTime? deletedAt)?
        categoryDefinition,
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
    if (measurableDataType != null) {
      return measurableDataType(
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
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MeasurableDataType value) measurableDataType,
    required TResult Function(CategoryDefinition value) categoryDefinition,
    required TResult Function(HabitDefinition value) habit,
    required TResult Function(DashboardDefinition value) dashboard,
  }) {
    return measurableDataType(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MeasurableDataType value)? measurableDataType,
    TResult? Function(CategoryDefinition value)? categoryDefinition,
    TResult? Function(HabitDefinition value)? habit,
    TResult? Function(DashboardDefinition value)? dashboard,
  }) {
    return measurableDataType?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MeasurableDataType value)? measurableDataType,
    TResult Function(CategoryDefinition value)? categoryDefinition,
    TResult Function(HabitDefinition value)? habit,
    TResult Function(DashboardDefinition value)? dashboard,
    required TResult orElse(),
  }) {
    if (measurableDataType != null) {
      return measurableDataType(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$MeasurableDataTypeToJson(
      this,
    );
  }
}

abstract class MeasurableDataType implements EntityDefinition {
  factory MeasurableDataType(
      {required final String id,
      required final DateTime createdAt,
      required final DateTime updatedAt,
      required final String displayName,
      required final String description,
      required final String unitName,
      required final int version,
      required final VectorClock? vectorClock,
      final DateTime? deletedAt,
      final bool? private,
      final bool? favorite,
      final String? categoryId,
      final AggregationType? aggregationType}) = _$MeasurableDataType;

  factory MeasurableDataType.fromJson(Map<String, dynamic> json) =
      _$MeasurableDataType.fromJson;

  @override
  String get id;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  String get displayName;
  String get description;
  String get unitName;
  int get version;
  @override
  VectorClock? get vectorClock;
  @override
  DateTime? get deletedAt;
  @override
  bool? get private;
  bool? get favorite;
  @override
  String? get categoryId;
  AggregationType? get aggregationType;
  @override
  @JsonKey(ignore: true)
  _$$MeasurableDataTypeCopyWith<_$MeasurableDataType> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$CategoryDefinitionCopyWith<$Res>
    implements $EntityDefinitionCopyWith<$Res> {
  factory _$$CategoryDefinitionCopyWith(_$CategoryDefinition value,
          $Res Function(_$CategoryDefinition) then) =
      __$$CategoryDefinitionCopyWithImpl<$Res>;
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
      String? color,
      String? categoryId,
      DateTime? deletedAt});
}

/// @nodoc
class __$$CategoryDefinitionCopyWithImpl<$Res>
    extends _$EntityDefinitionCopyWithImpl<$Res, _$CategoryDefinition>
    implements _$$CategoryDefinitionCopyWith<$Res> {
  __$$CategoryDefinitionCopyWithImpl(
      _$CategoryDefinition _value, $Res Function(_$CategoryDefinition) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? name = null,
    Object? vectorClock = freezed,
    Object? private = null,
    Object? active = null,
    Object? color = freezed,
    Object? categoryId = freezed,
    Object? deletedAt = freezed,
  }) {
    return _then(_$CategoryDefinition(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      vectorClock: freezed == vectorClock
          ? _value.vectorClock
          : vectorClock // ignore: cast_nullable_to_non_nullable
              as VectorClock?,
      private: null == private
          ? _value.private
          : private // ignore: cast_nullable_to_non_nullable
              as bool,
      active: null == active
          ? _value.active
          : active // ignore: cast_nullable_to_non_nullable
              as bool,
      color: freezed == color
          ? _value.color
          : color // ignore: cast_nullable_to_non_nullable
              as String?,
      categoryId: freezed == categoryId
          ? _value.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String?,
      deletedAt: freezed == deletedAt
          ? _value.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CategoryDefinition implements CategoryDefinition {
  _$CategoryDefinition(
      {required this.id,
      required this.createdAt,
      required this.updatedAt,
      required this.name,
      required this.vectorClock,
      required this.private,
      required this.active,
      this.color,
      this.categoryId,
      this.deletedAt,
      final String? $type})
      : $type = $type ?? 'categoryDefinition';

  factory _$CategoryDefinition.fromJson(Map<String, dynamic> json) =>
      _$$CategoryDefinitionFromJson(json);

  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final String name;
  @override
  final VectorClock? vectorClock;
  @override
  final bool private;
  @override
  final bool active;
  @override
  final String? color;
  @override
  final String? categoryId;
  @override
  final DateTime? deletedAt;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'EntityDefinition.categoryDefinition(id: $id, createdAt: $createdAt, updatedAt: $updatedAt, name: $name, vectorClock: $vectorClock, private: $private, active: $active, color: $color, categoryId: $categoryId, deletedAt: $deletedAt)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CategoryDefinition &&
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
            (identical(other.color, color) || other.color == color) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, createdAt, updatedAt, name,
      vectorClock, private, active, color, categoryId, deletedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CategoryDefinitionCopyWith<_$CategoryDefinition> get copyWith =>
      __$$CategoryDefinitionCopyWithImpl<_$CategoryDefinition>(
          this, _$identity);

  @override
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
            String? color,
            String? categoryId,
            DateTime? deletedAt)
        categoryDefinition,
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
    return categoryDefinition(id, createdAt, updatedAt, name, vectorClock,
        private, active, color, categoryId, deletedAt);
  }

  @override
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
            String? color,
            String? categoryId,
            DateTime? deletedAt)?
        categoryDefinition,
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
    return categoryDefinition?.call(id, createdAt, updatedAt, name, vectorClock,
        private, active, color, categoryId, deletedAt);
  }

  @override
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
            String? color,
            String? categoryId,
            DateTime? deletedAt)?
        categoryDefinition,
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
    if (categoryDefinition != null) {
      return categoryDefinition(id, createdAt, updatedAt, name, vectorClock,
          private, active, color, categoryId, deletedAt);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MeasurableDataType value) measurableDataType,
    required TResult Function(CategoryDefinition value) categoryDefinition,
    required TResult Function(HabitDefinition value) habit,
    required TResult Function(DashboardDefinition value) dashboard,
  }) {
    return categoryDefinition(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MeasurableDataType value)? measurableDataType,
    TResult? Function(CategoryDefinition value)? categoryDefinition,
    TResult? Function(HabitDefinition value)? habit,
    TResult? Function(DashboardDefinition value)? dashboard,
  }) {
    return categoryDefinition?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MeasurableDataType value)? measurableDataType,
    TResult Function(CategoryDefinition value)? categoryDefinition,
    TResult Function(HabitDefinition value)? habit,
    TResult Function(DashboardDefinition value)? dashboard,
    required TResult orElse(),
  }) {
    if (categoryDefinition != null) {
      return categoryDefinition(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$CategoryDefinitionToJson(
      this,
    );
  }
}

abstract class CategoryDefinition implements EntityDefinition {
  factory CategoryDefinition(
      {required final String id,
      required final DateTime createdAt,
      required final DateTime updatedAt,
      required final String name,
      required final VectorClock? vectorClock,
      required final bool private,
      required final bool active,
      final String? color,
      final String? categoryId,
      final DateTime? deletedAt}) = _$CategoryDefinition;

  factory CategoryDefinition.fromJson(Map<String, dynamic> json) =
      _$CategoryDefinition.fromJson;

  @override
  String get id;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  String get name;
  @override
  VectorClock? get vectorClock;
  @override
  bool get private;
  bool get active;
  String? get color;
  @override
  String? get categoryId;
  @override
  DateTime? get deletedAt;
  @override
  @JsonKey(ignore: true)
  _$$CategoryDefinitionCopyWith<_$CategoryDefinition> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$HabitDefinitionCopyWith<$Res>
    implements $EntityDefinitionCopyWith<$Res> {
  factory _$$HabitDefinitionCopyWith(
          _$HabitDefinition value, $Res Function(_$HabitDefinition) then) =
      __$$HabitDefinitionCopyWithImpl<$Res>;
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
class __$$HabitDefinitionCopyWithImpl<$Res>
    extends _$EntityDefinitionCopyWithImpl<$Res, _$HabitDefinition>
    implements _$$HabitDefinitionCopyWith<$Res> {
  __$$HabitDefinitionCopyWithImpl(
      _$HabitDefinition _value, $Res Function(_$HabitDefinition) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
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
    return _then(_$HabitDefinition(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      habitSchedule: null == habitSchedule
          ? _value.habitSchedule
          : habitSchedule // ignore: cast_nullable_to_non_nullable
              as HabitSchedule,
      vectorClock: freezed == vectorClock
          ? _value.vectorClock
          : vectorClock // ignore: cast_nullable_to_non_nullable
              as VectorClock?,
      active: null == active
          ? _value.active
          : active // ignore: cast_nullable_to_non_nullable
              as bool,
      private: null == private
          ? _value.private
          : private // ignore: cast_nullable_to_non_nullable
              as bool,
      autoCompleteRule: freezed == autoCompleteRule
          ? _value.autoCompleteRule
          : autoCompleteRule // ignore: cast_nullable_to_non_nullable
              as AutoCompleteRule?,
      version: freezed == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as String?,
      activeFrom: freezed == activeFrom
          ? _value.activeFrom
          : activeFrom // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      activeUntil: freezed == activeUntil
          ? _value.activeUntil
          : activeUntil // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      deletedAt: freezed == deletedAt
          ? _value.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      defaultStoryId: freezed == defaultStoryId
          ? _value.defaultStoryId
          : defaultStoryId // ignore: cast_nullable_to_non_nullable
              as String?,
      categoryId: freezed == categoryId
          ? _value.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String?,
      dashboardId: freezed == dashboardId
          ? _value.dashboardId
          : dashboardId // ignore: cast_nullable_to_non_nullable
              as String?,
      priority: freezed == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }

  @override
  @pragma('vm:prefer-inline')
  $HabitScheduleCopyWith<$Res> get habitSchedule {
    return $HabitScheduleCopyWith<$Res>(_value.habitSchedule, (value) {
      return _then(_value.copyWith(habitSchedule: value));
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $AutoCompleteRuleCopyWith<$Res>? get autoCompleteRule {
    if (_value.autoCompleteRule == null) {
      return null;
    }

    return $AutoCompleteRuleCopyWith<$Res>(_value.autoCompleteRule!, (value) {
      return _then(_value.copyWith(autoCompleteRule: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _$HabitDefinition implements HabitDefinition {
  _$HabitDefinition(
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

  factory _$HabitDefinition.fromJson(Map<String, dynamic> json) =>
      _$$HabitDefinitionFromJson(json);

  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final String name;
  @override
  final String description;
  @override
  final HabitSchedule habitSchedule;
  @override
  final VectorClock? vectorClock;
  @override
  final bool active;
  @override
  final bool private;
  @override
  final AutoCompleteRule? autoCompleteRule;
  @override
  final String? version;
  @override
  final DateTime? activeFrom;
  @override
  final DateTime? activeUntil;
  @override
  final DateTime? deletedAt;
  @override
  final String? defaultStoryId;
  @override
  final String? categoryId;
  @override
  final String? dashboardId;
  @override
  final bool? priority;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'EntityDefinition.habit(id: $id, createdAt: $createdAt, updatedAt: $updatedAt, name: $name, description: $description, habitSchedule: $habitSchedule, vectorClock: $vectorClock, active: $active, private: $private, autoCompleteRule: $autoCompleteRule, version: $version, activeFrom: $activeFrom, activeUntil: $activeUntil, deletedAt: $deletedAt, defaultStoryId: $defaultStoryId, categoryId: $categoryId, dashboardId: $dashboardId, priority: $priority)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HabitDefinition &&
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

  @JsonKey(ignore: true)
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

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$HabitDefinitionCopyWith<_$HabitDefinition> get copyWith =>
      __$$HabitDefinitionCopyWithImpl<_$HabitDefinition>(this, _$identity);

  @override
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
            String? color,
            String? categoryId,
            DateTime? deletedAt)
        categoryDefinition,
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
    return habit(
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
  }

  @override
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
            String? color,
            String? categoryId,
            DateTime? deletedAt)?
        categoryDefinition,
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
    return habit?.call(
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
  }

  @override
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
            String? color,
            String? categoryId,
            DateTime? deletedAt)?
        categoryDefinition,
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
    if (habit != null) {
      return habit(
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
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MeasurableDataType value) measurableDataType,
    required TResult Function(CategoryDefinition value) categoryDefinition,
    required TResult Function(HabitDefinition value) habit,
    required TResult Function(DashboardDefinition value) dashboard,
  }) {
    return habit(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MeasurableDataType value)? measurableDataType,
    TResult? Function(CategoryDefinition value)? categoryDefinition,
    TResult? Function(HabitDefinition value)? habit,
    TResult? Function(DashboardDefinition value)? dashboard,
  }) {
    return habit?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MeasurableDataType value)? measurableDataType,
    TResult Function(CategoryDefinition value)? categoryDefinition,
    TResult Function(HabitDefinition value)? habit,
    TResult Function(DashboardDefinition value)? dashboard,
    required TResult orElse(),
  }) {
    if (habit != null) {
      return habit(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$HabitDefinitionToJson(
      this,
    );
  }
}

abstract class HabitDefinition implements EntityDefinition {
  factory HabitDefinition(
      {required final String id,
      required final DateTime createdAt,
      required final DateTime updatedAt,
      required final String name,
      required final String description,
      required final HabitSchedule habitSchedule,
      required final VectorClock? vectorClock,
      required final bool active,
      required final bool private,
      final AutoCompleteRule? autoCompleteRule,
      final String? version,
      final DateTime? activeFrom,
      final DateTime? activeUntil,
      final DateTime? deletedAt,
      final String? defaultStoryId,
      final String? categoryId,
      final String? dashboardId,
      final bool? priority}) = _$HabitDefinition;

  factory HabitDefinition.fromJson(Map<String, dynamic> json) =
      _$HabitDefinition.fromJson;

  @override
  String get id;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  String get name;
  String get description;
  HabitSchedule get habitSchedule;
  @override
  VectorClock? get vectorClock;
  bool get active;
  @override
  bool get private;
  AutoCompleteRule? get autoCompleteRule;
  String? get version;
  DateTime? get activeFrom;
  DateTime? get activeUntil;
  @override
  DateTime? get deletedAt;
  String? get defaultStoryId;
  @override
  String? get categoryId;
  String? get dashboardId;
  bool? get priority;
  @override
  @JsonKey(ignore: true)
  _$$HabitDefinitionCopyWith<_$HabitDefinition> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$DashboardDefinitionCopyWith<$Res>
    implements $EntityDefinitionCopyWith<$Res> {
  factory _$$DashboardDefinitionCopyWith(_$DashboardDefinition value,
          $Res Function(_$DashboardDefinition) then) =
      __$$DashboardDefinitionCopyWithImpl<$Res>;
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
class __$$DashboardDefinitionCopyWithImpl<$Res>
    extends _$EntityDefinitionCopyWithImpl<$Res, _$DashboardDefinition>
    implements _$$DashboardDefinitionCopyWith<$Res> {
  __$$DashboardDefinitionCopyWithImpl(
      _$DashboardDefinition _value, $Res Function(_$DashboardDefinition) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
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
    return _then(_$DashboardDefinition(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      lastReviewed: null == lastReviewed
          ? _value.lastReviewed
          : lastReviewed // ignore: cast_nullable_to_non_nullable
              as DateTime,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      items: null == items
          ? _value._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<DashboardItem>,
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as String,
      vectorClock: freezed == vectorClock
          ? _value.vectorClock
          : vectorClock // ignore: cast_nullable_to_non_nullable
              as VectorClock?,
      active: null == active
          ? _value.active
          : active // ignore: cast_nullable_to_non_nullable
              as bool,
      private: null == private
          ? _value.private
          : private // ignore: cast_nullable_to_non_nullable
              as bool,
      reviewAt: freezed == reviewAt
          ? _value.reviewAt
          : reviewAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      days: null == days
          ? _value.days
          : days // ignore: cast_nullable_to_non_nullable
              as int,
      deletedAt: freezed == deletedAt
          ? _value.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      categoryId: freezed == categoryId
          ? _value.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DashboardDefinition implements DashboardDefinition {
  _$DashboardDefinition(
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

  factory _$DashboardDefinition.fromJson(Map<String, dynamic> json) =>
      _$$DashboardDefinitionFromJson(json);

  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final DateTime lastReviewed;
  @override
  final String name;
  @override
  final String description;
  final List<DashboardItem> _items;
  @override
  List<DashboardItem> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  final String version;
  @override
  final VectorClock? vectorClock;
  @override
  final bool active;
  @override
  final bool private;
  @override
  final DateTime? reviewAt;
  @override
  @JsonKey()
  final int days;
  @override
  final DateTime? deletedAt;
  @override
  final String? categoryId;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'EntityDefinition.dashboard(id: $id, createdAt: $createdAt, updatedAt: $updatedAt, lastReviewed: $lastReviewed, name: $name, description: $description, items: $items, version: $version, vectorClock: $vectorClock, active: $active, private: $private, reviewAt: $reviewAt, days: $days, deletedAt: $deletedAt, categoryId: $categoryId)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DashboardDefinition &&
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

  @JsonKey(ignore: true)
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

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$DashboardDefinitionCopyWith<_$DashboardDefinition> get copyWith =>
      __$$DashboardDefinitionCopyWithImpl<_$DashboardDefinition>(
          this, _$identity);

  @override
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
            String? color,
            String? categoryId,
            DateTime? deletedAt)
        categoryDefinition,
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
    return dashboard(
        id,
        createdAt,
        updatedAt,
        lastReviewed,
        name,
        description,
        items,
        version,
        vectorClock,
        active,
        private,
        reviewAt,
        days,
        deletedAt,
        categoryId);
  }

  @override
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
            String? color,
            String? categoryId,
            DateTime? deletedAt)?
        categoryDefinition,
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
    return dashboard?.call(
        id,
        createdAt,
        updatedAt,
        lastReviewed,
        name,
        description,
        items,
        version,
        vectorClock,
        active,
        private,
        reviewAt,
        days,
        deletedAt,
        categoryId);
  }

  @override
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
            String? color,
            String? categoryId,
            DateTime? deletedAt)?
        categoryDefinition,
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
    if (dashboard != null) {
      return dashboard(
          id,
          createdAt,
          updatedAt,
          lastReviewed,
          name,
          description,
          items,
          version,
          vectorClock,
          active,
          private,
          reviewAt,
          days,
          deletedAt,
          categoryId);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MeasurableDataType value) measurableDataType,
    required TResult Function(CategoryDefinition value) categoryDefinition,
    required TResult Function(HabitDefinition value) habit,
    required TResult Function(DashboardDefinition value) dashboard,
  }) {
    return dashboard(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MeasurableDataType value)? measurableDataType,
    TResult? Function(CategoryDefinition value)? categoryDefinition,
    TResult? Function(HabitDefinition value)? habit,
    TResult? Function(DashboardDefinition value)? dashboard,
  }) {
    return dashboard?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MeasurableDataType value)? measurableDataType,
    TResult Function(CategoryDefinition value)? categoryDefinition,
    TResult Function(HabitDefinition value)? habit,
    TResult Function(DashboardDefinition value)? dashboard,
    required TResult orElse(),
  }) {
    if (dashboard != null) {
      return dashboard(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$DashboardDefinitionToJson(
      this,
    );
  }
}

abstract class DashboardDefinition implements EntityDefinition {
  factory DashboardDefinition(
      {required final String id,
      required final DateTime createdAt,
      required final DateTime updatedAt,
      required final DateTime lastReviewed,
      required final String name,
      required final String description,
      required final List<DashboardItem> items,
      required final String version,
      required final VectorClock? vectorClock,
      required final bool active,
      required final bool private,
      final DateTime? reviewAt,
      final int days,
      final DateTime? deletedAt,
      final String? categoryId}) = _$DashboardDefinition;

  factory DashboardDefinition.fromJson(Map<String, dynamic> json) =
      _$DashboardDefinition.fromJson;

  @override
  String get id;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  DateTime get lastReviewed;
  String get name;
  String get description;
  List<DashboardItem> get items;
  String get version;
  @override
  VectorClock? get vectorClock;
  bool get active;
  @override
  bool get private;
  DateTime? get reviewAt;
  int get days;
  @override
  DateTime? get deletedAt;
  @override
  String? get categoryId;
  @override
  @JsonKey(ignore: true)
  _$$DashboardDefinitionCopyWith<_$DashboardDefinition> get copyWith =>
      throw _privateConstructorUsedError;
}

MeasurementData _$MeasurementDataFromJson(Map<String, dynamic> json) {
  return _MeasurementData.fromJson(json);
}

/// @nodoc
mixin _$MeasurementData {
  DateTime get dateFrom => throw _privateConstructorUsedError;
  DateTime get dateTo => throw _privateConstructorUsedError;
  num get value => throw _privateConstructorUsedError;
  String get dataTypeId => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $MeasurementDataCopyWith<MeasurementData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MeasurementDataCopyWith<$Res> {
  factory $MeasurementDataCopyWith(
          MeasurementData value, $Res Function(MeasurementData) then) =
      _$MeasurementDataCopyWithImpl<$Res, MeasurementData>;
  @useResult
  $Res call({DateTime dateFrom, DateTime dateTo, num value, String dataTypeId});
}

/// @nodoc
class _$MeasurementDataCopyWithImpl<$Res, $Val extends MeasurementData>
    implements $MeasurementDataCopyWith<$Res> {
  _$MeasurementDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dateFrom = null,
    Object? dateTo = null,
    Object? value = null,
    Object? dataTypeId = null,
  }) {
    return _then(_value.copyWith(
      dateFrom: null == dateFrom
          ? _value.dateFrom
          : dateFrom // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateTo: null == dateTo
          ? _value.dateTo
          : dateTo // ignore: cast_nullable_to_non_nullable
              as DateTime,
      value: null == value
          ? _value.value
          : value // ignore: cast_nullable_to_non_nullable
              as num,
      dataTypeId: null == dataTypeId
          ? _value.dataTypeId
          : dataTypeId // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_MeasurementDataCopyWith<$Res>
    implements $MeasurementDataCopyWith<$Res> {
  factory _$$_MeasurementDataCopyWith(
          _$_MeasurementData value, $Res Function(_$_MeasurementData) then) =
      __$$_MeasurementDataCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({DateTime dateFrom, DateTime dateTo, num value, String dataTypeId});
}

/// @nodoc
class __$$_MeasurementDataCopyWithImpl<$Res>
    extends _$MeasurementDataCopyWithImpl<$Res, _$_MeasurementData>
    implements _$$_MeasurementDataCopyWith<$Res> {
  __$$_MeasurementDataCopyWithImpl(
      _$_MeasurementData _value, $Res Function(_$_MeasurementData) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dateFrom = null,
    Object? dateTo = null,
    Object? value = null,
    Object? dataTypeId = null,
  }) {
    return _then(_$_MeasurementData(
      dateFrom: null == dateFrom
          ? _value.dateFrom
          : dateFrom // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateTo: null == dateTo
          ? _value.dateTo
          : dateTo // ignore: cast_nullable_to_non_nullable
              as DateTime,
      value: null == value
          ? _value.value
          : value // ignore: cast_nullable_to_non_nullable
              as num,
      dataTypeId: null == dataTypeId
          ? _value.dataTypeId
          : dataTypeId // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$_MeasurementData implements _MeasurementData {
  _$_MeasurementData(
      {required this.dateFrom,
      required this.dateTo,
      required this.value,
      required this.dataTypeId});

  factory _$_MeasurementData.fromJson(Map<String, dynamic> json) =>
      _$$_MeasurementDataFromJson(json);

  @override
  final DateTime dateFrom;
  @override
  final DateTime dateTo;
  @override
  final num value;
  @override
  final String dataTypeId;

  @override
  String toString() {
    return 'MeasurementData(dateFrom: $dateFrom, dateTo: $dateTo, value: $value, dataTypeId: $dataTypeId)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_MeasurementData &&
            (identical(other.dateFrom, dateFrom) ||
                other.dateFrom == dateFrom) &&
            (identical(other.dateTo, dateTo) || other.dateTo == dateTo) &&
            (identical(other.value, value) || other.value == value) &&
            (identical(other.dataTypeId, dataTypeId) ||
                other.dataTypeId == dataTypeId));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, dateFrom, dateTo, value, dataTypeId);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_MeasurementDataCopyWith<_$_MeasurementData> get copyWith =>
      __$$_MeasurementDataCopyWithImpl<_$_MeasurementData>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$_MeasurementDataToJson(
      this,
    );
  }
}

abstract class _MeasurementData implements MeasurementData {
  factory _MeasurementData(
      {required final DateTime dateFrom,
      required final DateTime dateTo,
      required final num value,
      required final String dataTypeId}) = _$_MeasurementData;

  factory _MeasurementData.fromJson(Map<String, dynamic> json) =
      _$_MeasurementData.fromJson;

  @override
  DateTime get dateFrom;
  @override
  DateTime get dateTo;
  @override
  num get value;
  @override
  String get dataTypeId;
  @override
  @JsonKey(ignore: true)
  _$$_MeasurementDataCopyWith<_$_MeasurementData> get copyWith =>
      throw _privateConstructorUsedError;
}

WorkoutData _$WorkoutDataFromJson(Map<String, dynamic> json) {
  return _WorkoutData.fromJson(json);
}

/// @nodoc
mixin _$WorkoutData {
  DateTime get dateFrom => throw _privateConstructorUsedError;
  DateTime get dateTo => throw _privateConstructorUsedError;
  String get id => throw _privateConstructorUsedError;
  String get workoutType => throw _privateConstructorUsedError;
  num? get energy => throw _privateConstructorUsedError;
  num? get distance => throw _privateConstructorUsedError;
  String? get source => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $WorkoutDataCopyWith<WorkoutData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WorkoutDataCopyWith<$Res> {
  factory $WorkoutDataCopyWith(
          WorkoutData value, $Res Function(WorkoutData) then) =
      _$WorkoutDataCopyWithImpl<$Res, WorkoutData>;
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
class _$WorkoutDataCopyWithImpl<$Res, $Val extends WorkoutData>
    implements $WorkoutDataCopyWith<$Res> {
  _$WorkoutDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

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
    return _then(_value.copyWith(
      dateFrom: null == dateFrom
          ? _value.dateFrom
          : dateFrom // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateTo: null == dateTo
          ? _value.dateTo
          : dateTo // ignore: cast_nullable_to_non_nullable
              as DateTime,
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      workoutType: null == workoutType
          ? _value.workoutType
          : workoutType // ignore: cast_nullable_to_non_nullable
              as String,
      energy: freezed == energy
          ? _value.energy
          : energy // ignore: cast_nullable_to_non_nullable
              as num?,
      distance: freezed == distance
          ? _value.distance
          : distance // ignore: cast_nullable_to_non_nullable
              as num?,
      source: freezed == source
          ? _value.source
          : source // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_WorkoutDataCopyWith<$Res>
    implements $WorkoutDataCopyWith<$Res> {
  factory _$$_WorkoutDataCopyWith(
          _$_WorkoutData value, $Res Function(_$_WorkoutData) then) =
      __$$_WorkoutDataCopyWithImpl<$Res>;
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
class __$$_WorkoutDataCopyWithImpl<$Res>
    extends _$WorkoutDataCopyWithImpl<$Res, _$_WorkoutData>
    implements _$$_WorkoutDataCopyWith<$Res> {
  __$$_WorkoutDataCopyWithImpl(
      _$_WorkoutData _value, $Res Function(_$_WorkoutData) _then)
      : super(_value, _then);

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
    return _then(_$_WorkoutData(
      dateFrom: null == dateFrom
          ? _value.dateFrom
          : dateFrom // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateTo: null == dateTo
          ? _value.dateTo
          : dateTo // ignore: cast_nullable_to_non_nullable
              as DateTime,
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      workoutType: null == workoutType
          ? _value.workoutType
          : workoutType // ignore: cast_nullable_to_non_nullable
              as String,
      energy: freezed == energy
          ? _value.energy
          : energy // ignore: cast_nullable_to_non_nullable
              as num?,
      distance: freezed == distance
          ? _value.distance
          : distance // ignore: cast_nullable_to_non_nullable
              as num?,
      source: freezed == source
          ? _value.source
          : source // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$_WorkoutData implements _WorkoutData {
  _$_WorkoutData(
      {required this.dateFrom,
      required this.dateTo,
      required this.id,
      required this.workoutType,
      required this.energy,
      required this.distance,
      required this.source});

  factory _$_WorkoutData.fromJson(Map<String, dynamic> json) =>
      _$$_WorkoutDataFromJson(json);

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

  @override
  String toString() {
    return 'WorkoutData(dateFrom: $dateFrom, dateTo: $dateTo, id: $id, workoutType: $workoutType, energy: $energy, distance: $distance, source: $source)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_WorkoutData &&
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

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType, dateFrom, dateTo, id, workoutType, energy, distance, source);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_WorkoutDataCopyWith<_$_WorkoutData> get copyWith =>
      __$$_WorkoutDataCopyWithImpl<_$_WorkoutData>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$_WorkoutDataToJson(
      this,
    );
  }
}

abstract class _WorkoutData implements WorkoutData {
  factory _WorkoutData(
      {required final DateTime dateFrom,
      required final DateTime dateTo,
      required final String id,
      required final String workoutType,
      required final num? energy,
      required final num? distance,
      required final String? source}) = _$_WorkoutData;

  factory _WorkoutData.fromJson(Map<String, dynamic> json) =
      _$_WorkoutData.fromJson;

  @override
  DateTime get dateFrom;
  @override
  DateTime get dateTo;
  @override
  String get id;
  @override
  String get workoutType;
  @override
  num? get energy;
  @override
  num? get distance;
  @override
  String? get source;
  @override
  @JsonKey(ignore: true)
  _$$_WorkoutDataCopyWith<_$_WorkoutData> get copyWith =>
      throw _privateConstructorUsedError;
}

HabitCompletionData _$HabitCompletionDataFromJson(Map<String, dynamic> json) {
  return _HabitCompletionData.fromJson(json);
}

/// @nodoc
mixin _$HabitCompletionData {
  DateTime get dateFrom => throw _privateConstructorUsedError;
  DateTime get dateTo => throw _privateConstructorUsedError;
  String get habitId => throw _privateConstructorUsedError;
  HabitCompletionType? get completionType => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $HabitCompletionDataCopyWith<HabitCompletionData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HabitCompletionDataCopyWith<$Res> {
  factory $HabitCompletionDataCopyWith(
          HabitCompletionData value, $Res Function(HabitCompletionData) then) =
      _$HabitCompletionDataCopyWithImpl<$Res, HabitCompletionData>;
  @useResult
  $Res call(
      {DateTime dateFrom,
      DateTime dateTo,
      String habitId,
      HabitCompletionType? completionType});
}

/// @nodoc
class _$HabitCompletionDataCopyWithImpl<$Res, $Val extends HabitCompletionData>
    implements $HabitCompletionDataCopyWith<$Res> {
  _$HabitCompletionDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dateFrom = null,
    Object? dateTo = null,
    Object? habitId = null,
    Object? completionType = freezed,
  }) {
    return _then(_value.copyWith(
      dateFrom: null == dateFrom
          ? _value.dateFrom
          : dateFrom // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateTo: null == dateTo
          ? _value.dateTo
          : dateTo // ignore: cast_nullable_to_non_nullable
              as DateTime,
      habitId: null == habitId
          ? _value.habitId
          : habitId // ignore: cast_nullable_to_non_nullable
              as String,
      completionType: freezed == completionType
          ? _value.completionType
          : completionType // ignore: cast_nullable_to_non_nullable
              as HabitCompletionType?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_HabitCompletionDataCopyWith<$Res>
    implements $HabitCompletionDataCopyWith<$Res> {
  factory _$$_HabitCompletionDataCopyWith(_$_HabitCompletionData value,
          $Res Function(_$_HabitCompletionData) then) =
      __$$_HabitCompletionDataCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {DateTime dateFrom,
      DateTime dateTo,
      String habitId,
      HabitCompletionType? completionType});
}

/// @nodoc
class __$$_HabitCompletionDataCopyWithImpl<$Res>
    extends _$HabitCompletionDataCopyWithImpl<$Res, _$_HabitCompletionData>
    implements _$$_HabitCompletionDataCopyWith<$Res> {
  __$$_HabitCompletionDataCopyWithImpl(_$_HabitCompletionData _value,
      $Res Function(_$_HabitCompletionData) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dateFrom = null,
    Object? dateTo = null,
    Object? habitId = null,
    Object? completionType = freezed,
  }) {
    return _then(_$_HabitCompletionData(
      dateFrom: null == dateFrom
          ? _value.dateFrom
          : dateFrom // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateTo: null == dateTo
          ? _value.dateTo
          : dateTo // ignore: cast_nullable_to_non_nullable
              as DateTime,
      habitId: null == habitId
          ? _value.habitId
          : habitId // ignore: cast_nullable_to_non_nullable
              as String,
      completionType: freezed == completionType
          ? _value.completionType
          : completionType // ignore: cast_nullable_to_non_nullable
              as HabitCompletionType?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$_HabitCompletionData implements _HabitCompletionData {
  _$_HabitCompletionData(
      {required this.dateFrom,
      required this.dateTo,
      required this.habitId,
      this.completionType});

  factory _$_HabitCompletionData.fromJson(Map<String, dynamic> json) =>
      _$$_HabitCompletionDataFromJson(json);

  @override
  final DateTime dateFrom;
  @override
  final DateTime dateTo;
  @override
  final String habitId;
  @override
  final HabitCompletionType? completionType;

  @override
  String toString() {
    return 'HabitCompletionData(dateFrom: $dateFrom, dateTo: $dateTo, habitId: $habitId, completionType: $completionType)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_HabitCompletionData &&
            (identical(other.dateFrom, dateFrom) ||
                other.dateFrom == dateFrom) &&
            (identical(other.dateTo, dateTo) || other.dateTo == dateTo) &&
            (identical(other.habitId, habitId) || other.habitId == habitId) &&
            (identical(other.completionType, completionType) ||
                other.completionType == completionType));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, dateFrom, dateTo, habitId, completionType);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_HabitCompletionDataCopyWith<_$_HabitCompletionData> get copyWith =>
      __$$_HabitCompletionDataCopyWithImpl<_$_HabitCompletionData>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$_HabitCompletionDataToJson(
      this,
    );
  }
}

abstract class _HabitCompletionData implements HabitCompletionData {
  factory _HabitCompletionData(
      {required final DateTime dateFrom,
      required final DateTime dateTo,
      required final String habitId,
      final HabitCompletionType? completionType}) = _$_HabitCompletionData;

  factory _HabitCompletionData.fromJson(Map<String, dynamic> json) =
      _$_HabitCompletionData.fromJson;

  @override
  DateTime get dateFrom;
  @override
  DateTime get dateTo;
  @override
  String get habitId;
  @override
  HabitCompletionType? get completionType;
  @override
  @JsonKey(ignore: true)
  _$$_HabitCompletionDataCopyWith<_$_HabitCompletionData> get copyWith =>
      throw _privateConstructorUsedError;
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
  }) =>
      throw _privateConstructorUsedError;
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
  }) =>
      throw _privateConstructorUsedError;
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
  }) =>
      throw _privateConstructorUsedError;
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
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(DashboardMeasurementItem value)? measurement,
    TResult? Function(DashboardHealthItem value)? healthChart,
    TResult? Function(DashboardWorkoutItem value)? workoutChart,
    TResult? Function(DashboardHabitItem value)? habitChart,
    TResult? Function(DashboardSurveyItem value)? surveyChart,
    TResult? Function(DashboardStoryTimeItem value)? storyTimeChart,
    TResult? Function(WildcardStoryTimeItem value)? wildcardStoryTimeChart,
  }) =>
      throw _privateConstructorUsedError;
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
  }) =>
      throw _privateConstructorUsedError;
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DashboardItemCopyWith<$Res> {
  factory $DashboardItemCopyWith(
          DashboardItem value, $Res Function(DashboardItem) then) =
      _$DashboardItemCopyWithImpl<$Res, DashboardItem>;
}

/// @nodoc
class _$DashboardItemCopyWithImpl<$Res, $Val extends DashboardItem>
    implements $DashboardItemCopyWith<$Res> {
  _$DashboardItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;
}

/// @nodoc
abstract class _$$DashboardMeasurementItemCopyWith<$Res> {
  factory _$$DashboardMeasurementItemCopyWith(_$DashboardMeasurementItem value,
          $Res Function(_$DashboardMeasurementItem) then) =
      __$$DashboardMeasurementItemCopyWithImpl<$Res>;
  @useResult
  $Res call({String id, AggregationType? aggregationType});
}

/// @nodoc
class __$$DashboardMeasurementItemCopyWithImpl<$Res>
    extends _$DashboardItemCopyWithImpl<$Res, _$DashboardMeasurementItem>
    implements _$$DashboardMeasurementItemCopyWith<$Res> {
  __$$DashboardMeasurementItemCopyWithImpl(_$DashboardMeasurementItem _value,
      $Res Function(_$DashboardMeasurementItem) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? aggregationType = freezed,
  }) {
    return _then(_$DashboardMeasurementItem(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      aggregationType: freezed == aggregationType
          ? _value.aggregationType
          : aggregationType // ignore: cast_nullable_to_non_nullable
              as AggregationType?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DashboardMeasurementItem implements DashboardMeasurementItem {
  _$DashboardMeasurementItem(
      {required this.id, this.aggregationType, final String? $type})
      : $type = $type ?? 'measurement';

  factory _$DashboardMeasurementItem.fromJson(Map<String, dynamic> json) =>
      _$$DashboardMeasurementItemFromJson(json);

  @override
  final String id;
  @override
  final AggregationType? aggregationType;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'DashboardItem.measurement(id: $id, aggregationType: $aggregationType)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DashboardMeasurementItem &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.aggregationType, aggregationType) ||
                other.aggregationType == aggregationType));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, aggregationType);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$DashboardMeasurementItemCopyWith<_$DashboardMeasurementItem>
      get copyWith =>
          __$$DashboardMeasurementItemCopyWithImpl<_$DashboardMeasurementItem>(
              this, _$identity);

  @override
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
    return measurement(id, aggregationType);
  }

  @override
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
    return measurement?.call(id, aggregationType);
  }

  @override
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
    if (measurement != null) {
      return measurement(id, aggregationType);
    }
    return orElse();
  }

  @override
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
    return measurement(this);
  }

  @override
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
    return measurement?.call(this);
  }

  @override
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
    if (measurement != null) {
      return measurement(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$DashboardMeasurementItemToJson(
      this,
    );
  }
}

abstract class DashboardMeasurementItem implements DashboardItem {
  factory DashboardMeasurementItem(
      {required final String id,
      final AggregationType? aggregationType}) = _$DashboardMeasurementItem;

  factory DashboardMeasurementItem.fromJson(Map<String, dynamic> json) =
      _$DashboardMeasurementItem.fromJson;

  String get id;
  AggregationType? get aggregationType;
  @JsonKey(ignore: true)
  _$$DashboardMeasurementItemCopyWith<_$DashboardMeasurementItem>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$DashboardHealthItemCopyWith<$Res> {
  factory _$$DashboardHealthItemCopyWith(_$DashboardHealthItem value,
          $Res Function(_$DashboardHealthItem) then) =
      __$$DashboardHealthItemCopyWithImpl<$Res>;
  @useResult
  $Res call({String color, String healthType});
}

/// @nodoc
class __$$DashboardHealthItemCopyWithImpl<$Res>
    extends _$DashboardItemCopyWithImpl<$Res, _$DashboardHealthItem>
    implements _$$DashboardHealthItemCopyWith<$Res> {
  __$$DashboardHealthItemCopyWithImpl(
      _$DashboardHealthItem _value, $Res Function(_$DashboardHealthItem) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? color = null,
    Object? healthType = null,
  }) {
    return _then(_$DashboardHealthItem(
      color: null == color
          ? _value.color
          : color // ignore: cast_nullable_to_non_nullable
              as String,
      healthType: null == healthType
          ? _value.healthType
          : healthType // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DashboardHealthItem implements DashboardHealthItem {
  _$DashboardHealthItem(
      {required this.color, required this.healthType, final String? $type})
      : $type = $type ?? 'healthChart';

  factory _$DashboardHealthItem.fromJson(Map<String, dynamic> json) =>
      _$$DashboardHealthItemFromJson(json);

  @override
  final String color;
  @override
  final String healthType;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'DashboardItem.healthChart(color: $color, healthType: $healthType)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DashboardHealthItem &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.healthType, healthType) ||
                other.healthType == healthType));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, color, healthType);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$DashboardHealthItemCopyWith<_$DashboardHealthItem> get copyWith =>
      __$$DashboardHealthItemCopyWithImpl<_$DashboardHealthItem>(
          this, _$identity);

  @override
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
    return healthChart(color, healthType);
  }

  @override
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
    return healthChart?.call(color, healthType);
  }

  @override
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
    if (healthChart != null) {
      return healthChart(color, healthType);
    }
    return orElse();
  }

  @override
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
    return healthChart(this);
  }

  @override
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
    return healthChart?.call(this);
  }

  @override
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
    if (healthChart != null) {
      return healthChart(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$DashboardHealthItemToJson(
      this,
    );
  }
}

abstract class DashboardHealthItem implements DashboardItem {
  factory DashboardHealthItem(
      {required final String color,
      required final String healthType}) = _$DashboardHealthItem;

  factory DashboardHealthItem.fromJson(Map<String, dynamic> json) =
      _$DashboardHealthItem.fromJson;

  String get color;
  String get healthType;
  @JsonKey(ignore: true)
  _$$DashboardHealthItemCopyWith<_$DashboardHealthItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$DashboardWorkoutItemCopyWith<$Res> {
  factory _$$DashboardWorkoutItemCopyWith(_$DashboardWorkoutItem value,
          $Res Function(_$DashboardWorkoutItem) then) =
      __$$DashboardWorkoutItemCopyWithImpl<$Res>;
  @useResult
  $Res call(
      {String workoutType,
      String displayName,
      String color,
      WorkoutValueType valueType});
}

/// @nodoc
class __$$DashboardWorkoutItemCopyWithImpl<$Res>
    extends _$DashboardItemCopyWithImpl<$Res, _$DashboardWorkoutItem>
    implements _$$DashboardWorkoutItemCopyWith<$Res> {
  __$$DashboardWorkoutItemCopyWithImpl(_$DashboardWorkoutItem _value,
      $Res Function(_$DashboardWorkoutItem) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? workoutType = null,
    Object? displayName = null,
    Object? color = null,
    Object? valueType = null,
  }) {
    return _then(_$DashboardWorkoutItem(
      workoutType: null == workoutType
          ? _value.workoutType
          : workoutType // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      color: null == color
          ? _value.color
          : color // ignore: cast_nullable_to_non_nullable
              as String,
      valueType: null == valueType
          ? _value.valueType
          : valueType // ignore: cast_nullable_to_non_nullable
              as WorkoutValueType,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DashboardWorkoutItem implements DashboardWorkoutItem {
  _$DashboardWorkoutItem(
      {required this.workoutType,
      required this.displayName,
      required this.color,
      required this.valueType,
      final String? $type})
      : $type = $type ?? 'workoutChart';

  factory _$DashboardWorkoutItem.fromJson(Map<String, dynamic> json) =>
      _$$DashboardWorkoutItemFromJson(json);

  @override
  final String workoutType;
  @override
  final String displayName;
  @override
  final String color;
  @override
  final WorkoutValueType valueType;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'DashboardItem.workoutChart(workoutType: $workoutType, displayName: $displayName, color: $color, valueType: $valueType)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DashboardWorkoutItem &&
            (identical(other.workoutType, workoutType) ||
                other.workoutType == workoutType) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.valueType, valueType) ||
                other.valueType == valueType));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, workoutType, displayName, color, valueType);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$DashboardWorkoutItemCopyWith<_$DashboardWorkoutItem> get copyWith =>
      __$$DashboardWorkoutItemCopyWithImpl<_$DashboardWorkoutItem>(
          this, _$identity);

  @override
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
    return workoutChart(workoutType, displayName, color, valueType);
  }

  @override
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
    return workoutChart?.call(workoutType, displayName, color, valueType);
  }

  @override
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
    if (workoutChart != null) {
      return workoutChart(workoutType, displayName, color, valueType);
    }
    return orElse();
  }

  @override
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
    return workoutChart(this);
  }

  @override
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
    return workoutChart?.call(this);
  }

  @override
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
    if (workoutChart != null) {
      return workoutChart(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$DashboardWorkoutItemToJson(
      this,
    );
  }
}

abstract class DashboardWorkoutItem implements DashboardItem {
  factory DashboardWorkoutItem(
      {required final String workoutType,
      required final String displayName,
      required final String color,
      required final WorkoutValueType valueType}) = _$DashboardWorkoutItem;

  factory DashboardWorkoutItem.fromJson(Map<String, dynamic> json) =
      _$DashboardWorkoutItem.fromJson;

  String get workoutType;
  String get displayName;
  String get color;
  WorkoutValueType get valueType;
  @JsonKey(ignore: true)
  _$$DashboardWorkoutItemCopyWith<_$DashboardWorkoutItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$DashboardHabitItemCopyWith<$Res> {
  factory _$$DashboardHabitItemCopyWith(_$DashboardHabitItem value,
          $Res Function(_$DashboardHabitItem) then) =
      __$$DashboardHabitItemCopyWithImpl<$Res>;
  @useResult
  $Res call({String habitId});
}

/// @nodoc
class __$$DashboardHabitItemCopyWithImpl<$Res>
    extends _$DashboardItemCopyWithImpl<$Res, _$DashboardHabitItem>
    implements _$$DashboardHabitItemCopyWith<$Res> {
  __$$DashboardHabitItemCopyWithImpl(
      _$DashboardHabitItem _value, $Res Function(_$DashboardHabitItem) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? habitId = null,
  }) {
    return _then(_$DashboardHabitItem(
      habitId: null == habitId
          ? _value.habitId
          : habitId // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DashboardHabitItem implements DashboardHabitItem {
  _$DashboardHabitItem({required this.habitId, final String? $type})
      : $type = $type ?? 'habitChart';

  factory _$DashboardHabitItem.fromJson(Map<String, dynamic> json) =>
      _$$DashboardHabitItemFromJson(json);

  @override
  final String habitId;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'DashboardItem.habitChart(habitId: $habitId)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DashboardHabitItem &&
            (identical(other.habitId, habitId) || other.habitId == habitId));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, habitId);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$DashboardHabitItemCopyWith<_$DashboardHabitItem> get copyWith =>
      __$$DashboardHabitItemCopyWithImpl<_$DashboardHabitItem>(
          this, _$identity);

  @override
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
    return habitChart(habitId);
  }

  @override
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
    return habitChart?.call(habitId);
  }

  @override
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
    if (habitChart != null) {
      return habitChart(habitId);
    }
    return orElse();
  }

  @override
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
    return habitChart(this);
  }

  @override
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
    return habitChart?.call(this);
  }

  @override
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
    if (habitChart != null) {
      return habitChart(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$DashboardHabitItemToJson(
      this,
    );
  }
}

abstract class DashboardHabitItem implements DashboardItem {
  factory DashboardHabitItem({required final String habitId}) =
      _$DashboardHabitItem;

  factory DashboardHabitItem.fromJson(Map<String, dynamic> json) =
      _$DashboardHabitItem.fromJson;

  String get habitId;
  @JsonKey(ignore: true)
  _$$DashboardHabitItemCopyWith<_$DashboardHabitItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$DashboardSurveyItemCopyWith<$Res> {
  factory _$$DashboardSurveyItemCopyWith(_$DashboardSurveyItem value,
          $Res Function(_$DashboardSurveyItem) then) =
      __$$DashboardSurveyItemCopyWithImpl<$Res>;
  @useResult
  $Res call(
      {Map<String, String> colorsByScoreKey,
      String surveyType,
      String surveyName});
}

/// @nodoc
class __$$DashboardSurveyItemCopyWithImpl<$Res>
    extends _$DashboardItemCopyWithImpl<$Res, _$DashboardSurveyItem>
    implements _$$DashboardSurveyItemCopyWith<$Res> {
  __$$DashboardSurveyItemCopyWithImpl(
      _$DashboardSurveyItem _value, $Res Function(_$DashboardSurveyItem) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? colorsByScoreKey = null,
    Object? surveyType = null,
    Object? surveyName = null,
  }) {
    return _then(_$DashboardSurveyItem(
      colorsByScoreKey: null == colorsByScoreKey
          ? _value._colorsByScoreKey
          : colorsByScoreKey // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      surveyType: null == surveyType
          ? _value.surveyType
          : surveyType // ignore: cast_nullable_to_non_nullable
              as String,
      surveyName: null == surveyName
          ? _value.surveyName
          : surveyName // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DashboardSurveyItem implements DashboardSurveyItem {
  _$DashboardSurveyItem(
      {required final Map<String, String> colorsByScoreKey,
      required this.surveyType,
      required this.surveyName,
      final String? $type})
      : _colorsByScoreKey = colorsByScoreKey,
        $type = $type ?? 'surveyChart';

  factory _$DashboardSurveyItem.fromJson(Map<String, dynamic> json) =>
      _$$DashboardSurveyItemFromJson(json);

  final Map<String, String> _colorsByScoreKey;
  @override
  Map<String, String> get colorsByScoreKey {
    if (_colorsByScoreKey is EqualUnmodifiableMapView) return _colorsByScoreKey;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_colorsByScoreKey);
  }

  @override
  final String surveyType;
  @override
  final String surveyName;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'DashboardItem.surveyChart(colorsByScoreKey: $colorsByScoreKey, surveyType: $surveyType, surveyName: $surveyName)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DashboardSurveyItem &&
            const DeepCollectionEquality()
                .equals(other._colorsByScoreKey, _colorsByScoreKey) &&
            (identical(other.surveyType, surveyType) ||
                other.surveyType == surveyType) &&
            (identical(other.surveyName, surveyName) ||
                other.surveyName == surveyName));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_colorsByScoreKey),
      surveyType,
      surveyName);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$DashboardSurveyItemCopyWith<_$DashboardSurveyItem> get copyWith =>
      __$$DashboardSurveyItemCopyWithImpl<_$DashboardSurveyItem>(
          this, _$identity);

  @override
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
    return surveyChart(colorsByScoreKey, surveyType, surveyName);
  }

  @override
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
    return surveyChart?.call(colorsByScoreKey, surveyType, surveyName);
  }

  @override
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
    if (surveyChart != null) {
      return surveyChart(colorsByScoreKey, surveyType, surveyName);
    }
    return orElse();
  }

  @override
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
    return surveyChart(this);
  }

  @override
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
    return surveyChart?.call(this);
  }

  @override
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
    if (surveyChart != null) {
      return surveyChart(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$DashboardSurveyItemToJson(
      this,
    );
  }
}

abstract class DashboardSurveyItem implements DashboardItem {
  factory DashboardSurveyItem(
      {required final Map<String, String> colorsByScoreKey,
      required final String surveyType,
      required final String surveyName}) = _$DashboardSurveyItem;

  factory DashboardSurveyItem.fromJson(Map<String, dynamic> json) =
      _$DashboardSurveyItem.fromJson;

  Map<String, String> get colorsByScoreKey;
  String get surveyType;
  String get surveyName;
  @JsonKey(ignore: true)
  _$$DashboardSurveyItemCopyWith<_$DashboardSurveyItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$DashboardStoryTimeItemCopyWith<$Res> {
  factory _$$DashboardStoryTimeItemCopyWith(_$DashboardStoryTimeItem value,
          $Res Function(_$DashboardStoryTimeItem) then) =
      __$$DashboardStoryTimeItemCopyWithImpl<$Res>;
  @useResult
  $Res call({String storyTagId, String color});
}

/// @nodoc
class __$$DashboardStoryTimeItemCopyWithImpl<$Res>
    extends _$DashboardItemCopyWithImpl<$Res, _$DashboardStoryTimeItem>
    implements _$$DashboardStoryTimeItemCopyWith<$Res> {
  __$$DashboardStoryTimeItemCopyWithImpl(_$DashboardStoryTimeItem _value,
      $Res Function(_$DashboardStoryTimeItem) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? storyTagId = null,
    Object? color = null,
  }) {
    return _then(_$DashboardStoryTimeItem(
      storyTagId: null == storyTagId
          ? _value.storyTagId
          : storyTagId // ignore: cast_nullable_to_non_nullable
              as String,
      color: null == color
          ? _value.color
          : color // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DashboardStoryTimeItem implements DashboardStoryTimeItem {
  _$DashboardStoryTimeItem(
      {required this.storyTagId, required this.color, final String? $type})
      : $type = $type ?? 'storyTimeChart';

  factory _$DashboardStoryTimeItem.fromJson(Map<String, dynamic> json) =>
      _$$DashboardStoryTimeItemFromJson(json);

  @override
  final String storyTagId;
  @override
  final String color;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'DashboardItem.storyTimeChart(storyTagId: $storyTagId, color: $color)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DashboardStoryTimeItem &&
            (identical(other.storyTagId, storyTagId) ||
                other.storyTagId == storyTagId) &&
            (identical(other.color, color) || other.color == color));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, storyTagId, color);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$DashboardStoryTimeItemCopyWith<_$DashboardStoryTimeItem> get copyWith =>
      __$$DashboardStoryTimeItemCopyWithImpl<_$DashboardStoryTimeItem>(
          this, _$identity);

  @override
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
    return storyTimeChart(storyTagId, color);
  }

  @override
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
    return storyTimeChart?.call(storyTagId, color);
  }

  @override
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
    if (storyTimeChart != null) {
      return storyTimeChart(storyTagId, color);
    }
    return orElse();
  }

  @override
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
    return storyTimeChart(this);
  }

  @override
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
    return storyTimeChart?.call(this);
  }

  @override
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
    if (storyTimeChart != null) {
      return storyTimeChart(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$DashboardStoryTimeItemToJson(
      this,
    );
  }
}

abstract class DashboardStoryTimeItem implements DashboardItem {
  factory DashboardStoryTimeItem(
      {required final String storyTagId,
      required final String color}) = _$DashboardStoryTimeItem;

  factory DashboardStoryTimeItem.fromJson(Map<String, dynamic> json) =
      _$DashboardStoryTimeItem.fromJson;

  String get storyTagId;
  String get color;
  @JsonKey(ignore: true)
  _$$DashboardStoryTimeItemCopyWith<_$DashboardStoryTimeItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$WildcardStoryTimeItemCopyWith<$Res> {
  factory _$$WildcardStoryTimeItemCopyWith(_$WildcardStoryTimeItem value,
          $Res Function(_$WildcardStoryTimeItem) then) =
      __$$WildcardStoryTimeItemCopyWithImpl<$Res>;
  @useResult
  $Res call({String storySubstring, String color});
}

/// @nodoc
class __$$WildcardStoryTimeItemCopyWithImpl<$Res>
    extends _$DashboardItemCopyWithImpl<$Res, _$WildcardStoryTimeItem>
    implements _$$WildcardStoryTimeItemCopyWith<$Res> {
  __$$WildcardStoryTimeItemCopyWithImpl(_$WildcardStoryTimeItem _value,
      $Res Function(_$WildcardStoryTimeItem) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? storySubstring = null,
    Object? color = null,
  }) {
    return _then(_$WildcardStoryTimeItem(
      storySubstring: null == storySubstring
          ? _value.storySubstring
          : storySubstring // ignore: cast_nullable_to_non_nullable
              as String,
      color: null == color
          ? _value.color
          : color // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$WildcardStoryTimeItem implements WildcardStoryTimeItem {
  _$WildcardStoryTimeItem(
      {required this.storySubstring, required this.color, final String? $type})
      : $type = $type ?? 'wildcardStoryTimeChart';

  factory _$WildcardStoryTimeItem.fromJson(Map<String, dynamic> json) =>
      _$$WildcardStoryTimeItemFromJson(json);

  @override
  final String storySubstring;
  @override
  final String color;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'DashboardItem.wildcardStoryTimeChart(storySubstring: $storySubstring, color: $color)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WildcardStoryTimeItem &&
            (identical(other.storySubstring, storySubstring) ||
                other.storySubstring == storySubstring) &&
            (identical(other.color, color) || other.color == color));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, storySubstring, color);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$WildcardStoryTimeItemCopyWith<_$WildcardStoryTimeItem> get copyWith =>
      __$$WildcardStoryTimeItemCopyWithImpl<_$WildcardStoryTimeItem>(
          this, _$identity);

  @override
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
    return wildcardStoryTimeChart(storySubstring, color);
  }

  @override
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
    return wildcardStoryTimeChart?.call(storySubstring, color);
  }

  @override
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
    if (wildcardStoryTimeChart != null) {
      return wildcardStoryTimeChart(storySubstring, color);
    }
    return orElse();
  }

  @override
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
    return wildcardStoryTimeChart(this);
  }

  @override
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
    return wildcardStoryTimeChart?.call(this);
  }

  @override
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
    if (wildcardStoryTimeChart != null) {
      return wildcardStoryTimeChart(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$WildcardStoryTimeItemToJson(
      this,
    );
  }
}

abstract class WildcardStoryTimeItem implements DashboardItem {
  factory WildcardStoryTimeItem(
      {required final String storySubstring,
      required final String color}) = _$WildcardStoryTimeItem;

  factory WildcardStoryTimeItem.fromJson(Map<String, dynamic> json) =
      _$WildcardStoryTimeItem.fromJson;

  String get storySubstring;
  String get color;
  @JsonKey(ignore: true)
  _$$WildcardStoryTimeItemCopyWith<_$WildcardStoryTimeItem> get copyWith =>
      throw _privateConstructorUsedError;
}
