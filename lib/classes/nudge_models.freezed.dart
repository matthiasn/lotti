// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'nudge_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NudgeBrief {

 String get headline; NudgeTone get tone; NudgeBannerAnimation get animation; NudgeBannerAccent get accent; String? get tagline; String? get cta;
/// Create a copy of NudgeBrief
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NudgeBriefCopyWith<NudgeBrief> get copyWith => _$NudgeBriefCopyWithImpl<NudgeBrief>(this as NudgeBrief, _$identity);

  /// Serializes this NudgeBrief to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NudgeBrief&&(identical(other.headline, headline) || other.headline == headline)&&(identical(other.tone, tone) || other.tone == tone)&&(identical(other.animation, animation) || other.animation == animation)&&(identical(other.accent, accent) || other.accent == accent)&&(identical(other.tagline, tagline) || other.tagline == tagline)&&(identical(other.cta, cta) || other.cta == cta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,headline,tone,animation,accent,tagline,cta);

@override
String toString() {
  return 'NudgeBrief(headline: $headline, tone: $tone, animation: $animation, accent: $accent, tagline: $tagline, cta: $cta)';
}


}

/// @nodoc
abstract mixin class $NudgeBriefCopyWith<$Res>  {
  factory $NudgeBriefCopyWith(NudgeBrief value, $Res Function(NudgeBrief) _then) = _$NudgeBriefCopyWithImpl;
@useResult
$Res call({
 String headline, NudgeTone tone, NudgeBannerAnimation animation, NudgeBannerAccent accent, String? tagline, String? cta
});




}
/// @nodoc
class _$NudgeBriefCopyWithImpl<$Res>
    implements $NudgeBriefCopyWith<$Res> {
  _$NudgeBriefCopyWithImpl(this._self, this._then);

  final NudgeBrief _self;
  final $Res Function(NudgeBrief) _then;

/// Create a copy of NudgeBrief
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? headline = null,Object? tone = null,Object? animation = null,Object? accent = null,Object? tagline = freezed,Object? cta = freezed,}) {
  return _then(_self.copyWith(
headline: null == headline ? _self.headline : headline // ignore: cast_nullable_to_non_nullable
as String,tone: null == tone ? _self.tone : tone // ignore: cast_nullable_to_non_nullable
as NudgeTone,animation: null == animation ? _self.animation : animation // ignore: cast_nullable_to_non_nullable
as NudgeBannerAnimation,accent: null == accent ? _self.accent : accent // ignore: cast_nullable_to_non_nullable
as NudgeBannerAccent,tagline: freezed == tagline ? _self.tagline : tagline // ignore: cast_nullable_to_non_nullable
as String?,cta: freezed == cta ? _self.cta : cta // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [NudgeBrief].
extension NudgeBriefPatterns on NudgeBrief {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NudgeBrief value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NudgeBrief() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NudgeBrief value)  $default,){
final _that = this;
switch (_that) {
case _NudgeBrief():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NudgeBrief value)?  $default,){
final _that = this;
switch (_that) {
case _NudgeBrief() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String headline,  NudgeTone tone,  NudgeBannerAnimation animation,  NudgeBannerAccent accent,  String? tagline,  String? cta)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NudgeBrief() when $default != null:
return $default(_that.headline,_that.tone,_that.animation,_that.accent,_that.tagline,_that.cta);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String headline,  NudgeTone tone,  NudgeBannerAnimation animation,  NudgeBannerAccent accent,  String? tagline,  String? cta)  $default,) {final _that = this;
switch (_that) {
case _NudgeBrief():
return $default(_that.headline,_that.tone,_that.animation,_that.accent,_that.tagline,_that.cta);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String headline,  NudgeTone tone,  NudgeBannerAnimation animation,  NudgeBannerAccent accent,  String? tagline,  String? cta)?  $default,) {final _that = this;
switch (_that) {
case _NudgeBrief() when $default != null:
return $default(_that.headline,_that.tone,_that.animation,_that.accent,_that.tagline,_that.cta);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NudgeBrief implements NudgeBrief {
  const _NudgeBrief({required this.headline, required this.tone, required this.animation, this.accent = NudgeBannerAccent.calm, this.tagline, this.cta});
  factory _NudgeBrief.fromJson(Map<String, dynamic> json) => _$NudgeBriefFromJson(json);

@override final  String headline;
@override final  NudgeTone tone;
@override final  NudgeBannerAnimation animation;
@override@JsonKey() final  NudgeBannerAccent accent;
@override final  String? tagline;
@override final  String? cta;

/// Create a copy of NudgeBrief
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NudgeBriefCopyWith<_NudgeBrief> get copyWith => __$NudgeBriefCopyWithImpl<_NudgeBrief>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NudgeBriefToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NudgeBrief&&(identical(other.headline, headline) || other.headline == headline)&&(identical(other.tone, tone) || other.tone == tone)&&(identical(other.animation, animation) || other.animation == animation)&&(identical(other.accent, accent) || other.accent == accent)&&(identical(other.tagline, tagline) || other.tagline == tagline)&&(identical(other.cta, cta) || other.cta == cta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,headline,tone,animation,accent,tagline,cta);

@override
String toString() {
  return 'NudgeBrief(headline: $headline, tone: $tone, animation: $animation, accent: $accent, tagline: $tagline, cta: $cta)';
}


}

/// @nodoc
abstract mixin class _$NudgeBriefCopyWith<$Res> implements $NudgeBriefCopyWith<$Res> {
  factory _$NudgeBriefCopyWith(_NudgeBrief value, $Res Function(_NudgeBrief) _then) = __$NudgeBriefCopyWithImpl;
@override @useResult
$Res call({
 String headline, NudgeTone tone, NudgeBannerAnimation animation, NudgeBannerAccent accent, String? tagline, String? cta
});




}
/// @nodoc
class __$NudgeBriefCopyWithImpl<$Res>
    implements _$NudgeBriefCopyWith<$Res> {
  __$NudgeBriefCopyWithImpl(this._self, this._then);

  final _NudgeBrief _self;
  final $Res Function(_NudgeBrief) _then;

/// Create a copy of NudgeBrief
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? headline = null,Object? tone = null,Object? animation = null,Object? accent = null,Object? tagline = freezed,Object? cta = freezed,}) {
  return _then(_NudgeBrief(
headline: null == headline ? _self.headline : headline // ignore: cast_nullable_to_non_nullable
as String,tone: null == tone ? _self.tone : tone // ignore: cast_nullable_to_non_nullable
as NudgeTone,animation: null == animation ? _self.animation : animation // ignore: cast_nullable_to_non_nullable
as NudgeBannerAnimation,accent: null == accent ? _self.accent : accent // ignore: cast_nullable_to_non_nullable
as NudgeBannerAccent,tagline: freezed == tagline ? _self.tagline : tagline // ignore: cast_nullable_to_non_nullable
as String?,cta: freezed == cta ? _self.cta : cta // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$NudgeRating {

/// Which run of this banner the outcome belongs to (1-based).
@JsonKey(fromJson: _decodeActivation) int get activation; DateTime get ratedAt;/// 1 (useless) .. 5 (loved it); null iff [skipped].
@JsonKey(fromJson: _decodeRating) int? get rating; bool get skipped;
/// Create a copy of NudgeRating
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NudgeRatingCopyWith<NudgeRating> get copyWith => _$NudgeRatingCopyWithImpl<NudgeRating>(this as NudgeRating, _$identity);

  /// Serializes this NudgeRating to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NudgeRating&&(identical(other.activation, activation) || other.activation == activation)&&(identical(other.ratedAt, ratedAt) || other.ratedAt == ratedAt)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.skipped, skipped) || other.skipped == skipped));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,activation,ratedAt,rating,skipped);

@override
String toString() {
  return 'NudgeRating(activation: $activation, ratedAt: $ratedAt, rating: $rating, skipped: $skipped)';
}


}

/// @nodoc
abstract mixin class $NudgeRatingCopyWith<$Res>  {
  factory $NudgeRatingCopyWith(NudgeRating value, $Res Function(NudgeRating) _then) = _$NudgeRatingCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _decodeActivation) int activation, DateTime ratedAt,@JsonKey(fromJson: _decodeRating) int? rating, bool skipped
});




}
/// @nodoc
class _$NudgeRatingCopyWithImpl<$Res>
    implements $NudgeRatingCopyWith<$Res> {
  _$NudgeRatingCopyWithImpl(this._self, this._then);

  final NudgeRating _self;
  final $Res Function(NudgeRating) _then;

/// Create a copy of NudgeRating
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? activation = null,Object? ratedAt = null,Object? rating = freezed,Object? skipped = null,}) {
  return _then(_self.copyWith(
activation: null == activation ? _self.activation : activation // ignore: cast_nullable_to_non_nullable
as int,ratedAt: null == ratedAt ? _self.ratedAt : ratedAt // ignore: cast_nullable_to_non_nullable
as DateTime,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as int?,skipped: null == skipped ? _self.skipped : skipped // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [NudgeRating].
extension NudgeRatingPatterns on NudgeRating {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NudgeRating value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NudgeRating() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NudgeRating value)  $default,){
final _that = this;
switch (_that) {
case _NudgeRating():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NudgeRating value)?  $default,){
final _that = this;
switch (_that) {
case _NudgeRating() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _decodeActivation)  int activation,  DateTime ratedAt, @JsonKey(fromJson: _decodeRating)  int? rating,  bool skipped)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NudgeRating() when $default != null:
return $default(_that.activation,_that.ratedAt,_that.rating,_that.skipped);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _decodeActivation)  int activation,  DateTime ratedAt, @JsonKey(fromJson: _decodeRating)  int? rating,  bool skipped)  $default,) {final _that = this;
switch (_that) {
case _NudgeRating():
return $default(_that.activation,_that.ratedAt,_that.rating,_that.skipped);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _decodeActivation)  int activation,  DateTime ratedAt, @JsonKey(fromJson: _decodeRating)  int? rating,  bool skipped)?  $default,) {final _that = this;
switch (_that) {
case _NudgeRating() when $default != null:
return $default(_that.activation,_that.ratedAt,_that.rating,_that.skipped);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NudgeRating implements NudgeRating {
  const _NudgeRating({@JsonKey(fromJson: _decodeActivation) required this.activation, required this.ratedAt, @JsonKey(fromJson: _decodeRating) this.rating, this.skipped = false});
  factory _NudgeRating.fromJson(Map<String, dynamic> json) => _$NudgeRatingFromJson(json);

/// Which run of this banner the outcome belongs to (1-based).
@override@JsonKey(fromJson: _decodeActivation) final  int activation;
@override final  DateTime ratedAt;
/// 1 (useless) .. 5 (loved it); null iff [skipped].
@override@JsonKey(fromJson: _decodeRating) final  int? rating;
@override@JsonKey() final  bool skipped;

/// Create a copy of NudgeRating
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NudgeRatingCopyWith<_NudgeRating> get copyWith => __$NudgeRatingCopyWithImpl<_NudgeRating>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NudgeRatingToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NudgeRating&&(identical(other.activation, activation) || other.activation == activation)&&(identical(other.ratedAt, ratedAt) || other.ratedAt == ratedAt)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.skipped, skipped) || other.skipped == skipped));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,activation,ratedAt,rating,skipped);

@override
String toString() {
  return 'NudgeRating(activation: $activation, ratedAt: $ratedAt, rating: $rating, skipped: $skipped)';
}


}

/// @nodoc
abstract mixin class _$NudgeRatingCopyWith<$Res> implements $NudgeRatingCopyWith<$Res> {
  factory _$NudgeRatingCopyWith(_NudgeRating value, $Res Function(_NudgeRating) _then) = __$NudgeRatingCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _decodeActivation) int activation, DateTime ratedAt,@JsonKey(fromJson: _decodeRating) int? rating, bool skipped
});




}
/// @nodoc
class __$NudgeRatingCopyWithImpl<$Res>
    implements _$NudgeRatingCopyWith<$Res> {
  __$NudgeRatingCopyWithImpl(this._self, this._then);

  final _NudgeRating _self;
  final $Res Function(_NudgeRating) _then;

/// Create a copy of NudgeRating
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? activation = null,Object? ratedAt = null,Object? rating = freezed,Object? skipped = null,}) {
  return _then(_NudgeRating(
activation: null == activation ? _self.activation : activation // ignore: cast_nullable_to_non_nullable
as int,ratedAt: null == ratedAt ? _self.ratedAt : ratedAt // ignore: cast_nullable_to_non_nullable
as DateTime,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as int?,skipped: null == skipped ? _self.skipped : skipped // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$NudgeSnooze {

 String get id;@JsonKey(fromJson: _decodeActivation) int get activation; DateTime get snoozedAt; DateTime get snoozedUntil; NudgeBannerSnoozeDuration get duration;@JsonKey(fromJson: _decodePositiveMinutes) int get durationMinutes;@JsonKey(fromJson: _decodeUtcOffsetMinutes) int get utcOffsetMinutes;@JsonKey(fromJson: _decodeOptionalUtcOffsetMinutes) int? get returnUtcOffsetMinutes;
/// Create a copy of NudgeSnooze
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NudgeSnoozeCopyWith<NudgeSnooze> get copyWith => _$NudgeSnoozeCopyWithImpl<NudgeSnooze>(this as NudgeSnooze, _$identity);

  /// Serializes this NudgeSnooze to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NudgeSnooze&&(identical(other.id, id) || other.id == id)&&(identical(other.activation, activation) || other.activation == activation)&&(identical(other.snoozedAt, snoozedAt) || other.snoozedAt == snoozedAt)&&(identical(other.snoozedUntil, snoozedUntil) || other.snoozedUntil == snoozedUntil)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.durationMinutes, durationMinutes) || other.durationMinutes == durationMinutes)&&(identical(other.utcOffsetMinutes, utcOffsetMinutes) || other.utcOffsetMinutes == utcOffsetMinutes)&&(identical(other.returnUtcOffsetMinutes, returnUtcOffsetMinutes) || other.returnUtcOffsetMinutes == returnUtcOffsetMinutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,activation,snoozedAt,snoozedUntil,duration,durationMinutes,utcOffsetMinutes,returnUtcOffsetMinutes);

@override
String toString() {
  return 'NudgeSnooze(id: $id, activation: $activation, snoozedAt: $snoozedAt, snoozedUntil: $snoozedUntil, duration: $duration, durationMinutes: $durationMinutes, utcOffsetMinutes: $utcOffsetMinutes, returnUtcOffsetMinutes: $returnUtcOffsetMinutes)';
}


}

/// @nodoc
abstract mixin class $NudgeSnoozeCopyWith<$Res>  {
  factory $NudgeSnoozeCopyWith(NudgeSnooze value, $Res Function(NudgeSnooze) _then) = _$NudgeSnoozeCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(fromJson: _decodeActivation) int activation, DateTime snoozedAt, DateTime snoozedUntil, NudgeBannerSnoozeDuration duration,@JsonKey(fromJson: _decodePositiveMinutes) int durationMinutes,@JsonKey(fromJson: _decodeUtcOffsetMinutes) int utcOffsetMinutes,@JsonKey(fromJson: _decodeOptionalUtcOffsetMinutes) int? returnUtcOffsetMinutes
});




}
/// @nodoc
class _$NudgeSnoozeCopyWithImpl<$Res>
    implements $NudgeSnoozeCopyWith<$Res> {
  _$NudgeSnoozeCopyWithImpl(this._self, this._then);

  final NudgeSnooze _self;
  final $Res Function(NudgeSnooze) _then;

/// Create a copy of NudgeSnooze
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? activation = null,Object? snoozedAt = null,Object? snoozedUntil = null,Object? duration = null,Object? durationMinutes = null,Object? utcOffsetMinutes = null,Object? returnUtcOffsetMinutes = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,activation: null == activation ? _self.activation : activation // ignore: cast_nullable_to_non_nullable
as int,snoozedAt: null == snoozedAt ? _self.snoozedAt : snoozedAt // ignore: cast_nullable_to_non_nullable
as DateTime,snoozedUntil: null == snoozedUntil ? _self.snoozedUntil : snoozedUntil // ignore: cast_nullable_to_non_nullable
as DateTime,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as NudgeBannerSnoozeDuration,durationMinutes: null == durationMinutes ? _self.durationMinutes : durationMinutes // ignore: cast_nullable_to_non_nullable
as int,utcOffsetMinutes: null == utcOffsetMinutes ? _self.utcOffsetMinutes : utcOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int,returnUtcOffsetMinutes: freezed == returnUtcOffsetMinutes ? _self.returnUtcOffsetMinutes : returnUtcOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [NudgeSnooze].
extension NudgeSnoozePatterns on NudgeSnooze {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NudgeSnooze value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NudgeSnooze() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NudgeSnooze value)  $default,){
final _that = this;
switch (_that) {
case _NudgeSnooze():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NudgeSnooze value)?  $default,){
final _that = this;
switch (_that) {
case _NudgeSnooze() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(fromJson: _decodeActivation)  int activation,  DateTime snoozedAt,  DateTime snoozedUntil,  NudgeBannerSnoozeDuration duration, @JsonKey(fromJson: _decodePositiveMinutes)  int durationMinutes, @JsonKey(fromJson: _decodeUtcOffsetMinutes)  int utcOffsetMinutes, @JsonKey(fromJson: _decodeOptionalUtcOffsetMinutes)  int? returnUtcOffsetMinutes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NudgeSnooze() when $default != null:
return $default(_that.id,_that.activation,_that.snoozedAt,_that.snoozedUntil,_that.duration,_that.durationMinutes,_that.utcOffsetMinutes,_that.returnUtcOffsetMinutes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(fromJson: _decodeActivation)  int activation,  DateTime snoozedAt,  DateTime snoozedUntil,  NudgeBannerSnoozeDuration duration, @JsonKey(fromJson: _decodePositiveMinutes)  int durationMinutes, @JsonKey(fromJson: _decodeUtcOffsetMinutes)  int utcOffsetMinutes, @JsonKey(fromJson: _decodeOptionalUtcOffsetMinutes)  int? returnUtcOffsetMinutes)  $default,) {final _that = this;
switch (_that) {
case _NudgeSnooze():
return $default(_that.id,_that.activation,_that.snoozedAt,_that.snoozedUntil,_that.duration,_that.durationMinutes,_that.utcOffsetMinutes,_that.returnUtcOffsetMinutes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(fromJson: _decodeActivation)  int activation,  DateTime snoozedAt,  DateTime snoozedUntil,  NudgeBannerSnoozeDuration duration, @JsonKey(fromJson: _decodePositiveMinutes)  int durationMinutes, @JsonKey(fromJson: _decodeUtcOffsetMinutes)  int utcOffsetMinutes, @JsonKey(fromJson: _decodeOptionalUtcOffsetMinutes)  int? returnUtcOffsetMinutes)?  $default,) {final _that = this;
switch (_that) {
case _NudgeSnooze() when $default != null:
return $default(_that.id,_that.activation,_that.snoozedAt,_that.snoozedUntil,_that.duration,_that.durationMinutes,_that.utcOffsetMinutes,_that.returnUtcOffsetMinutes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NudgeSnooze extends NudgeSnooze {
  const _NudgeSnooze({required this.id, @JsonKey(fromJson: _decodeActivation) required this.activation, required this.snoozedAt, required this.snoozedUntil, required this.duration, @JsonKey(fromJson: _decodePositiveMinutes) required this.durationMinutes, @JsonKey(fromJson: _decodeUtcOffsetMinutes) required this.utcOffsetMinutes, @JsonKey(fromJson: _decodeOptionalUtcOffsetMinutes) this.returnUtcOffsetMinutes}): super._();
  factory _NudgeSnooze.fromJson(Map<String, dynamic> json) => _$NudgeSnoozeFromJson(json);

@override final  String id;
@override@JsonKey(fromJson: _decodeActivation) final  int activation;
@override final  DateTime snoozedAt;
@override final  DateTime snoozedUntil;
@override final  NudgeBannerSnoozeDuration duration;
@override@JsonKey(fromJson: _decodePositiveMinutes) final  int durationMinutes;
@override@JsonKey(fromJson: _decodeUtcOffsetMinutes) final  int utcOffsetMinutes;
@override@JsonKey(fromJson: _decodeOptionalUtcOffsetMinutes) final  int? returnUtcOffsetMinutes;

/// Create a copy of NudgeSnooze
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NudgeSnoozeCopyWith<_NudgeSnooze> get copyWith => __$NudgeSnoozeCopyWithImpl<_NudgeSnooze>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NudgeSnoozeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NudgeSnooze&&(identical(other.id, id) || other.id == id)&&(identical(other.activation, activation) || other.activation == activation)&&(identical(other.snoozedAt, snoozedAt) || other.snoozedAt == snoozedAt)&&(identical(other.snoozedUntil, snoozedUntil) || other.snoozedUntil == snoozedUntil)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.durationMinutes, durationMinutes) || other.durationMinutes == durationMinutes)&&(identical(other.utcOffsetMinutes, utcOffsetMinutes) || other.utcOffsetMinutes == utcOffsetMinutes)&&(identical(other.returnUtcOffsetMinutes, returnUtcOffsetMinutes) || other.returnUtcOffsetMinutes == returnUtcOffsetMinutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,activation,snoozedAt,snoozedUntil,duration,durationMinutes,utcOffsetMinutes,returnUtcOffsetMinutes);

@override
String toString() {
  return 'NudgeSnooze(id: $id, activation: $activation, snoozedAt: $snoozedAt, snoozedUntil: $snoozedUntil, duration: $duration, durationMinutes: $durationMinutes, utcOffsetMinutes: $utcOffsetMinutes, returnUtcOffsetMinutes: $returnUtcOffsetMinutes)';
}


}

/// @nodoc
abstract mixin class _$NudgeSnoozeCopyWith<$Res> implements $NudgeSnoozeCopyWith<$Res> {
  factory _$NudgeSnoozeCopyWith(_NudgeSnooze value, $Res Function(_NudgeSnooze) _then) = __$NudgeSnoozeCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(fromJson: _decodeActivation) int activation, DateTime snoozedAt, DateTime snoozedUntil, NudgeBannerSnoozeDuration duration,@JsonKey(fromJson: _decodePositiveMinutes) int durationMinutes,@JsonKey(fromJson: _decodeUtcOffsetMinutes) int utcOffsetMinutes,@JsonKey(fromJson: _decodeOptionalUtcOffsetMinutes) int? returnUtcOffsetMinutes
});




}
/// @nodoc
class __$NudgeSnoozeCopyWithImpl<$Res>
    implements _$NudgeSnoozeCopyWith<$Res> {
  __$NudgeSnoozeCopyWithImpl(this._self, this._then);

  final _NudgeSnooze _self;
  final $Res Function(_NudgeSnooze) _then;

/// Create a copy of NudgeSnooze
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? activation = null,Object? snoozedAt = null,Object? snoozedUntil = null,Object? duration = null,Object? durationMinutes = null,Object? utcOffsetMinutes = null,Object? returnUtcOffsetMinutes = freezed,}) {
  return _then(_NudgeSnooze(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,activation: null == activation ? _self.activation : activation // ignore: cast_nullable_to_non_nullable
as int,snoozedAt: null == snoozedAt ? _self.snoozedAt : snoozedAt // ignore: cast_nullable_to_non_nullable
as DateTime,snoozedUntil: null == snoozedUntil ? _self.snoozedUntil : snoozedUntil // ignore: cast_nullable_to_non_nullable
as DateTime,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as NudgeBannerSnoozeDuration,durationMinutes: null == durationMinutes ? _self.durationMinutes : durationMinutes // ignore: cast_nullable_to_non_nullable
as int,utcOffsetMinutes: null == utcOffsetMinutes ? _self.utcOffsetMinutes : utcOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int,returnUtcOffsetMinutes: freezed == returnUtcOffsetMinutes ? _self.returnUtcOffsetMinutes : returnUtcOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$NudgeDayDismissal {

 String get id;@JsonKey(fromJson: _decodeActivation) int get activation; DateTime get dismissedAt; DateTime get dismissedUntil;@JsonKey(fromJson: _decodeUtcOffsetMinutes) int get utcOffsetMinutes;
/// Create a copy of NudgeDayDismissal
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NudgeDayDismissalCopyWith<NudgeDayDismissal> get copyWith => _$NudgeDayDismissalCopyWithImpl<NudgeDayDismissal>(this as NudgeDayDismissal, _$identity);

  /// Serializes this NudgeDayDismissal to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NudgeDayDismissal&&(identical(other.id, id) || other.id == id)&&(identical(other.activation, activation) || other.activation == activation)&&(identical(other.dismissedAt, dismissedAt) || other.dismissedAt == dismissedAt)&&(identical(other.dismissedUntil, dismissedUntil) || other.dismissedUntil == dismissedUntil)&&(identical(other.utcOffsetMinutes, utcOffsetMinutes) || other.utcOffsetMinutes == utcOffsetMinutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,activation,dismissedAt,dismissedUntil,utcOffsetMinutes);

@override
String toString() {
  return 'NudgeDayDismissal(id: $id, activation: $activation, dismissedAt: $dismissedAt, dismissedUntil: $dismissedUntil, utcOffsetMinutes: $utcOffsetMinutes)';
}


}

/// @nodoc
abstract mixin class $NudgeDayDismissalCopyWith<$Res>  {
  factory $NudgeDayDismissalCopyWith(NudgeDayDismissal value, $Res Function(NudgeDayDismissal) _then) = _$NudgeDayDismissalCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(fromJson: _decodeActivation) int activation, DateTime dismissedAt, DateTime dismissedUntil,@JsonKey(fromJson: _decodeUtcOffsetMinutes) int utcOffsetMinutes
});




}
/// @nodoc
class _$NudgeDayDismissalCopyWithImpl<$Res>
    implements $NudgeDayDismissalCopyWith<$Res> {
  _$NudgeDayDismissalCopyWithImpl(this._self, this._then);

  final NudgeDayDismissal _self;
  final $Res Function(NudgeDayDismissal) _then;

/// Create a copy of NudgeDayDismissal
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? activation = null,Object? dismissedAt = null,Object? dismissedUntil = null,Object? utcOffsetMinutes = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,activation: null == activation ? _self.activation : activation // ignore: cast_nullable_to_non_nullable
as int,dismissedAt: null == dismissedAt ? _self.dismissedAt : dismissedAt // ignore: cast_nullable_to_non_nullable
as DateTime,dismissedUntil: null == dismissedUntil ? _self.dismissedUntil : dismissedUntil // ignore: cast_nullable_to_non_nullable
as DateTime,utcOffsetMinutes: null == utcOffsetMinutes ? _self.utcOffsetMinutes : utcOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [NudgeDayDismissal].
extension NudgeDayDismissalPatterns on NudgeDayDismissal {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NudgeDayDismissal value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NudgeDayDismissal() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NudgeDayDismissal value)  $default,){
final _that = this;
switch (_that) {
case _NudgeDayDismissal():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NudgeDayDismissal value)?  $default,){
final _that = this;
switch (_that) {
case _NudgeDayDismissal() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(fromJson: _decodeActivation)  int activation,  DateTime dismissedAt,  DateTime dismissedUntil, @JsonKey(fromJson: _decodeUtcOffsetMinutes)  int utcOffsetMinutes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NudgeDayDismissal() when $default != null:
return $default(_that.id,_that.activation,_that.dismissedAt,_that.dismissedUntil,_that.utcOffsetMinutes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(fromJson: _decodeActivation)  int activation,  DateTime dismissedAt,  DateTime dismissedUntil, @JsonKey(fromJson: _decodeUtcOffsetMinutes)  int utcOffsetMinutes)  $default,) {final _that = this;
switch (_that) {
case _NudgeDayDismissal():
return $default(_that.id,_that.activation,_that.dismissedAt,_that.dismissedUntil,_that.utcOffsetMinutes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(fromJson: _decodeActivation)  int activation,  DateTime dismissedAt,  DateTime dismissedUntil, @JsonKey(fromJson: _decodeUtcOffsetMinutes)  int utcOffsetMinutes)?  $default,) {final _that = this;
switch (_that) {
case _NudgeDayDismissal() when $default != null:
return $default(_that.id,_that.activation,_that.dismissedAt,_that.dismissedUntil,_that.utcOffsetMinutes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NudgeDayDismissal extends NudgeDayDismissal {
  const _NudgeDayDismissal({required this.id, @JsonKey(fromJson: _decodeActivation) required this.activation, required this.dismissedAt, required this.dismissedUntil, @JsonKey(fromJson: _decodeUtcOffsetMinutes) required this.utcOffsetMinutes}): super._();
  factory _NudgeDayDismissal.fromJson(Map<String, dynamic> json) => _$NudgeDayDismissalFromJson(json);

@override final  String id;
@override@JsonKey(fromJson: _decodeActivation) final  int activation;
@override final  DateTime dismissedAt;
@override final  DateTime dismissedUntil;
@override@JsonKey(fromJson: _decodeUtcOffsetMinutes) final  int utcOffsetMinutes;

/// Create a copy of NudgeDayDismissal
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NudgeDayDismissalCopyWith<_NudgeDayDismissal> get copyWith => __$NudgeDayDismissalCopyWithImpl<_NudgeDayDismissal>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NudgeDayDismissalToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NudgeDayDismissal&&(identical(other.id, id) || other.id == id)&&(identical(other.activation, activation) || other.activation == activation)&&(identical(other.dismissedAt, dismissedAt) || other.dismissedAt == dismissedAt)&&(identical(other.dismissedUntil, dismissedUntil) || other.dismissedUntil == dismissedUntil)&&(identical(other.utcOffsetMinutes, utcOffsetMinutes) || other.utcOffsetMinutes == utcOffsetMinutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,activation,dismissedAt,dismissedUntil,utcOffsetMinutes);

@override
String toString() {
  return 'NudgeDayDismissal(id: $id, activation: $activation, dismissedAt: $dismissedAt, dismissedUntil: $dismissedUntil, utcOffsetMinutes: $utcOffsetMinutes)';
}


}

/// @nodoc
abstract mixin class _$NudgeDayDismissalCopyWith<$Res> implements $NudgeDayDismissalCopyWith<$Res> {
  factory _$NudgeDayDismissalCopyWith(_NudgeDayDismissal value, $Res Function(_NudgeDayDismissal) _then) = __$NudgeDayDismissalCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(fromJson: _decodeActivation) int activation, DateTime dismissedAt, DateTime dismissedUntil,@JsonKey(fromJson: _decodeUtcOffsetMinutes) int utcOffsetMinutes
});




}
/// @nodoc
class __$NudgeDayDismissalCopyWithImpl<$Res>
    implements _$NudgeDayDismissalCopyWith<$Res> {
  __$NudgeDayDismissalCopyWithImpl(this._self, this._then);

  final _NudgeDayDismissal _self;
  final $Res Function(_NudgeDayDismissal) _then;

/// Create a copy of NudgeDayDismissal
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? activation = null,Object? dismissedAt = null,Object? dismissedUntil = null,Object? utcOffsetMinutes = null,}) {
  return _then(_NudgeDayDismissal(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,activation: null == activation ? _self.activation : activation // ignore: cast_nullable_to_non_nullable
as int,dismissedAt: null == dismissedAt ? _self.dismissedAt : dismissedAt // ignore: cast_nullable_to_non_nullable
as DateTime,dismissedUntil: null == dismissedUntil ? _self.dismissedUntil : dismissedUntil // ignore: cast_nullable_to_non_nullable
as DateTime,utcOffsetMinutes: null == utcOffsetMinutes ? _self.utcOffsetMinutes : utcOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
