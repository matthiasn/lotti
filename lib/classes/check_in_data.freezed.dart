// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'check_in_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CheckInData {

/// The relationship this check-in belongs to, denormalized alongside the
/// `RelationshipLink` so `affectedIds` can emit it as a precise wake
/// token — the `HabitCompletionData.habitId` precedent.
 String get relationshipId; CheckInInteractionType get interactionType; CheckInSentiment? get sentiment;/// What was discussed.
 List<String> get topics;/// "Next time" guidance the executive briefing surfaces (ADR 0040).
 String? get payAttentionTo; String? get avoid;
/// Create a copy of CheckInData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CheckInDataCopyWith<CheckInData> get copyWith => _$CheckInDataCopyWithImpl<CheckInData>(this as CheckInData, _$identity);

  /// Serializes this CheckInData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CheckInData&&(identical(other.relationshipId, relationshipId) || other.relationshipId == relationshipId)&&(identical(other.interactionType, interactionType) || other.interactionType == interactionType)&&(identical(other.sentiment, sentiment) || other.sentiment == sentiment)&&const DeepCollectionEquality().equals(other.topics, topics)&&(identical(other.payAttentionTo, payAttentionTo) || other.payAttentionTo == payAttentionTo)&&(identical(other.avoid, avoid) || other.avoid == avoid));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,relationshipId,interactionType,sentiment,const DeepCollectionEquality().hash(topics),payAttentionTo,avoid);

@override
String toString() {
  return 'CheckInData(relationshipId: $relationshipId, interactionType: $interactionType, sentiment: $sentiment, topics: $topics, payAttentionTo: $payAttentionTo, avoid: $avoid)';
}


}

/// @nodoc
abstract mixin class $CheckInDataCopyWith<$Res>  {
  factory $CheckInDataCopyWith(CheckInData value, $Res Function(CheckInData) _then) = _$CheckInDataCopyWithImpl;
@useResult
$Res call({
 String relationshipId, CheckInInteractionType interactionType, CheckInSentiment? sentiment, List<String> topics, String? payAttentionTo, String? avoid
});




}
/// @nodoc
class _$CheckInDataCopyWithImpl<$Res>
    implements $CheckInDataCopyWith<$Res> {
  _$CheckInDataCopyWithImpl(this._self, this._then);

  final CheckInData _self;
  final $Res Function(CheckInData) _then;

/// Create a copy of CheckInData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? relationshipId = null,Object? interactionType = null,Object? sentiment = freezed,Object? topics = null,Object? payAttentionTo = freezed,Object? avoid = freezed,}) {
  return _then(_self.copyWith(
relationshipId: null == relationshipId ? _self.relationshipId : relationshipId // ignore: cast_nullable_to_non_nullable
as String,interactionType: null == interactionType ? _self.interactionType : interactionType // ignore: cast_nullable_to_non_nullable
as CheckInInteractionType,sentiment: freezed == sentiment ? _self.sentiment : sentiment // ignore: cast_nullable_to_non_nullable
as CheckInSentiment?,topics: null == topics ? _self.topics : topics // ignore: cast_nullable_to_non_nullable
as List<String>,payAttentionTo: freezed == payAttentionTo ? _self.payAttentionTo : payAttentionTo // ignore: cast_nullable_to_non_nullable
as String?,avoid: freezed == avoid ? _self.avoid : avoid // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CheckInData].
extension CheckInDataPatterns on CheckInData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CheckInData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CheckInData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CheckInData value)  $default,){
final _that = this;
switch (_that) {
case _CheckInData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CheckInData value)?  $default,){
final _that = this;
switch (_that) {
case _CheckInData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String relationshipId,  CheckInInteractionType interactionType,  CheckInSentiment? sentiment,  List<String> topics,  String? payAttentionTo,  String? avoid)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CheckInData() when $default != null:
return $default(_that.relationshipId,_that.interactionType,_that.sentiment,_that.topics,_that.payAttentionTo,_that.avoid);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String relationshipId,  CheckInInteractionType interactionType,  CheckInSentiment? sentiment,  List<String> topics,  String? payAttentionTo,  String? avoid)  $default,) {final _that = this;
switch (_that) {
case _CheckInData():
return $default(_that.relationshipId,_that.interactionType,_that.sentiment,_that.topics,_that.payAttentionTo,_that.avoid);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String relationshipId,  CheckInInteractionType interactionType,  CheckInSentiment? sentiment,  List<String> topics,  String? payAttentionTo,  String? avoid)?  $default,) {final _that = this;
switch (_that) {
case _CheckInData() when $default != null:
return $default(_that.relationshipId,_that.interactionType,_that.sentiment,_that.topics,_that.payAttentionTo,_that.avoid);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CheckInData implements CheckInData {
  const _CheckInData({required this.relationshipId, required this.interactionType, this.sentiment, final  List<String> topics = const [], this.payAttentionTo, this.avoid}): _topics = topics;
  factory _CheckInData.fromJson(Map<String, dynamic> json) => _$CheckInDataFromJson(json);

/// The relationship this check-in belongs to, denormalized alongside the
/// `RelationshipLink` so `affectedIds` can emit it as a precise wake
/// token — the `HabitCompletionData.habitId` precedent.
@override final  String relationshipId;
@override final  CheckInInteractionType interactionType;
@override final  CheckInSentiment? sentiment;
/// What was discussed.
 final  List<String> _topics;
/// What was discussed.
@override@JsonKey() List<String> get topics {
  if (_topics is EqualUnmodifiableListView) return _topics;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_topics);
}

/// "Next time" guidance the executive briefing surfaces (ADR 0040).
@override final  String? payAttentionTo;
@override final  String? avoid;

/// Create a copy of CheckInData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CheckInDataCopyWith<_CheckInData> get copyWith => __$CheckInDataCopyWithImpl<_CheckInData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CheckInDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CheckInData&&(identical(other.relationshipId, relationshipId) || other.relationshipId == relationshipId)&&(identical(other.interactionType, interactionType) || other.interactionType == interactionType)&&(identical(other.sentiment, sentiment) || other.sentiment == sentiment)&&const DeepCollectionEquality().equals(other._topics, _topics)&&(identical(other.payAttentionTo, payAttentionTo) || other.payAttentionTo == payAttentionTo)&&(identical(other.avoid, avoid) || other.avoid == avoid));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,relationshipId,interactionType,sentiment,const DeepCollectionEquality().hash(_topics),payAttentionTo,avoid);

@override
String toString() {
  return 'CheckInData(relationshipId: $relationshipId, interactionType: $interactionType, sentiment: $sentiment, topics: $topics, payAttentionTo: $payAttentionTo, avoid: $avoid)';
}


}

/// @nodoc
abstract mixin class _$CheckInDataCopyWith<$Res> implements $CheckInDataCopyWith<$Res> {
  factory _$CheckInDataCopyWith(_CheckInData value, $Res Function(_CheckInData) _then) = __$CheckInDataCopyWithImpl;
@override @useResult
$Res call({
 String relationshipId, CheckInInteractionType interactionType, CheckInSentiment? sentiment, List<String> topics, String? payAttentionTo, String? avoid
});




}
/// @nodoc
class __$CheckInDataCopyWithImpl<$Res>
    implements _$CheckInDataCopyWith<$Res> {
  __$CheckInDataCopyWithImpl(this._self, this._then);

  final _CheckInData _self;
  final $Res Function(_CheckInData) _then;

/// Create a copy of CheckInData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? relationshipId = null,Object? interactionType = null,Object? sentiment = freezed,Object? topics = null,Object? payAttentionTo = freezed,Object? avoid = freezed,}) {
  return _then(_CheckInData(
relationshipId: null == relationshipId ? _self.relationshipId : relationshipId // ignore: cast_nullable_to_non_nullable
as String,interactionType: null == interactionType ? _self.interactionType : interactionType // ignore: cast_nullable_to_non_nullable
as CheckInInteractionType,sentiment: freezed == sentiment ? _self.sentiment : sentiment // ignore: cast_nullable_to_non_nullable
as CheckInSentiment?,topics: null == topics ? _self._topics : topics // ignore: cast_nullable_to_non_nullable
as List<String>,payAttentionTo: freezed == payAttentionTo ? _self.payAttentionTo : payAttentionTo // ignore: cast_nullable_to_non_nullable
as String?,avoid: freezed == avoid ? _self.avoid : avoid // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
