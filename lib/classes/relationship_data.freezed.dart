// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'relationship_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ContactChannel {

 ContactChannelType get type; String get value; String? get label;
/// Create a copy of ContactChannel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ContactChannelCopyWith<ContactChannel> get copyWith => _$ContactChannelCopyWithImpl<ContactChannel>(this as ContactChannel, _$identity);

  /// Serializes this ContactChannel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ContactChannel&&(identical(other.type, type) || other.type == type)&&(identical(other.value, value) || other.value == value)&&(identical(other.label, label) || other.label == label));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,value,label);

@override
String toString() {
  return 'ContactChannel(type: $type, value: $value, label: $label)';
}


}

/// @nodoc
abstract mixin class $ContactChannelCopyWith<$Res>  {
  factory $ContactChannelCopyWith(ContactChannel value, $Res Function(ContactChannel) _then) = _$ContactChannelCopyWithImpl;
@useResult
$Res call({
 ContactChannelType type, String value, String? label
});




}
/// @nodoc
class _$ContactChannelCopyWithImpl<$Res>
    implements $ContactChannelCopyWith<$Res> {
  _$ContactChannelCopyWithImpl(this._self, this._then);

  final ContactChannel _self;
  final $Res Function(ContactChannel) _then;

/// Create a copy of ContactChannel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? value = null,Object? label = freezed,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ContactChannelType,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ContactChannel].
extension ContactChannelPatterns on ContactChannel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ContactChannel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ContactChannel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ContactChannel value)  $default,){
final _that = this;
switch (_that) {
case _ContactChannel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ContactChannel value)?  $default,){
final _that = this;
switch (_that) {
case _ContactChannel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ContactChannelType type,  String value,  String? label)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ContactChannel() when $default != null:
return $default(_that.type,_that.value,_that.label);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ContactChannelType type,  String value,  String? label)  $default,) {final _that = this;
switch (_that) {
case _ContactChannel():
return $default(_that.type,_that.value,_that.label);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ContactChannelType type,  String value,  String? label)?  $default,) {final _that = this;
switch (_that) {
case _ContactChannel() when $default != null:
return $default(_that.type,_that.value,_that.label);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ContactChannel implements ContactChannel {
  const _ContactChannel({required this.type, required this.value, this.label});
  factory _ContactChannel.fromJson(Map<String, dynamic> json) => _$ContactChannelFromJson(json);

@override final  ContactChannelType type;
@override final  String value;
@override final  String? label;

/// Create a copy of ContactChannel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ContactChannelCopyWith<_ContactChannel> get copyWith => __$ContactChannelCopyWithImpl<_ContactChannel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ContactChannelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ContactChannel&&(identical(other.type, type) || other.type == type)&&(identical(other.value, value) || other.value == value)&&(identical(other.label, label) || other.label == label));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,value,label);

@override
String toString() {
  return 'ContactChannel(type: $type, value: $value, label: $label)';
}


}

/// @nodoc
abstract mixin class _$ContactChannelCopyWith<$Res> implements $ContactChannelCopyWith<$Res> {
  factory _$ContactChannelCopyWith(_ContactChannel value, $Res Function(_ContactChannel) _then) = __$ContactChannelCopyWithImpl;
@override @useResult
$Res call({
 ContactChannelType type, String value, String? label
});




}
/// @nodoc
class __$ContactChannelCopyWithImpl<$Res>
    implements _$ContactChannelCopyWith<$Res> {
  __$ContactChannelCopyWithImpl(this._self, this._then);

  final _ContactChannel _self;
  final $Res Function(_ContactChannel) _then;

/// Create a copy of ContactChannel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? value = null,Object? label = freezed,}) {
  return _then(_ContactChannel(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ContactChannelType,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

RelationshipStatus _$RelationshipStatusFromJson(
  Map<String, dynamic> json
) {
        switch (json['runtimeType']) {
                  case 'active':
          return RelationshipActive.fromJson(
            json
          );
                case 'dormant':
          return RelationshipDormant.fromJson(
            json
          );
                case 'archived':
          return RelationshipArchived.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'runtimeType',
  'RelationshipStatus',
  'Invalid union type "${json['runtimeType']}"!'
);
        }
      
}

/// @nodoc
mixin _$RelationshipStatus {

 String get id; DateTime get createdAt; int get utcOffset; String? get timezone; Geolocation? get geolocation;
/// Create a copy of RelationshipStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RelationshipStatusCopyWith<RelationshipStatus> get copyWith => _$RelationshipStatusCopyWithImpl<RelationshipStatus>(this as RelationshipStatus, _$identity);

  /// Serializes this RelationshipStatus to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RelationshipStatus&&(identical(other.id, id) || other.id == id)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.utcOffset, utcOffset) || other.utcOffset == utcOffset)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.geolocation, geolocation) || other.geolocation == geolocation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,createdAt,utcOffset,timezone,geolocation);

@override
String toString() {
  return 'RelationshipStatus(id: $id, createdAt: $createdAt, utcOffset: $utcOffset, timezone: $timezone, geolocation: $geolocation)';
}


}

/// @nodoc
abstract mixin class $RelationshipStatusCopyWith<$Res>  {
  factory $RelationshipStatusCopyWith(RelationshipStatus value, $Res Function(RelationshipStatus) _then) = _$RelationshipStatusCopyWithImpl;
@useResult
$Res call({
 String id, DateTime createdAt, int utcOffset, String? timezone, Geolocation? geolocation
});


$GeolocationCopyWith<$Res>? get geolocation;

}
/// @nodoc
class _$RelationshipStatusCopyWithImpl<$Res>
    implements $RelationshipStatusCopyWith<$Res> {
  _$RelationshipStatusCopyWithImpl(this._self, this._then);

  final RelationshipStatus _self;
  final $Res Function(RelationshipStatus) _then;

/// Create a copy of RelationshipStatus
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
/// Create a copy of RelationshipStatus
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


/// Adds pattern-matching-related methods to [RelationshipStatus].
extension RelationshipStatusPatterns on RelationshipStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( RelationshipActive value)?  active,TResult Function( RelationshipDormant value)?  dormant,TResult Function( RelationshipArchived value)?  archived,required TResult orElse(),}){
final _that = this;
switch (_that) {
case RelationshipActive() when active != null:
return active(_that);case RelationshipDormant() when dormant != null:
return dormant(_that);case RelationshipArchived() when archived != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( RelationshipActive value)  active,required TResult Function( RelationshipDormant value)  dormant,required TResult Function( RelationshipArchived value)  archived,}){
final _that = this;
switch (_that) {
case RelationshipActive():
return active(_that);case RelationshipDormant():
return dormant(_that);case RelationshipArchived():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( RelationshipActive value)?  active,TResult? Function( RelationshipDormant value)?  dormant,TResult? Function( RelationshipArchived value)?  archived,}){
final _that = this;
switch (_that) {
case RelationshipActive() when active != null:
return active(_that);case RelationshipDormant() when dormant != null:
return dormant(_that);case RelationshipArchived() when archived != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String id,  DateTime createdAt,  int utcOffset,  String? timezone,  Geolocation? geolocation)?  active,TResult Function( String id,  DateTime createdAt,  int utcOffset,  String? timezone,  Geolocation? geolocation)?  dormant,TResult Function( String id,  DateTime createdAt,  int utcOffset,  String? timezone,  Geolocation? geolocation)?  archived,required TResult orElse(),}) {final _that = this;
switch (_that) {
case RelationshipActive() when active != null:
return active(_that.id,_that.createdAt,_that.utcOffset,_that.timezone,_that.geolocation);case RelationshipDormant() when dormant != null:
return dormant(_that.id,_that.createdAt,_that.utcOffset,_that.timezone,_that.geolocation);case RelationshipArchived() when archived != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String id,  DateTime createdAt,  int utcOffset,  String? timezone,  Geolocation? geolocation)  active,required TResult Function( String id,  DateTime createdAt,  int utcOffset,  String? timezone,  Geolocation? geolocation)  dormant,required TResult Function( String id,  DateTime createdAt,  int utcOffset,  String? timezone,  Geolocation? geolocation)  archived,}) {final _that = this;
switch (_that) {
case RelationshipActive():
return active(_that.id,_that.createdAt,_that.utcOffset,_that.timezone,_that.geolocation);case RelationshipDormant():
return dormant(_that.id,_that.createdAt,_that.utcOffset,_that.timezone,_that.geolocation);case RelationshipArchived():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String id,  DateTime createdAt,  int utcOffset,  String? timezone,  Geolocation? geolocation)?  active,TResult? Function( String id,  DateTime createdAt,  int utcOffset,  String? timezone,  Geolocation? geolocation)?  dormant,TResult? Function( String id,  DateTime createdAt,  int utcOffset,  String? timezone,  Geolocation? geolocation)?  archived,}) {final _that = this;
switch (_that) {
case RelationshipActive() when active != null:
return active(_that.id,_that.createdAt,_that.utcOffset,_that.timezone,_that.geolocation);case RelationshipDormant() when dormant != null:
return dormant(_that.id,_that.createdAt,_that.utcOffset,_that.timezone,_that.geolocation);case RelationshipArchived() when archived != null:
return archived(_that.id,_that.createdAt,_that.utcOffset,_that.timezone,_that.geolocation);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class RelationshipActive implements RelationshipStatus {
  const RelationshipActive({required this.id, required this.createdAt, required this.utcOffset, this.timezone, this.geolocation, final  String? $type}): $type = $type ?? 'active';
  factory RelationshipActive.fromJson(Map<String, dynamic> json) => _$RelationshipActiveFromJson(json);

@override final  String id;
@override final  DateTime createdAt;
@override final  int utcOffset;
@override final  String? timezone;
@override final  Geolocation? geolocation;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of RelationshipStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RelationshipActiveCopyWith<RelationshipActive> get copyWith => _$RelationshipActiveCopyWithImpl<RelationshipActive>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RelationshipActiveToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RelationshipActive&&(identical(other.id, id) || other.id == id)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.utcOffset, utcOffset) || other.utcOffset == utcOffset)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.geolocation, geolocation) || other.geolocation == geolocation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,createdAt,utcOffset,timezone,geolocation);

@override
String toString() {
  return 'RelationshipStatus.active(id: $id, createdAt: $createdAt, utcOffset: $utcOffset, timezone: $timezone, geolocation: $geolocation)';
}


}

/// @nodoc
abstract mixin class $RelationshipActiveCopyWith<$Res> implements $RelationshipStatusCopyWith<$Res> {
  factory $RelationshipActiveCopyWith(RelationshipActive value, $Res Function(RelationshipActive) _then) = _$RelationshipActiveCopyWithImpl;
@override @useResult
$Res call({
 String id, DateTime createdAt, int utcOffset, String? timezone, Geolocation? geolocation
});


@override $GeolocationCopyWith<$Res>? get geolocation;

}
/// @nodoc
class _$RelationshipActiveCopyWithImpl<$Res>
    implements $RelationshipActiveCopyWith<$Res> {
  _$RelationshipActiveCopyWithImpl(this._self, this._then);

  final RelationshipActive _self;
  final $Res Function(RelationshipActive) _then;

/// Create a copy of RelationshipStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? createdAt = null,Object? utcOffset = null,Object? timezone = freezed,Object? geolocation = freezed,}) {
  return _then(RelationshipActive(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,utcOffset: null == utcOffset ? _self.utcOffset : utcOffset // ignore: cast_nullable_to_non_nullable
as int,timezone: freezed == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String?,geolocation: freezed == geolocation ? _self.geolocation : geolocation // ignore: cast_nullable_to_non_nullable
as Geolocation?,
  ));
}

/// Create a copy of RelationshipStatus
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

class RelationshipDormant implements RelationshipStatus {
  const RelationshipDormant({required this.id, required this.createdAt, required this.utcOffset, this.timezone, this.geolocation, final  String? $type}): $type = $type ?? 'dormant';
  factory RelationshipDormant.fromJson(Map<String, dynamic> json) => _$RelationshipDormantFromJson(json);

@override final  String id;
@override final  DateTime createdAt;
@override final  int utcOffset;
@override final  String? timezone;
@override final  Geolocation? geolocation;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of RelationshipStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RelationshipDormantCopyWith<RelationshipDormant> get copyWith => _$RelationshipDormantCopyWithImpl<RelationshipDormant>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RelationshipDormantToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RelationshipDormant&&(identical(other.id, id) || other.id == id)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.utcOffset, utcOffset) || other.utcOffset == utcOffset)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.geolocation, geolocation) || other.geolocation == geolocation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,createdAt,utcOffset,timezone,geolocation);

@override
String toString() {
  return 'RelationshipStatus.dormant(id: $id, createdAt: $createdAt, utcOffset: $utcOffset, timezone: $timezone, geolocation: $geolocation)';
}


}

/// @nodoc
abstract mixin class $RelationshipDormantCopyWith<$Res> implements $RelationshipStatusCopyWith<$Res> {
  factory $RelationshipDormantCopyWith(RelationshipDormant value, $Res Function(RelationshipDormant) _then) = _$RelationshipDormantCopyWithImpl;
@override @useResult
$Res call({
 String id, DateTime createdAt, int utcOffset, String? timezone, Geolocation? geolocation
});


@override $GeolocationCopyWith<$Res>? get geolocation;

}
/// @nodoc
class _$RelationshipDormantCopyWithImpl<$Res>
    implements $RelationshipDormantCopyWith<$Res> {
  _$RelationshipDormantCopyWithImpl(this._self, this._then);

  final RelationshipDormant _self;
  final $Res Function(RelationshipDormant) _then;

/// Create a copy of RelationshipStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? createdAt = null,Object? utcOffset = null,Object? timezone = freezed,Object? geolocation = freezed,}) {
  return _then(RelationshipDormant(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,utcOffset: null == utcOffset ? _self.utcOffset : utcOffset // ignore: cast_nullable_to_non_nullable
as int,timezone: freezed == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String?,geolocation: freezed == geolocation ? _self.geolocation : geolocation // ignore: cast_nullable_to_non_nullable
as Geolocation?,
  ));
}

/// Create a copy of RelationshipStatus
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

class RelationshipArchived implements RelationshipStatus {
  const RelationshipArchived({required this.id, required this.createdAt, required this.utcOffset, this.timezone, this.geolocation, final  String? $type}): $type = $type ?? 'archived';
  factory RelationshipArchived.fromJson(Map<String, dynamic> json) => _$RelationshipArchivedFromJson(json);

@override final  String id;
@override final  DateTime createdAt;
@override final  int utcOffset;
@override final  String? timezone;
@override final  Geolocation? geolocation;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of RelationshipStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RelationshipArchivedCopyWith<RelationshipArchived> get copyWith => _$RelationshipArchivedCopyWithImpl<RelationshipArchived>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RelationshipArchivedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RelationshipArchived&&(identical(other.id, id) || other.id == id)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.utcOffset, utcOffset) || other.utcOffset == utcOffset)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.geolocation, geolocation) || other.geolocation == geolocation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,createdAt,utcOffset,timezone,geolocation);

@override
String toString() {
  return 'RelationshipStatus.archived(id: $id, createdAt: $createdAt, utcOffset: $utcOffset, timezone: $timezone, geolocation: $geolocation)';
}


}

/// @nodoc
abstract mixin class $RelationshipArchivedCopyWith<$Res> implements $RelationshipStatusCopyWith<$Res> {
  factory $RelationshipArchivedCopyWith(RelationshipArchived value, $Res Function(RelationshipArchived) _then) = _$RelationshipArchivedCopyWithImpl;
@override @useResult
$Res call({
 String id, DateTime createdAt, int utcOffset, String? timezone, Geolocation? geolocation
});


@override $GeolocationCopyWith<$Res>? get geolocation;

}
/// @nodoc
class _$RelationshipArchivedCopyWithImpl<$Res>
    implements $RelationshipArchivedCopyWith<$Res> {
  _$RelationshipArchivedCopyWithImpl(this._self, this._then);

  final RelationshipArchived _self;
  final $Res Function(RelationshipArchived) _then;

/// Create a copy of RelationshipStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? createdAt = null,Object? utcOffset = null,Object? timezone = freezed,Object? geolocation = freezed,}) {
  return _then(RelationshipArchived(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,utcOffset: null == utcOffset ? _self.utcOffset : utcOffset // ignore: cast_nullable_to_non_nullable
as int,timezone: freezed == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String?,geolocation: freezed == geolocation ? _self.geolocation : geolocation // ignore: cast_nullable_to_non_nullable
as Geolocation?,
  ));
}

/// Create a copy of RelationshipStatus
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
mixin _$RelationshipData {

/// The person's display name.
 String get title; RelationshipStatus get status; String? get nickname;/// The single consent switch for proactive behavior: only important
/// relationships produce cadence nudges and reminders (ADR 0039).
 bool get important; List<RelationshipStatus> get statusHistory;/// Desired check-in interval in days; only meaningful when [important]
/// is set. Defaults to 30 at the evaluation site when unset.
 int? get checkInCadenceDays; DateTime? get birthday;/// Inference profile ID for the relationship agent (ADR 0040),
/// mirroring `ProjectData.profileId`.
 String? get profileId; String? get languageCode;/// ID of a linked JournalImage to use as cover art.
 String? get coverArtId;/// Excluded from AI context (ADR 0041 §5).
 List<ContactChannel> get contactChannels;/// Per-platform OS contact identifiers, used only for an explicit
/// "Update from contact" refresh on the device that owns the contact
/// (ADR 0041 §2). Excluded from AI context.
 Map<String, String> get contactRefs;
/// Create a copy of RelationshipData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RelationshipDataCopyWith<RelationshipData> get copyWith => _$RelationshipDataCopyWithImpl<RelationshipData>(this as RelationshipData, _$identity);

  /// Serializes this RelationshipData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RelationshipData&&(identical(other.title, title) || other.title == title)&&(identical(other.status, status) || other.status == status)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.important, important) || other.important == important)&&const DeepCollectionEquality().equals(other.statusHistory, statusHistory)&&(identical(other.checkInCadenceDays, checkInCadenceDays) || other.checkInCadenceDays == checkInCadenceDays)&&(identical(other.birthday, birthday) || other.birthday == birthday)&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.languageCode, languageCode) || other.languageCode == languageCode)&&(identical(other.coverArtId, coverArtId) || other.coverArtId == coverArtId)&&const DeepCollectionEquality().equals(other.contactChannels, contactChannels)&&const DeepCollectionEquality().equals(other.contactRefs, contactRefs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,status,nickname,important,const DeepCollectionEquality().hash(statusHistory),checkInCadenceDays,birthday,profileId,languageCode,coverArtId,const DeepCollectionEquality().hash(contactChannels),const DeepCollectionEquality().hash(contactRefs));

@override
String toString() {
  return 'RelationshipData(title: $title, status: $status, nickname: $nickname, important: $important, statusHistory: $statusHistory, checkInCadenceDays: $checkInCadenceDays, birthday: $birthday, profileId: $profileId, languageCode: $languageCode, coverArtId: $coverArtId, contactChannels: $contactChannels, contactRefs: $contactRefs)';
}


}

/// @nodoc
abstract mixin class $RelationshipDataCopyWith<$Res>  {
  factory $RelationshipDataCopyWith(RelationshipData value, $Res Function(RelationshipData) _then) = _$RelationshipDataCopyWithImpl;
@useResult
$Res call({
 String title, RelationshipStatus status, String? nickname, bool important, List<RelationshipStatus> statusHistory, int? checkInCadenceDays, DateTime? birthday, String? profileId, String? languageCode, String? coverArtId, List<ContactChannel> contactChannels, Map<String, String> contactRefs
});


$RelationshipStatusCopyWith<$Res> get status;

}
/// @nodoc
class _$RelationshipDataCopyWithImpl<$Res>
    implements $RelationshipDataCopyWith<$Res> {
  _$RelationshipDataCopyWithImpl(this._self, this._then);

  final RelationshipData _self;
  final $Res Function(RelationshipData) _then;

/// Create a copy of RelationshipData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? status = null,Object? nickname = freezed,Object? important = null,Object? statusHistory = null,Object? checkInCadenceDays = freezed,Object? birthday = freezed,Object? profileId = freezed,Object? languageCode = freezed,Object? coverArtId = freezed,Object? contactChannels = null,Object? contactRefs = null,}) {
  return _then(_self.copyWith(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as RelationshipStatus,nickname: freezed == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String?,important: null == important ? _self.important : important // ignore: cast_nullable_to_non_nullable
as bool,statusHistory: null == statusHistory ? _self.statusHistory : statusHistory // ignore: cast_nullable_to_non_nullable
as List<RelationshipStatus>,checkInCadenceDays: freezed == checkInCadenceDays ? _self.checkInCadenceDays : checkInCadenceDays // ignore: cast_nullable_to_non_nullable
as int?,birthday: freezed == birthday ? _self.birthday : birthday // ignore: cast_nullable_to_non_nullable
as DateTime?,profileId: freezed == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as String?,languageCode: freezed == languageCode ? _self.languageCode : languageCode // ignore: cast_nullable_to_non_nullable
as String?,coverArtId: freezed == coverArtId ? _self.coverArtId : coverArtId // ignore: cast_nullable_to_non_nullable
as String?,contactChannels: null == contactChannels ? _self.contactChannels : contactChannels // ignore: cast_nullable_to_non_nullable
as List<ContactChannel>,contactRefs: null == contactRefs ? _self.contactRefs : contactRefs // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}
/// Create a copy of RelationshipData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RelationshipStatusCopyWith<$Res> get status {
  
  return $RelationshipStatusCopyWith<$Res>(_self.status, (value) {
    return _then(_self.copyWith(status: value));
  });
}
}


/// Adds pattern-matching-related methods to [RelationshipData].
extension RelationshipDataPatterns on RelationshipData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RelationshipData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RelationshipData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RelationshipData value)  $default,){
final _that = this;
switch (_that) {
case _RelationshipData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RelationshipData value)?  $default,){
final _that = this;
switch (_that) {
case _RelationshipData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String title,  RelationshipStatus status,  String? nickname,  bool important,  List<RelationshipStatus> statusHistory,  int? checkInCadenceDays,  DateTime? birthday,  String? profileId,  String? languageCode,  String? coverArtId,  List<ContactChannel> contactChannels,  Map<String, String> contactRefs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RelationshipData() when $default != null:
return $default(_that.title,_that.status,_that.nickname,_that.important,_that.statusHistory,_that.checkInCadenceDays,_that.birthday,_that.profileId,_that.languageCode,_that.coverArtId,_that.contactChannels,_that.contactRefs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String title,  RelationshipStatus status,  String? nickname,  bool important,  List<RelationshipStatus> statusHistory,  int? checkInCadenceDays,  DateTime? birthday,  String? profileId,  String? languageCode,  String? coverArtId,  List<ContactChannel> contactChannels,  Map<String, String> contactRefs)  $default,) {final _that = this;
switch (_that) {
case _RelationshipData():
return $default(_that.title,_that.status,_that.nickname,_that.important,_that.statusHistory,_that.checkInCadenceDays,_that.birthday,_that.profileId,_that.languageCode,_that.coverArtId,_that.contactChannels,_that.contactRefs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String title,  RelationshipStatus status,  String? nickname,  bool important,  List<RelationshipStatus> statusHistory,  int? checkInCadenceDays,  DateTime? birthday,  String? profileId,  String? languageCode,  String? coverArtId,  List<ContactChannel> contactChannels,  Map<String, String> contactRefs)?  $default,) {final _that = this;
switch (_that) {
case _RelationshipData() when $default != null:
return $default(_that.title,_that.status,_that.nickname,_that.important,_that.statusHistory,_that.checkInCadenceDays,_that.birthday,_that.profileId,_that.languageCode,_that.coverArtId,_that.contactChannels,_that.contactRefs);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RelationshipData implements RelationshipData {
  const _RelationshipData({required this.title, required this.status, this.nickname, this.important = false, final  List<RelationshipStatus> statusHistory = const [], this.checkInCadenceDays, this.birthday, this.profileId, this.languageCode, this.coverArtId, final  List<ContactChannel> contactChannels = const [], final  Map<String, String> contactRefs = const <String, String>{}}): _statusHistory = statusHistory,_contactChannels = contactChannels,_contactRefs = contactRefs;
  factory _RelationshipData.fromJson(Map<String, dynamic> json) => _$RelationshipDataFromJson(json);

/// The person's display name.
@override final  String title;
@override final  RelationshipStatus status;
@override final  String? nickname;
/// The single consent switch for proactive behavior: only important
/// relationships produce cadence nudges and reminders (ADR 0039).
@override@JsonKey() final  bool important;
 final  List<RelationshipStatus> _statusHistory;
@override@JsonKey() List<RelationshipStatus> get statusHistory {
  if (_statusHistory is EqualUnmodifiableListView) return _statusHistory;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_statusHistory);
}

/// Desired check-in interval in days; only meaningful when [important]
/// is set. Defaults to 30 at the evaluation site when unset.
@override final  int? checkInCadenceDays;
@override final  DateTime? birthday;
/// Inference profile ID for the relationship agent (ADR 0040),
/// mirroring `ProjectData.profileId`.
@override final  String? profileId;
@override final  String? languageCode;
/// ID of a linked JournalImage to use as cover art.
@override final  String? coverArtId;
/// Excluded from AI context (ADR 0041 §5).
 final  List<ContactChannel> _contactChannels;
/// Excluded from AI context (ADR 0041 §5).
@override@JsonKey() List<ContactChannel> get contactChannels {
  if (_contactChannels is EqualUnmodifiableListView) return _contactChannels;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_contactChannels);
}

/// Per-platform OS contact identifiers, used only for an explicit
/// "Update from contact" refresh on the device that owns the contact
/// (ADR 0041 §2). Excluded from AI context.
 final  Map<String, String> _contactRefs;
/// Per-platform OS contact identifiers, used only for an explicit
/// "Update from contact" refresh on the device that owns the contact
/// (ADR 0041 §2). Excluded from AI context.
@override@JsonKey() Map<String, String> get contactRefs {
  if (_contactRefs is EqualUnmodifiableMapView) return _contactRefs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_contactRefs);
}


/// Create a copy of RelationshipData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RelationshipDataCopyWith<_RelationshipData> get copyWith => __$RelationshipDataCopyWithImpl<_RelationshipData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RelationshipDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RelationshipData&&(identical(other.title, title) || other.title == title)&&(identical(other.status, status) || other.status == status)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.important, important) || other.important == important)&&const DeepCollectionEquality().equals(other._statusHistory, _statusHistory)&&(identical(other.checkInCadenceDays, checkInCadenceDays) || other.checkInCadenceDays == checkInCadenceDays)&&(identical(other.birthday, birthday) || other.birthday == birthday)&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.languageCode, languageCode) || other.languageCode == languageCode)&&(identical(other.coverArtId, coverArtId) || other.coverArtId == coverArtId)&&const DeepCollectionEquality().equals(other._contactChannels, _contactChannels)&&const DeepCollectionEquality().equals(other._contactRefs, _contactRefs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,status,nickname,important,const DeepCollectionEquality().hash(_statusHistory),checkInCadenceDays,birthday,profileId,languageCode,coverArtId,const DeepCollectionEquality().hash(_contactChannels),const DeepCollectionEquality().hash(_contactRefs));

@override
String toString() {
  return 'RelationshipData(title: $title, status: $status, nickname: $nickname, important: $important, statusHistory: $statusHistory, checkInCadenceDays: $checkInCadenceDays, birthday: $birthday, profileId: $profileId, languageCode: $languageCode, coverArtId: $coverArtId, contactChannels: $contactChannels, contactRefs: $contactRefs)';
}


}

/// @nodoc
abstract mixin class _$RelationshipDataCopyWith<$Res> implements $RelationshipDataCopyWith<$Res> {
  factory _$RelationshipDataCopyWith(_RelationshipData value, $Res Function(_RelationshipData) _then) = __$RelationshipDataCopyWithImpl;
@override @useResult
$Res call({
 String title, RelationshipStatus status, String? nickname, bool important, List<RelationshipStatus> statusHistory, int? checkInCadenceDays, DateTime? birthday, String? profileId, String? languageCode, String? coverArtId, List<ContactChannel> contactChannels, Map<String, String> contactRefs
});


@override $RelationshipStatusCopyWith<$Res> get status;

}
/// @nodoc
class __$RelationshipDataCopyWithImpl<$Res>
    implements _$RelationshipDataCopyWith<$Res> {
  __$RelationshipDataCopyWithImpl(this._self, this._then);

  final _RelationshipData _self;
  final $Res Function(_RelationshipData) _then;

/// Create a copy of RelationshipData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? status = null,Object? nickname = freezed,Object? important = null,Object? statusHistory = null,Object? checkInCadenceDays = freezed,Object? birthday = freezed,Object? profileId = freezed,Object? languageCode = freezed,Object? coverArtId = freezed,Object? contactChannels = null,Object? contactRefs = null,}) {
  return _then(_RelationshipData(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as RelationshipStatus,nickname: freezed == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String?,important: null == important ? _self.important : important // ignore: cast_nullable_to_non_nullable
as bool,statusHistory: null == statusHistory ? _self._statusHistory : statusHistory // ignore: cast_nullable_to_non_nullable
as List<RelationshipStatus>,checkInCadenceDays: freezed == checkInCadenceDays ? _self.checkInCadenceDays : checkInCadenceDays // ignore: cast_nullable_to_non_nullable
as int?,birthday: freezed == birthday ? _self.birthday : birthday // ignore: cast_nullable_to_non_nullable
as DateTime?,profileId: freezed == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as String?,languageCode: freezed == languageCode ? _self.languageCode : languageCode // ignore: cast_nullable_to_non_nullable
as String?,coverArtId: freezed == coverArtId ? _self.coverArtId : coverArtId // ignore: cast_nullable_to_non_nullable
as String?,contactChannels: null == contactChannels ? _self._contactChannels : contactChannels // ignore: cast_nullable_to_non_nullable
as List<ContactChannel>,contactRefs: null == contactRefs ? _self._contactRefs : contactRefs // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}

/// Create a copy of RelationshipData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RelationshipStatusCopyWith<$Res> get status {
  
  return $RelationshipStatusCopyWith<$Res>(_self.status, (value) {
    return _then(_self.copyWith(status: value));
  });
}
}

// dart format on
