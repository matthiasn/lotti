// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'event_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EventData {

 String get title; double get stars; EventStatus get status;/// Id of a linked `JournalImage` used as the event's cover art. New events
/// have none until the user picks one (or one is derived from a linked
/// photo); the UI falls back to a category-tinted card.
 String? get coverArtId;/// Horizontal crop offset for the cover art (0.0 = left … 1.0 = right).
 double get coverArtCropX;/// The language the event's record is kept in (a `SupportedLanguage`
/// code such as `de`): the event agent's recap and suggestions, the
/// analyses of its photos and the summaries of its recordings are all
/// written in it. Null until the agent reads it from the first voice memo
/// or the user picks one.
 String? get languageCode;/// Who set [languageCode] — the agent (from a voice memo) or the user.
/// The agent only ever fills an empty language; the user can change it
/// any time. Defaults to [ChangeSource.user], the safe reading for a
/// value whose author is unknown.
@JsonKey(unknownEnumValue: ChangeSource.user) ChangeSource get languageSource;
/// Create a copy of EventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EventDataCopyWith<EventData> get copyWith => _$EventDataCopyWithImpl<EventData>(this as EventData, _$identity);

  /// Serializes this EventData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EventData&&(identical(other.title, title) || other.title == title)&&(identical(other.stars, stars) || other.stars == stars)&&(identical(other.status, status) || other.status == status)&&(identical(other.coverArtId, coverArtId) || other.coverArtId == coverArtId)&&(identical(other.coverArtCropX, coverArtCropX) || other.coverArtCropX == coverArtCropX)&&(identical(other.languageCode, languageCode) || other.languageCode == languageCode)&&(identical(other.languageSource, languageSource) || other.languageSource == languageSource));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,stars,status,coverArtId,coverArtCropX,languageCode,languageSource);

@override
String toString() {
  return 'EventData(title: $title, stars: $stars, status: $status, coverArtId: $coverArtId, coverArtCropX: $coverArtCropX, languageCode: $languageCode, languageSource: $languageSource)';
}


}

/// @nodoc
abstract mixin class $EventDataCopyWith<$Res>  {
  factory $EventDataCopyWith(EventData value, $Res Function(EventData) _then) = _$EventDataCopyWithImpl;
@useResult
$Res call({
 String title, double stars, EventStatus status, String? coverArtId, double coverArtCropX, String? languageCode,@JsonKey(unknownEnumValue: ChangeSource.user) ChangeSource languageSource
});




}
/// @nodoc
class _$EventDataCopyWithImpl<$Res>
    implements $EventDataCopyWith<$Res> {
  _$EventDataCopyWithImpl(this._self, this._then);

  final EventData _self;
  final $Res Function(EventData) _then;

/// Create a copy of EventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? stars = null,Object? status = null,Object? coverArtId = freezed,Object? coverArtCropX = null,Object? languageCode = freezed,Object? languageSource = null,}) {
  return _then(_self.copyWith(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,stars: null == stars ? _self.stars : stars // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as EventStatus,coverArtId: freezed == coverArtId ? _self.coverArtId : coverArtId // ignore: cast_nullable_to_non_nullable
as String?,coverArtCropX: null == coverArtCropX ? _self.coverArtCropX : coverArtCropX // ignore: cast_nullable_to_non_nullable
as double,languageCode: freezed == languageCode ? _self.languageCode : languageCode // ignore: cast_nullable_to_non_nullable
as String?,languageSource: null == languageSource ? _self.languageSource : languageSource // ignore: cast_nullable_to_non_nullable
as ChangeSource,
  ));
}

}


/// Adds pattern-matching-related methods to [EventData].
extension EventDataPatterns on EventData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EventData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EventData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EventData value)  $default,){
final _that = this;
switch (_that) {
case _EventData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EventData value)?  $default,){
final _that = this;
switch (_that) {
case _EventData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String title,  double stars,  EventStatus status,  String? coverArtId,  double coverArtCropX,  String? languageCode, @JsonKey(unknownEnumValue: ChangeSource.user)  ChangeSource languageSource)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EventData() when $default != null:
return $default(_that.title,_that.stars,_that.status,_that.coverArtId,_that.coverArtCropX,_that.languageCode,_that.languageSource);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String title,  double stars,  EventStatus status,  String? coverArtId,  double coverArtCropX,  String? languageCode, @JsonKey(unknownEnumValue: ChangeSource.user)  ChangeSource languageSource)  $default,) {final _that = this;
switch (_that) {
case _EventData():
return $default(_that.title,_that.stars,_that.status,_that.coverArtId,_that.coverArtCropX,_that.languageCode,_that.languageSource);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String title,  double stars,  EventStatus status,  String? coverArtId,  double coverArtCropX,  String? languageCode, @JsonKey(unknownEnumValue: ChangeSource.user)  ChangeSource languageSource)?  $default,) {final _that = this;
switch (_that) {
case _EventData() when $default != null:
return $default(_that.title,_that.stars,_that.status,_that.coverArtId,_that.coverArtCropX,_that.languageCode,_that.languageSource);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EventData implements EventData {
  const _EventData({required this.title, required this.stars, required this.status, this.coverArtId, this.coverArtCropX = 0.5, this.languageCode, @JsonKey(unknownEnumValue: ChangeSource.user) this.languageSource = ChangeSource.user});
  factory _EventData.fromJson(Map<String, dynamic> json) => _$EventDataFromJson(json);

@override final  String title;
@override final  double stars;
@override final  EventStatus status;
/// Id of a linked `JournalImage` used as the event's cover art. New events
/// have none until the user picks one (or one is derived from a linked
/// photo); the UI falls back to a category-tinted card.
@override final  String? coverArtId;
/// Horizontal crop offset for the cover art (0.0 = left … 1.0 = right).
@override@JsonKey() final  double coverArtCropX;
/// The language the event's record is kept in (a `SupportedLanguage`
/// code such as `de`): the event agent's recap and suggestions, the
/// analyses of its photos and the summaries of its recordings are all
/// written in it. Null until the agent reads it from the first voice memo
/// or the user picks one.
@override final  String? languageCode;
/// Who set [languageCode] — the agent (from a voice memo) or the user.
/// The agent only ever fills an empty language; the user can change it
/// any time. Defaults to [ChangeSource.user], the safe reading for a
/// value whose author is unknown.
@override@JsonKey(unknownEnumValue: ChangeSource.user) final  ChangeSource languageSource;

/// Create a copy of EventData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EventDataCopyWith<_EventData> get copyWith => __$EventDataCopyWithImpl<_EventData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EventDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EventData&&(identical(other.title, title) || other.title == title)&&(identical(other.stars, stars) || other.stars == stars)&&(identical(other.status, status) || other.status == status)&&(identical(other.coverArtId, coverArtId) || other.coverArtId == coverArtId)&&(identical(other.coverArtCropX, coverArtCropX) || other.coverArtCropX == coverArtCropX)&&(identical(other.languageCode, languageCode) || other.languageCode == languageCode)&&(identical(other.languageSource, languageSource) || other.languageSource == languageSource));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,stars,status,coverArtId,coverArtCropX,languageCode,languageSource);

@override
String toString() {
  return 'EventData(title: $title, stars: $stars, status: $status, coverArtId: $coverArtId, coverArtCropX: $coverArtCropX, languageCode: $languageCode, languageSource: $languageSource)';
}


}

/// @nodoc
abstract mixin class _$EventDataCopyWith<$Res> implements $EventDataCopyWith<$Res> {
  factory _$EventDataCopyWith(_EventData value, $Res Function(_EventData) _then) = __$EventDataCopyWithImpl;
@override @useResult
$Res call({
 String title, double stars, EventStatus status, String? coverArtId, double coverArtCropX, String? languageCode,@JsonKey(unknownEnumValue: ChangeSource.user) ChangeSource languageSource
});




}
/// @nodoc
class __$EventDataCopyWithImpl<$Res>
    implements _$EventDataCopyWith<$Res> {
  __$EventDataCopyWithImpl(this._self, this._then);

  final _EventData _self;
  final $Res Function(_EventData) _then;

/// Create a copy of EventData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? stars = null,Object? status = null,Object? coverArtId = freezed,Object? coverArtCropX = null,Object? languageCode = freezed,Object? languageSource = null,}) {
  return _then(_EventData(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,stars: null == stars ? _self.stars : stars // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as EventStatus,coverArtId: freezed == coverArtId ? _self.coverArtId : coverArtId // ignore: cast_nullable_to_non_nullable
as String?,coverArtCropX: null == coverArtCropX ? _self.coverArtCropX : coverArtCropX // ignore: cast_nullable_to_non_nullable
as double,languageCode: freezed == languageCode ? _self.languageCode : languageCode // ignore: cast_nullable_to_non_nullable
as String?,languageSource: null == languageSource ? _self.languageSource : languageSource // ignore: cast_nullable_to_non_nullable
as ChangeSource,
  ));
}


}

// dart format on
