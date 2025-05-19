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
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

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
    required TResult Function(
            int requiredCompletions, DateTime? showFrom, DateTime? alertAtTime)
        daily,
    required TResult Function(int requiredCompletions) weekly,
    required TResult Function(int requiredCompletions) monthly,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            int requiredCompletions, DateTime? showFrom, DateTime? alertAtTime)?
        daily,
    TResult? Function(int requiredCompletions)? weekly,
    TResult? Function(int requiredCompletions)? monthly,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            int requiredCompletions, DateTime? showFrom, DateTime? alertAtTime)?
        daily,
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

  /// Serializes this HabitSchedule to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of HabitSchedule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
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

  /// Create a copy of HabitSchedule
  /// with the given fields replaced by the non-null parameter values.
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
abstract class _$$DailyHabitScheduleImplCopyWith<$Res>
    implements $HabitScheduleCopyWith<$Res> {
  factory _$$DailyHabitScheduleImplCopyWith(_$DailyHabitScheduleImpl value,
          $Res Function(_$DailyHabitScheduleImpl) then) =
      __$$DailyHabitScheduleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int requiredCompletions, DateTime? showFrom, DateTime? alertAtTime});
}

/// @nodoc
class __$$DailyHabitScheduleImplCopyWithImpl<$Res>
    extends _$HabitScheduleCopyWithImpl<$Res, _$DailyHabitScheduleImpl>
    implements _$$DailyHabitScheduleImplCopyWith<$Res> {
  __$$DailyHabitScheduleImplCopyWithImpl(_$DailyHabitScheduleImpl _value,
      $Res Function(_$DailyHabitScheduleImpl) _then)
      : super(_value, _then);

  /// Create a copy of HabitSchedule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? requiredCompletions = null,
    Object? showFrom = freezed,
    Object? alertAtTime = freezed,
  }) {
    return _then(_$DailyHabitScheduleImpl(
      requiredCompletions: null == requiredCompletions
          ? _value.requiredCompletions
          : requiredCompletions // ignore: cast_nullable_to_non_nullable
              as int,
      showFrom: freezed == showFrom
          ? _value.showFrom
          : showFrom // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      alertAtTime: freezed == alertAtTime
          ? _value.alertAtTime
          : alertAtTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DailyHabitScheduleImpl implements DailyHabitSchedule {
  const _$DailyHabitScheduleImpl(
      {required this.requiredCompletions,
      this.showFrom,
      this.alertAtTime,
      final String? $type})
      : $type = $type ?? 'daily';

  factory _$DailyHabitScheduleImpl.fromJson(Map<String, dynamic> json) =>
      _$$DailyHabitScheduleImplFromJson(json);

  @override
  final int requiredCompletions;
  @override
  final DateTime? showFrom;
  @override
  final DateTime? alertAtTime;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'HabitSchedule.daily(requiredCompletions: $requiredCompletions, showFrom: $showFrom, alertAtTime: $alertAtTime)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DailyHabitScheduleImpl &&
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

  /// Create a copy of HabitSchedule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DailyHabitScheduleImplCopyWith<_$DailyHabitScheduleImpl> get copyWith =>
      __$$DailyHabitScheduleImplCopyWithImpl<_$DailyHabitScheduleImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            int requiredCompletions, DateTime? showFrom, DateTime? alertAtTime)
        daily,
    required TResult Function(int requiredCompletions) weekly,
    required TResult Function(int requiredCompletions) monthly,
  }) {
    return daily(requiredCompletions, showFrom, alertAtTime);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            int requiredCompletions, DateTime? showFrom, DateTime? alertAtTime)?
        daily,
    TResult? Function(int requiredCompletions)? weekly,
    TResult? Function(int requiredCompletions)? monthly,
  }) {
    return daily?.call(requiredCompletions, showFrom, alertAtTime);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            int requiredCompletions, DateTime? showFrom, DateTime? alertAtTime)?
        daily,
    TResult Function(int requiredCompletions)? weekly,
    TResult Function(int requiredCompletions)? monthly,
    required TResult orElse(),
  }) {
    if (daily != null) {
      return daily(requiredCompletions, showFrom, alertAtTime);
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
    return _$$DailyHabitScheduleImplToJson(
      this,
    );
  }
}

abstract class DailyHabitSchedule implements HabitSchedule {
  const factory DailyHabitSchedule(
      {required final int requiredCompletions,
      final DateTime? showFrom,
      final DateTime? alertAtTime}) = _$DailyHabitScheduleImpl;

  factory DailyHabitSchedule.fromJson(Map<String, dynamic> json) =
      _$DailyHabitScheduleImpl.fromJson;

  @override
  int get requiredCompletions;
  DateTime? get showFrom;
  DateTime? get alertAtTime;

  /// Create a copy of HabitSchedule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DailyHabitScheduleImplCopyWith<_$DailyHabitScheduleImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$WeeklyHabitScheduleImplCopyWith<$Res>
    implements $HabitScheduleCopyWith<$Res> {
  factory _$$WeeklyHabitScheduleImplCopyWith(_$WeeklyHabitScheduleImpl value,
          $Res Function(_$WeeklyHabitScheduleImpl) then) =
      __$$WeeklyHabitScheduleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int requiredCompletions});
}

/// @nodoc
class __$$WeeklyHabitScheduleImplCopyWithImpl<$Res>
    extends _$HabitScheduleCopyWithImpl<$Res, _$WeeklyHabitScheduleImpl>
    implements _$$WeeklyHabitScheduleImplCopyWith<$Res> {
  __$$WeeklyHabitScheduleImplCopyWithImpl(_$WeeklyHabitScheduleImpl _value,
      $Res Function(_$WeeklyHabitScheduleImpl) _then)
      : super(_value, _then);

  /// Create a copy of HabitSchedule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? requiredCompletions = null,
  }) {
    return _then(_$WeeklyHabitScheduleImpl(
      requiredCompletions: null == requiredCompletions
          ? _value.requiredCompletions
          : requiredCompletions // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$WeeklyHabitScheduleImpl implements WeeklyHabitSchedule {
  const _$WeeklyHabitScheduleImpl(
      {required this.requiredCompletions, final String? $type})
      : $type = $type ?? 'weekly';

  factory _$WeeklyHabitScheduleImpl.fromJson(Map<String, dynamic> json) =>
      _$$WeeklyHabitScheduleImplFromJson(json);

  @override
  final int requiredCompletions;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'HabitSchedule.weekly(requiredCompletions: $requiredCompletions)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WeeklyHabitScheduleImpl &&
            (identical(other.requiredCompletions, requiredCompletions) ||
                other.requiredCompletions == requiredCompletions));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, requiredCompletions);

  /// Create a copy of HabitSchedule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WeeklyHabitScheduleImplCopyWith<_$WeeklyHabitScheduleImpl> get copyWith =>
      __$$WeeklyHabitScheduleImplCopyWithImpl<_$WeeklyHabitScheduleImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            int requiredCompletions, DateTime? showFrom, DateTime? alertAtTime)
        daily,
    required TResult Function(int requiredCompletions) weekly,
    required TResult Function(int requiredCompletions) monthly,
  }) {
    return weekly(requiredCompletions);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            int requiredCompletions, DateTime? showFrom, DateTime? alertAtTime)?
        daily,
    TResult? Function(int requiredCompletions)? weekly,
    TResult? Function(int requiredCompletions)? monthly,
  }) {
    return weekly?.call(requiredCompletions);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            int requiredCompletions, DateTime? showFrom, DateTime? alertAtTime)?
        daily,
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
    return _$$WeeklyHabitScheduleImplToJson(
      this,
    );
  }
}

abstract class WeeklyHabitSchedule implements HabitSchedule {
  const factory WeeklyHabitSchedule({required final int requiredCompletions}) =
      _$WeeklyHabitScheduleImpl;

  factory WeeklyHabitSchedule.fromJson(Map<String, dynamic> json) =
      _$WeeklyHabitScheduleImpl.fromJson;

  @override
  int get requiredCompletions;

  /// Create a copy of HabitSchedule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WeeklyHabitScheduleImplCopyWith<_$WeeklyHabitScheduleImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$MonthlyHabitScheduleImplCopyWith<$Res>
    implements $HabitScheduleCopyWith<$Res> {
  factory _$$MonthlyHabitScheduleImplCopyWith(_$MonthlyHabitScheduleImpl value,
          $Res Function(_$MonthlyHabitScheduleImpl) then) =
      __$$MonthlyHabitScheduleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int requiredCompletions});
}

/// @nodoc
class __$$MonthlyHabitScheduleImplCopyWithImpl<$Res>
    extends _$HabitScheduleCopyWithImpl<$Res, _$MonthlyHabitScheduleImpl>
    implements _$$MonthlyHabitScheduleImplCopyWith<$Res> {
  __$$MonthlyHabitScheduleImplCopyWithImpl(_$MonthlyHabitScheduleImpl _value,
      $Res Function(_$MonthlyHabitScheduleImpl) _then)
      : super(_value, _then);

  /// Create a copy of HabitSchedule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? requiredCompletions = null,
  }) {
    return _then(_$MonthlyHabitScheduleImpl(
      requiredCompletions: null == requiredCompletions
          ? _value.requiredCompletions
          : requiredCompletions // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MonthlyHabitScheduleImpl implements MonthlyHabitSchedule {
  const _$MonthlyHabitScheduleImpl(
      {required this.requiredCompletions, final String? $type})
      : $type = $type ?? 'monthly';

  factory _$MonthlyHabitScheduleImpl.fromJson(Map<String, dynamic> json) =>
      _$$MonthlyHabitScheduleImplFromJson(json);

  @override
  final int requiredCompletions;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'HabitSchedule.monthly(requiredCompletions: $requiredCompletions)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MonthlyHabitScheduleImpl &&
            (identical(other.requiredCompletions, requiredCompletions) ||
                other.requiredCompletions == requiredCompletions));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, requiredCompletions);

  /// Create a copy of HabitSchedule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MonthlyHabitScheduleImplCopyWith<_$MonthlyHabitScheduleImpl>
      get copyWith =>
          __$$MonthlyHabitScheduleImplCopyWithImpl<_$MonthlyHabitScheduleImpl>(
              this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            int requiredCompletions, DateTime? showFrom, DateTime? alertAtTime)
        daily,
    required TResult Function(int requiredCompletions) weekly,
    required TResult Function(int requiredCompletions) monthly,
  }) {
    return monthly(requiredCompletions);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            int requiredCompletions, DateTime? showFrom, DateTime? alertAtTime)?
        daily,
    TResult? Function(int requiredCompletions)? weekly,
    TResult? Function(int requiredCompletions)? monthly,
  }) {
    return monthly?.call(requiredCompletions);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            int requiredCompletions, DateTime? showFrom, DateTime? alertAtTime)?
        daily,
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
    return _$$MonthlyHabitScheduleImplToJson(
      this,
    );
  }
}

abstract class MonthlyHabitSchedule implements HabitSchedule {
  const factory MonthlyHabitSchedule({required final int requiredCompletions}) =
      _$MonthlyHabitScheduleImpl;

  factory MonthlyHabitSchedule.fromJson(Map<String, dynamic> json) =
      _$MonthlyHabitScheduleImpl.fromJson;

  @override
  int get requiredCompletions;

  /// Create a copy of HabitSchedule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MonthlyHabitScheduleImplCopyWith<_$MonthlyHabitScheduleImpl>
      get copyWith => throw _privateConstructorUsedError;
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

  /// Serializes this AutoCompleteRule to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
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

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
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
abstract class _$$AutoCompleteRuleHealthImplCopyWith<$Res>
    implements $AutoCompleteRuleCopyWith<$Res> {
  factory _$$AutoCompleteRuleHealthImplCopyWith(
          _$AutoCompleteRuleHealthImpl value,
          $Res Function(_$AutoCompleteRuleHealthImpl) then) =
      __$$AutoCompleteRuleHealthImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String dataType, num? minimum, num? maximum, String? title});
}

/// @nodoc
class __$$AutoCompleteRuleHealthImplCopyWithImpl<$Res>
    extends _$AutoCompleteRuleCopyWithImpl<$Res, _$AutoCompleteRuleHealthImpl>
    implements _$$AutoCompleteRuleHealthImplCopyWith<$Res> {
  __$$AutoCompleteRuleHealthImplCopyWithImpl(
      _$AutoCompleteRuleHealthImpl _value,
      $Res Function(_$AutoCompleteRuleHealthImpl) _then)
      : super(_value, _then);

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dataType = null,
    Object? minimum = freezed,
    Object? maximum = freezed,
    Object? title = freezed,
  }) {
    return _then(_$AutoCompleteRuleHealthImpl(
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
class _$AutoCompleteRuleHealthImpl implements AutoCompleteRuleHealth {
  const _$AutoCompleteRuleHealthImpl(
      {required this.dataType,
      this.minimum,
      this.maximum,
      this.title,
      final String? $type})
      : $type = $type ?? 'health';

  factory _$AutoCompleteRuleHealthImpl.fromJson(Map<String, dynamic> json) =>
      _$$AutoCompleteRuleHealthImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AutoCompleteRuleHealthImpl &&
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

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AutoCompleteRuleHealthImplCopyWith<_$AutoCompleteRuleHealthImpl>
      get copyWith => __$$AutoCompleteRuleHealthImplCopyWithImpl<
          _$AutoCompleteRuleHealthImpl>(this, _$identity);

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
    return _$$AutoCompleteRuleHealthImplToJson(
      this,
    );
  }
}

abstract class AutoCompleteRuleHealth implements AutoCompleteRule {
  const factory AutoCompleteRuleHealth(
      {required final String dataType,
      final num? minimum,
      final num? maximum,
      final String? title}) = _$AutoCompleteRuleHealthImpl;

  factory AutoCompleteRuleHealth.fromJson(Map<String, dynamic> json) =
      _$AutoCompleteRuleHealthImpl.fromJson;

  String get dataType;
  num? get minimum;
  num? get maximum;
  @override
  String? get title;

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AutoCompleteRuleHealthImplCopyWith<_$AutoCompleteRuleHealthImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$AutoCompleteRuleWorkoutImplCopyWith<$Res>
    implements $AutoCompleteRuleCopyWith<$Res> {
  factory _$$AutoCompleteRuleWorkoutImplCopyWith(
          _$AutoCompleteRuleWorkoutImpl value,
          $Res Function(_$AutoCompleteRuleWorkoutImpl) then) =
      __$$AutoCompleteRuleWorkoutImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String dataType, num? minimum, num? maximum, String? title});
}

/// @nodoc
class __$$AutoCompleteRuleWorkoutImplCopyWithImpl<$Res>
    extends _$AutoCompleteRuleCopyWithImpl<$Res, _$AutoCompleteRuleWorkoutImpl>
    implements _$$AutoCompleteRuleWorkoutImplCopyWith<$Res> {
  __$$AutoCompleteRuleWorkoutImplCopyWithImpl(
      _$AutoCompleteRuleWorkoutImpl _value,
      $Res Function(_$AutoCompleteRuleWorkoutImpl) _then)
      : super(_value, _then);

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dataType = null,
    Object? minimum = freezed,
    Object? maximum = freezed,
    Object? title = freezed,
  }) {
    return _then(_$AutoCompleteRuleWorkoutImpl(
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
class _$AutoCompleteRuleWorkoutImpl implements AutoCompleteRuleWorkout {
  const _$AutoCompleteRuleWorkoutImpl(
      {required this.dataType,
      this.minimum,
      this.maximum,
      this.title,
      final String? $type})
      : $type = $type ?? 'workout';

  factory _$AutoCompleteRuleWorkoutImpl.fromJson(Map<String, dynamic> json) =>
      _$$AutoCompleteRuleWorkoutImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AutoCompleteRuleWorkoutImpl &&
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

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AutoCompleteRuleWorkoutImplCopyWith<_$AutoCompleteRuleWorkoutImpl>
      get copyWith => __$$AutoCompleteRuleWorkoutImplCopyWithImpl<
          _$AutoCompleteRuleWorkoutImpl>(this, _$identity);

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
    return _$$AutoCompleteRuleWorkoutImplToJson(
      this,
    );
  }
}

abstract class AutoCompleteRuleWorkout implements AutoCompleteRule {
  const factory AutoCompleteRuleWorkout(
      {required final String dataType,
      final num? minimum,
      final num? maximum,
      final String? title}) = _$AutoCompleteRuleWorkoutImpl;

  factory AutoCompleteRuleWorkout.fromJson(Map<String, dynamic> json) =
      _$AutoCompleteRuleWorkoutImpl.fromJson;

  String get dataType;
  num? get minimum;
  num? get maximum;
  @override
  String? get title;

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AutoCompleteRuleWorkoutImplCopyWith<_$AutoCompleteRuleWorkoutImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$AutoCompleteRuleMeasurableImplCopyWith<$Res>
    implements $AutoCompleteRuleCopyWith<$Res> {
  factory _$$AutoCompleteRuleMeasurableImplCopyWith(
          _$AutoCompleteRuleMeasurableImpl value,
          $Res Function(_$AutoCompleteRuleMeasurableImpl) then) =
      __$$AutoCompleteRuleMeasurableImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String dataTypeId, num? minimum, num? maximum, String? title});
}

/// @nodoc
class __$$AutoCompleteRuleMeasurableImplCopyWithImpl<$Res>
    extends _$AutoCompleteRuleCopyWithImpl<$Res,
        _$AutoCompleteRuleMeasurableImpl>
    implements _$$AutoCompleteRuleMeasurableImplCopyWith<$Res> {
  __$$AutoCompleteRuleMeasurableImplCopyWithImpl(
      _$AutoCompleteRuleMeasurableImpl _value,
      $Res Function(_$AutoCompleteRuleMeasurableImpl) _then)
      : super(_value, _then);

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dataTypeId = null,
    Object? minimum = freezed,
    Object? maximum = freezed,
    Object? title = freezed,
  }) {
    return _then(_$AutoCompleteRuleMeasurableImpl(
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
class _$AutoCompleteRuleMeasurableImpl implements AutoCompleteRuleMeasurable {
  const _$AutoCompleteRuleMeasurableImpl(
      {required this.dataTypeId,
      this.minimum,
      this.maximum,
      this.title,
      final String? $type})
      : $type = $type ?? 'measurable';

  factory _$AutoCompleteRuleMeasurableImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$AutoCompleteRuleMeasurableImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AutoCompleteRuleMeasurableImpl &&
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

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AutoCompleteRuleMeasurableImplCopyWith<_$AutoCompleteRuleMeasurableImpl>
      get copyWith => __$$AutoCompleteRuleMeasurableImplCopyWithImpl<
          _$AutoCompleteRuleMeasurableImpl>(this, _$identity);

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
    return _$$AutoCompleteRuleMeasurableImplToJson(
      this,
    );
  }
}

abstract class AutoCompleteRuleMeasurable implements AutoCompleteRule {
  const factory AutoCompleteRuleMeasurable(
      {required final String dataTypeId,
      final num? minimum,
      final num? maximum,
      final String? title}) = _$AutoCompleteRuleMeasurableImpl;

  factory AutoCompleteRuleMeasurable.fromJson(Map<String, dynamic> json) =
      _$AutoCompleteRuleMeasurableImpl.fromJson;

  String get dataTypeId;
  num? get minimum;
  num? get maximum;
  @override
  String? get title;

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AutoCompleteRuleMeasurableImplCopyWith<_$AutoCompleteRuleMeasurableImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$AutoCompleteRuleHabitImplCopyWith<$Res>
    implements $AutoCompleteRuleCopyWith<$Res> {
  factory _$$AutoCompleteRuleHabitImplCopyWith(
          _$AutoCompleteRuleHabitImpl value,
          $Res Function(_$AutoCompleteRuleHabitImpl) then) =
      __$$AutoCompleteRuleHabitImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String habitId, String? title});
}

/// @nodoc
class __$$AutoCompleteRuleHabitImplCopyWithImpl<$Res>
    extends _$AutoCompleteRuleCopyWithImpl<$Res, _$AutoCompleteRuleHabitImpl>
    implements _$$AutoCompleteRuleHabitImplCopyWith<$Res> {
  __$$AutoCompleteRuleHabitImplCopyWithImpl(_$AutoCompleteRuleHabitImpl _value,
      $Res Function(_$AutoCompleteRuleHabitImpl) _then)
      : super(_value, _then);

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? habitId = null,
    Object? title = freezed,
  }) {
    return _then(_$AutoCompleteRuleHabitImpl(
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
class _$AutoCompleteRuleHabitImpl implements AutoCompleteRuleHabit {
  const _$AutoCompleteRuleHabitImpl(
      {required this.habitId, this.title, final String? $type})
      : $type = $type ?? 'habit';

  factory _$AutoCompleteRuleHabitImpl.fromJson(Map<String, dynamic> json) =>
      _$$AutoCompleteRuleHabitImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AutoCompleteRuleHabitImpl &&
            (identical(other.habitId, habitId) || other.habitId == habitId) &&
            (identical(other.title, title) || other.title == title));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, habitId, title);

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AutoCompleteRuleHabitImplCopyWith<_$AutoCompleteRuleHabitImpl>
      get copyWith => __$$AutoCompleteRuleHabitImplCopyWithImpl<
          _$AutoCompleteRuleHabitImpl>(this, _$identity);

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
    return _$$AutoCompleteRuleHabitImplToJson(
      this,
    );
  }
}

abstract class AutoCompleteRuleHabit implements AutoCompleteRule {
  const factory AutoCompleteRuleHabit(
      {required final String habitId,
      final String? title}) = _$AutoCompleteRuleHabitImpl;

  factory AutoCompleteRuleHabit.fromJson(Map<String, dynamic> json) =
      _$AutoCompleteRuleHabitImpl.fromJson;

  String get habitId;
  @override
  String? get title;

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AutoCompleteRuleHabitImplCopyWith<_$AutoCompleteRuleHabitImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$AutoCompleteRuleAndImplCopyWith<$Res>
    implements $AutoCompleteRuleCopyWith<$Res> {
  factory _$$AutoCompleteRuleAndImplCopyWith(_$AutoCompleteRuleAndImpl value,
          $Res Function(_$AutoCompleteRuleAndImpl) then) =
      __$$AutoCompleteRuleAndImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<AutoCompleteRule> rules, String? title});
}

/// @nodoc
class __$$AutoCompleteRuleAndImplCopyWithImpl<$Res>
    extends _$AutoCompleteRuleCopyWithImpl<$Res, _$AutoCompleteRuleAndImpl>
    implements _$$AutoCompleteRuleAndImplCopyWith<$Res> {
  __$$AutoCompleteRuleAndImplCopyWithImpl(_$AutoCompleteRuleAndImpl _value,
      $Res Function(_$AutoCompleteRuleAndImpl) _then)
      : super(_value, _then);

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? rules = null,
    Object? title = freezed,
  }) {
    return _then(_$AutoCompleteRuleAndImpl(
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
class _$AutoCompleteRuleAndImpl implements AutoCompleteRuleAnd {
  const _$AutoCompleteRuleAndImpl(
      {required final List<AutoCompleteRule> rules,
      this.title,
      final String? $type})
      : _rules = rules,
        $type = $type ?? 'and';

  factory _$AutoCompleteRuleAndImpl.fromJson(Map<String, dynamic> json) =>
      _$$AutoCompleteRuleAndImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AutoCompleteRuleAndImpl &&
            const DeepCollectionEquality().equals(other._rules, _rules) &&
            (identical(other.title, title) || other.title == title));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(_rules), title);

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AutoCompleteRuleAndImplCopyWith<_$AutoCompleteRuleAndImpl> get copyWith =>
      __$$AutoCompleteRuleAndImplCopyWithImpl<_$AutoCompleteRuleAndImpl>(
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
    return _$$AutoCompleteRuleAndImplToJson(
      this,
    );
  }
}

abstract class AutoCompleteRuleAnd implements AutoCompleteRule {
  const factory AutoCompleteRuleAnd(
      {required final List<AutoCompleteRule> rules,
      final String? title}) = _$AutoCompleteRuleAndImpl;

  factory AutoCompleteRuleAnd.fromJson(Map<String, dynamic> json) =
      _$AutoCompleteRuleAndImpl.fromJson;

  List<AutoCompleteRule> get rules;
  @override
  String? get title;

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AutoCompleteRuleAndImplCopyWith<_$AutoCompleteRuleAndImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$AutoCompleteRuleOrImplCopyWith<$Res>
    implements $AutoCompleteRuleCopyWith<$Res> {
  factory _$$AutoCompleteRuleOrImplCopyWith(_$AutoCompleteRuleOrImpl value,
          $Res Function(_$AutoCompleteRuleOrImpl) then) =
      __$$AutoCompleteRuleOrImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<AutoCompleteRule> rules, String? title});
}

/// @nodoc
class __$$AutoCompleteRuleOrImplCopyWithImpl<$Res>
    extends _$AutoCompleteRuleCopyWithImpl<$Res, _$AutoCompleteRuleOrImpl>
    implements _$$AutoCompleteRuleOrImplCopyWith<$Res> {
  __$$AutoCompleteRuleOrImplCopyWithImpl(_$AutoCompleteRuleOrImpl _value,
      $Res Function(_$AutoCompleteRuleOrImpl) _then)
      : super(_value, _then);

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? rules = null,
    Object? title = freezed,
  }) {
    return _then(_$AutoCompleteRuleOrImpl(
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
class _$AutoCompleteRuleOrImpl implements AutoCompleteRuleOr {
  const _$AutoCompleteRuleOrImpl(
      {required final List<AutoCompleteRule> rules,
      this.title,
      final String? $type})
      : _rules = rules,
        $type = $type ?? 'or';

  factory _$AutoCompleteRuleOrImpl.fromJson(Map<String, dynamic> json) =>
      _$$AutoCompleteRuleOrImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AutoCompleteRuleOrImpl &&
            const DeepCollectionEquality().equals(other._rules, _rules) &&
            (identical(other.title, title) || other.title == title));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(_rules), title);

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AutoCompleteRuleOrImplCopyWith<_$AutoCompleteRuleOrImpl> get copyWith =>
      __$$AutoCompleteRuleOrImplCopyWithImpl<_$AutoCompleteRuleOrImpl>(
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
    return _$$AutoCompleteRuleOrImplToJson(
      this,
    );
  }
}

abstract class AutoCompleteRuleOr implements AutoCompleteRule {
  const factory AutoCompleteRuleOr(
      {required final List<AutoCompleteRule> rules,
      final String? title}) = _$AutoCompleteRuleOrImpl;

  factory AutoCompleteRuleOr.fromJson(Map<String, dynamic> json) =
      _$AutoCompleteRuleOrImpl.fromJson;

  List<AutoCompleteRule> get rules;
  @override
  String? get title;

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AutoCompleteRuleOrImplCopyWith<_$AutoCompleteRuleOrImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$AutoCompleteRuleMultipleImplCopyWith<$Res>
    implements $AutoCompleteRuleCopyWith<$Res> {
  factory _$$AutoCompleteRuleMultipleImplCopyWith(
          _$AutoCompleteRuleMultipleImpl value,
          $Res Function(_$AutoCompleteRuleMultipleImpl) then) =
      __$$AutoCompleteRuleMultipleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<AutoCompleteRule> rules, int successes, String? title});
}

/// @nodoc
class __$$AutoCompleteRuleMultipleImplCopyWithImpl<$Res>
    extends _$AutoCompleteRuleCopyWithImpl<$Res, _$AutoCompleteRuleMultipleImpl>
    implements _$$AutoCompleteRuleMultipleImplCopyWith<$Res> {
  __$$AutoCompleteRuleMultipleImplCopyWithImpl(
      _$AutoCompleteRuleMultipleImpl _value,
      $Res Function(_$AutoCompleteRuleMultipleImpl) _then)
      : super(_value, _then);

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? rules = null,
    Object? successes = null,
    Object? title = freezed,
  }) {
    return _then(_$AutoCompleteRuleMultipleImpl(
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
class _$AutoCompleteRuleMultipleImpl implements AutoCompleteRuleMultiple {
  const _$AutoCompleteRuleMultipleImpl(
      {required final List<AutoCompleteRule> rules,
      required this.successes,
      this.title,
      final String? $type})
      : _rules = rules,
        $type = $type ?? 'multiple';

  factory _$AutoCompleteRuleMultipleImpl.fromJson(Map<String, dynamic> json) =>
      _$$AutoCompleteRuleMultipleImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AutoCompleteRuleMultipleImpl &&
            const DeepCollectionEquality().equals(other._rules, _rules) &&
            (identical(other.successes, successes) ||
                other.successes == successes) &&
            (identical(other.title, title) || other.title == title));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType,
      const DeepCollectionEquality().hash(_rules), successes, title);

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AutoCompleteRuleMultipleImplCopyWith<_$AutoCompleteRuleMultipleImpl>
      get copyWith => __$$AutoCompleteRuleMultipleImplCopyWithImpl<
          _$AutoCompleteRuleMultipleImpl>(this, _$identity);

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
    return _$$AutoCompleteRuleMultipleImplToJson(
      this,
    );
  }
}

abstract class AutoCompleteRuleMultiple implements AutoCompleteRule {
  const factory AutoCompleteRuleMultiple(
      {required final List<AutoCompleteRule> rules,
      required final int successes,
      final String? title}) = _$AutoCompleteRuleMultipleImpl;

  factory AutoCompleteRuleMultiple.fromJson(Map<String, dynamic> json) =
      _$AutoCompleteRuleMultipleImpl.fromJson;

  List<AutoCompleteRule> get rules;
  int get successes;
  @override
  String? get title;

  /// Create a copy of AutoCompleteRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AutoCompleteRuleMultipleImplCopyWith<_$AutoCompleteRuleMultipleImpl>
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
            bool? favorite,
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
            bool? favorite,
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
            bool? favorite,
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

  /// Serializes this EntityDefinition to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EntityDefinition
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
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
abstract class _$$MeasurableDataTypeImplCopyWith<$Res>
    implements $EntityDefinitionCopyWith<$Res> {
  factory _$$MeasurableDataTypeImplCopyWith(_$MeasurableDataTypeImpl value,
          $Res Function(_$MeasurableDataTypeImpl) then) =
      __$$MeasurableDataTypeImplCopyWithImpl<$Res>;
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
class __$$MeasurableDataTypeImplCopyWithImpl<$Res>
    extends _$EntityDefinitionCopyWithImpl<$Res, _$MeasurableDataTypeImpl>
    implements _$$MeasurableDataTypeImplCopyWith<$Res> {
  __$$MeasurableDataTypeImplCopyWithImpl(_$MeasurableDataTypeImpl _value,
      $Res Function(_$MeasurableDataTypeImpl) _then)
      : super(_value, _then);

  /// Create a copy of EntityDefinition
  /// with the given fields replaced by the non-null parameter values.
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
    return _then(_$MeasurableDataTypeImpl(
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
class _$MeasurableDataTypeImpl implements MeasurableDataType {
  const _$MeasurableDataTypeImpl(
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

  factory _$MeasurableDataTypeImpl.fromJson(Map<String, dynamic> json) =>
      _$$MeasurableDataTypeImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MeasurableDataTypeImpl &&
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

  /// Create a copy of EntityDefinition
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MeasurableDataTypeImplCopyWith<_$MeasurableDataTypeImpl> get copyWith =>
      __$$MeasurableDataTypeImplCopyWithImpl<_$MeasurableDataTypeImpl>(
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
            bool? favorite,
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
            bool? favorite,
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
            bool? favorite,
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
    return _$$MeasurableDataTypeImplToJson(
      this,
    );
  }
}

abstract class MeasurableDataType implements EntityDefinition {
  const factory MeasurableDataType(
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
      final AggregationType? aggregationType}) = _$MeasurableDataTypeImpl;

  factory MeasurableDataType.fromJson(Map<String, dynamic> json) =
      _$MeasurableDataTypeImpl.fromJson;

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

  /// Create a copy of EntityDefinition
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MeasurableDataTypeImplCopyWith<_$MeasurableDataTypeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$CategoryDefinitionImplCopyWith<$Res>
    implements $EntityDefinitionCopyWith<$Res> {
  factory _$$CategoryDefinitionImplCopyWith(_$CategoryDefinitionImpl value,
          $Res Function(_$CategoryDefinitionImpl) then) =
      __$$CategoryDefinitionImplCopyWithImpl<$Res>;
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
      DateTime? deletedAt});
}

/// @nodoc
class __$$CategoryDefinitionImplCopyWithImpl<$Res>
    extends _$EntityDefinitionCopyWithImpl<$Res, _$CategoryDefinitionImpl>
    implements _$$CategoryDefinitionImplCopyWith<$Res> {
  __$$CategoryDefinitionImplCopyWithImpl(_$CategoryDefinitionImpl _value,
      $Res Function(_$CategoryDefinitionImpl) _then)
      : super(_value, _then);

  /// Create a copy of EntityDefinition
  /// with the given fields replaced by the non-null parameter values.
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
    Object? favorite = freezed,
    Object? color = freezed,
    Object? categoryId = freezed,
    Object? deletedAt = freezed,
  }) {
    return _then(_$CategoryDefinitionImpl(
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
      favorite: freezed == favorite
          ? _value.favorite
          : favorite // ignore: cast_nullable_to_non_nullable
              as bool?,
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
class _$CategoryDefinitionImpl implements CategoryDefinition {
  const _$CategoryDefinitionImpl(
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
      final String? $type})
      : $type = $type ?? 'categoryDefinition';

  factory _$CategoryDefinitionImpl.fromJson(Map<String, dynamic> json) =>
      _$$CategoryDefinitionImplFromJson(json);

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
  final bool? favorite;
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
    return 'EntityDefinition.categoryDefinition(id: $id, createdAt: $createdAt, updatedAt: $updatedAt, name: $name, vectorClock: $vectorClock, private: $private, active: $active, favorite: $favorite, color: $color, categoryId: $categoryId, deletedAt: $deletedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CategoryDefinitionImpl &&
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
                other.deletedAt == deletedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, createdAt, updatedAt, name,
      vectorClock, private, active, favorite, color, categoryId, deletedAt);

  /// Create a copy of EntityDefinition
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CategoryDefinitionImplCopyWith<_$CategoryDefinitionImpl> get copyWith =>
      __$$CategoryDefinitionImplCopyWithImpl<_$CategoryDefinitionImpl>(
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
            bool? favorite,
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
        private, active, favorite, color, categoryId, deletedAt);
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
            bool? favorite,
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
        private, active, favorite, color, categoryId, deletedAt);
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
            bool? favorite,
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
          private, active, favorite, color, categoryId, deletedAt);
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
    return _$$CategoryDefinitionImplToJson(
      this,
    );
  }
}

abstract class CategoryDefinition implements EntityDefinition {
  const factory CategoryDefinition(
      {required final String id,
      required final DateTime createdAt,
      required final DateTime updatedAt,
      required final String name,
      required final VectorClock? vectorClock,
      required final bool private,
      required final bool active,
      final bool? favorite,
      final String? color,
      final String? categoryId,
      final DateTime? deletedAt}) = _$CategoryDefinitionImpl;

  factory CategoryDefinition.fromJson(Map<String, dynamic> json) =
      _$CategoryDefinitionImpl.fromJson;

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
  bool? get favorite;
  String? get color;
  @override
  String? get categoryId;
  @override
  DateTime? get deletedAt;

  /// Create a copy of EntityDefinition
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CategoryDefinitionImplCopyWith<_$CategoryDefinitionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$HabitDefinitionImplCopyWith<$Res>
    implements $EntityDefinitionCopyWith<$Res> {
  factory _$$HabitDefinitionImplCopyWith(_$HabitDefinitionImpl value,
          $Res Function(_$HabitDefinitionImpl) then) =
      __$$HabitDefinitionImplCopyWithImpl<$Res>;
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
class __$$HabitDefinitionImplCopyWithImpl<$Res>
    extends _$EntityDefinitionCopyWithImpl<$Res, _$HabitDefinitionImpl>
    implements _$$HabitDefinitionImplCopyWith<$Res> {
  __$$HabitDefinitionImplCopyWithImpl(
      _$HabitDefinitionImpl _value, $Res Function(_$HabitDefinitionImpl) _then)
      : super(_value, _then);

  /// Create a copy of EntityDefinition
  /// with the given fields replaced by the non-null parameter values.
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
    return _then(_$HabitDefinitionImpl(
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

  /// Create a copy of EntityDefinition
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $HabitScheduleCopyWith<$Res> get habitSchedule {
    return $HabitScheduleCopyWith<$Res>(_value.habitSchedule, (value) {
      return _then(_value.copyWith(habitSchedule: value));
    });
  }

  /// Create a copy of EntityDefinition
  /// with the given fields replaced by the non-null parameter values.
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
class _$HabitDefinitionImpl implements HabitDefinition {
  const _$HabitDefinitionImpl(
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

  factory _$HabitDefinitionImpl.fromJson(Map<String, dynamic> json) =>
      _$$HabitDefinitionImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HabitDefinitionImpl &&
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

  /// Create a copy of EntityDefinition
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HabitDefinitionImplCopyWith<_$HabitDefinitionImpl> get copyWith =>
      __$$HabitDefinitionImplCopyWithImpl<_$HabitDefinitionImpl>(
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
            bool? favorite,
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
            bool? favorite,
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
            bool? favorite,
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
    return _$$HabitDefinitionImplToJson(
      this,
    );
  }
}

abstract class HabitDefinition implements EntityDefinition {
  const factory HabitDefinition(
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
      final bool? priority}) = _$HabitDefinitionImpl;

  factory HabitDefinition.fromJson(Map<String, dynamic> json) =
      _$HabitDefinitionImpl.fromJson;

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

  /// Create a copy of EntityDefinition
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HabitDefinitionImplCopyWith<_$HabitDefinitionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$DashboardDefinitionImplCopyWith<$Res>
    implements $EntityDefinitionCopyWith<$Res> {
  factory _$$DashboardDefinitionImplCopyWith(_$DashboardDefinitionImpl value,
          $Res Function(_$DashboardDefinitionImpl) then) =
      __$$DashboardDefinitionImplCopyWithImpl<$Res>;
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
class __$$DashboardDefinitionImplCopyWithImpl<$Res>
    extends _$EntityDefinitionCopyWithImpl<$Res, _$DashboardDefinitionImpl>
    implements _$$DashboardDefinitionImplCopyWith<$Res> {
  __$$DashboardDefinitionImplCopyWithImpl(_$DashboardDefinitionImpl _value,
      $Res Function(_$DashboardDefinitionImpl) _then)
      : super(_value, _then);

  /// Create a copy of EntityDefinition
  /// with the given fields replaced by the non-null parameter values.
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
    return _then(_$DashboardDefinitionImpl(
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
class _$DashboardDefinitionImpl implements DashboardDefinition {
  const _$DashboardDefinitionImpl(
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

  factory _$DashboardDefinitionImpl.fromJson(Map<String, dynamic> json) =>
      _$$DashboardDefinitionImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DashboardDefinitionImpl &&
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

  /// Create a copy of EntityDefinition
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DashboardDefinitionImplCopyWith<_$DashboardDefinitionImpl> get copyWith =>
      __$$DashboardDefinitionImplCopyWithImpl<_$DashboardDefinitionImpl>(
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
            bool? favorite,
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
            bool? favorite,
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
            bool? favorite,
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
    return _$$DashboardDefinitionImplToJson(
      this,
    );
  }
}

abstract class DashboardDefinition implements EntityDefinition {
  const factory DashboardDefinition(
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
      final String? categoryId}) = _$DashboardDefinitionImpl;

  factory DashboardDefinition.fromJson(Map<String, dynamic> json) =
      _$DashboardDefinitionImpl.fromJson;

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

  /// Create a copy of EntityDefinition
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DashboardDefinitionImplCopyWith<_$DashboardDefinitionImpl> get copyWith =>
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

  /// Serializes this MeasurementData to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MeasurementData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
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
abstract class _$$MeasurementDataImplCopyWith<$Res>
    implements $MeasurementDataCopyWith<$Res> {
  factory _$$MeasurementDataImplCopyWith(_$MeasurementDataImpl value,
          $Res Function(_$MeasurementDataImpl) then) =
      __$$MeasurementDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({DateTime dateFrom, DateTime dateTo, num value, String dataTypeId});
}

/// @nodoc
class __$$MeasurementDataImplCopyWithImpl<$Res>
    extends _$MeasurementDataCopyWithImpl<$Res, _$MeasurementDataImpl>
    implements _$$MeasurementDataImplCopyWith<$Res> {
  __$$MeasurementDataImplCopyWithImpl(
      _$MeasurementDataImpl _value, $Res Function(_$MeasurementDataImpl) _then)
      : super(_value, _then);

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
    return _then(_$MeasurementDataImpl(
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
class _$MeasurementDataImpl implements _MeasurementData {
  const _$MeasurementDataImpl(
      {required this.dateFrom,
      required this.dateTo,
      required this.value,
      required this.dataTypeId});

  factory _$MeasurementDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$MeasurementDataImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MeasurementDataImpl &&
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

  /// Create a copy of MeasurementData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MeasurementDataImplCopyWith<_$MeasurementDataImpl> get copyWith =>
      __$$MeasurementDataImplCopyWithImpl<_$MeasurementDataImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MeasurementDataImplToJson(
      this,
    );
  }
}

abstract class _MeasurementData implements MeasurementData {
  const factory _MeasurementData(
      {required final DateTime dateFrom,
      required final DateTime dateTo,
      required final num value,
      required final String dataTypeId}) = _$MeasurementDataImpl;

  factory _MeasurementData.fromJson(Map<String, dynamic> json) =
      _$MeasurementDataImpl.fromJson;

  @override
  DateTime get dateFrom;
  @override
  DateTime get dateTo;
  @override
  num get value;
  @override
  String get dataTypeId;

  /// Create a copy of MeasurementData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MeasurementDataImplCopyWith<_$MeasurementDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AiResponseData _$AiResponseDataFromJson(Map<String, dynamic> json) {
  return _AiResponseData.fromJson(json);
}

/// @nodoc
mixin _$AiResponseData {
  String get model => throw _privateConstructorUsedError;
  String get systemMessage => throw _privateConstructorUsedError;
  String get prompt => throw _privateConstructorUsedError;
  String get thoughts => throw _privateConstructorUsedError;
  String get response => throw _privateConstructorUsedError;
  List<AiActionItem>? get suggestedActionItems =>
      throw _privateConstructorUsedError;
  AiResponseType? get type => throw _privateConstructorUsedError;
  double? get temperature => throw _privateConstructorUsedError;

  /// Serializes this AiResponseData to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AiResponseData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AiResponseDataCopyWith<AiResponseData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AiResponseDataCopyWith<$Res> {
  factory $AiResponseDataCopyWith(
          AiResponseData value, $Res Function(AiResponseData) then) =
      _$AiResponseDataCopyWithImpl<$Res, AiResponseData>;
  @useResult
  $Res call(
      {String model,
      String systemMessage,
      String prompt,
      String thoughts,
      String response,
      List<AiActionItem>? suggestedActionItems,
      AiResponseType? type,
      double? temperature});
}

/// @nodoc
class _$AiResponseDataCopyWithImpl<$Res, $Val extends AiResponseData>
    implements $AiResponseDataCopyWith<$Res> {
  _$AiResponseDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

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
    Object? suggestedActionItems = freezed,
    Object? type = freezed,
    Object? temperature = freezed,
  }) {
    return _then(_value.copyWith(
      model: null == model
          ? _value.model
          : model // ignore: cast_nullable_to_non_nullable
              as String,
      systemMessage: null == systemMessage
          ? _value.systemMessage
          : systemMessage // ignore: cast_nullable_to_non_nullable
              as String,
      prompt: null == prompt
          ? _value.prompt
          : prompt // ignore: cast_nullable_to_non_nullable
              as String,
      thoughts: null == thoughts
          ? _value.thoughts
          : thoughts // ignore: cast_nullable_to_non_nullable
              as String,
      response: null == response
          ? _value.response
          : response // ignore: cast_nullable_to_non_nullable
              as String,
      suggestedActionItems: freezed == suggestedActionItems
          ? _value.suggestedActionItems
          : suggestedActionItems // ignore: cast_nullable_to_non_nullable
              as List<AiActionItem>?,
      type: freezed == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as AiResponseType?,
      temperature: freezed == temperature
          ? _value.temperature
          : temperature // ignore: cast_nullable_to_non_nullable
              as double?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AiResponseDataImplCopyWith<$Res>
    implements $AiResponseDataCopyWith<$Res> {
  factory _$$AiResponseDataImplCopyWith(_$AiResponseDataImpl value,
          $Res Function(_$AiResponseDataImpl) then) =
      __$$AiResponseDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String model,
      String systemMessage,
      String prompt,
      String thoughts,
      String response,
      List<AiActionItem>? suggestedActionItems,
      AiResponseType? type,
      double? temperature});
}

/// @nodoc
class __$$AiResponseDataImplCopyWithImpl<$Res>
    extends _$AiResponseDataCopyWithImpl<$Res, _$AiResponseDataImpl>
    implements _$$AiResponseDataImplCopyWith<$Res> {
  __$$AiResponseDataImplCopyWithImpl(
      _$AiResponseDataImpl _value, $Res Function(_$AiResponseDataImpl) _then)
      : super(_value, _then);

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
    Object? suggestedActionItems = freezed,
    Object? type = freezed,
    Object? temperature = freezed,
  }) {
    return _then(_$AiResponseDataImpl(
      model: null == model
          ? _value.model
          : model // ignore: cast_nullable_to_non_nullable
              as String,
      systemMessage: null == systemMessage
          ? _value.systemMessage
          : systemMessage // ignore: cast_nullable_to_non_nullable
              as String,
      prompt: null == prompt
          ? _value.prompt
          : prompt // ignore: cast_nullable_to_non_nullable
              as String,
      thoughts: null == thoughts
          ? _value.thoughts
          : thoughts // ignore: cast_nullable_to_non_nullable
              as String,
      response: null == response
          ? _value.response
          : response // ignore: cast_nullable_to_non_nullable
              as String,
      suggestedActionItems: freezed == suggestedActionItems
          ? _value._suggestedActionItems
          : suggestedActionItems // ignore: cast_nullable_to_non_nullable
              as List<AiActionItem>?,
      type: freezed == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as AiResponseType?,
      temperature: freezed == temperature
          ? _value.temperature
          : temperature // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AiResponseDataImpl implements _AiResponseData {
  const _$AiResponseDataImpl(
      {required this.model,
      required this.systemMessage,
      required this.prompt,
      required this.thoughts,
      required this.response,
      final List<AiActionItem>? suggestedActionItems,
      this.type,
      this.temperature})
      : _suggestedActionItems = suggestedActionItems;

  factory _$AiResponseDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$AiResponseDataImplFromJson(json);

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

  @override
  String toString() {
    return 'AiResponseData(model: $model, systemMessage: $systemMessage, prompt: $prompt, thoughts: $thoughts, response: $response, suggestedActionItems: $suggestedActionItems, type: $type, temperature: $temperature)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AiResponseDataImpl &&
            (identical(other.model, model) || other.model == model) &&
            (identical(other.systemMessage, systemMessage) ||
                other.systemMessage == systemMessage) &&
            (identical(other.prompt, prompt) || other.prompt == prompt) &&
            (identical(other.thoughts, thoughts) ||
                other.thoughts == thoughts) &&
            (identical(other.response, response) ||
                other.response == response) &&
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
      const DeepCollectionEquality().hash(_suggestedActionItems),
      type,
      temperature);

  /// Create a copy of AiResponseData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AiResponseDataImplCopyWith<_$AiResponseDataImpl> get copyWith =>
      __$$AiResponseDataImplCopyWithImpl<_$AiResponseDataImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AiResponseDataImplToJson(
      this,
    );
  }
}

abstract class _AiResponseData implements AiResponseData {
  const factory _AiResponseData(
      {required final String model,
      required final String systemMessage,
      required final String prompt,
      required final String thoughts,
      required final String response,
      final List<AiActionItem>? suggestedActionItems,
      final AiResponseType? type,
      final double? temperature}) = _$AiResponseDataImpl;

  factory _AiResponseData.fromJson(Map<String, dynamic> json) =
      _$AiResponseDataImpl.fromJson;

  @override
  String get model;
  @override
  String get systemMessage;
  @override
  String get prompt;
  @override
  String get thoughts;
  @override
  String get response;
  @override
  List<AiActionItem>? get suggestedActionItems;
  @override
  AiResponseType? get type;
  @override
  double? get temperature;

  /// Create a copy of AiResponseData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AiResponseDataImplCopyWith<_$AiResponseDataImpl> get copyWith =>
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

  /// Serializes this WorkoutData to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WorkoutData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
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
abstract class _$$WorkoutDataImplCopyWith<$Res>
    implements $WorkoutDataCopyWith<$Res> {
  factory _$$WorkoutDataImplCopyWith(
          _$WorkoutDataImpl value, $Res Function(_$WorkoutDataImpl) then) =
      __$$WorkoutDataImplCopyWithImpl<$Res>;
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
class __$$WorkoutDataImplCopyWithImpl<$Res>
    extends _$WorkoutDataCopyWithImpl<$Res, _$WorkoutDataImpl>
    implements _$$WorkoutDataImplCopyWith<$Res> {
  __$$WorkoutDataImplCopyWithImpl(
      _$WorkoutDataImpl _value, $Res Function(_$WorkoutDataImpl) _then)
      : super(_value, _then);

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
    return _then(_$WorkoutDataImpl(
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
class _$WorkoutDataImpl implements _WorkoutData {
  const _$WorkoutDataImpl(
      {required this.dateFrom,
      required this.dateTo,
      required this.id,
      required this.workoutType,
      required this.energy,
      required this.distance,
      required this.source});

  factory _$WorkoutDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$WorkoutDataImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WorkoutDataImpl &&
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

  /// Create a copy of WorkoutData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WorkoutDataImplCopyWith<_$WorkoutDataImpl> get copyWith =>
      __$$WorkoutDataImplCopyWithImpl<_$WorkoutDataImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WorkoutDataImplToJson(
      this,
    );
  }
}

abstract class _WorkoutData implements WorkoutData {
  const factory _WorkoutData(
      {required final DateTime dateFrom,
      required final DateTime dateTo,
      required final String id,
      required final String workoutType,
      required final num? energy,
      required final num? distance,
      required final String? source}) = _$WorkoutDataImpl;

  factory _WorkoutData.fromJson(Map<String, dynamic> json) =
      _$WorkoutDataImpl.fromJson;

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

  /// Create a copy of WorkoutData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WorkoutDataImplCopyWith<_$WorkoutDataImpl> get copyWith =>
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

  /// Serializes this HabitCompletionData to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of HabitCompletionData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
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
abstract class _$$HabitCompletionDataImplCopyWith<$Res>
    implements $HabitCompletionDataCopyWith<$Res> {
  factory _$$HabitCompletionDataImplCopyWith(_$HabitCompletionDataImpl value,
          $Res Function(_$HabitCompletionDataImpl) then) =
      __$$HabitCompletionDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {DateTime dateFrom,
      DateTime dateTo,
      String habitId,
      HabitCompletionType? completionType});
}

/// @nodoc
class __$$HabitCompletionDataImplCopyWithImpl<$Res>
    extends _$HabitCompletionDataCopyWithImpl<$Res, _$HabitCompletionDataImpl>
    implements _$$HabitCompletionDataImplCopyWith<$Res> {
  __$$HabitCompletionDataImplCopyWithImpl(_$HabitCompletionDataImpl _value,
      $Res Function(_$HabitCompletionDataImpl) _then)
      : super(_value, _then);

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
    return _then(_$HabitCompletionDataImpl(
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
class _$HabitCompletionDataImpl implements _HabitCompletionData {
  const _$HabitCompletionDataImpl(
      {required this.dateFrom,
      required this.dateTo,
      required this.habitId,
      this.completionType});

  factory _$HabitCompletionDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$HabitCompletionDataImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HabitCompletionDataImpl &&
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

  /// Create a copy of HabitCompletionData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HabitCompletionDataImplCopyWith<_$HabitCompletionDataImpl> get copyWith =>
      __$$HabitCompletionDataImplCopyWithImpl<_$HabitCompletionDataImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$HabitCompletionDataImplToJson(
      this,
    );
  }
}

abstract class _HabitCompletionData implements HabitCompletionData {
  const factory _HabitCompletionData(
      {required final DateTime dateFrom,
      required final DateTime dateTo,
      required final String habitId,
      final HabitCompletionType? completionType}) = _$HabitCompletionDataImpl;

  factory _HabitCompletionData.fromJson(Map<String, dynamic> json) =
      _$HabitCompletionDataImpl.fromJson;

  @override
  DateTime get dateFrom;
  @override
  DateTime get dateTo;
  @override
  String get habitId;
  @override
  HabitCompletionType? get completionType;

  /// Create a copy of HabitCompletionData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HabitCompletionDataImplCopyWith<_$HabitCompletionDataImpl> get copyWith =>
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

  /// Serializes this DashboardItem to a JSON map.
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

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$DashboardMeasurementItemImplCopyWith<$Res> {
  factory _$$DashboardMeasurementItemImplCopyWith(
          _$DashboardMeasurementItemImpl value,
          $Res Function(_$DashboardMeasurementItemImpl) then) =
      __$$DashboardMeasurementItemImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String id, AggregationType? aggregationType});
}

/// @nodoc
class __$$DashboardMeasurementItemImplCopyWithImpl<$Res>
    extends _$DashboardItemCopyWithImpl<$Res, _$DashboardMeasurementItemImpl>
    implements _$$DashboardMeasurementItemImplCopyWith<$Res> {
  __$$DashboardMeasurementItemImplCopyWithImpl(
      _$DashboardMeasurementItemImpl _value,
      $Res Function(_$DashboardMeasurementItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? aggregationType = freezed,
  }) {
    return _then(_$DashboardMeasurementItemImpl(
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
class _$DashboardMeasurementItemImpl implements DashboardMeasurementItem {
  const _$DashboardMeasurementItemImpl(
      {required this.id, this.aggregationType, final String? $type})
      : $type = $type ?? 'measurement';

  factory _$DashboardMeasurementItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$DashboardMeasurementItemImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DashboardMeasurementItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.aggregationType, aggregationType) ||
                other.aggregationType == aggregationType));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, aggregationType);

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DashboardMeasurementItemImplCopyWith<_$DashboardMeasurementItemImpl>
      get copyWith => __$$DashboardMeasurementItemImplCopyWithImpl<
          _$DashboardMeasurementItemImpl>(this, _$identity);

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
    return _$$DashboardMeasurementItemImplToJson(
      this,
    );
  }
}

abstract class DashboardMeasurementItem implements DashboardItem {
  const factory DashboardMeasurementItem(
      {required final String id,
      final AggregationType? aggregationType}) = _$DashboardMeasurementItemImpl;

  factory DashboardMeasurementItem.fromJson(Map<String, dynamic> json) =
      _$DashboardMeasurementItemImpl.fromJson;

  String get id;
  AggregationType? get aggregationType;

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DashboardMeasurementItemImplCopyWith<_$DashboardMeasurementItemImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$DashboardHealthItemImplCopyWith<$Res> {
  factory _$$DashboardHealthItemImplCopyWith(_$DashboardHealthItemImpl value,
          $Res Function(_$DashboardHealthItemImpl) then) =
      __$$DashboardHealthItemImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String color, String healthType});
}

/// @nodoc
class __$$DashboardHealthItemImplCopyWithImpl<$Res>
    extends _$DashboardItemCopyWithImpl<$Res, _$DashboardHealthItemImpl>
    implements _$$DashboardHealthItemImplCopyWith<$Res> {
  __$$DashboardHealthItemImplCopyWithImpl(_$DashboardHealthItemImpl _value,
      $Res Function(_$DashboardHealthItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? color = null,
    Object? healthType = null,
  }) {
    return _then(_$DashboardHealthItemImpl(
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
class _$DashboardHealthItemImpl implements DashboardHealthItem {
  const _$DashboardHealthItemImpl(
      {required this.color, required this.healthType, final String? $type})
      : $type = $type ?? 'healthChart';

  factory _$DashboardHealthItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$DashboardHealthItemImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DashboardHealthItemImpl &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.healthType, healthType) ||
                other.healthType == healthType));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, color, healthType);

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DashboardHealthItemImplCopyWith<_$DashboardHealthItemImpl> get copyWith =>
      __$$DashboardHealthItemImplCopyWithImpl<_$DashboardHealthItemImpl>(
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
    return _$$DashboardHealthItemImplToJson(
      this,
    );
  }
}

abstract class DashboardHealthItem implements DashboardItem {
  const factory DashboardHealthItem(
      {required final String color,
      required final String healthType}) = _$DashboardHealthItemImpl;

  factory DashboardHealthItem.fromJson(Map<String, dynamic> json) =
      _$DashboardHealthItemImpl.fromJson;

  String get color;
  String get healthType;

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DashboardHealthItemImplCopyWith<_$DashboardHealthItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$DashboardWorkoutItemImplCopyWith<$Res> {
  factory _$$DashboardWorkoutItemImplCopyWith(_$DashboardWorkoutItemImpl value,
          $Res Function(_$DashboardWorkoutItemImpl) then) =
      __$$DashboardWorkoutItemImplCopyWithImpl<$Res>;
  @useResult
  $Res call(
      {String workoutType,
      String displayName,
      String color,
      WorkoutValueType valueType});
}

/// @nodoc
class __$$DashboardWorkoutItemImplCopyWithImpl<$Res>
    extends _$DashboardItemCopyWithImpl<$Res, _$DashboardWorkoutItemImpl>
    implements _$$DashboardWorkoutItemImplCopyWith<$Res> {
  __$$DashboardWorkoutItemImplCopyWithImpl(_$DashboardWorkoutItemImpl _value,
      $Res Function(_$DashboardWorkoutItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? workoutType = null,
    Object? displayName = null,
    Object? color = null,
    Object? valueType = null,
  }) {
    return _then(_$DashboardWorkoutItemImpl(
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
class _$DashboardWorkoutItemImpl implements DashboardWorkoutItem {
  const _$DashboardWorkoutItemImpl(
      {required this.workoutType,
      required this.displayName,
      required this.color,
      required this.valueType,
      final String? $type})
      : $type = $type ?? 'workoutChart';

  factory _$DashboardWorkoutItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$DashboardWorkoutItemImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DashboardWorkoutItemImpl &&
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

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DashboardWorkoutItemImplCopyWith<_$DashboardWorkoutItemImpl>
      get copyWith =>
          __$$DashboardWorkoutItemImplCopyWithImpl<_$DashboardWorkoutItemImpl>(
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
    return _$$DashboardWorkoutItemImplToJson(
      this,
    );
  }
}

abstract class DashboardWorkoutItem implements DashboardItem {
  const factory DashboardWorkoutItem(
      {required final String workoutType,
      required final String displayName,
      required final String color,
      required final WorkoutValueType valueType}) = _$DashboardWorkoutItemImpl;

  factory DashboardWorkoutItem.fromJson(Map<String, dynamic> json) =
      _$DashboardWorkoutItemImpl.fromJson;

  String get workoutType;
  String get displayName;
  String get color;
  WorkoutValueType get valueType;

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DashboardWorkoutItemImplCopyWith<_$DashboardWorkoutItemImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$DashboardHabitItemImplCopyWith<$Res> {
  factory _$$DashboardHabitItemImplCopyWith(_$DashboardHabitItemImpl value,
          $Res Function(_$DashboardHabitItemImpl) then) =
      __$$DashboardHabitItemImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String habitId});
}

/// @nodoc
class __$$DashboardHabitItemImplCopyWithImpl<$Res>
    extends _$DashboardItemCopyWithImpl<$Res, _$DashboardHabitItemImpl>
    implements _$$DashboardHabitItemImplCopyWith<$Res> {
  __$$DashboardHabitItemImplCopyWithImpl(_$DashboardHabitItemImpl _value,
      $Res Function(_$DashboardHabitItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? habitId = null,
  }) {
    return _then(_$DashboardHabitItemImpl(
      habitId: null == habitId
          ? _value.habitId
          : habitId // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DashboardHabitItemImpl implements DashboardHabitItem {
  const _$DashboardHabitItemImpl({required this.habitId, final String? $type})
      : $type = $type ?? 'habitChart';

  factory _$DashboardHabitItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$DashboardHabitItemImplFromJson(json);

  @override
  final String habitId;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'DashboardItem.habitChart(habitId: $habitId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DashboardHabitItemImpl &&
            (identical(other.habitId, habitId) || other.habitId == habitId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, habitId);

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DashboardHabitItemImplCopyWith<_$DashboardHabitItemImpl> get copyWith =>
      __$$DashboardHabitItemImplCopyWithImpl<_$DashboardHabitItemImpl>(
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
    return _$$DashboardHabitItemImplToJson(
      this,
    );
  }
}

abstract class DashboardHabitItem implements DashboardItem {
  const factory DashboardHabitItem({required final String habitId}) =
      _$DashboardHabitItemImpl;

  factory DashboardHabitItem.fromJson(Map<String, dynamic> json) =
      _$DashboardHabitItemImpl.fromJson;

  String get habitId;

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DashboardHabitItemImplCopyWith<_$DashboardHabitItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$DashboardSurveyItemImplCopyWith<$Res> {
  factory _$$DashboardSurveyItemImplCopyWith(_$DashboardSurveyItemImpl value,
          $Res Function(_$DashboardSurveyItemImpl) then) =
      __$$DashboardSurveyItemImplCopyWithImpl<$Res>;
  @useResult
  $Res call(
      {Map<String, String> colorsByScoreKey,
      String surveyType,
      String surveyName});
}

/// @nodoc
class __$$DashboardSurveyItemImplCopyWithImpl<$Res>
    extends _$DashboardItemCopyWithImpl<$Res, _$DashboardSurveyItemImpl>
    implements _$$DashboardSurveyItemImplCopyWith<$Res> {
  __$$DashboardSurveyItemImplCopyWithImpl(_$DashboardSurveyItemImpl _value,
      $Res Function(_$DashboardSurveyItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? colorsByScoreKey = null,
    Object? surveyType = null,
    Object? surveyName = null,
  }) {
    return _then(_$DashboardSurveyItemImpl(
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
class _$DashboardSurveyItemImpl implements DashboardSurveyItem {
  const _$DashboardSurveyItemImpl(
      {required final Map<String, String> colorsByScoreKey,
      required this.surveyType,
      required this.surveyName,
      final String? $type})
      : _colorsByScoreKey = colorsByScoreKey,
        $type = $type ?? 'surveyChart';

  factory _$DashboardSurveyItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$DashboardSurveyItemImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DashboardSurveyItemImpl &&
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

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DashboardSurveyItemImplCopyWith<_$DashboardSurveyItemImpl> get copyWith =>
      __$$DashboardSurveyItemImplCopyWithImpl<_$DashboardSurveyItemImpl>(
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
    return _$$DashboardSurveyItemImplToJson(
      this,
    );
  }
}

abstract class DashboardSurveyItem implements DashboardItem {
  const factory DashboardSurveyItem(
      {required final Map<String, String> colorsByScoreKey,
      required final String surveyType,
      required final String surveyName}) = _$DashboardSurveyItemImpl;

  factory DashboardSurveyItem.fromJson(Map<String, dynamic> json) =
      _$DashboardSurveyItemImpl.fromJson;

  Map<String, String> get colorsByScoreKey;
  String get surveyType;
  String get surveyName;

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DashboardSurveyItemImplCopyWith<_$DashboardSurveyItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$DashboardStoryTimeItemImplCopyWith<$Res> {
  factory _$$DashboardStoryTimeItemImplCopyWith(
          _$DashboardStoryTimeItemImpl value,
          $Res Function(_$DashboardStoryTimeItemImpl) then) =
      __$$DashboardStoryTimeItemImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String storyTagId, String color});
}

/// @nodoc
class __$$DashboardStoryTimeItemImplCopyWithImpl<$Res>
    extends _$DashboardItemCopyWithImpl<$Res, _$DashboardStoryTimeItemImpl>
    implements _$$DashboardStoryTimeItemImplCopyWith<$Res> {
  __$$DashboardStoryTimeItemImplCopyWithImpl(
      _$DashboardStoryTimeItemImpl _value,
      $Res Function(_$DashboardStoryTimeItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? storyTagId = null,
    Object? color = null,
  }) {
    return _then(_$DashboardStoryTimeItemImpl(
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
class _$DashboardStoryTimeItemImpl implements DashboardStoryTimeItem {
  const _$DashboardStoryTimeItemImpl(
      {required this.storyTagId, required this.color, final String? $type})
      : $type = $type ?? 'storyTimeChart';

  factory _$DashboardStoryTimeItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$DashboardStoryTimeItemImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DashboardStoryTimeItemImpl &&
            (identical(other.storyTagId, storyTagId) ||
                other.storyTagId == storyTagId) &&
            (identical(other.color, color) || other.color == color));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, storyTagId, color);

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DashboardStoryTimeItemImplCopyWith<_$DashboardStoryTimeItemImpl>
      get copyWith => __$$DashboardStoryTimeItemImplCopyWithImpl<
          _$DashboardStoryTimeItemImpl>(this, _$identity);

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
    return _$$DashboardStoryTimeItemImplToJson(
      this,
    );
  }
}

abstract class DashboardStoryTimeItem implements DashboardItem {
  const factory DashboardStoryTimeItem(
      {required final String storyTagId,
      required final String color}) = _$DashboardStoryTimeItemImpl;

  factory DashboardStoryTimeItem.fromJson(Map<String, dynamic> json) =
      _$DashboardStoryTimeItemImpl.fromJson;

  String get storyTagId;
  String get color;

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DashboardStoryTimeItemImplCopyWith<_$DashboardStoryTimeItemImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$WildcardStoryTimeItemImplCopyWith<$Res> {
  factory _$$WildcardStoryTimeItemImplCopyWith(
          _$WildcardStoryTimeItemImpl value,
          $Res Function(_$WildcardStoryTimeItemImpl) then) =
      __$$WildcardStoryTimeItemImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String storySubstring, String color});
}

/// @nodoc
class __$$WildcardStoryTimeItemImplCopyWithImpl<$Res>
    extends _$DashboardItemCopyWithImpl<$Res, _$WildcardStoryTimeItemImpl>
    implements _$$WildcardStoryTimeItemImplCopyWith<$Res> {
  __$$WildcardStoryTimeItemImplCopyWithImpl(_$WildcardStoryTimeItemImpl _value,
      $Res Function(_$WildcardStoryTimeItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? storySubstring = null,
    Object? color = null,
  }) {
    return _then(_$WildcardStoryTimeItemImpl(
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
class _$WildcardStoryTimeItemImpl implements WildcardStoryTimeItem {
  const _$WildcardStoryTimeItemImpl(
      {required this.storySubstring, required this.color, final String? $type})
      : $type = $type ?? 'wildcardStoryTimeChart';

  factory _$WildcardStoryTimeItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$WildcardStoryTimeItemImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WildcardStoryTimeItemImpl &&
            (identical(other.storySubstring, storySubstring) ||
                other.storySubstring == storySubstring) &&
            (identical(other.color, color) || other.color == color));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, storySubstring, color);

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WildcardStoryTimeItemImplCopyWith<_$WildcardStoryTimeItemImpl>
      get copyWith => __$$WildcardStoryTimeItemImplCopyWithImpl<
          _$WildcardStoryTimeItemImpl>(this, _$identity);

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
    return _$$WildcardStoryTimeItemImplToJson(
      this,
    );
  }
}

abstract class WildcardStoryTimeItem implements DashboardItem {
  const factory WildcardStoryTimeItem(
      {required final String storySubstring,
      required final String color}) = _$WildcardStoryTimeItemImpl;

  factory WildcardStoryTimeItem.fromJson(Map<String, dynamic> json) =
      _$WildcardStoryTimeItemImpl.fromJson;

  String get storySubstring;
  String get color;

  /// Create a copy of DashboardItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WildcardStoryTimeItemImplCopyWith<_$WildcardStoryTimeItemImpl>
      get copyWith => throw _privateConstructorUsedError;
}
