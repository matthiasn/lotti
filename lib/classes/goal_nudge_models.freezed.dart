// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'goal_nudge_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GoalNudgeBrief {

 String get sceneConcept; String get headline; String get altText; GoalNudgeTone get tone; String? get cta; String? get mood; String? get stylePreset;
/// Create a copy of GoalNudgeBrief
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoalNudgeBriefCopyWith<GoalNudgeBrief> get copyWith => _$GoalNudgeBriefCopyWithImpl<GoalNudgeBrief>(this as GoalNudgeBrief, _$identity);

  /// Serializes this GoalNudgeBrief to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoalNudgeBrief&&(identical(other.sceneConcept, sceneConcept) || other.sceneConcept == sceneConcept)&&(identical(other.headline, headline) || other.headline == headline)&&(identical(other.altText, altText) || other.altText == altText)&&(identical(other.tone, tone) || other.tone == tone)&&(identical(other.cta, cta) || other.cta == cta)&&(identical(other.mood, mood) || other.mood == mood)&&(identical(other.stylePreset, stylePreset) || other.stylePreset == stylePreset));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sceneConcept,headline,altText,tone,cta,mood,stylePreset);

@override
String toString() {
  return 'GoalNudgeBrief(sceneConcept: $sceneConcept, headline: $headline, altText: $altText, tone: $tone, cta: $cta, mood: $mood, stylePreset: $stylePreset)';
}


}

/// @nodoc
abstract mixin class $GoalNudgeBriefCopyWith<$Res>  {
  factory $GoalNudgeBriefCopyWith(GoalNudgeBrief value, $Res Function(GoalNudgeBrief) _then) = _$GoalNudgeBriefCopyWithImpl;
@useResult
$Res call({
 String sceneConcept, String headline, String altText, GoalNudgeTone tone, String? cta, String? mood, String? stylePreset
});




}
/// @nodoc
class _$GoalNudgeBriefCopyWithImpl<$Res>
    implements $GoalNudgeBriefCopyWith<$Res> {
  _$GoalNudgeBriefCopyWithImpl(this._self, this._then);

  final GoalNudgeBrief _self;
  final $Res Function(GoalNudgeBrief) _then;

/// Create a copy of GoalNudgeBrief
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sceneConcept = null,Object? headline = null,Object? altText = null,Object? tone = null,Object? cta = freezed,Object? mood = freezed,Object? stylePreset = freezed,}) {
  return _then(_self.copyWith(
sceneConcept: null == sceneConcept ? _self.sceneConcept : sceneConcept // ignore: cast_nullable_to_non_nullable
as String,headline: null == headline ? _self.headline : headline // ignore: cast_nullable_to_non_nullable
as String,altText: null == altText ? _self.altText : altText // ignore: cast_nullable_to_non_nullable
as String,tone: null == tone ? _self.tone : tone // ignore: cast_nullable_to_non_nullable
as GoalNudgeTone,cta: freezed == cta ? _self.cta : cta // ignore: cast_nullable_to_non_nullable
as String?,mood: freezed == mood ? _self.mood : mood // ignore: cast_nullable_to_non_nullable
as String?,stylePreset: freezed == stylePreset ? _self.stylePreset : stylePreset // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [GoalNudgeBrief].
extension GoalNudgeBriefPatterns on GoalNudgeBrief {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GoalNudgeBrief value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GoalNudgeBrief() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GoalNudgeBrief value)  $default,){
final _that = this;
switch (_that) {
case _GoalNudgeBrief():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GoalNudgeBrief value)?  $default,){
final _that = this;
switch (_that) {
case _GoalNudgeBrief() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sceneConcept,  String headline,  String altText,  GoalNudgeTone tone,  String? cta,  String? mood,  String? stylePreset)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GoalNudgeBrief() when $default != null:
return $default(_that.sceneConcept,_that.headline,_that.altText,_that.tone,_that.cta,_that.mood,_that.stylePreset);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sceneConcept,  String headline,  String altText,  GoalNudgeTone tone,  String? cta,  String? mood,  String? stylePreset)  $default,) {final _that = this;
switch (_that) {
case _GoalNudgeBrief():
return $default(_that.sceneConcept,_that.headline,_that.altText,_that.tone,_that.cta,_that.mood,_that.stylePreset);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sceneConcept,  String headline,  String altText,  GoalNudgeTone tone,  String? cta,  String? mood,  String? stylePreset)?  $default,) {final _that = this;
switch (_that) {
case _GoalNudgeBrief() when $default != null:
return $default(_that.sceneConcept,_that.headline,_that.altText,_that.tone,_that.cta,_that.mood,_that.stylePreset);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GoalNudgeBrief implements GoalNudgeBrief {
  const _GoalNudgeBrief({required this.sceneConcept, required this.headline, required this.altText, required this.tone, this.cta, this.mood, this.stylePreset});
  factory _GoalNudgeBrief.fromJson(Map<String, dynamic> json) => _$GoalNudgeBriefFromJson(json);

@override final  String sceneConcept;
@override final  String headline;
@override final  String altText;
@override final  GoalNudgeTone tone;
@override final  String? cta;
@override final  String? mood;
@override final  String? stylePreset;

/// Create a copy of GoalNudgeBrief
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GoalNudgeBriefCopyWith<_GoalNudgeBrief> get copyWith => __$GoalNudgeBriefCopyWithImpl<_GoalNudgeBrief>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GoalNudgeBriefToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GoalNudgeBrief&&(identical(other.sceneConcept, sceneConcept) || other.sceneConcept == sceneConcept)&&(identical(other.headline, headline) || other.headline == headline)&&(identical(other.altText, altText) || other.altText == altText)&&(identical(other.tone, tone) || other.tone == tone)&&(identical(other.cta, cta) || other.cta == cta)&&(identical(other.mood, mood) || other.mood == mood)&&(identical(other.stylePreset, stylePreset) || other.stylePreset == stylePreset));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sceneConcept,headline,altText,tone,cta,mood,stylePreset);

@override
String toString() {
  return 'GoalNudgeBrief(sceneConcept: $sceneConcept, headline: $headline, altText: $altText, tone: $tone, cta: $cta, mood: $mood, stylePreset: $stylePreset)';
}


}

/// @nodoc
abstract mixin class _$GoalNudgeBriefCopyWith<$Res> implements $GoalNudgeBriefCopyWith<$Res> {
  factory _$GoalNudgeBriefCopyWith(_GoalNudgeBrief value, $Res Function(_GoalNudgeBrief) _then) = __$GoalNudgeBriefCopyWithImpl;
@override @useResult
$Res call({
 String sceneConcept, String headline, String altText, GoalNudgeTone tone, String? cta, String? mood, String? stylePreset
});




}
/// @nodoc
class __$GoalNudgeBriefCopyWithImpl<$Res>
    implements _$GoalNudgeBriefCopyWith<$Res> {
  __$GoalNudgeBriefCopyWithImpl(this._self, this._then);

  final _GoalNudgeBrief _self;
  final $Res Function(_GoalNudgeBrief) _then;

/// Create a copy of GoalNudgeBrief
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sceneConcept = null,Object? headline = null,Object? altText = null,Object? tone = null,Object? cta = freezed,Object? mood = freezed,Object? stylePreset = freezed,}) {
  return _then(_GoalNudgeBrief(
sceneConcept: null == sceneConcept ? _self.sceneConcept : sceneConcept // ignore: cast_nullable_to_non_nullable
as String,headline: null == headline ? _self.headline : headline // ignore: cast_nullable_to_non_nullable
as String,altText: null == altText ? _self.altText : altText // ignore: cast_nullable_to_non_nullable
as String,tone: null == tone ? _self.tone : tone // ignore: cast_nullable_to_non_nullable
as GoalNudgeTone,cta: freezed == cta ? _self.cta : cta // ignore: cast_nullable_to_non_nullable
as String?,mood: freezed == mood ? _self.mood : mood // ignore: cast_nullable_to_non_nullable
as String?,stylePreset: freezed == stylePreset ? _self.stylePreset : stylePreset // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$GoalNudgeRating {

/// 1 (useless) .. 5 (loved it).
 int get rating; DateTime get ratedAt;
/// Create a copy of GoalNudgeRating
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoalNudgeRatingCopyWith<GoalNudgeRating> get copyWith => _$GoalNudgeRatingCopyWithImpl<GoalNudgeRating>(this as GoalNudgeRating, _$identity);

  /// Serializes this GoalNudgeRating to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoalNudgeRating&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.ratedAt, ratedAt) || other.ratedAt == ratedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,rating,ratedAt);

@override
String toString() {
  return 'GoalNudgeRating(rating: $rating, ratedAt: $ratedAt)';
}


}

/// @nodoc
abstract mixin class $GoalNudgeRatingCopyWith<$Res>  {
  factory $GoalNudgeRatingCopyWith(GoalNudgeRating value, $Res Function(GoalNudgeRating) _then) = _$GoalNudgeRatingCopyWithImpl;
@useResult
$Res call({
 int rating, DateTime ratedAt
});




}
/// @nodoc
class _$GoalNudgeRatingCopyWithImpl<$Res>
    implements $GoalNudgeRatingCopyWith<$Res> {
  _$GoalNudgeRatingCopyWithImpl(this._self, this._then);

  final GoalNudgeRating _self;
  final $Res Function(GoalNudgeRating) _then;

/// Create a copy of GoalNudgeRating
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rating = null,Object? ratedAt = null,}) {
  return _then(_self.copyWith(
rating: null == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as int,ratedAt: null == ratedAt ? _self.ratedAt : ratedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [GoalNudgeRating].
extension GoalNudgeRatingPatterns on GoalNudgeRating {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GoalNudgeRating value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GoalNudgeRating() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GoalNudgeRating value)  $default,){
final _that = this;
switch (_that) {
case _GoalNudgeRating():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GoalNudgeRating value)?  $default,){
final _that = this;
switch (_that) {
case _GoalNudgeRating() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int rating,  DateTime ratedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GoalNudgeRating() when $default != null:
return $default(_that.rating,_that.ratedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int rating,  DateTime ratedAt)  $default,) {final _that = this;
switch (_that) {
case _GoalNudgeRating():
return $default(_that.rating,_that.ratedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int rating,  DateTime ratedAt)?  $default,) {final _that = this;
switch (_that) {
case _GoalNudgeRating() when $default != null:
return $default(_that.rating,_that.ratedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GoalNudgeRating implements GoalNudgeRating {
  const _GoalNudgeRating({required this.rating, required this.ratedAt});
  factory _GoalNudgeRating.fromJson(Map<String, dynamic> json) => _$GoalNudgeRatingFromJson(json);

/// 1 (useless) .. 5 (loved it).
@override final  int rating;
@override final  DateTime ratedAt;

/// Create a copy of GoalNudgeRating
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GoalNudgeRatingCopyWith<_GoalNudgeRating> get copyWith => __$GoalNudgeRatingCopyWithImpl<_GoalNudgeRating>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GoalNudgeRatingToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GoalNudgeRating&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.ratedAt, ratedAt) || other.ratedAt == ratedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,rating,ratedAt);

@override
String toString() {
  return 'GoalNudgeRating(rating: $rating, ratedAt: $ratedAt)';
}


}

/// @nodoc
abstract mixin class _$GoalNudgeRatingCopyWith<$Res> implements $GoalNudgeRatingCopyWith<$Res> {
  factory _$GoalNudgeRatingCopyWith(_GoalNudgeRating value, $Res Function(_GoalNudgeRating) _then) = __$GoalNudgeRatingCopyWithImpl;
@override @useResult
$Res call({
 int rating, DateTime ratedAt
});




}
/// @nodoc
class __$GoalNudgeRatingCopyWithImpl<$Res>
    implements _$GoalNudgeRatingCopyWith<$Res> {
  __$GoalNudgeRatingCopyWithImpl(this._self, this._then);

  final _GoalNudgeRating _self;
  final $Res Function(_GoalNudgeRating) _then;

/// Create a copy of GoalNudgeRating
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? rating = null,Object? ratedAt = null,}) {
  return _then(_GoalNudgeRating(
rating: null == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as int,ratedAt: null == ratedAt ? _self.ratedAt : ratedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
