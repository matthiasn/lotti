// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'query_chat_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$QueryScope {

 QueryScopeKind get kind; String get id;
/// Create a copy of QueryScope
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QueryScopeCopyWith<QueryScope> get copyWith => _$QueryScopeCopyWithImpl<QueryScope>(this as QueryScope, _$identity);

  /// Serializes this QueryScope to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QueryScope&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,id);

@override
String toString() {
  return 'QueryScope(kind: $kind, id: $id)';
}


}

/// @nodoc
abstract mixin class $QueryScopeCopyWith<$Res>  {
  factory $QueryScopeCopyWith(QueryScope value, $Res Function(QueryScope) _then) = _$QueryScopeCopyWithImpl;
@useResult
$Res call({
 QueryScopeKind kind, String id
});




}
/// @nodoc
class _$QueryScopeCopyWithImpl<$Res>
    implements $QueryScopeCopyWith<$Res> {
  _$QueryScopeCopyWithImpl(this._self, this._then);

  final QueryScope _self;
  final $Res Function(QueryScope) _then;

/// Create a copy of QueryScope
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? id = null,}) {
  return _then(_self.copyWith(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as QueryScopeKind,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [QueryScope].
extension QueryScopePatterns on QueryScope {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _QueryScope value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _QueryScope() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _QueryScope value)  $default,){
final _that = this;
switch (_that) {
case _QueryScope():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _QueryScope value)?  $default,){
final _that = this;
switch (_that) {
case _QueryScope() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( QueryScopeKind kind,  String id)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _QueryScope() when $default != null:
return $default(_that.kind,_that.id);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( QueryScopeKind kind,  String id)  $default,) {final _that = this;
switch (_that) {
case _QueryScope():
return $default(_that.kind,_that.id);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( QueryScopeKind kind,  String id)?  $default,) {final _that = this;
switch (_that) {
case _QueryScope() when $default != null:
return $default(_that.kind,_that.id);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _QueryScope implements QueryScope {
  const _QueryScope({required this.kind, required this.id});
  factory _QueryScope.fromJson(Map<String, dynamic> json) => _$QueryScopeFromJson(json);

@override final  QueryScopeKind kind;
@override final  String id;

/// Create a copy of QueryScope
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QueryScopeCopyWith<_QueryScope> get copyWith => __$QueryScopeCopyWithImpl<_QueryScope>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QueryScopeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QueryScope&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,id);

@override
String toString() {
  return 'QueryScope(kind: $kind, id: $id)';
}


}

/// @nodoc
abstract mixin class _$QueryScopeCopyWith<$Res> implements $QueryScopeCopyWith<$Res> {
  factory _$QueryScopeCopyWith(_QueryScope value, $Res Function(_QueryScope) _then) = __$QueryScopeCopyWithImpl;
@override @useResult
$Res call({
 QueryScopeKind kind, String id
});




}
/// @nodoc
class __$QueryScopeCopyWithImpl<$Res>
    implements _$QueryScopeCopyWith<$Res> {
  __$QueryScopeCopyWithImpl(this._self, this._then);

  final _QueryScope _self;
  final $Res Function(_QueryScope) _then;

/// Create a copy of QueryScope
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? id = null,}) {
  return _then(_QueryScope(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as QueryScopeKind,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$QuerySourceRef {

 String get id; bool get private; bool get categoryPrivate; String? get categoryId;
/// Create a copy of QuerySourceRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuerySourceRefCopyWith<QuerySourceRef> get copyWith => _$QuerySourceRefCopyWithImpl<QuerySourceRef>(this as QuerySourceRef, _$identity);

  /// Serializes this QuerySourceRef to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QuerySourceRef&&(identical(other.id, id) || other.id == id)&&(identical(other.private, private) || other.private == private)&&(identical(other.categoryPrivate, categoryPrivate) || other.categoryPrivate == categoryPrivate)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,private,categoryPrivate,categoryId);

@override
String toString() {
  return 'QuerySourceRef(id: $id, private: $private, categoryPrivate: $categoryPrivate, categoryId: $categoryId)';
}


}

/// @nodoc
abstract mixin class $QuerySourceRefCopyWith<$Res>  {
  factory $QuerySourceRefCopyWith(QuerySourceRef value, $Res Function(QuerySourceRef) _then) = _$QuerySourceRefCopyWithImpl;
@useResult
$Res call({
 String id, bool private, bool categoryPrivate, String? categoryId
});




}
/// @nodoc
class _$QuerySourceRefCopyWithImpl<$Res>
    implements $QuerySourceRefCopyWith<$Res> {
  _$QuerySourceRefCopyWithImpl(this._self, this._then);

  final QuerySourceRef _self;
  final $Res Function(QuerySourceRef) _then;

/// Create a copy of QuerySourceRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? private = null,Object? categoryPrivate = null,Object? categoryId = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,private: null == private ? _self.private : private // ignore: cast_nullable_to_non_nullable
as bool,categoryPrivate: null == categoryPrivate ? _self.categoryPrivate : categoryPrivate // ignore: cast_nullable_to_non_nullable
as bool,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [QuerySourceRef].
extension QuerySourceRefPatterns on QuerySourceRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _QuerySourceRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _QuerySourceRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _QuerySourceRef value)  $default,){
final _that = this;
switch (_that) {
case _QuerySourceRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _QuerySourceRef value)?  $default,){
final _that = this;
switch (_that) {
case _QuerySourceRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  bool private,  bool categoryPrivate,  String? categoryId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _QuerySourceRef() when $default != null:
return $default(_that.id,_that.private,_that.categoryPrivate,_that.categoryId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  bool private,  bool categoryPrivate,  String? categoryId)  $default,) {final _that = this;
switch (_that) {
case _QuerySourceRef():
return $default(_that.id,_that.private,_that.categoryPrivate,_that.categoryId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  bool private,  bool categoryPrivate,  String? categoryId)?  $default,) {final _that = this;
switch (_that) {
case _QuerySourceRef() when $default != null:
return $default(_that.id,_that.private,_that.categoryPrivate,_that.categoryId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _QuerySourceRef implements QuerySourceRef {
  const _QuerySourceRef({required this.id, required this.private, required this.categoryPrivate, this.categoryId});
  factory _QuerySourceRef.fromJson(Map<String, dynamic> json) => _$QuerySourceRefFromJson(json);

@override final  String id;
@override final  bool private;
@override final  bool categoryPrivate;
@override final  String? categoryId;

/// Create a copy of QuerySourceRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QuerySourceRefCopyWith<_QuerySourceRef> get copyWith => __$QuerySourceRefCopyWithImpl<_QuerySourceRef>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QuerySourceRefToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QuerySourceRef&&(identical(other.id, id) || other.id == id)&&(identical(other.private, private) || other.private == private)&&(identical(other.categoryPrivate, categoryPrivate) || other.categoryPrivate == categoryPrivate)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,private,categoryPrivate,categoryId);

@override
String toString() {
  return 'QuerySourceRef(id: $id, private: $private, categoryPrivate: $categoryPrivate, categoryId: $categoryId)';
}


}

/// @nodoc
abstract mixin class _$QuerySourceRefCopyWith<$Res> implements $QuerySourceRefCopyWith<$Res> {
  factory _$QuerySourceRefCopyWith(_QuerySourceRef value, $Res Function(_QuerySourceRef) _then) = __$QuerySourceRefCopyWithImpl;
@override @useResult
$Res call({
 String id, bool private, bool categoryPrivate, String? categoryId
});




}
/// @nodoc
class __$QuerySourceRefCopyWithImpl<$Res>
    implements _$QuerySourceRefCopyWith<$Res> {
  __$QuerySourceRefCopyWithImpl(this._self, this._then);

  final _QuerySourceRef _self;
  final $Res Function(_QuerySourceRef) _then;

/// Create a copy of QuerySourceRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? private = null,Object? categoryPrivate = null,Object? categoryId = freezed,}) {
  return _then(_QuerySourceRef(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,private: null == private ? _self.private : private // ignore: cast_nullable_to_non_nullable
as bool,categoryPrivate: null == categoryPrivate ? _self.categoryPrivate : categoryPrivate // ignore: cast_nullable_to_non_nullable
as bool,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$QueryEvidence {

 QuerySourceRef get source; QuerySourceKind get kind; String get label; DateTime get sourceDate; String get textVersion; String get fingerprint; String get sourceText; int get start; int get end; String get summary; List<String> get affiliations; bool get outsideHome; String get relevance;
/// Create a copy of QueryEvidence
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QueryEvidenceCopyWith<QueryEvidence> get copyWith => _$QueryEvidenceCopyWithImpl<QueryEvidence>(this as QueryEvidence, _$identity);

  /// Serializes this QueryEvidence to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QueryEvidence&&(identical(other.source, source) || other.source == source)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.label, label) || other.label == label)&&(identical(other.sourceDate, sourceDate) || other.sourceDate == sourceDate)&&(identical(other.textVersion, textVersion) || other.textVersion == textVersion)&&(identical(other.fingerprint, fingerprint) || other.fingerprint == fingerprint)&&(identical(other.sourceText, sourceText) || other.sourceText == sourceText)&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end)&&(identical(other.summary, summary) || other.summary == summary)&&const DeepCollectionEquality().equals(other.affiliations, affiliations)&&(identical(other.outsideHome, outsideHome) || other.outsideHome == outsideHome)&&(identical(other.relevance, relevance) || other.relevance == relevance));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,source,kind,label,sourceDate,textVersion,fingerprint,sourceText,start,end,summary,const DeepCollectionEquality().hash(affiliations),outsideHome,relevance);

@override
String toString() {
  return 'QueryEvidence(source: $source, kind: $kind, label: $label, sourceDate: $sourceDate, textVersion: $textVersion, fingerprint: $fingerprint, sourceText: $sourceText, start: $start, end: $end, summary: $summary, affiliations: $affiliations, outsideHome: $outsideHome, relevance: $relevance)';
}


}

/// @nodoc
abstract mixin class $QueryEvidenceCopyWith<$Res>  {
  factory $QueryEvidenceCopyWith(QueryEvidence value, $Res Function(QueryEvidence) _then) = _$QueryEvidenceCopyWithImpl;
@useResult
$Res call({
 QuerySourceRef source, QuerySourceKind kind, String label, DateTime sourceDate, String textVersion, String fingerprint, String sourceText, int start, int end, String summary, List<String> affiliations, bool outsideHome, String relevance
});


$QuerySourceRefCopyWith<$Res> get source;

}
/// @nodoc
class _$QueryEvidenceCopyWithImpl<$Res>
    implements $QueryEvidenceCopyWith<$Res> {
  _$QueryEvidenceCopyWithImpl(this._self, this._then);

  final QueryEvidence _self;
  final $Res Function(QueryEvidence) _then;

/// Create a copy of QueryEvidence
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? source = null,Object? kind = null,Object? label = null,Object? sourceDate = null,Object? textVersion = null,Object? fingerprint = null,Object? sourceText = null,Object? start = null,Object? end = null,Object? summary = null,Object? affiliations = null,Object? outsideHome = null,Object? relevance = null,}) {
  return _then(_self.copyWith(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as QuerySourceRef,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as QuerySourceKind,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,sourceDate: null == sourceDate ? _self.sourceDate : sourceDate // ignore: cast_nullable_to_non_nullable
as DateTime,textVersion: null == textVersion ? _self.textVersion : textVersion // ignore: cast_nullable_to_non_nullable
as String,fingerprint: null == fingerprint ? _self.fingerprint : fingerprint // ignore: cast_nullable_to_non_nullable
as String,sourceText: null == sourceText ? _self.sourceText : sourceText // ignore: cast_nullable_to_non_nullable
as String,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as int,end: null == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as int,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,affiliations: null == affiliations ? _self.affiliations : affiliations // ignore: cast_nullable_to_non_nullable
as List<String>,outsideHome: null == outsideHome ? _self.outsideHome : outsideHome // ignore: cast_nullable_to_non_nullable
as bool,relevance: null == relevance ? _self.relevance : relevance // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of QueryEvidence
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$QuerySourceRefCopyWith<$Res> get source {
  
  return $QuerySourceRefCopyWith<$Res>(_self.source, (value) {
    return _then(_self.copyWith(source: value));
  });
}
}


/// Adds pattern-matching-related methods to [QueryEvidence].
extension QueryEvidencePatterns on QueryEvidence {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _QueryEvidence value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _QueryEvidence() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _QueryEvidence value)  $default,){
final _that = this;
switch (_that) {
case _QueryEvidence():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _QueryEvidence value)?  $default,){
final _that = this;
switch (_that) {
case _QueryEvidence() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( QuerySourceRef source,  QuerySourceKind kind,  String label,  DateTime sourceDate,  String textVersion,  String fingerprint,  String sourceText,  int start,  int end,  String summary,  List<String> affiliations,  bool outsideHome,  String relevance)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _QueryEvidence() when $default != null:
return $default(_that.source,_that.kind,_that.label,_that.sourceDate,_that.textVersion,_that.fingerprint,_that.sourceText,_that.start,_that.end,_that.summary,_that.affiliations,_that.outsideHome,_that.relevance);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( QuerySourceRef source,  QuerySourceKind kind,  String label,  DateTime sourceDate,  String textVersion,  String fingerprint,  String sourceText,  int start,  int end,  String summary,  List<String> affiliations,  bool outsideHome,  String relevance)  $default,) {final _that = this;
switch (_that) {
case _QueryEvidence():
return $default(_that.source,_that.kind,_that.label,_that.sourceDate,_that.textVersion,_that.fingerprint,_that.sourceText,_that.start,_that.end,_that.summary,_that.affiliations,_that.outsideHome,_that.relevance);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( QuerySourceRef source,  QuerySourceKind kind,  String label,  DateTime sourceDate,  String textVersion,  String fingerprint,  String sourceText,  int start,  int end,  String summary,  List<String> affiliations,  bool outsideHome,  String relevance)?  $default,) {final _that = this;
switch (_that) {
case _QueryEvidence() when $default != null:
return $default(_that.source,_that.kind,_that.label,_that.sourceDate,_that.textVersion,_that.fingerprint,_that.sourceText,_that.start,_that.end,_that.summary,_that.affiliations,_that.outsideHome,_that.relevance);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _QueryEvidence extends QueryEvidence {
  const _QueryEvidence({required this.source, required this.kind, required this.label, required this.sourceDate, required this.textVersion, required this.fingerprint, required this.sourceText, required this.start, required this.end, required this.summary, final  List<String> affiliations = const [], this.outsideHome = false, this.relevance = ''}): _affiliations = affiliations,super._();
  factory _QueryEvidence.fromJson(Map<String, dynamic> json) => _$QueryEvidenceFromJson(json);

@override final  QuerySourceRef source;
@override final  QuerySourceKind kind;
@override final  String label;
@override final  DateTime sourceDate;
@override final  String textVersion;
@override final  String fingerprint;
@override final  String sourceText;
@override final  int start;
@override final  int end;
@override final  String summary;
 final  List<String> _affiliations;
@override@JsonKey() List<String> get affiliations {
  if (_affiliations is EqualUnmodifiableListView) return _affiliations;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_affiliations);
}

@override@JsonKey() final  bool outsideHome;
@override@JsonKey() final  String relevance;

/// Create a copy of QueryEvidence
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QueryEvidenceCopyWith<_QueryEvidence> get copyWith => __$QueryEvidenceCopyWithImpl<_QueryEvidence>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QueryEvidenceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QueryEvidence&&(identical(other.source, source) || other.source == source)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.label, label) || other.label == label)&&(identical(other.sourceDate, sourceDate) || other.sourceDate == sourceDate)&&(identical(other.textVersion, textVersion) || other.textVersion == textVersion)&&(identical(other.fingerprint, fingerprint) || other.fingerprint == fingerprint)&&(identical(other.sourceText, sourceText) || other.sourceText == sourceText)&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end)&&(identical(other.summary, summary) || other.summary == summary)&&const DeepCollectionEquality().equals(other._affiliations, _affiliations)&&(identical(other.outsideHome, outsideHome) || other.outsideHome == outsideHome)&&(identical(other.relevance, relevance) || other.relevance == relevance));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,source,kind,label,sourceDate,textVersion,fingerprint,sourceText,start,end,summary,const DeepCollectionEquality().hash(_affiliations),outsideHome,relevance);

@override
String toString() {
  return 'QueryEvidence(source: $source, kind: $kind, label: $label, sourceDate: $sourceDate, textVersion: $textVersion, fingerprint: $fingerprint, sourceText: $sourceText, start: $start, end: $end, summary: $summary, affiliations: $affiliations, outsideHome: $outsideHome, relevance: $relevance)';
}


}

/// @nodoc
abstract mixin class _$QueryEvidenceCopyWith<$Res> implements $QueryEvidenceCopyWith<$Res> {
  factory _$QueryEvidenceCopyWith(_QueryEvidence value, $Res Function(_QueryEvidence) _then) = __$QueryEvidenceCopyWithImpl;
@override @useResult
$Res call({
 QuerySourceRef source, QuerySourceKind kind, String label, DateTime sourceDate, String textVersion, String fingerprint, String sourceText, int start, int end, String summary, List<String> affiliations, bool outsideHome, String relevance
});


@override $QuerySourceRefCopyWith<$Res> get source;

}
/// @nodoc
class __$QueryEvidenceCopyWithImpl<$Res>
    implements _$QueryEvidenceCopyWith<$Res> {
  __$QueryEvidenceCopyWithImpl(this._self, this._then);

  final _QueryEvidence _self;
  final $Res Function(_QueryEvidence) _then;

/// Create a copy of QueryEvidence
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? source = null,Object? kind = null,Object? label = null,Object? sourceDate = null,Object? textVersion = null,Object? fingerprint = null,Object? sourceText = null,Object? start = null,Object? end = null,Object? summary = null,Object? affiliations = null,Object? outsideHome = null,Object? relevance = null,}) {
  return _then(_QueryEvidence(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as QuerySourceRef,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as QuerySourceKind,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,sourceDate: null == sourceDate ? _self.sourceDate : sourceDate // ignore: cast_nullable_to_non_nullable
as DateTime,textVersion: null == textVersion ? _self.textVersion : textVersion // ignore: cast_nullable_to_non_nullable
as String,fingerprint: null == fingerprint ? _self.fingerprint : fingerprint // ignore: cast_nullable_to_non_nullable
as String,sourceText: null == sourceText ? _self.sourceText : sourceText // ignore: cast_nullable_to_non_nullable
as String,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as int,end: null == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as int,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,affiliations: null == affiliations ? _self._affiliations : affiliations // ignore: cast_nullable_to_non_nullable
as List<String>,outsideHome: null == outsideHome ? _self.outsideHome : outsideHome // ignore: cast_nullable_to_non_nullable
as bool,relevance: null == relevance ? _self.relevance : relevance // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of QueryEvidence
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$QuerySourceRefCopyWith<$Res> get source {
  
  return $QuerySourceRefCopyWith<$Res>(_self.source, (value) {
    return _then(_self.copyWith(source: value));
  });
}
}


/// @nodoc
mixin _$QueryCoverage {

 int get checked; int get missingTranscripts; bool get incomplete; bool get expanded;
/// Create a copy of QueryCoverage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QueryCoverageCopyWith<QueryCoverage> get copyWith => _$QueryCoverageCopyWithImpl<QueryCoverage>(this as QueryCoverage, _$identity);

  /// Serializes this QueryCoverage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QueryCoverage&&(identical(other.checked, checked) || other.checked == checked)&&(identical(other.missingTranscripts, missingTranscripts) || other.missingTranscripts == missingTranscripts)&&(identical(other.incomplete, incomplete) || other.incomplete == incomplete)&&(identical(other.expanded, expanded) || other.expanded == expanded));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,checked,missingTranscripts,incomplete,expanded);

@override
String toString() {
  return 'QueryCoverage(checked: $checked, missingTranscripts: $missingTranscripts, incomplete: $incomplete, expanded: $expanded)';
}


}

/// @nodoc
abstract mixin class $QueryCoverageCopyWith<$Res>  {
  factory $QueryCoverageCopyWith(QueryCoverage value, $Res Function(QueryCoverage) _then) = _$QueryCoverageCopyWithImpl;
@useResult
$Res call({
 int checked, int missingTranscripts, bool incomplete, bool expanded
});




}
/// @nodoc
class _$QueryCoverageCopyWithImpl<$Res>
    implements $QueryCoverageCopyWith<$Res> {
  _$QueryCoverageCopyWithImpl(this._self, this._then);

  final QueryCoverage _self;
  final $Res Function(QueryCoverage) _then;

/// Create a copy of QueryCoverage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? checked = null,Object? missingTranscripts = null,Object? incomplete = null,Object? expanded = null,}) {
  return _then(_self.copyWith(
checked: null == checked ? _self.checked : checked // ignore: cast_nullable_to_non_nullable
as int,missingTranscripts: null == missingTranscripts ? _self.missingTranscripts : missingTranscripts // ignore: cast_nullable_to_non_nullable
as int,incomplete: null == incomplete ? _self.incomplete : incomplete // ignore: cast_nullable_to_non_nullable
as bool,expanded: null == expanded ? _self.expanded : expanded // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [QueryCoverage].
extension QueryCoveragePatterns on QueryCoverage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _QueryCoverage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _QueryCoverage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _QueryCoverage value)  $default,){
final _that = this;
switch (_that) {
case _QueryCoverage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _QueryCoverage value)?  $default,){
final _that = this;
switch (_that) {
case _QueryCoverage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int checked,  int missingTranscripts,  bool incomplete,  bool expanded)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _QueryCoverage() when $default != null:
return $default(_that.checked,_that.missingTranscripts,_that.incomplete,_that.expanded);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int checked,  int missingTranscripts,  bool incomplete,  bool expanded)  $default,) {final _that = this;
switch (_that) {
case _QueryCoverage():
return $default(_that.checked,_that.missingTranscripts,_that.incomplete,_that.expanded);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int checked,  int missingTranscripts,  bool incomplete,  bool expanded)?  $default,) {final _that = this;
switch (_that) {
case _QueryCoverage() when $default != null:
return $default(_that.checked,_that.missingTranscripts,_that.incomplete,_that.expanded);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _QueryCoverage implements QueryCoverage {
  const _QueryCoverage({this.checked = 0, this.missingTranscripts = 0, this.incomplete = false, this.expanded = false});
  factory _QueryCoverage.fromJson(Map<String, dynamic> json) => _$QueryCoverageFromJson(json);

@override@JsonKey() final  int checked;
@override@JsonKey() final  int missingTranscripts;
@override@JsonKey() final  bool incomplete;
@override@JsonKey() final  bool expanded;

/// Create a copy of QueryCoverage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QueryCoverageCopyWith<_QueryCoverage> get copyWith => __$QueryCoverageCopyWithImpl<_QueryCoverage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QueryCoverageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QueryCoverage&&(identical(other.checked, checked) || other.checked == checked)&&(identical(other.missingTranscripts, missingTranscripts) || other.missingTranscripts == missingTranscripts)&&(identical(other.incomplete, incomplete) || other.incomplete == incomplete)&&(identical(other.expanded, expanded) || other.expanded == expanded));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,checked,missingTranscripts,incomplete,expanded);

@override
String toString() {
  return 'QueryCoverage(checked: $checked, missingTranscripts: $missingTranscripts, incomplete: $incomplete, expanded: $expanded)';
}


}

/// @nodoc
abstract mixin class _$QueryCoverageCopyWith<$Res> implements $QueryCoverageCopyWith<$Res> {
  factory _$QueryCoverageCopyWith(_QueryCoverage value, $Res Function(_QueryCoverage) _then) = __$QueryCoverageCopyWithImpl;
@override @useResult
$Res call({
 int checked, int missingTranscripts, bool incomplete, bool expanded
});




}
/// @nodoc
class __$QueryCoverageCopyWithImpl<$Res>
    implements _$QueryCoverageCopyWith<$Res> {
  __$QueryCoverageCopyWithImpl(this._self, this._then);

  final _QueryCoverage _self;
  final $Res Function(_QueryCoverage) _then;

/// Create a copy of QueryCoverage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? checked = null,Object? missingTranscripts = null,Object? incomplete = null,Object? expanded = null,}) {
  return _then(_QueryCoverage(
checked: null == checked ? _self.checked : checked // ignore: cast_nullable_to_non_nullable
as int,missingTranscripts: null == missingTranscripts ? _self.missingTranscripts : missingTranscripts // ignore: cast_nullable_to_non_nullable
as int,incomplete: null == incomplete ? _self.incomplete : incomplete // ignore: cast_nullable_to_non_nullable
as bool,expanded: null == expanded ? _self.expanded : expanded // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

QueryChatEventData _$QueryChatEventDataFromJson(
  Map<String, dynamic> json
) {
        switch (json['runtimeType']) {
                  case 'created':
          return QueryChatCreated.fromJson(
            json
          );
                case 'renamed':
          return QueryChatRenamed.fromJson(
            json
          );
                case 'archived':
          return QueryChatArchived.fromJson(
            json
          );
                case 'deleted':
          return QueryChatDeleted.fromJson(
            json
          );
                case 'read':
          return QueryChatRead.fromJson(
            json
          );
                case 'question':
          return QueryChatQuestion.fromJson(
            json
          );
                case 'answer':
          return QueryChatAnswer.fromJson(
            json
          );
                case 'failed':
          return QueryChatFailed.fromJson(
            json
          );
                case 'cancelled':
          return QueryChatCancelled.fromJson(
            json
          );
                case 'memory':
          return QueryChatMemory.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'runtimeType',
  'QueryChatEventData',
  'Invalid union type "${json['runtimeType']}"!'
);
        }
      
}

/// @nodoc
mixin _$QueryChatEventData {



  /// Serializes this QueryChatEventData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QueryChatEventData);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'QueryChatEventData()';
}


}

/// @nodoc
class $QueryChatEventDataCopyWith<$Res>  {
$QueryChatEventDataCopyWith(QueryChatEventData _, $Res Function(QueryChatEventData) __);
}


/// Adds pattern-matching-related methods to [QueryChatEventData].
extension QueryChatEventDataPatterns on QueryChatEventData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( QueryChatCreated value)?  created,TResult Function( QueryChatRenamed value)?  renamed,TResult Function( QueryChatArchived value)?  archived,TResult Function( QueryChatDeleted value)?  deleted,TResult Function( QueryChatRead value)?  read,TResult Function( QueryChatQuestion value)?  question,TResult Function( QueryChatAnswer value)?  answer,TResult Function( QueryChatFailed value)?  failed,TResult Function( QueryChatCancelled value)?  cancelled,TResult Function( QueryChatMemory value)?  memory,required TResult orElse(),}){
final _that = this;
switch (_that) {
case QueryChatCreated() when created != null:
return created(_that);case QueryChatRenamed() when renamed != null:
return renamed(_that);case QueryChatArchived() when archived != null:
return archived(_that);case QueryChatDeleted() when deleted != null:
return deleted(_that);case QueryChatRead() when read != null:
return read(_that);case QueryChatQuestion() when question != null:
return question(_that);case QueryChatAnswer() when answer != null:
return answer(_that);case QueryChatFailed() when failed != null:
return failed(_that);case QueryChatCancelled() when cancelled != null:
return cancelled(_that);case QueryChatMemory() when memory != null:
return memory(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( QueryChatCreated value)  created,required TResult Function( QueryChatRenamed value)  renamed,required TResult Function( QueryChatArchived value)  archived,required TResult Function( QueryChatDeleted value)  deleted,required TResult Function( QueryChatRead value)  read,required TResult Function( QueryChatQuestion value)  question,required TResult Function( QueryChatAnswer value)  answer,required TResult Function( QueryChatFailed value)  failed,required TResult Function( QueryChatCancelled value)  cancelled,required TResult Function( QueryChatMemory value)  memory,}){
final _that = this;
switch (_that) {
case QueryChatCreated():
return created(_that);case QueryChatRenamed():
return renamed(_that);case QueryChatArchived():
return archived(_that);case QueryChatDeleted():
return deleted(_that);case QueryChatRead():
return read(_that);case QueryChatQuestion():
return question(_that);case QueryChatAnswer():
return answer(_that);case QueryChatFailed():
return failed(_that);case QueryChatCancelled():
return cancelled(_that);case QueryChatMemory():
return memory(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( QueryChatCreated value)?  created,TResult? Function( QueryChatRenamed value)?  renamed,TResult? Function( QueryChatArchived value)?  archived,TResult? Function( QueryChatDeleted value)?  deleted,TResult? Function( QueryChatRead value)?  read,TResult? Function( QueryChatQuestion value)?  question,TResult? Function( QueryChatAnswer value)?  answer,TResult? Function( QueryChatFailed value)?  failed,TResult? Function( QueryChatCancelled value)?  cancelled,TResult? Function( QueryChatMemory value)?  memory,}){
final _that = this;
switch (_that) {
case QueryChatCreated() when created != null:
return created(_that);case QueryChatRenamed() when renamed != null:
return renamed(_that);case QueryChatArchived() when archived != null:
return archived(_that);case QueryChatDeleted() when deleted != null:
return deleted(_that);case QueryChatRead() when read != null:
return read(_that);case QueryChatQuestion() when question != null:
return question(_that);case QueryChatAnswer() when answer != null:
return answer(_that);case QueryChatFailed() when failed != null:
return failed(_that);case QueryChatCancelled() when cancelled != null:
return cancelled(_that);case QueryChatMemory() when memory != null:
return memory(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( QueryScope scope,  String title,  bool private)?  created,TResult Function( String title,  bool private)?  renamed,TResult Function( bool archived)?  archived,TResult Function( bool forget)?  deleted,TResult Function( String throughEventId)?  read,TResult Function( String text,  bool private,  List<QuerySourceRef> dependencies)?  question,TResult Function( String questionId,  String text,  QueryCoverage coverage,  bool private,  List<QueryEvidence> evidence,  List<QuerySourceRef> dependencies,  List<String> recalledMemoryIds)?  answer,TResult Function( String questionId)?  failed,TResult Function( String questionId)?  cancelled,TResult Function( String questionId,  String text,  bool private,  List<QuerySourceRef> dependencies,  List<String> recalledMemoryIds)?  memory,required TResult orElse(),}) {final _that = this;
switch (_that) {
case QueryChatCreated() when created != null:
return created(_that.scope,_that.title,_that.private);case QueryChatRenamed() when renamed != null:
return renamed(_that.title,_that.private);case QueryChatArchived() when archived != null:
return archived(_that.archived);case QueryChatDeleted() when deleted != null:
return deleted(_that.forget);case QueryChatRead() when read != null:
return read(_that.throughEventId);case QueryChatQuestion() when question != null:
return question(_that.text,_that.private,_that.dependencies);case QueryChatAnswer() when answer != null:
return answer(_that.questionId,_that.text,_that.coverage,_that.private,_that.evidence,_that.dependencies,_that.recalledMemoryIds);case QueryChatFailed() when failed != null:
return failed(_that.questionId);case QueryChatCancelled() when cancelled != null:
return cancelled(_that.questionId);case QueryChatMemory() when memory != null:
return memory(_that.questionId,_that.text,_that.private,_that.dependencies,_that.recalledMemoryIds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( QueryScope scope,  String title,  bool private)  created,required TResult Function( String title,  bool private)  renamed,required TResult Function( bool archived)  archived,required TResult Function( bool forget)  deleted,required TResult Function( String throughEventId)  read,required TResult Function( String text,  bool private,  List<QuerySourceRef> dependencies)  question,required TResult Function( String questionId,  String text,  QueryCoverage coverage,  bool private,  List<QueryEvidence> evidence,  List<QuerySourceRef> dependencies,  List<String> recalledMemoryIds)  answer,required TResult Function( String questionId)  failed,required TResult Function( String questionId)  cancelled,required TResult Function( String questionId,  String text,  bool private,  List<QuerySourceRef> dependencies,  List<String> recalledMemoryIds)  memory,}) {final _that = this;
switch (_that) {
case QueryChatCreated():
return created(_that.scope,_that.title,_that.private);case QueryChatRenamed():
return renamed(_that.title,_that.private);case QueryChatArchived():
return archived(_that.archived);case QueryChatDeleted():
return deleted(_that.forget);case QueryChatRead():
return read(_that.throughEventId);case QueryChatQuestion():
return question(_that.text,_that.private,_that.dependencies);case QueryChatAnswer():
return answer(_that.questionId,_that.text,_that.coverage,_that.private,_that.evidence,_that.dependencies,_that.recalledMemoryIds);case QueryChatFailed():
return failed(_that.questionId);case QueryChatCancelled():
return cancelled(_that.questionId);case QueryChatMemory():
return memory(_that.questionId,_that.text,_that.private,_that.dependencies,_that.recalledMemoryIds);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( QueryScope scope,  String title,  bool private)?  created,TResult? Function( String title,  bool private)?  renamed,TResult? Function( bool archived)?  archived,TResult? Function( bool forget)?  deleted,TResult? Function( String throughEventId)?  read,TResult? Function( String text,  bool private,  List<QuerySourceRef> dependencies)?  question,TResult? Function( String questionId,  String text,  QueryCoverage coverage,  bool private,  List<QueryEvidence> evidence,  List<QuerySourceRef> dependencies,  List<String> recalledMemoryIds)?  answer,TResult? Function( String questionId)?  failed,TResult? Function( String questionId)?  cancelled,TResult? Function( String questionId,  String text,  bool private,  List<QuerySourceRef> dependencies,  List<String> recalledMemoryIds)?  memory,}) {final _that = this;
switch (_that) {
case QueryChatCreated() when created != null:
return created(_that.scope,_that.title,_that.private);case QueryChatRenamed() when renamed != null:
return renamed(_that.title,_that.private);case QueryChatArchived() when archived != null:
return archived(_that.archived);case QueryChatDeleted() when deleted != null:
return deleted(_that.forget);case QueryChatRead() when read != null:
return read(_that.throughEventId);case QueryChatQuestion() when question != null:
return question(_that.text,_that.private,_that.dependencies);case QueryChatAnswer() when answer != null:
return answer(_that.questionId,_that.text,_that.coverage,_that.private,_that.evidence,_that.dependencies,_that.recalledMemoryIds);case QueryChatFailed() when failed != null:
return failed(_that.questionId);case QueryChatCancelled() when cancelled != null:
return cancelled(_that.questionId);case QueryChatMemory() when memory != null:
return memory(_that.questionId,_that.text,_that.private,_that.dependencies,_that.recalledMemoryIds);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class QueryChatCreated implements QueryChatEventData {
  const QueryChatCreated({required this.scope, required this.title, this.private = false, final  String? $type}): $type = $type ?? 'created';
  factory QueryChatCreated.fromJson(Map<String, dynamic> json) => _$QueryChatCreatedFromJson(json);

 final  QueryScope scope;
 final  String title;
@JsonKey() final  bool private;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of QueryChatEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QueryChatCreatedCopyWith<QueryChatCreated> get copyWith => _$QueryChatCreatedCopyWithImpl<QueryChatCreated>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QueryChatCreatedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QueryChatCreated&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.title, title) || other.title == title)&&(identical(other.private, private) || other.private == private));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,scope,title,private);

@override
String toString() {
  return 'QueryChatEventData.created(scope: $scope, title: $title, private: $private)';
}


}

/// @nodoc
abstract mixin class $QueryChatCreatedCopyWith<$Res> implements $QueryChatEventDataCopyWith<$Res> {
  factory $QueryChatCreatedCopyWith(QueryChatCreated value, $Res Function(QueryChatCreated) _then) = _$QueryChatCreatedCopyWithImpl;
@useResult
$Res call({
 QueryScope scope, String title, bool private
});


$QueryScopeCopyWith<$Res> get scope;

}
/// @nodoc
class _$QueryChatCreatedCopyWithImpl<$Res>
    implements $QueryChatCreatedCopyWith<$Res> {
  _$QueryChatCreatedCopyWithImpl(this._self, this._then);

  final QueryChatCreated _self;
  final $Res Function(QueryChatCreated) _then;

/// Create a copy of QueryChatEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? scope = null,Object? title = null,Object? private = null,}) {
  return _then(QueryChatCreated(
scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as QueryScope,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,private: null == private ? _self.private : private // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of QueryChatEventData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$QueryScopeCopyWith<$Res> get scope {
  
  return $QueryScopeCopyWith<$Res>(_self.scope, (value) {
    return _then(_self.copyWith(scope: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class QueryChatRenamed implements QueryChatEventData {
  const QueryChatRenamed({required this.title, this.private = false, final  String? $type}): $type = $type ?? 'renamed';
  factory QueryChatRenamed.fromJson(Map<String, dynamic> json) => _$QueryChatRenamedFromJson(json);

 final  String title;
@JsonKey() final  bool private;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of QueryChatEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QueryChatRenamedCopyWith<QueryChatRenamed> get copyWith => _$QueryChatRenamedCopyWithImpl<QueryChatRenamed>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QueryChatRenamedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QueryChatRenamed&&(identical(other.title, title) || other.title == title)&&(identical(other.private, private) || other.private == private));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,private);

@override
String toString() {
  return 'QueryChatEventData.renamed(title: $title, private: $private)';
}


}

/// @nodoc
abstract mixin class $QueryChatRenamedCopyWith<$Res> implements $QueryChatEventDataCopyWith<$Res> {
  factory $QueryChatRenamedCopyWith(QueryChatRenamed value, $Res Function(QueryChatRenamed) _then) = _$QueryChatRenamedCopyWithImpl;
@useResult
$Res call({
 String title, bool private
});




}
/// @nodoc
class _$QueryChatRenamedCopyWithImpl<$Res>
    implements $QueryChatRenamedCopyWith<$Res> {
  _$QueryChatRenamedCopyWithImpl(this._self, this._then);

  final QueryChatRenamed _self;
  final $Res Function(QueryChatRenamed) _then;

/// Create a copy of QueryChatEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? title = null,Object? private = null,}) {
  return _then(QueryChatRenamed(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,private: null == private ? _self.private : private // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
@JsonSerializable()

class QueryChatArchived implements QueryChatEventData {
  const QueryChatArchived({required this.archived, final  String? $type}): $type = $type ?? 'archived';
  factory QueryChatArchived.fromJson(Map<String, dynamic> json) => _$QueryChatArchivedFromJson(json);

 final  bool archived;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of QueryChatEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QueryChatArchivedCopyWith<QueryChatArchived> get copyWith => _$QueryChatArchivedCopyWithImpl<QueryChatArchived>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QueryChatArchivedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QueryChatArchived&&(identical(other.archived, archived) || other.archived == archived));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,archived);

@override
String toString() {
  return 'QueryChatEventData.archived(archived: $archived)';
}


}

/// @nodoc
abstract mixin class $QueryChatArchivedCopyWith<$Res> implements $QueryChatEventDataCopyWith<$Res> {
  factory $QueryChatArchivedCopyWith(QueryChatArchived value, $Res Function(QueryChatArchived) _then) = _$QueryChatArchivedCopyWithImpl;
@useResult
$Res call({
 bool archived
});




}
/// @nodoc
class _$QueryChatArchivedCopyWithImpl<$Res>
    implements $QueryChatArchivedCopyWith<$Res> {
  _$QueryChatArchivedCopyWithImpl(this._self, this._then);

  final QueryChatArchived _self;
  final $Res Function(QueryChatArchived) _then;

/// Create a copy of QueryChatEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? archived = null,}) {
  return _then(QueryChatArchived(
archived: null == archived ? _self.archived : archived // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
@JsonSerializable()

class QueryChatDeleted implements QueryChatEventData {
  const QueryChatDeleted({required this.forget, final  String? $type}): $type = $type ?? 'deleted';
  factory QueryChatDeleted.fromJson(Map<String, dynamic> json) => _$QueryChatDeletedFromJson(json);

 final  bool forget;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of QueryChatEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QueryChatDeletedCopyWith<QueryChatDeleted> get copyWith => _$QueryChatDeletedCopyWithImpl<QueryChatDeleted>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QueryChatDeletedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QueryChatDeleted&&(identical(other.forget, forget) || other.forget == forget));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,forget);

@override
String toString() {
  return 'QueryChatEventData.deleted(forget: $forget)';
}


}

/// @nodoc
abstract mixin class $QueryChatDeletedCopyWith<$Res> implements $QueryChatEventDataCopyWith<$Res> {
  factory $QueryChatDeletedCopyWith(QueryChatDeleted value, $Res Function(QueryChatDeleted) _then) = _$QueryChatDeletedCopyWithImpl;
@useResult
$Res call({
 bool forget
});




}
/// @nodoc
class _$QueryChatDeletedCopyWithImpl<$Res>
    implements $QueryChatDeletedCopyWith<$Res> {
  _$QueryChatDeletedCopyWithImpl(this._self, this._then);

  final QueryChatDeleted _self;
  final $Res Function(QueryChatDeleted) _then;

/// Create a copy of QueryChatEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? forget = null,}) {
  return _then(QueryChatDeleted(
forget: null == forget ? _self.forget : forget // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
@JsonSerializable()

class QueryChatRead implements QueryChatEventData {
  const QueryChatRead({required this.throughEventId, final  String? $type}): $type = $type ?? 'read';
  factory QueryChatRead.fromJson(Map<String, dynamic> json) => _$QueryChatReadFromJson(json);

 final  String throughEventId;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of QueryChatEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QueryChatReadCopyWith<QueryChatRead> get copyWith => _$QueryChatReadCopyWithImpl<QueryChatRead>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QueryChatReadToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QueryChatRead&&(identical(other.throughEventId, throughEventId) || other.throughEventId == throughEventId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,throughEventId);

@override
String toString() {
  return 'QueryChatEventData.read(throughEventId: $throughEventId)';
}


}

/// @nodoc
abstract mixin class $QueryChatReadCopyWith<$Res> implements $QueryChatEventDataCopyWith<$Res> {
  factory $QueryChatReadCopyWith(QueryChatRead value, $Res Function(QueryChatRead) _then) = _$QueryChatReadCopyWithImpl;
@useResult
$Res call({
 String throughEventId
});




}
/// @nodoc
class _$QueryChatReadCopyWithImpl<$Res>
    implements $QueryChatReadCopyWith<$Res> {
  _$QueryChatReadCopyWithImpl(this._self, this._then);

  final QueryChatRead _self;
  final $Res Function(QueryChatRead) _then;

/// Create a copy of QueryChatEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? throughEventId = null,}) {
  return _then(QueryChatRead(
throughEventId: null == throughEventId ? _self.throughEventId : throughEventId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class QueryChatQuestion implements QueryChatEventData {
  const QueryChatQuestion({required this.text, this.private = false, final  List<QuerySourceRef> dependencies = const [], final  String? $type}): _dependencies = dependencies,$type = $type ?? 'question';
  factory QueryChatQuestion.fromJson(Map<String, dynamic> json) => _$QueryChatQuestionFromJson(json);

 final  String text;
@JsonKey() final  bool private;
 final  List<QuerySourceRef> _dependencies;
@JsonKey() List<QuerySourceRef> get dependencies {
  if (_dependencies is EqualUnmodifiableListView) return _dependencies;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_dependencies);
}


@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of QueryChatEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QueryChatQuestionCopyWith<QueryChatQuestion> get copyWith => _$QueryChatQuestionCopyWithImpl<QueryChatQuestion>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QueryChatQuestionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QueryChatQuestion&&(identical(other.text, text) || other.text == text)&&(identical(other.private, private) || other.private == private)&&const DeepCollectionEquality().equals(other._dependencies, _dependencies));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text,private,const DeepCollectionEquality().hash(_dependencies));

@override
String toString() {
  return 'QueryChatEventData.question(text: $text, private: $private, dependencies: $dependencies)';
}


}

/// @nodoc
abstract mixin class $QueryChatQuestionCopyWith<$Res> implements $QueryChatEventDataCopyWith<$Res> {
  factory $QueryChatQuestionCopyWith(QueryChatQuestion value, $Res Function(QueryChatQuestion) _then) = _$QueryChatQuestionCopyWithImpl;
@useResult
$Res call({
 String text, bool private, List<QuerySourceRef> dependencies
});




}
/// @nodoc
class _$QueryChatQuestionCopyWithImpl<$Res>
    implements $QueryChatQuestionCopyWith<$Res> {
  _$QueryChatQuestionCopyWithImpl(this._self, this._then);

  final QueryChatQuestion _self;
  final $Res Function(QueryChatQuestion) _then;

/// Create a copy of QueryChatEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? text = null,Object? private = null,Object? dependencies = null,}) {
  return _then(QueryChatQuestion(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,private: null == private ? _self.private : private // ignore: cast_nullable_to_non_nullable
as bool,dependencies: null == dependencies ? _self._dependencies : dependencies // ignore: cast_nullable_to_non_nullable
as List<QuerySourceRef>,
  ));
}


}

/// @nodoc
@JsonSerializable()

class QueryChatAnswer implements QueryChatEventData {
  const QueryChatAnswer({required this.questionId, required this.text, required this.coverage, this.private = false, final  List<QueryEvidence> evidence = const [], final  List<QuerySourceRef> dependencies = const [], final  List<String> recalledMemoryIds = const [], final  String? $type}): _evidence = evidence,_dependencies = dependencies,_recalledMemoryIds = recalledMemoryIds,$type = $type ?? 'answer';
  factory QueryChatAnswer.fromJson(Map<String, dynamic> json) => _$QueryChatAnswerFromJson(json);

 final  String questionId;
 final  String text;
 final  QueryCoverage coverage;
@JsonKey() final  bool private;
 final  List<QueryEvidence> _evidence;
@JsonKey() List<QueryEvidence> get evidence {
  if (_evidence is EqualUnmodifiableListView) return _evidence;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_evidence);
}

 final  List<QuerySourceRef> _dependencies;
@JsonKey() List<QuerySourceRef> get dependencies {
  if (_dependencies is EqualUnmodifiableListView) return _dependencies;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_dependencies);
}

 final  List<String> _recalledMemoryIds;
@JsonKey() List<String> get recalledMemoryIds {
  if (_recalledMemoryIds is EqualUnmodifiableListView) return _recalledMemoryIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_recalledMemoryIds);
}


@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of QueryChatEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QueryChatAnswerCopyWith<QueryChatAnswer> get copyWith => _$QueryChatAnswerCopyWithImpl<QueryChatAnswer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QueryChatAnswerToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QueryChatAnswer&&(identical(other.questionId, questionId) || other.questionId == questionId)&&(identical(other.text, text) || other.text == text)&&(identical(other.coverage, coverage) || other.coverage == coverage)&&(identical(other.private, private) || other.private == private)&&const DeepCollectionEquality().equals(other._evidence, _evidence)&&const DeepCollectionEquality().equals(other._dependencies, _dependencies)&&const DeepCollectionEquality().equals(other._recalledMemoryIds, _recalledMemoryIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,questionId,text,coverage,private,const DeepCollectionEquality().hash(_evidence),const DeepCollectionEquality().hash(_dependencies),const DeepCollectionEquality().hash(_recalledMemoryIds));

@override
String toString() {
  return 'QueryChatEventData.answer(questionId: $questionId, text: $text, coverage: $coverage, private: $private, evidence: $evidence, dependencies: $dependencies, recalledMemoryIds: $recalledMemoryIds)';
}


}

/// @nodoc
abstract mixin class $QueryChatAnswerCopyWith<$Res> implements $QueryChatEventDataCopyWith<$Res> {
  factory $QueryChatAnswerCopyWith(QueryChatAnswer value, $Res Function(QueryChatAnswer) _then) = _$QueryChatAnswerCopyWithImpl;
@useResult
$Res call({
 String questionId, String text, QueryCoverage coverage, bool private, List<QueryEvidence> evidence, List<QuerySourceRef> dependencies, List<String> recalledMemoryIds
});


$QueryCoverageCopyWith<$Res> get coverage;

}
/// @nodoc
class _$QueryChatAnswerCopyWithImpl<$Res>
    implements $QueryChatAnswerCopyWith<$Res> {
  _$QueryChatAnswerCopyWithImpl(this._self, this._then);

  final QueryChatAnswer _self;
  final $Res Function(QueryChatAnswer) _then;

/// Create a copy of QueryChatEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? questionId = null,Object? text = null,Object? coverage = null,Object? private = null,Object? evidence = null,Object? dependencies = null,Object? recalledMemoryIds = null,}) {
  return _then(QueryChatAnswer(
questionId: null == questionId ? _self.questionId : questionId // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,coverage: null == coverage ? _self.coverage : coverage // ignore: cast_nullable_to_non_nullable
as QueryCoverage,private: null == private ? _self.private : private // ignore: cast_nullable_to_non_nullable
as bool,evidence: null == evidence ? _self._evidence : evidence // ignore: cast_nullable_to_non_nullable
as List<QueryEvidence>,dependencies: null == dependencies ? _self._dependencies : dependencies // ignore: cast_nullable_to_non_nullable
as List<QuerySourceRef>,recalledMemoryIds: null == recalledMemoryIds ? _self._recalledMemoryIds : recalledMemoryIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

/// Create a copy of QueryChatEventData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$QueryCoverageCopyWith<$Res> get coverage {
  
  return $QueryCoverageCopyWith<$Res>(_self.coverage, (value) {
    return _then(_self.copyWith(coverage: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class QueryChatFailed implements QueryChatEventData {
  const QueryChatFailed({required this.questionId, final  String? $type}): $type = $type ?? 'failed';
  factory QueryChatFailed.fromJson(Map<String, dynamic> json) => _$QueryChatFailedFromJson(json);

 final  String questionId;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of QueryChatEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QueryChatFailedCopyWith<QueryChatFailed> get copyWith => _$QueryChatFailedCopyWithImpl<QueryChatFailed>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QueryChatFailedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QueryChatFailed&&(identical(other.questionId, questionId) || other.questionId == questionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,questionId);

@override
String toString() {
  return 'QueryChatEventData.failed(questionId: $questionId)';
}


}

/// @nodoc
abstract mixin class $QueryChatFailedCopyWith<$Res> implements $QueryChatEventDataCopyWith<$Res> {
  factory $QueryChatFailedCopyWith(QueryChatFailed value, $Res Function(QueryChatFailed) _then) = _$QueryChatFailedCopyWithImpl;
@useResult
$Res call({
 String questionId
});




}
/// @nodoc
class _$QueryChatFailedCopyWithImpl<$Res>
    implements $QueryChatFailedCopyWith<$Res> {
  _$QueryChatFailedCopyWithImpl(this._self, this._then);

  final QueryChatFailed _self;
  final $Res Function(QueryChatFailed) _then;

/// Create a copy of QueryChatEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? questionId = null,}) {
  return _then(QueryChatFailed(
questionId: null == questionId ? _self.questionId : questionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class QueryChatCancelled implements QueryChatEventData {
  const QueryChatCancelled({required this.questionId, final  String? $type}): $type = $type ?? 'cancelled';
  factory QueryChatCancelled.fromJson(Map<String, dynamic> json) => _$QueryChatCancelledFromJson(json);

 final  String questionId;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of QueryChatEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QueryChatCancelledCopyWith<QueryChatCancelled> get copyWith => _$QueryChatCancelledCopyWithImpl<QueryChatCancelled>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QueryChatCancelledToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QueryChatCancelled&&(identical(other.questionId, questionId) || other.questionId == questionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,questionId);

@override
String toString() {
  return 'QueryChatEventData.cancelled(questionId: $questionId)';
}


}

/// @nodoc
abstract mixin class $QueryChatCancelledCopyWith<$Res> implements $QueryChatEventDataCopyWith<$Res> {
  factory $QueryChatCancelledCopyWith(QueryChatCancelled value, $Res Function(QueryChatCancelled) _then) = _$QueryChatCancelledCopyWithImpl;
@useResult
$Res call({
 String questionId
});




}
/// @nodoc
class _$QueryChatCancelledCopyWithImpl<$Res>
    implements $QueryChatCancelledCopyWith<$Res> {
  _$QueryChatCancelledCopyWithImpl(this._self, this._then);

  final QueryChatCancelled _self;
  final $Res Function(QueryChatCancelled) _then;

/// Create a copy of QueryChatEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? questionId = null,}) {
  return _then(QueryChatCancelled(
questionId: null == questionId ? _self.questionId : questionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class QueryChatMemory implements QueryChatEventData {
  const QueryChatMemory({required this.questionId, required this.text, this.private = false, final  List<QuerySourceRef> dependencies = const [], final  List<String> recalledMemoryIds = const [], final  String? $type}): _dependencies = dependencies,_recalledMemoryIds = recalledMemoryIds,$type = $type ?? 'memory';
  factory QueryChatMemory.fromJson(Map<String, dynamic> json) => _$QueryChatMemoryFromJson(json);

 final  String questionId;
 final  String text;
@JsonKey() final  bool private;
 final  List<QuerySourceRef> _dependencies;
@JsonKey() List<QuerySourceRef> get dependencies {
  if (_dependencies is EqualUnmodifiableListView) return _dependencies;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_dependencies);
}

 final  List<String> _recalledMemoryIds;
@JsonKey() List<String> get recalledMemoryIds {
  if (_recalledMemoryIds is EqualUnmodifiableListView) return _recalledMemoryIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_recalledMemoryIds);
}


@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of QueryChatEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QueryChatMemoryCopyWith<QueryChatMemory> get copyWith => _$QueryChatMemoryCopyWithImpl<QueryChatMemory>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QueryChatMemoryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QueryChatMemory&&(identical(other.questionId, questionId) || other.questionId == questionId)&&(identical(other.text, text) || other.text == text)&&(identical(other.private, private) || other.private == private)&&const DeepCollectionEquality().equals(other._dependencies, _dependencies)&&const DeepCollectionEquality().equals(other._recalledMemoryIds, _recalledMemoryIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,questionId,text,private,const DeepCollectionEquality().hash(_dependencies),const DeepCollectionEquality().hash(_recalledMemoryIds));

@override
String toString() {
  return 'QueryChatEventData.memory(questionId: $questionId, text: $text, private: $private, dependencies: $dependencies, recalledMemoryIds: $recalledMemoryIds)';
}


}

/// @nodoc
abstract mixin class $QueryChatMemoryCopyWith<$Res> implements $QueryChatEventDataCopyWith<$Res> {
  factory $QueryChatMemoryCopyWith(QueryChatMemory value, $Res Function(QueryChatMemory) _then) = _$QueryChatMemoryCopyWithImpl;
@useResult
$Res call({
 String questionId, String text, bool private, List<QuerySourceRef> dependencies, List<String> recalledMemoryIds
});




}
/// @nodoc
class _$QueryChatMemoryCopyWithImpl<$Res>
    implements $QueryChatMemoryCopyWith<$Res> {
  _$QueryChatMemoryCopyWithImpl(this._self, this._then);

  final QueryChatMemory _self;
  final $Res Function(QueryChatMemory) _then;

/// Create a copy of QueryChatEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? questionId = null,Object? text = null,Object? private = null,Object? dependencies = null,Object? recalledMemoryIds = null,}) {
  return _then(QueryChatMemory(
questionId: null == questionId ? _self.questionId : questionId // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,private: null == private ? _self.private : private // ignore: cast_nullable_to_non_nullable
as bool,dependencies: null == dependencies ? _self._dependencies : dependencies // ignore: cast_nullable_to_non_nullable
as List<QuerySourceRef>,recalledMemoryIds: null == recalledMemoryIds ? _self._recalledMemoryIds : recalledMemoryIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
