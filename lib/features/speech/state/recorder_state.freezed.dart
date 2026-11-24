// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recorder_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AudioRecorderState {

/// Current status of the recorder.
 AudioRecorderStatus get status;/// Duration of the current recording.
 Duration get progress;/// Current audio level in dBFS, as the level line draws it.
 double get dBFS;/// Whether a check-in screen is drawing this take in place. The
/// recording strip stays hidden while it is: the take already has a
/// recorder on screen.
 bool get inlineHostVisible;/// Optional ID to link recording to existing journal entry.
 String? get linkedId;/// Where the running take was started; null while nothing records.
 RecordingOrigin? get origin;/// Whether to trigger speech recognition after recording.
/// If null, uses category default settings.
 bool? get enableSpeechRecognition;
/// Create a copy of AudioRecorderState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudioRecorderStateCopyWith<AudioRecorderState> get copyWith => _$AudioRecorderStateCopyWithImpl<AudioRecorderState>(this as AudioRecorderState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioRecorderState&&(identical(other.status, status) || other.status == status)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.dBFS, dBFS) || other.dBFS == dBFS)&&(identical(other.inlineHostVisible, inlineHostVisible) || other.inlineHostVisible == inlineHostVisible)&&(identical(other.linkedId, linkedId) || other.linkedId == linkedId)&&(identical(other.origin, origin) || other.origin == origin)&&(identical(other.enableSpeechRecognition, enableSpeechRecognition) || other.enableSpeechRecognition == enableSpeechRecognition));
}


@override
int get hashCode => Object.hash(runtimeType,status,progress,dBFS,inlineHostVisible,linkedId,origin,enableSpeechRecognition);

@override
String toString() {
  return 'AudioRecorderState(status: $status, progress: $progress, dBFS: $dBFS, inlineHostVisible: $inlineHostVisible, linkedId: $linkedId, origin: $origin, enableSpeechRecognition: $enableSpeechRecognition)';
}


}

/// @nodoc
abstract mixin class $AudioRecorderStateCopyWith<$Res>  {
  factory $AudioRecorderStateCopyWith(AudioRecorderState value, $Res Function(AudioRecorderState) _then) = _$AudioRecorderStateCopyWithImpl;
@useResult
$Res call({
 AudioRecorderStatus status, Duration progress, double dBFS, bool inlineHostVisible, String? linkedId, RecordingOrigin? origin, bool? enableSpeechRecognition
});


$RecordingOriginCopyWith<$Res>? get origin;

}
/// @nodoc
class _$AudioRecorderStateCopyWithImpl<$Res>
    implements $AudioRecorderStateCopyWith<$Res> {
  _$AudioRecorderStateCopyWithImpl(this._self, this._then);

  final AudioRecorderState _self;
  final $Res Function(AudioRecorderState) _then;

/// Create a copy of AudioRecorderState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? progress = null,Object? dBFS = null,Object? inlineHostVisible = null,Object? linkedId = freezed,Object? origin = freezed,Object? enableSpeechRecognition = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AudioRecorderStatus,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as Duration,dBFS: null == dBFS ? _self.dBFS : dBFS // ignore: cast_nullable_to_non_nullable
as double,inlineHostVisible: null == inlineHostVisible ? _self.inlineHostVisible : inlineHostVisible // ignore: cast_nullable_to_non_nullable
as bool,linkedId: freezed == linkedId ? _self.linkedId : linkedId // ignore: cast_nullable_to_non_nullable
as String?,origin: freezed == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as RecordingOrigin?,enableSpeechRecognition: freezed == enableSpeechRecognition ? _self.enableSpeechRecognition : enableSpeechRecognition // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}
/// Create a copy of AudioRecorderState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RecordingOriginCopyWith<$Res>? get origin {
    if (_self.origin == null) {
    return null;
  }

  return $RecordingOriginCopyWith<$Res>(_self.origin!, (value) {
    return _then(_self.copyWith(origin: value));
  });
}
}


/// Adds pattern-matching-related methods to [AudioRecorderState].
extension AudioRecorderStatePatterns on AudioRecorderState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AudioRecorderState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AudioRecorderState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AudioRecorderState value)  $default,){
final _that = this;
switch (_that) {
case _AudioRecorderState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AudioRecorderState value)?  $default,){
final _that = this;
switch (_that) {
case _AudioRecorderState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AudioRecorderStatus status,  Duration progress,  double dBFS,  bool inlineHostVisible,  String? linkedId,  RecordingOrigin? origin,  bool? enableSpeechRecognition)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AudioRecorderState() when $default != null:
return $default(_that.status,_that.progress,_that.dBFS,_that.inlineHostVisible,_that.linkedId,_that.origin,_that.enableSpeechRecognition);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AudioRecorderStatus status,  Duration progress,  double dBFS,  bool inlineHostVisible,  String? linkedId,  RecordingOrigin? origin,  bool? enableSpeechRecognition)  $default,) {final _that = this;
switch (_that) {
case _AudioRecorderState():
return $default(_that.status,_that.progress,_that.dBFS,_that.inlineHostVisible,_that.linkedId,_that.origin,_that.enableSpeechRecognition);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AudioRecorderStatus status,  Duration progress,  double dBFS,  bool inlineHostVisible,  String? linkedId,  RecordingOrigin? origin,  bool? enableSpeechRecognition)?  $default,) {final _that = this;
switch (_that) {
case _AudioRecorderState() when $default != null:
return $default(_that.status,_that.progress,_that.dBFS,_that.inlineHostVisible,_that.linkedId,_that.origin,_that.enableSpeechRecognition);case _:
  return null;

}
}

}

/// @nodoc


class _AudioRecorderState implements AudioRecorderState {
   _AudioRecorderState({required this.status, required this.progress, required this.dBFS, required this.inlineHostVisible, this.linkedId, this.origin, this.enableSpeechRecognition});
  

/// Current status of the recorder.
@override final  AudioRecorderStatus status;
/// Duration of the current recording.
@override final  Duration progress;
/// Current audio level in dBFS, as the level line draws it.
@override final  double dBFS;
/// Whether a check-in screen is drawing this take in place. The
/// recording strip stays hidden while it is: the take already has a
/// recorder on screen.
@override final  bool inlineHostVisible;
/// Optional ID to link recording to existing journal entry.
@override final  String? linkedId;
/// Where the running take was started; null while nothing records.
@override final  RecordingOrigin? origin;
/// Whether to trigger speech recognition after recording.
/// If null, uses category default settings.
@override final  bool? enableSpeechRecognition;

/// Create a copy of AudioRecorderState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AudioRecorderStateCopyWith<_AudioRecorderState> get copyWith => __$AudioRecorderStateCopyWithImpl<_AudioRecorderState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AudioRecorderState&&(identical(other.status, status) || other.status == status)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.dBFS, dBFS) || other.dBFS == dBFS)&&(identical(other.inlineHostVisible, inlineHostVisible) || other.inlineHostVisible == inlineHostVisible)&&(identical(other.linkedId, linkedId) || other.linkedId == linkedId)&&(identical(other.origin, origin) || other.origin == origin)&&(identical(other.enableSpeechRecognition, enableSpeechRecognition) || other.enableSpeechRecognition == enableSpeechRecognition));
}


@override
int get hashCode => Object.hash(runtimeType,status,progress,dBFS,inlineHostVisible,linkedId,origin,enableSpeechRecognition);

@override
String toString() {
  return 'AudioRecorderState(status: $status, progress: $progress, dBFS: $dBFS, inlineHostVisible: $inlineHostVisible, linkedId: $linkedId, origin: $origin, enableSpeechRecognition: $enableSpeechRecognition)';
}


}

/// @nodoc
abstract mixin class _$AudioRecorderStateCopyWith<$Res> implements $AudioRecorderStateCopyWith<$Res> {
  factory _$AudioRecorderStateCopyWith(_AudioRecorderState value, $Res Function(_AudioRecorderState) _then) = __$AudioRecorderStateCopyWithImpl;
@override @useResult
$Res call({
 AudioRecorderStatus status, Duration progress, double dBFS, bool inlineHostVisible, String? linkedId, RecordingOrigin? origin, bool? enableSpeechRecognition
});


@override $RecordingOriginCopyWith<$Res>? get origin;

}
/// @nodoc
class __$AudioRecorderStateCopyWithImpl<$Res>
    implements _$AudioRecorderStateCopyWith<$Res> {
  __$AudioRecorderStateCopyWithImpl(this._self, this._then);

  final _AudioRecorderState _self;
  final $Res Function(_AudioRecorderState) _then;

/// Create a copy of AudioRecorderState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? progress = null,Object? dBFS = null,Object? inlineHostVisible = null,Object? linkedId = freezed,Object? origin = freezed,Object? enableSpeechRecognition = freezed,}) {
  return _then(_AudioRecorderState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AudioRecorderStatus,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as Duration,dBFS: null == dBFS ? _self.dBFS : dBFS // ignore: cast_nullable_to_non_nullable
as double,inlineHostVisible: null == inlineHostVisible ? _self.inlineHostVisible : inlineHostVisible // ignore: cast_nullable_to_non_nullable
as bool,linkedId: freezed == linkedId ? _self.linkedId : linkedId // ignore: cast_nullable_to_non_nullable
as String?,origin: freezed == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as RecordingOrigin?,enableSpeechRecognition: freezed == enableSpeechRecognition ? _self.enableSpeechRecognition : enableSpeechRecognition // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

/// Create a copy of AudioRecorderState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RecordingOriginCopyWith<$Res>? get origin {
    if (_self.origin == null) {
    return null;
  }

  return $RecordingOriginCopyWith<$Res>(_self.origin!, (value) {
    return _then(_self.copyWith(origin: value));
  });
}
}

// dart format on
