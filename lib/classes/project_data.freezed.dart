// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
ProjectStatus _$ProjectStatusFromJson(
  Map<String, dynamic> json
) {
        switch (json['runtimeType']) {
                  case 'open':
          return ProjectOpen.fromJson(
            json
          );
                case 'active':
          return ProjectActive.fromJson(
            json
          );
                case 'onHold':
          return ProjectOnHold.fromJson(
            json
          );
                case 'completed':
          return ProjectCompleted.fromJson(
            json
          );
                case 'archived':
          return ProjectArchived.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'runtimeType',
  'ProjectStatus',
  'Invalid union type "${json['runtimeType']}"!'
);
        }
      
}

/// @nodoc
mixin _$ProjectStatus {

 String get id; DateTime get createdAt; int get utcOffset; String? get timezone; Geolocation? get geolocation;
/// Create a copy of ProjectStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectStatusCopyWith<ProjectStatus> get copyWith => _$ProjectStatusCopyWithImpl<ProjectStatus>(this as ProjectStatus, _$identity);

  /// Serializes this ProjectStatus to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectStatus&&(identical(other.id, id) || other.id == id)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.utcOffset, utcOffset) || other.utcOffset == utcOffset)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.geolocation, geolocation) || other.geolocation == geolocation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,createdAt,utcOffset,timezone,geolocation);

@override
String toString() {
  return 'ProjectStatus(id: $id, createdAt: $createdAt, utcOffset: $utcOffset, timezone: $timezone, geolocation: $geolocation)';
}


}

/// @nodoc
abstract mixin class $ProjectStatusCopyWith<$Res>  {
  factory $ProjectStatusCopyWith(ProjectStatus value, $Res Function(ProjectStatus) _then) = _$ProjectStatusCopyWithImpl;
@useResult
$Res call({
 String id, DateTime createdAt, int utcOffset, String? timezone, Geolocation? geolocation
});


$GeolocationCopyWith<$Res>? get geolocation;

}
/// @nodoc
class _$ProjectStatusCopyWithImpl<$Res>
    implements $ProjectStatusCopyWith<$Res> {
  _$ProjectStatusCopyWithImpl(this._self, this._then);

  final ProjectStatus _self;
  final $Res Function(ProjectStatus) _then;

/// Create a copy of ProjectStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? createdAt = null,Object? utcOffset = null,Object? timezone = freezed,Object? geolocation = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,utcOffset: null == utcOffset ? _self.utcOffset : utcOffset // ignore: cast_nullable_to_non_nullable
as int,timezone: freezed == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String?,geolocation: freezed == geolocation ? _self.geolocation : geolocation // ignore: cast_nullable_to_non_nullable
as Geolocation?,
  ));
}
/// Create a copy of ProjectStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeolocationCopyWith<$Res>? get geolocation {
    if (_self.geolocation == null) {
    return null;
  }

  return $GeolocationCopyWith<$Res>(_self.geolocation!, (value) {
    return _then(_self.copyWith(geolocation: value));
  });
}
}


/// Adds pattern-matching-related methods to [ProjectStatus].
extension ProjectStatusPatterns on ProjectStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ProjectOpen value)?  open,TResult Function( ProjectActive value)?  active,TResult Function( ProjectOnHold value)?  onHold,TResult Function( ProjectCompleted value)?  completed,TResult Function( ProjectArchived value)?  archived,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ProjectOpen() when open != null:
return open(_that);case ProjectActive() when active != null:
return active(_that);case ProjectOnHold() when onHold != null:
return onHold(_that);case ProjectCompleted() when completed != null:
return completed(_that);case ProjectArchived() when archived != null:
return archived(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ProjectOpen value)  open,required TResult Function( ProjectActive value)  active,required TResult Function( ProjectOnHold value)  onHold,required TResult Function( ProjectCompleted value)  completed,required TResult Function( ProjectArchived value)  archived,}){
final _that = this;
switch (_that) {
case ProjectOpen():
return open(_that);case ProjectActive():
return active(_that);case ProjectOnHold():
return onHold(_that);case ProjectCompleted():
return completed(_that);case ProjectArchived():
return archived(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ProjectOpen value)?  open,TResult? Function( ProjectActive value)?  active,TResult? Function( ProjectOnHold value)?  onHold,TResult? Function( ProjectCompleted value)?  completed,TResult? Function( ProjectArchived value)?  archived,}){
final _that = this;
switch (_that) {
case ProjectOpen() when open != null:
return open(_that);case ProjectActive() when active != null:
return active(_that);case ProjectOnHold() when onHold != null:
return onHold(_that);case ProjectCompleted() when completed != null:
return completed(_that);case ProjectArchived() when archived != null:
return archived(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String id,  DateTime createdAt,  int utcOffset,  String? timezone,  Geolocation? geolocation)?  open,TResult Function( String id,  DateTime createdAt,  int utcOffset,  String? timezone,  Geolocation? geolocation)?  active,TResult Function( String id,  DateTime createdAt,  int utcOffset,  String reason,  String? timezone,  Geolocation? geolocation)?  onHold,TResult Function( String id,  DateTime createdAt,  int utcOffset,  String? timezone,  Geolocation? geolocation)?  completed,TResult Function( String id,  DateTime createdAt,  int utcOffset,  String? timezone,  Geolocation? geolocation)?  archived,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ProjectOpen() when open != null:
return open(_that.id,_that.createdAt,_that.utcOffset,_that.timezone,_that.geolocation);case ProjectActive() when active != null:
return active(_that.id,_that.createdAt,_that.utcOffset,_that.timezone,_that.geolocation);case ProjectOnHold() when onHold != null:
return onHold(_that.id,_that.createdAt,_that.utcOffset,_that.reason,_that.timezone,_that.geolocation);case ProjectCompleted() when completed != null:
return completed(_that.id,_that.createdAt,_that.utcOffset,_that.timezone,_that.geolocation);case ProjectArchived() when archived != null:
return archived(_that.id,_that.createdAt,_that.utcOffset,_that.timezone,_that.geolocation);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String id,  DateTime createdAt,  int utcOffset,  String? timezone,  Geolocation? geolocation)  open,required TResult Function( String id,  DateTime createdAt,  int utcOffset,  String? timezone,  Geolocation? geolocation)  active,required TResult Function( String id,  DateTime createdAt,  int utcOffset,  String reason,  String? timezone,  Geolocation? geolocation)  onHold,required TResult Function( String id,  DateTime createdAt,  int utcOffset,  String? timezone,  Geolocation? geolocation)  completed,required TResult Function( String id,  DateTime createdAt,  int utcOffset,  String? timezone,  Geolocation? geolocation)  archived,}) {final _that = this;
switch (_that) {
case ProjectOpen():
return open(_that.id,_that.createdAt,_that.utcOffset,_that.timezone,_that.geolocation);case ProjectActive():
return active(_that.id,_that.createdAt,_that.utcOffset,_that.timezone,_that.geolocation);case ProjectOnHold():
return onHold(_that.id,_that.createdAt,_that.utcOffset,_that.reason,_that.timezone,_that.geolocation);case ProjectCompleted():
return completed(_that.id,_that.createdAt,_that.utcOffset,_that.timezone,_that.geolocation);case ProjectArchived():
return archived(_that.id,_that.createdAt,_that.utcOffset,_that.timezone,_that.geolocation);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String id,  DateTime createdAt,  int utcOffset,  String? timezone,  Geolocation? geolocation)?  open,TResult? Function( String id,  DateTime createdAt,  int utcOffset,  String? timezone,  Geolocation? geolocation)?  active,TResult? Function( String id,  DateTime createdAt,  int utcOffset,  String reason,  String? timezone,  Geolocation? geolocation)?  onHold,TResult? Function( String id,  DateTime createdAt,  int utcOffset,  String? timezone,  Geolocation? geolocation)?  completed,TResult? Function( String id,  DateTime createdAt,  int utcOffset,  String? timezone,  Geolocation? geolocation)?  archived,}) {final _that = this;
switch (_that) {
case ProjectOpen() when open != null:
return open(_that.id,_that.createdAt,_that.utcOffset,_that.timezone,_that.geolocation);case ProjectActive() when active != null:
return active(_that.id,_that.createdAt,_that.utcOffset,_that.timezone,_that.geolocation);case ProjectOnHold() when onHold != null:
return onHold(_that.id,_that.createdAt,_that.utcOffset,_that.reason,_that.timezone,_that.geolocation);case ProjectCompleted() when completed != null:
return completed(_that.id,_that.createdAt,_that.utcOffset,_that.timezone,_that.geolocation);case ProjectArchived() when archived != null:
return archived(_that.id,_that.createdAt,_that.utcOffset,_that.timezone,_that.geolocation);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class ProjectOpen implements ProjectStatus {
  const ProjectOpen({required this.id, required this.createdAt, required this.utcOffset, this.timezone, this.geolocation, final  String? $type}): $type = $type ?? 'open';
  factory ProjectOpen.fromJson(Map<String, dynamic> json) => _$ProjectOpenFromJson(json);

@override final  String id;
@override final  DateTime createdAt;
@override final  int utcOffset;
@override final  String? timezone;
@override final  Geolocation? geolocation;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of ProjectStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectOpenCopyWith<ProjectOpen> get copyWith => _$ProjectOpenCopyWithImpl<ProjectOpen>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectOpenToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectOpen&&(identical(other.id, id) || other.id == id)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.utcOffset, utcOffset) || other.utcOffset == utcOffset)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.geolocation, geolocation) || other.geolocation == geolocation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,createdAt,utcOffset,timezone,geolocation);

@override
String toString() {
  return 'ProjectStatus.open(id: $id, createdAt: $createdAt, utcOffset: $utcOffset, timezone: $timezone, geolocation: $geolocation)';
}


}

/// @nodoc
abstract mixin class $ProjectOpenCopyWith<$Res> implements $ProjectStatusCopyWith<$Res> {
  factory $ProjectOpenCopyWith(ProjectOpen value, $Res Function(ProjectOpen) _then) = _$ProjectOpenCopyWithImpl;
@override @useResult
$Res call({
 String id, DateTime createdAt, int utcOffset, String? timezone, Geolocation? geolocation
});


@override $GeolocationCopyWith<$Res>? get geolocation;

}
/// @nodoc
class _$ProjectOpenCopyWithImpl<$Res>
    implements $ProjectOpenCopyWith<$Res> {
  _$ProjectOpenCopyWithImpl(this._self, this._then);

  final ProjectOpen _self;
  final $Res Function(ProjectOpen) _then;

/// Create a copy of ProjectStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? createdAt = null,Object? utcOffset = null,Object? timezone = freezed,Object? geolocation = freezed,}) {
  return _then(ProjectOpen(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,utcOffset: null == utcOffset ? _self.utcOffset : utcOffset // ignore: cast_nullable_to_non_nullable
as int,timezone: freezed == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String?,geolocation: freezed == geolocation ? _self.geolocation : geolocation // ignore: cast_nullable_to_non_nullable
as Geolocation?,
  ));
}

/// Create a copy of ProjectStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeolocationCopyWith<$Res>? get geolocation {
    if (_self.geolocation == null) {
    return null;
  }

  return $GeolocationCopyWith<$Res>(_self.geolocation!, (value) {
    return _then(_self.copyWith(geolocation: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class ProjectActive implements ProjectStatus {
  const ProjectActive({required this.id, required this.createdAt, required this.utcOffset, this.timezone, this.geolocation, final  String? $type}): $type = $type ?? 'active';
  factory ProjectActive.fromJson(Map<String, dynamic> json) => _$ProjectActiveFromJson(json);

@override final  String id;
@override final  DateTime createdAt;
@override final  int utcOffset;
@override final  String? timezone;
@override final  Geolocation? geolocation;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of ProjectStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectActiveCopyWith<ProjectActive> get copyWith => _$ProjectActiveCopyWithImpl<ProjectActive>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectActiveToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectActive&&(identical(other.id, id) || other.id == id)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.utcOffset, utcOffset) || other.utcOffset == utcOffset)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.geolocation, geolocation) || other.geolocation == geolocation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,createdAt,utcOffset,timezone,geolocation);

@override
String toString() {
  return 'ProjectStatus.active(id: $id, createdAt: $createdAt, utcOffset: $utcOffset, timezone: $timezone, geolocation: $geolocation)';
}


}

/// @nodoc
abstract mixin class $ProjectActiveCopyWith<$Res> implements $ProjectStatusCopyWith<$Res> {
  factory $ProjectActiveCopyWith(ProjectActive value, $Res Function(ProjectActive) _then) = _$ProjectActiveCopyWithImpl;
@override @useResult
$Res call({
 String id, DateTime createdAt, int utcOffset, String? timezone, Geolocation? geolocation
});


@override $GeolocationCopyWith<$Res>? get geolocation;

}
/// @nodoc
class _$ProjectActiveCopyWithImpl<$Res>
    implements $ProjectActiveCopyWith<$Res> {
  _$ProjectActiveCopyWithImpl(this._self, this._then);

  final ProjectActive _self;
  final $Res Function(ProjectActive) _then;

/// Create a copy of ProjectStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? createdAt = null,Object? utcOffset = null,Object? timezone = freezed,Object? geolocation = freezed,}) {
  return _then(ProjectActive(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,utcOffset: null == utcOffset ? _self.utcOffset : utcOffset // ignore: cast_nullable_to_non_nullable
as int,timezone: freezed == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String?,geolocation: freezed == geolocation ? _self.geolocation : geolocation // ignore: cast_nullable_to_non_nullable
as Geolocation?,
  ));
}

/// Create a copy of ProjectStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeolocationCopyWith<$Res>? get geolocation {
    if (_self.geolocation == null) {
    return null;
  }

  return $GeolocationCopyWith<$Res>(_self.geolocation!, (value) {
    return _then(_self.copyWith(geolocation: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class ProjectOnHold implements ProjectStatus {
  const ProjectOnHold({required this.id, required this.createdAt, required this.utcOffset, required this.reason, this.timezone, this.geolocation, final  String? $type}): $type = $type ?? 'onHold';
  factory ProjectOnHold.fromJson(Map<String, dynamic> json) => _$ProjectOnHoldFromJson(json);

@override final  String id;
@override final  DateTime createdAt;
@override final  int utcOffset;
 final  String reason;
@override final  String? timezone;
@override final  Geolocation? geolocation;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of ProjectStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectOnHoldCopyWith<ProjectOnHold> get copyWith => _$ProjectOnHoldCopyWithImpl<ProjectOnHold>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectOnHoldToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectOnHold&&(identical(other.id, id) || other.id == id)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.utcOffset, utcOffset) || other.utcOffset == utcOffset)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.geolocation, geolocation) || other.geolocation == geolocation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,createdAt,utcOffset,reason,timezone,geolocation);

@override
String toString() {
  return 'ProjectStatus.onHold(id: $id, createdAt: $createdAt, utcOffset: $utcOffset, reason: $reason, timezone: $timezone, geolocation: $geolocation)';
}


}

/// @nodoc
abstract mixin class $ProjectOnHoldCopyWith<$Res> implements $ProjectStatusCopyWith<$Res> {
  factory $ProjectOnHoldCopyWith(ProjectOnHold value, $Res Function(ProjectOnHold) _then) = _$ProjectOnHoldCopyWithImpl;
@override @useResult
$Res call({
 String id, DateTime createdAt, int utcOffset, String reason, String? timezone, Geolocation? geolocation
});


@override $GeolocationCopyWith<$Res>? get geolocation;

}
/// @nodoc
class _$ProjectOnHoldCopyWithImpl<$Res>
    implements $ProjectOnHoldCopyWith<$Res> {
  _$ProjectOnHoldCopyWithImpl(this._self, this._then);

  final ProjectOnHold _self;
  final $Res Function(ProjectOnHold) _then;

/// Create a copy of ProjectStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? createdAt = null,Object? utcOffset = null,Object? reason = null,Object? timezone = freezed,Object? geolocation = freezed,}) {
  return _then(ProjectOnHold(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,utcOffset: null == utcOffset ? _self.utcOffset : utcOffset // ignore: cast_nullable_to_non_nullable
as int,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,timezone: freezed == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String?,geolocation: freezed == geolocation ? _self.geolocation : geolocation // ignore: cast_nullable_to_non_nullable
as Geolocation?,
  ));
}

/// Create a copy of ProjectStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeolocationCopyWith<$Res>? get geolocation {
    if (_self.geolocation == null) {
    return null;
  }

  return $GeolocationCopyWith<$Res>(_self.geolocation!, (value) {
    return _then(_self.copyWith(geolocation: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class ProjectCompleted implements ProjectStatus {
  const ProjectCompleted({required this.id, required this.createdAt, required this.utcOffset, this.timezone, this.geolocation, final  String? $type}): $type = $type ?? 'completed';
  factory ProjectCompleted.fromJson(Map<String, dynamic> json) => _$ProjectCompletedFromJson(json);

@override final  String id;
@override final  DateTime createdAt;
@override final  int utcOffset;
@override final  String? timezone;
@override final  Geolocation? geolocation;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of ProjectStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectCompletedCopyWith<ProjectCompleted> get copyWith => _$ProjectCompletedCopyWithImpl<ProjectCompleted>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectCompletedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectCompleted&&(identical(other.id, id) || other.id == id)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.utcOffset, utcOffset) || other.utcOffset == utcOffset)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.geolocation, geolocation) || other.geolocation == geolocation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,createdAt,utcOffset,timezone,geolocation);

@override
String toString() {
  return 'ProjectStatus.completed(id: $id, createdAt: $createdAt, utcOffset: $utcOffset, timezone: $timezone, geolocation: $geolocation)';
}


}

/// @nodoc
abstract mixin class $ProjectCompletedCopyWith<$Res> implements $ProjectStatusCopyWith<$Res> {
  factory $ProjectCompletedCopyWith(ProjectCompleted value, $Res Function(ProjectCompleted) _then) = _$ProjectCompletedCopyWithImpl;
@override @useResult
$Res call({
 String id, DateTime createdAt, int utcOffset, String? timezone, Geolocation? geolocation
});


@override $GeolocationCopyWith<$Res>? get geolocation;

}
/// @nodoc
class _$ProjectCompletedCopyWithImpl<$Res>
    implements $ProjectCompletedCopyWith<$Res> {
  _$ProjectCompletedCopyWithImpl(this._self, this._then);

  final ProjectCompleted _self;
  final $Res Function(ProjectCompleted) _then;

/// Create a copy of ProjectStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? createdAt = null,Object? utcOffset = null,Object? timezone = freezed,Object? geolocation = freezed,}) {
  return _then(ProjectCompleted(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,utcOffset: null == utcOffset ? _self.utcOffset : utcOffset // ignore: cast_nullable_to_non_nullable
as int,timezone: freezed == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String?,geolocation: freezed == geolocation ? _self.geolocation : geolocation // ignore: cast_nullable_to_non_nullable
as Geolocation?,
  ));
}

/// Create a copy of ProjectStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeolocationCopyWith<$Res>? get geolocation {
    if (_self.geolocation == null) {
    return null;
  }

  return $GeolocationCopyWith<$Res>(_self.geolocation!, (value) {
    return _then(_self.copyWith(geolocation: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class ProjectArchived implements ProjectStatus {
  const ProjectArchived({required this.id, required this.createdAt, required this.utcOffset, this.timezone, this.geolocation, final  String? $type}): $type = $type ?? 'archived';
  factory ProjectArchived.fromJson(Map<String, dynamic> json) => _$ProjectArchivedFromJson(json);

@override final  String id;
@override final  DateTime createdAt;
@override final  int utcOffset;
@override final  String? timezone;
@override final  Geolocation? geolocation;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of ProjectStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectArchivedCopyWith<ProjectArchived> get copyWith => _$ProjectArchivedCopyWithImpl<ProjectArchived>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectArchivedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectArchived&&(identical(other.id, id) || other.id == id)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.utcOffset, utcOffset) || other.utcOffset == utcOffset)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.geolocation, geolocation) || other.geolocation == geolocation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,createdAt,utcOffset,timezone,geolocation);

@override
String toString() {
  return 'ProjectStatus.archived(id: $id, createdAt: $createdAt, utcOffset: $utcOffset, timezone: $timezone, geolocation: $geolocation)';
}


}

/// @nodoc
abstract mixin class $ProjectArchivedCopyWith<$Res> implements $ProjectStatusCopyWith<$Res> {
  factory $ProjectArchivedCopyWith(ProjectArchived value, $Res Function(ProjectArchived) _then) = _$ProjectArchivedCopyWithImpl;
@override @useResult
$Res call({
 String id, DateTime createdAt, int utcOffset, String? timezone, Geolocation? geolocation
});


@override $GeolocationCopyWith<$Res>? get geolocation;

}
/// @nodoc
class _$ProjectArchivedCopyWithImpl<$Res>
    implements $ProjectArchivedCopyWith<$Res> {
  _$ProjectArchivedCopyWithImpl(this._self, this._then);

  final ProjectArchived _self;
  final $Res Function(ProjectArchived) _then;

/// Create a copy of ProjectStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? createdAt = null,Object? utcOffset = null,Object? timezone = freezed,Object? geolocation = freezed,}) {
  return _then(ProjectArchived(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,utcOffset: null == utcOffset ? _self.utcOffset : utcOffset // ignore: cast_nullable_to_non_nullable
as int,timezone: freezed == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String?,geolocation: freezed == geolocation ? _self.geolocation : geolocation // ignore: cast_nullable_to_non_nullable
as Geolocation?,
  ));
}

/// Create a copy of ProjectStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeolocationCopyWith<$Res>? get geolocation {
    if (_self.geolocation == null) {
    return null;
  }

  return $GeolocationCopyWith<$Res>(_self.geolocation!, (value) {
    return _then(_self.copyWith(geolocation: value));
  });
}
}


/// @nodoc
mixin _$ProjectData {

 String get title; ProjectStatus get status; DateTime get dateFrom; DateTime get dateTo; List<ProjectStatus> get statusHistory; DateTime? get targetDate;/// Inference profile ID for the project agent.
 String? get profileId;/// ID of a linked JournalImage to use as cover art.
 String? get coverArtId;/// Horizontal offset for square thumbnail crop from 2:1 cover art.
 double get coverArtCropX;
/// Create a copy of ProjectData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectDataCopyWith<ProjectData> get copyWith => _$ProjectDataCopyWithImpl<ProjectData>(this as ProjectData, _$identity);

  /// Serializes this ProjectData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectData&&(identical(other.title, title) || other.title == title)&&(identical(other.status, status) || other.status == status)&&(identical(other.dateFrom, dateFrom) || other.dateFrom == dateFrom)&&(identical(other.dateTo, dateTo) || other.dateTo == dateTo)&&const DeepCollectionEquality().equals(other.statusHistory, statusHistory)&&(identical(other.targetDate, targetDate) || other.targetDate == targetDate)&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.coverArtId, coverArtId) || other.coverArtId == coverArtId)&&(identical(other.coverArtCropX, coverArtCropX) || other.coverArtCropX == coverArtCropX));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,status,dateFrom,dateTo,const DeepCollectionEquality().hash(statusHistory),targetDate,profileId,coverArtId,coverArtCropX);

@override
String toString() {
  return 'ProjectData(title: $title, status: $status, dateFrom: $dateFrom, dateTo: $dateTo, statusHistory: $statusHistory, targetDate: $targetDate, profileId: $profileId, coverArtId: $coverArtId, coverArtCropX: $coverArtCropX)';
}


}

/// @nodoc
abstract mixin class $ProjectDataCopyWith<$Res>  {
  factory $ProjectDataCopyWith(ProjectData value, $Res Function(ProjectData) _then) = _$ProjectDataCopyWithImpl;
@useResult
$Res call({
 String title, ProjectStatus status, DateTime dateFrom, DateTime dateTo, List<ProjectStatus> statusHistory, DateTime? targetDate, String? profileId, String? coverArtId, double coverArtCropX
});


$ProjectStatusCopyWith<$Res> get status;

}
/// @nodoc
class _$ProjectDataCopyWithImpl<$Res>
    implements $ProjectDataCopyWith<$Res> {
  _$ProjectDataCopyWithImpl(this._self, this._then);

  final ProjectData _self;
  final $Res Function(ProjectData) _then;

/// Create a copy of ProjectData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? status = null,Object? dateFrom = null,Object? dateTo = null,Object? statusHistory = null,Object? targetDate = freezed,Object? profileId = freezed,Object? coverArtId = freezed,Object? coverArtCropX = null,}) {
  return _then(_self.copyWith(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ProjectStatus,dateFrom: null == dateFrom ? _self.dateFrom : dateFrom // ignore: cast_nullable_to_non_nullable
as DateTime,dateTo: null == dateTo ? _self.dateTo : dateTo // ignore: cast_nullable_to_non_nullable
as DateTime,statusHistory: null == statusHistory ? _self.statusHistory : statusHistory // ignore: cast_nullable_to_non_nullable
as List<ProjectStatus>,targetDate: freezed == targetDate ? _self.targetDate : targetDate // ignore: cast_nullable_to_non_nullable
as DateTime?,profileId: freezed == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as String?,coverArtId: freezed == coverArtId ? _self.coverArtId : coverArtId // ignore: cast_nullable_to_non_nullable
as String?,coverArtCropX: null == coverArtCropX ? _self.coverArtCropX : coverArtCropX // ignore: cast_nullable_to_non_nullable
as double,
  ));
}
/// Create a copy of ProjectData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProjectStatusCopyWith<$Res> get status {
  
  return $ProjectStatusCopyWith<$Res>(_self.status, (value) {
    return _then(_self.copyWith(status: value));
  });
}
}


/// Adds pattern-matching-related methods to [ProjectData].
extension ProjectDataPatterns on ProjectData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProjectData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProjectData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProjectData value)  $default,){
final _that = this;
switch (_that) {
case _ProjectData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProjectData value)?  $default,){
final _that = this;
switch (_that) {
case _ProjectData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String title,  ProjectStatus status,  DateTime dateFrom,  DateTime dateTo,  List<ProjectStatus> statusHistory,  DateTime? targetDate,  String? profileId,  String? coverArtId,  double coverArtCropX)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProjectData() when $default != null:
return $default(_that.title,_that.status,_that.dateFrom,_that.dateTo,_that.statusHistory,_that.targetDate,_that.profileId,_that.coverArtId,_that.coverArtCropX);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String title,  ProjectStatus status,  DateTime dateFrom,  DateTime dateTo,  List<ProjectStatus> statusHistory,  DateTime? targetDate,  String? profileId,  String? coverArtId,  double coverArtCropX)  $default,) {final _that = this;
switch (_that) {
case _ProjectData():
return $default(_that.title,_that.status,_that.dateFrom,_that.dateTo,_that.statusHistory,_that.targetDate,_that.profileId,_that.coverArtId,_that.coverArtCropX);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String title,  ProjectStatus status,  DateTime dateFrom,  DateTime dateTo,  List<ProjectStatus> statusHistory,  DateTime? targetDate,  String? profileId,  String? coverArtId,  double coverArtCropX)?  $default,) {final _that = this;
switch (_that) {
case _ProjectData() when $default != null:
return $default(_that.title,_that.status,_that.dateFrom,_that.dateTo,_that.statusHistory,_that.targetDate,_that.profileId,_that.coverArtId,_that.coverArtCropX);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProjectData implements ProjectData {
  const _ProjectData({required this.title, required this.status, required this.dateFrom, required this.dateTo, final  List<ProjectStatus> statusHistory = const [], this.targetDate, this.profileId, this.coverArtId, this.coverArtCropX = 0.5}): _statusHistory = statusHistory;
  factory _ProjectData.fromJson(Map<String, dynamic> json) => _$ProjectDataFromJson(json);

@override final  String title;
@override final  ProjectStatus status;
@override final  DateTime dateFrom;
@override final  DateTime dateTo;
 final  List<ProjectStatus> _statusHistory;
@override@JsonKey() List<ProjectStatus> get statusHistory {
  if (_statusHistory is EqualUnmodifiableListView) return _statusHistory;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_statusHistory);
}

@override final  DateTime? targetDate;
/// Inference profile ID for the project agent.
@override final  String? profileId;
/// ID of a linked JournalImage to use as cover art.
@override final  String? coverArtId;
/// Horizontal offset for square thumbnail crop from 2:1 cover art.
@override@JsonKey() final  double coverArtCropX;

/// Create a copy of ProjectData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectDataCopyWith<_ProjectData> get copyWith => __$ProjectDataCopyWithImpl<_ProjectData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectData&&(identical(other.title, title) || other.title == title)&&(identical(other.status, status) || other.status == status)&&(identical(other.dateFrom, dateFrom) || other.dateFrom == dateFrom)&&(identical(other.dateTo, dateTo) || other.dateTo == dateTo)&&const DeepCollectionEquality().equals(other._statusHistory, _statusHistory)&&(identical(other.targetDate, targetDate) || other.targetDate == targetDate)&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.coverArtId, coverArtId) || other.coverArtId == coverArtId)&&(identical(other.coverArtCropX, coverArtCropX) || other.coverArtCropX == coverArtCropX));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,status,dateFrom,dateTo,const DeepCollectionEquality().hash(_statusHistory),targetDate,profileId,coverArtId,coverArtCropX);

@override
String toString() {
  return 'ProjectData(title: $title, status: $status, dateFrom: $dateFrom, dateTo: $dateTo, statusHistory: $statusHistory, targetDate: $targetDate, profileId: $profileId, coverArtId: $coverArtId, coverArtCropX: $coverArtCropX)';
}


}

/// @nodoc
abstract mixin class _$ProjectDataCopyWith<$Res> implements $ProjectDataCopyWith<$Res> {
  factory _$ProjectDataCopyWith(_ProjectData value, $Res Function(_ProjectData) _then) = __$ProjectDataCopyWithImpl;
@override @useResult
$Res call({
 String title, ProjectStatus status, DateTime dateFrom, DateTime dateTo, List<ProjectStatus> statusHistory, DateTime? targetDate, String? profileId, String? coverArtId, double coverArtCropX
});


@override $ProjectStatusCopyWith<$Res> get status;

}
/// @nodoc
class __$ProjectDataCopyWithImpl<$Res>
    implements _$ProjectDataCopyWith<$Res> {
  __$ProjectDataCopyWithImpl(this._self, this._then);

  final _ProjectData _self;
  final $Res Function(_ProjectData) _then;

/// Create a copy of ProjectData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? status = null,Object? dateFrom = null,Object? dateTo = null,Object? statusHistory = null,Object? targetDate = freezed,Object? profileId = freezed,Object? coverArtId = freezed,Object? coverArtCropX = null,}) {
  return _then(_ProjectData(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ProjectStatus,dateFrom: null == dateFrom ? _self.dateFrom : dateFrom // ignore: cast_nullable_to_non_nullable
as DateTime,dateTo: null == dateTo ? _self.dateTo : dateTo // ignore: cast_nullable_to_non_nullable
as DateTime,statusHistory: null == statusHistory ? _self._statusHistory : statusHistory // ignore: cast_nullable_to_non_nullable
as List<ProjectStatus>,targetDate: freezed == targetDate ? _self.targetDate : targetDate // ignore: cast_nullable_to_non_nullable
as DateTime?,profileId: freezed == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as String?,coverArtId: freezed == coverArtId ? _self.coverArtId : coverArtId // ignore: cast_nullable_to_non_nullable
as String?,coverArtCropX: null == coverArtCropX ? _self.coverArtCropX : coverArtCropX // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

/// Create a copy of ProjectData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProjectStatusCopyWith<$Res> get status {
  
  return $ProjectStatusCopyWith<$Res>(_self.status, (value) {
    return _then(_self.copyWith(status: value));
  });
}
}

// dart format on
