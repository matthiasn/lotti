// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'audio_transcript_timing.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AudioTimedSegment {

 String get text; int get startMilliseconds; int get endMilliseconds;
/// Create a copy of AudioTimedSegment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudioTimedSegmentCopyWith<AudioTimedSegment> get copyWith => _$AudioTimedSegmentCopyWithImpl<AudioTimedSegment>(this as AudioTimedSegment, _$identity);

  /// Serializes this AudioTimedSegment to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioTimedSegment&&(identical(other.text, text) || other.text == text)&&(identical(other.startMilliseconds, startMilliseconds) || other.startMilliseconds == startMilliseconds)&&(identical(other.endMilliseconds, endMilliseconds) || other.endMilliseconds == endMilliseconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text,startMilliseconds,endMilliseconds);

@override
String toString() {
  return 'AudioTimedSegment(text: $text, startMilliseconds: $startMilliseconds, endMilliseconds: $endMilliseconds)';
}


}

/// @nodoc
abstract mixin class $AudioTimedSegmentCopyWith<$Res>  {
  factory $AudioTimedSegmentCopyWith(AudioTimedSegment value, $Res Function(AudioTimedSegment) _then) = _$AudioTimedSegmentCopyWithImpl;
@useResult
$Res call({
 String text, int startMilliseconds, int endMilliseconds
});




}
/// @nodoc
class _$AudioTimedSegmentCopyWithImpl<$Res>
    implements $AudioTimedSegmentCopyWith<$Res> {
  _$AudioTimedSegmentCopyWithImpl(this._self, this._then);

  final AudioTimedSegment _self;
  final $Res Function(AudioTimedSegment) _then;

/// Create a copy of AudioTimedSegment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? text = null,Object? startMilliseconds = null,Object? endMilliseconds = null,}) {
  return _then(_self.copyWith(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,startMilliseconds: null == startMilliseconds ? _self.startMilliseconds : startMilliseconds // ignore: cast_nullable_to_non_nullable
as int,endMilliseconds: null == endMilliseconds ? _self.endMilliseconds : endMilliseconds // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AudioTimedSegment].
extension AudioTimedSegmentPatterns on AudioTimedSegment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AudioTimedSegment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AudioTimedSegment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AudioTimedSegment value)  $default,){
final _that = this;
switch (_that) {
case _AudioTimedSegment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AudioTimedSegment value)?  $default,){
final _that = this;
switch (_that) {
case _AudioTimedSegment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String text,  int startMilliseconds,  int endMilliseconds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AudioTimedSegment() when $default != null:
return $default(_that.text,_that.startMilliseconds,_that.endMilliseconds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String text,  int startMilliseconds,  int endMilliseconds)  $default,) {final _that = this;
switch (_that) {
case _AudioTimedSegment():
return $default(_that.text,_that.startMilliseconds,_that.endMilliseconds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String text,  int startMilliseconds,  int endMilliseconds)?  $default,) {final _that = this;
switch (_that) {
case _AudioTimedSegment() when $default != null:
return $default(_that.text,_that.startMilliseconds,_that.endMilliseconds);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AudioTimedSegment implements AudioTimedSegment {
  const _AudioTimedSegment({required this.text, required this.startMilliseconds, required this.endMilliseconds});
  factory _AudioTimedSegment.fromJson(Map<String, dynamic> json) => _$AudioTimedSegmentFromJson(json);

@override final  String text;
@override final  int startMilliseconds;
@override final  int endMilliseconds;

/// Create a copy of AudioTimedSegment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AudioTimedSegmentCopyWith<_AudioTimedSegment> get copyWith => __$AudioTimedSegmentCopyWithImpl<_AudioTimedSegment>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AudioTimedSegmentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AudioTimedSegment&&(identical(other.text, text) || other.text == text)&&(identical(other.startMilliseconds, startMilliseconds) || other.startMilliseconds == startMilliseconds)&&(identical(other.endMilliseconds, endMilliseconds) || other.endMilliseconds == endMilliseconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text,startMilliseconds,endMilliseconds);

@override
String toString() {
  return 'AudioTimedSegment(text: $text, startMilliseconds: $startMilliseconds, endMilliseconds: $endMilliseconds)';
}


}

/// @nodoc
abstract mixin class _$AudioTimedSegmentCopyWith<$Res> implements $AudioTimedSegmentCopyWith<$Res> {
  factory _$AudioTimedSegmentCopyWith(_AudioTimedSegment value, $Res Function(_AudioTimedSegment) _then) = __$AudioTimedSegmentCopyWithImpl;
@override @useResult
$Res call({
 String text, int startMilliseconds, int endMilliseconds
});




}
/// @nodoc
class __$AudioTimedSegmentCopyWithImpl<$Res>
    implements _$AudioTimedSegmentCopyWith<$Res> {
  __$AudioTimedSegmentCopyWithImpl(this._self, this._then);

  final _AudioTimedSegment _self;
  final $Res Function(_AudioTimedSegment) _then;

/// Create a copy of AudioTimedSegment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = null,Object? startMilliseconds = null,Object? endMilliseconds = null,}) {
  return _then(_AudioTimedSegment(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,startMilliseconds: null == startMilliseconds ? _self.startMilliseconds : startMilliseconds // ignore: cast_nullable_to_non_nullable
as int,endMilliseconds: null == endMilliseconds ? _self.endMilliseconds : endMilliseconds // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$AudioTranscriptTiming {

 DateTime get createdAt; String get audioSha256; String get sourceFingerprint; String get sourceVersion; String get providerId; String get model; List<AudioTimedSegment> get segments;
/// Create a copy of AudioTranscriptTiming
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudioTranscriptTimingCopyWith<AudioTranscriptTiming> get copyWith => _$AudioTranscriptTimingCopyWithImpl<AudioTranscriptTiming>(this as AudioTranscriptTiming, _$identity);

  /// Serializes this AudioTranscriptTiming to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioTranscriptTiming&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.audioSha256, audioSha256) || other.audioSha256 == audioSha256)&&(identical(other.sourceFingerprint, sourceFingerprint) || other.sourceFingerprint == sourceFingerprint)&&(identical(other.sourceVersion, sourceVersion) || other.sourceVersion == sourceVersion)&&(identical(other.providerId, providerId) || other.providerId == providerId)&&(identical(other.model, model) || other.model == model)&&const DeepCollectionEquality().equals(other.segments, segments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,createdAt,audioSha256,sourceFingerprint,sourceVersion,providerId,model,const DeepCollectionEquality().hash(segments));

@override
String toString() {
  return 'AudioTranscriptTiming(createdAt: $createdAt, audioSha256: $audioSha256, sourceFingerprint: $sourceFingerprint, sourceVersion: $sourceVersion, providerId: $providerId, model: $model, segments: $segments)';
}


}

/// @nodoc
abstract mixin class $AudioTranscriptTimingCopyWith<$Res>  {
  factory $AudioTranscriptTimingCopyWith(AudioTranscriptTiming value, $Res Function(AudioTranscriptTiming) _then) = _$AudioTranscriptTimingCopyWithImpl;
@useResult
$Res call({
 DateTime createdAt, String audioSha256, String sourceFingerprint, String sourceVersion, String providerId, String model, List<AudioTimedSegment> segments
});




}
/// @nodoc
class _$AudioTranscriptTimingCopyWithImpl<$Res>
    implements $AudioTranscriptTimingCopyWith<$Res> {
  _$AudioTranscriptTimingCopyWithImpl(this._self, this._then);

  final AudioTranscriptTiming _self;
  final $Res Function(AudioTranscriptTiming) _then;

/// Create a copy of AudioTranscriptTiming
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? createdAt = null,Object? audioSha256 = null,Object? sourceFingerprint = null,Object? sourceVersion = null,Object? providerId = null,Object? model = null,Object? segments = null,}) {
  return _then(_self.copyWith(
createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,audioSha256: null == audioSha256 ? _self.audioSha256 : audioSha256 // ignore: cast_nullable_to_non_nullable
as String,sourceFingerprint: null == sourceFingerprint ? _self.sourceFingerprint : sourceFingerprint // ignore: cast_nullable_to_non_nullable
as String,sourceVersion: null == sourceVersion ? _self.sourceVersion : sourceVersion // ignore: cast_nullable_to_non_nullable
as String,providerId: null == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,segments: null == segments ? _self.segments : segments // ignore: cast_nullable_to_non_nullable
as List<AudioTimedSegment>,
  ));
}

}


/// Adds pattern-matching-related methods to [AudioTranscriptTiming].
extension AudioTranscriptTimingPatterns on AudioTranscriptTiming {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AudioTranscriptTiming value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AudioTranscriptTiming() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AudioTranscriptTiming value)  $default,){
final _that = this;
switch (_that) {
case _AudioTranscriptTiming():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AudioTranscriptTiming value)?  $default,){
final _that = this;
switch (_that) {
case _AudioTranscriptTiming() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime createdAt,  String audioSha256,  String sourceFingerprint,  String sourceVersion,  String providerId,  String model,  List<AudioTimedSegment> segments)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AudioTranscriptTiming() when $default != null:
return $default(_that.createdAt,_that.audioSha256,_that.sourceFingerprint,_that.sourceVersion,_that.providerId,_that.model,_that.segments);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime createdAt,  String audioSha256,  String sourceFingerprint,  String sourceVersion,  String providerId,  String model,  List<AudioTimedSegment> segments)  $default,) {final _that = this;
switch (_that) {
case _AudioTranscriptTiming():
return $default(_that.createdAt,_that.audioSha256,_that.sourceFingerprint,_that.sourceVersion,_that.providerId,_that.model,_that.segments);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime createdAt,  String audioSha256,  String sourceFingerprint,  String sourceVersion,  String providerId,  String model,  List<AudioTimedSegment> segments)?  $default,) {final _that = this;
switch (_that) {
case _AudioTranscriptTiming() when $default != null:
return $default(_that.createdAt,_that.audioSha256,_that.sourceFingerprint,_that.sourceVersion,_that.providerId,_that.model,_that.segments);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AudioTranscriptTiming implements AudioTranscriptTiming {
  const _AudioTranscriptTiming({required this.createdAt, required this.audioSha256, required this.sourceFingerprint, required this.sourceVersion, required this.providerId, required this.model, required final  List<AudioTimedSegment> segments}): _segments = segments;
  factory _AudioTranscriptTiming.fromJson(Map<String, dynamic> json) => _$AudioTranscriptTimingFromJson(json);

@override final  DateTime createdAt;
@override final  String audioSha256;
@override final  String sourceFingerprint;
@override final  String sourceVersion;
@override final  String providerId;
@override final  String model;
 final  List<AudioTimedSegment> _segments;
@override List<AudioTimedSegment> get segments {
  if (_segments is EqualUnmodifiableListView) return _segments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_segments);
}


/// Create a copy of AudioTranscriptTiming
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AudioTranscriptTimingCopyWith<_AudioTranscriptTiming> get copyWith => __$AudioTranscriptTimingCopyWithImpl<_AudioTranscriptTiming>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AudioTranscriptTimingToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AudioTranscriptTiming&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.audioSha256, audioSha256) || other.audioSha256 == audioSha256)&&(identical(other.sourceFingerprint, sourceFingerprint) || other.sourceFingerprint == sourceFingerprint)&&(identical(other.sourceVersion, sourceVersion) || other.sourceVersion == sourceVersion)&&(identical(other.providerId, providerId) || other.providerId == providerId)&&(identical(other.model, model) || other.model == model)&&const DeepCollectionEquality().equals(other._segments, _segments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,createdAt,audioSha256,sourceFingerprint,sourceVersion,providerId,model,const DeepCollectionEquality().hash(_segments));

@override
String toString() {
  return 'AudioTranscriptTiming(createdAt: $createdAt, audioSha256: $audioSha256, sourceFingerprint: $sourceFingerprint, sourceVersion: $sourceVersion, providerId: $providerId, model: $model, segments: $segments)';
}


}

/// @nodoc
abstract mixin class _$AudioTranscriptTimingCopyWith<$Res> implements $AudioTranscriptTimingCopyWith<$Res> {
  factory _$AudioTranscriptTimingCopyWith(_AudioTranscriptTiming value, $Res Function(_AudioTranscriptTiming) _then) = __$AudioTranscriptTimingCopyWithImpl;
@override @useResult
$Res call({
 DateTime createdAt, String audioSha256, String sourceFingerprint, String sourceVersion, String providerId, String model, List<AudioTimedSegment> segments
});




}
/// @nodoc
class __$AudioTranscriptTimingCopyWithImpl<$Res>
    implements _$AudioTranscriptTimingCopyWith<$Res> {
  __$AudioTranscriptTimingCopyWithImpl(this._self, this._then);

  final _AudioTranscriptTiming _self;
  final $Res Function(_AudioTranscriptTiming) _then;

/// Create a copy of AudioTranscriptTiming
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? createdAt = null,Object? audioSha256 = null,Object? sourceFingerprint = null,Object? sourceVersion = null,Object? providerId = null,Object? model = null,Object? segments = null,}) {
  return _then(_AudioTranscriptTiming(
createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,audioSha256: null == audioSha256 ? _self.audioSha256 : audioSha256 // ignore: cast_nullable_to_non_nullable
as String,sourceFingerprint: null == sourceFingerprint ? _self.sourceFingerprint : sourceFingerprint // ignore: cast_nullable_to_non_nullable
as String,sourceVersion: null == sourceVersion ? _self.sourceVersion : sourceVersion // ignore: cast_nullable_to_non_nullable
as String,providerId: null == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,segments: null == segments ? _self._segments : segments // ignore: cast_nullable_to_non_nullable
as List<AudioTimedSegment>,
  ));
}


}

// dart format on
