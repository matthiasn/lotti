// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_document_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TaskDocumentData {

/// What the document is called on the task, e.g. "Client one-pager".
 String get title;/// The version the document shows; null until its first version is
/// written.
 TaskDocumentVersionRef? get current;
/// Create a copy of TaskDocumentData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskDocumentDataCopyWith<TaskDocumentData> get copyWith => _$TaskDocumentDataCopyWithImpl<TaskDocumentData>(this as TaskDocumentData, _$identity);

  /// Serializes this TaskDocumentData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskDocumentData&&(identical(other.title, title) || other.title == title)&&(identical(other.current, current) || other.current == current));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,current);

@override
String toString() {
  return 'TaskDocumentData(title: $title, current: $current)';
}


}

/// @nodoc
abstract mixin class $TaskDocumentDataCopyWith<$Res>  {
  factory $TaskDocumentDataCopyWith(TaskDocumentData value, $Res Function(TaskDocumentData) _then) = _$TaskDocumentDataCopyWithImpl;
@useResult
$Res call({
 String title, TaskDocumentVersionRef? current
});


$TaskDocumentVersionRefCopyWith<$Res>? get current;

}
/// @nodoc
class _$TaskDocumentDataCopyWithImpl<$Res>
    implements $TaskDocumentDataCopyWith<$Res> {
  _$TaskDocumentDataCopyWithImpl(this._self, this._then);

  final TaskDocumentData _self;
  final $Res Function(TaskDocumentData) _then;

/// Create a copy of TaskDocumentData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? current = freezed,}) {
  return _then(_self.copyWith(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,current: freezed == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as TaskDocumentVersionRef?,
  ));
}
/// Create a copy of TaskDocumentData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TaskDocumentVersionRefCopyWith<$Res>? get current {
    if (_self.current == null) {
    return null;
  }

  return $TaskDocumentVersionRefCopyWith<$Res>(_self.current!, (value) {
    return _then(_self.copyWith(current: value));
  });
}
}


/// Adds pattern-matching-related methods to [TaskDocumentData].
extension TaskDocumentDataPatterns on TaskDocumentData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TaskDocumentData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TaskDocumentData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TaskDocumentData value)  $default,){
final _that = this;
switch (_that) {
case _TaskDocumentData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TaskDocumentData value)?  $default,){
final _that = this;
switch (_that) {
case _TaskDocumentData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String title,  TaskDocumentVersionRef? current)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaskDocumentData() when $default != null:
return $default(_that.title,_that.current);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String title,  TaskDocumentVersionRef? current)  $default,) {final _that = this;
switch (_that) {
case _TaskDocumentData():
return $default(_that.title,_that.current);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String title,  TaskDocumentVersionRef? current)?  $default,) {final _that = this;
switch (_that) {
case _TaskDocumentData() when $default != null:
return $default(_that.title,_that.current);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TaskDocumentData implements TaskDocumentData {
  const _TaskDocumentData({required this.title, this.current});
  factory _TaskDocumentData.fromJson(Map<String, dynamic> json) => _$TaskDocumentDataFromJson(json);

/// What the document is called on the task, e.g. "Client one-pager".
@override final  String title;
/// The version the document shows; null until its first version is
/// written.
@override final  TaskDocumentVersionRef? current;

/// Create a copy of TaskDocumentData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskDocumentDataCopyWith<_TaskDocumentData> get copyWith => __$TaskDocumentDataCopyWithImpl<_TaskDocumentData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaskDocumentDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaskDocumentData&&(identical(other.title, title) || other.title == title)&&(identical(other.current, current) || other.current == current));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,current);

@override
String toString() {
  return 'TaskDocumentData(title: $title, current: $current)';
}


}

/// @nodoc
abstract mixin class _$TaskDocumentDataCopyWith<$Res> implements $TaskDocumentDataCopyWith<$Res> {
  factory _$TaskDocumentDataCopyWith(_TaskDocumentData value, $Res Function(_TaskDocumentData) _then) = __$TaskDocumentDataCopyWithImpl;
@override @useResult
$Res call({
 String title, TaskDocumentVersionRef? current
});


@override $TaskDocumentVersionRefCopyWith<$Res>? get current;

}
/// @nodoc
class __$TaskDocumentDataCopyWithImpl<$Res>
    implements _$TaskDocumentDataCopyWith<$Res> {
  __$TaskDocumentDataCopyWithImpl(this._self, this._then);

  final _TaskDocumentData _self;
  final $Res Function(_TaskDocumentData) _then;

/// Create a copy of TaskDocumentData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? current = freezed,}) {
  return _then(_TaskDocumentData(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,current: freezed == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as TaskDocumentVersionRef?,
  ));
}

/// Create a copy of TaskDocumentData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TaskDocumentVersionRefCopyWith<$Res>? get current {
    if (_self.current == null) {
    return null;
  }

  return $TaskDocumentVersionRefCopyWith<$Res>(_self.current!, (value) {
    return _then(_self.copyWith(current: value));
  });
}
}


/// @nodoc
mixin _$TaskDocumentVersionRef {

/// The id of the `JournalEntity.taskDocumentVersion` row.
 String get id;/// The version's number, as shown ("v3").
 int get number;/// When the version was written: its `meta.createdAt`.
 DateTime get createdAt;
/// Create a copy of TaskDocumentVersionRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskDocumentVersionRefCopyWith<TaskDocumentVersionRef> get copyWith => _$TaskDocumentVersionRefCopyWithImpl<TaskDocumentVersionRef>(this as TaskDocumentVersionRef, _$identity);

  /// Serializes this TaskDocumentVersionRef to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskDocumentVersionRef&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,number,createdAt);

@override
String toString() {
  return 'TaskDocumentVersionRef(id: $id, number: $number, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $TaskDocumentVersionRefCopyWith<$Res>  {
  factory $TaskDocumentVersionRefCopyWith(TaskDocumentVersionRef value, $Res Function(TaskDocumentVersionRef) _then) = _$TaskDocumentVersionRefCopyWithImpl;
@useResult
$Res call({
 String id, int number, DateTime createdAt
});




}
/// @nodoc
class _$TaskDocumentVersionRefCopyWithImpl<$Res>
    implements $TaskDocumentVersionRefCopyWith<$Res> {
  _$TaskDocumentVersionRefCopyWithImpl(this._self, this._then);

  final TaskDocumentVersionRef _self;
  final $Res Function(TaskDocumentVersionRef) _then;

/// Create a copy of TaskDocumentVersionRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? number = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [TaskDocumentVersionRef].
extension TaskDocumentVersionRefPatterns on TaskDocumentVersionRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TaskDocumentVersionRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TaskDocumentVersionRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TaskDocumentVersionRef value)  $default,){
final _that = this;
switch (_that) {
case _TaskDocumentVersionRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TaskDocumentVersionRef value)?  $default,){
final _that = this;
switch (_that) {
case _TaskDocumentVersionRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  int number,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaskDocumentVersionRef() when $default != null:
return $default(_that.id,_that.number,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  int number,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _TaskDocumentVersionRef():
return $default(_that.id,_that.number,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  int number,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _TaskDocumentVersionRef() when $default != null:
return $default(_that.id,_that.number,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TaskDocumentVersionRef implements TaskDocumentVersionRef {
  const _TaskDocumentVersionRef({required this.id, required this.number, required this.createdAt});
  factory _TaskDocumentVersionRef.fromJson(Map<String, dynamic> json) => _$TaskDocumentVersionRefFromJson(json);

/// The id of the `JournalEntity.taskDocumentVersion` row.
@override final  String id;
/// The version's number, as shown ("v3").
@override final  int number;
/// When the version was written: its `meta.createdAt`.
@override final  DateTime createdAt;

/// Create a copy of TaskDocumentVersionRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskDocumentVersionRefCopyWith<_TaskDocumentVersionRef> get copyWith => __$TaskDocumentVersionRefCopyWithImpl<_TaskDocumentVersionRef>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaskDocumentVersionRefToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaskDocumentVersionRef&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,number,createdAt);

@override
String toString() {
  return 'TaskDocumentVersionRef(id: $id, number: $number, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$TaskDocumentVersionRefCopyWith<$Res> implements $TaskDocumentVersionRefCopyWith<$Res> {
  factory _$TaskDocumentVersionRefCopyWith(_TaskDocumentVersionRef value, $Res Function(_TaskDocumentVersionRef) _then) = __$TaskDocumentVersionRefCopyWithImpl;
@override @useResult
$Res call({
 String id, int number, DateTime createdAt
});




}
/// @nodoc
class __$TaskDocumentVersionRefCopyWithImpl<$Res>
    implements _$TaskDocumentVersionRefCopyWith<$Res> {
  __$TaskDocumentVersionRefCopyWithImpl(this._self, this._then);

  final _TaskDocumentVersionRef _self;
  final $Res Function(_TaskDocumentVersionRef) _then;

/// Create a copy of TaskDocumentVersionRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? number = null,Object? createdAt = null,}) {
  return _then(_TaskDocumentVersionRef(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$TaskDocumentVersionData {

/// The `JournalEntity.taskDocument` this is a version of. Stored as the
/// row's subtype, so a document's versions are an indexed lookup.
 String get documentId;/// One more than the version it was written over. Two devices writing
/// over the same version at once both get the same number; the merge
/// still orders them (see [TaskDocumentVersionRef]).
 int get number;/// The document's full text, as markdown.
 String get markdown;@JsonKey(unknownEnumValue: TaskDocumentAuthor.user) TaskDocumentAuthor get author;/// The version this one was written over; null for a first version.
 String? get baseVersionId;/// What changed, in a sentence: the agent's summary of its proposal, or
/// empty for a hand edit.
 String? get changeSummary;/// For an agent version, the change set and item it was confirmed from:
/// its provenance.
 String? get changeSetId; String? get changeItemId;/// For a restore, the older version whose text this repeats.
 String? get restoredFromVersionId;
/// Create a copy of TaskDocumentVersionData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskDocumentVersionDataCopyWith<TaskDocumentVersionData> get copyWith => _$TaskDocumentVersionDataCopyWithImpl<TaskDocumentVersionData>(this as TaskDocumentVersionData, _$identity);

  /// Serializes this TaskDocumentVersionData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskDocumentVersionData&&(identical(other.documentId, documentId) || other.documentId == documentId)&&(identical(other.number, number) || other.number == number)&&(identical(other.markdown, markdown) || other.markdown == markdown)&&(identical(other.author, author) || other.author == author)&&(identical(other.baseVersionId, baseVersionId) || other.baseVersionId == baseVersionId)&&(identical(other.changeSummary, changeSummary) || other.changeSummary == changeSummary)&&(identical(other.changeSetId, changeSetId) || other.changeSetId == changeSetId)&&(identical(other.changeItemId, changeItemId) || other.changeItemId == changeItemId)&&(identical(other.restoredFromVersionId, restoredFromVersionId) || other.restoredFromVersionId == restoredFromVersionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,documentId,number,markdown,author,baseVersionId,changeSummary,changeSetId,changeItemId,restoredFromVersionId);

@override
String toString() {
  return 'TaskDocumentVersionData(documentId: $documentId, number: $number, markdown: $markdown, author: $author, baseVersionId: $baseVersionId, changeSummary: $changeSummary, changeSetId: $changeSetId, changeItemId: $changeItemId, restoredFromVersionId: $restoredFromVersionId)';
}


}

/// @nodoc
abstract mixin class $TaskDocumentVersionDataCopyWith<$Res>  {
  factory $TaskDocumentVersionDataCopyWith(TaskDocumentVersionData value, $Res Function(TaskDocumentVersionData) _then) = _$TaskDocumentVersionDataCopyWithImpl;
@useResult
$Res call({
 String documentId, int number, String markdown,@JsonKey(unknownEnumValue: TaskDocumentAuthor.user) TaskDocumentAuthor author, String? baseVersionId, String? changeSummary, String? changeSetId, String? changeItemId, String? restoredFromVersionId
});




}
/// @nodoc
class _$TaskDocumentVersionDataCopyWithImpl<$Res>
    implements $TaskDocumentVersionDataCopyWith<$Res> {
  _$TaskDocumentVersionDataCopyWithImpl(this._self, this._then);

  final TaskDocumentVersionData _self;
  final $Res Function(TaskDocumentVersionData) _then;

/// Create a copy of TaskDocumentVersionData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? documentId = null,Object? number = null,Object? markdown = null,Object? author = null,Object? baseVersionId = freezed,Object? changeSummary = freezed,Object? changeSetId = freezed,Object? changeItemId = freezed,Object? restoredFromVersionId = freezed,}) {
  return _then(_self.copyWith(
documentId: null == documentId ? _self.documentId : documentId // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,markdown: null == markdown ? _self.markdown : markdown // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as TaskDocumentAuthor,baseVersionId: freezed == baseVersionId ? _self.baseVersionId : baseVersionId // ignore: cast_nullable_to_non_nullable
as String?,changeSummary: freezed == changeSummary ? _self.changeSummary : changeSummary // ignore: cast_nullable_to_non_nullable
as String?,changeSetId: freezed == changeSetId ? _self.changeSetId : changeSetId // ignore: cast_nullable_to_non_nullable
as String?,changeItemId: freezed == changeItemId ? _self.changeItemId : changeItemId // ignore: cast_nullable_to_non_nullable
as String?,restoredFromVersionId: freezed == restoredFromVersionId ? _self.restoredFromVersionId : restoredFromVersionId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [TaskDocumentVersionData].
extension TaskDocumentVersionDataPatterns on TaskDocumentVersionData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TaskDocumentVersionData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TaskDocumentVersionData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TaskDocumentVersionData value)  $default,){
final _that = this;
switch (_that) {
case _TaskDocumentVersionData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TaskDocumentVersionData value)?  $default,){
final _that = this;
switch (_that) {
case _TaskDocumentVersionData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String documentId,  int number,  String markdown, @JsonKey(unknownEnumValue: TaskDocumentAuthor.user)  TaskDocumentAuthor author,  String? baseVersionId,  String? changeSummary,  String? changeSetId,  String? changeItemId,  String? restoredFromVersionId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaskDocumentVersionData() when $default != null:
return $default(_that.documentId,_that.number,_that.markdown,_that.author,_that.baseVersionId,_that.changeSummary,_that.changeSetId,_that.changeItemId,_that.restoredFromVersionId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String documentId,  int number,  String markdown, @JsonKey(unknownEnumValue: TaskDocumentAuthor.user)  TaskDocumentAuthor author,  String? baseVersionId,  String? changeSummary,  String? changeSetId,  String? changeItemId,  String? restoredFromVersionId)  $default,) {final _that = this;
switch (_that) {
case _TaskDocumentVersionData():
return $default(_that.documentId,_that.number,_that.markdown,_that.author,_that.baseVersionId,_that.changeSummary,_that.changeSetId,_that.changeItemId,_that.restoredFromVersionId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String documentId,  int number,  String markdown, @JsonKey(unknownEnumValue: TaskDocumentAuthor.user)  TaskDocumentAuthor author,  String? baseVersionId,  String? changeSummary,  String? changeSetId,  String? changeItemId,  String? restoredFromVersionId)?  $default,) {final _that = this;
switch (_that) {
case _TaskDocumentVersionData() when $default != null:
return $default(_that.documentId,_that.number,_that.markdown,_that.author,_that.baseVersionId,_that.changeSummary,_that.changeSetId,_that.changeItemId,_that.restoredFromVersionId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TaskDocumentVersionData implements TaskDocumentVersionData {
  const _TaskDocumentVersionData({required this.documentId, required this.number, required this.markdown, @JsonKey(unknownEnumValue: TaskDocumentAuthor.user) required this.author, this.baseVersionId, this.changeSummary, this.changeSetId, this.changeItemId, this.restoredFromVersionId});
  factory _TaskDocumentVersionData.fromJson(Map<String, dynamic> json) => _$TaskDocumentVersionDataFromJson(json);

/// The `JournalEntity.taskDocument` this is a version of. Stored as the
/// row's subtype, so a document's versions are an indexed lookup.
@override final  String documentId;
/// One more than the version it was written over. Two devices writing
/// over the same version at once both get the same number; the merge
/// still orders them (see [TaskDocumentVersionRef]).
@override final  int number;
/// The document's full text, as markdown.
@override final  String markdown;
@override@JsonKey(unknownEnumValue: TaskDocumentAuthor.user) final  TaskDocumentAuthor author;
/// The version this one was written over; null for a first version.
@override final  String? baseVersionId;
/// What changed, in a sentence: the agent's summary of its proposal, or
/// empty for a hand edit.
@override final  String? changeSummary;
/// For an agent version, the change set and item it was confirmed from:
/// its provenance.
@override final  String? changeSetId;
@override final  String? changeItemId;
/// For a restore, the older version whose text this repeats.
@override final  String? restoredFromVersionId;

/// Create a copy of TaskDocumentVersionData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskDocumentVersionDataCopyWith<_TaskDocumentVersionData> get copyWith => __$TaskDocumentVersionDataCopyWithImpl<_TaskDocumentVersionData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaskDocumentVersionDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaskDocumentVersionData&&(identical(other.documentId, documentId) || other.documentId == documentId)&&(identical(other.number, number) || other.number == number)&&(identical(other.markdown, markdown) || other.markdown == markdown)&&(identical(other.author, author) || other.author == author)&&(identical(other.baseVersionId, baseVersionId) || other.baseVersionId == baseVersionId)&&(identical(other.changeSummary, changeSummary) || other.changeSummary == changeSummary)&&(identical(other.changeSetId, changeSetId) || other.changeSetId == changeSetId)&&(identical(other.changeItemId, changeItemId) || other.changeItemId == changeItemId)&&(identical(other.restoredFromVersionId, restoredFromVersionId) || other.restoredFromVersionId == restoredFromVersionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,documentId,number,markdown,author,baseVersionId,changeSummary,changeSetId,changeItemId,restoredFromVersionId);

@override
String toString() {
  return 'TaskDocumentVersionData(documentId: $documentId, number: $number, markdown: $markdown, author: $author, baseVersionId: $baseVersionId, changeSummary: $changeSummary, changeSetId: $changeSetId, changeItemId: $changeItemId, restoredFromVersionId: $restoredFromVersionId)';
}


}

/// @nodoc
abstract mixin class _$TaskDocumentVersionDataCopyWith<$Res> implements $TaskDocumentVersionDataCopyWith<$Res> {
  factory _$TaskDocumentVersionDataCopyWith(_TaskDocumentVersionData value, $Res Function(_TaskDocumentVersionData) _then) = __$TaskDocumentVersionDataCopyWithImpl;
@override @useResult
$Res call({
 String documentId, int number, String markdown,@JsonKey(unknownEnumValue: TaskDocumentAuthor.user) TaskDocumentAuthor author, String? baseVersionId, String? changeSummary, String? changeSetId, String? changeItemId, String? restoredFromVersionId
});




}
/// @nodoc
class __$TaskDocumentVersionDataCopyWithImpl<$Res>
    implements _$TaskDocumentVersionDataCopyWith<$Res> {
  __$TaskDocumentVersionDataCopyWithImpl(this._self, this._then);

  final _TaskDocumentVersionData _self;
  final $Res Function(_TaskDocumentVersionData) _then;

/// Create a copy of TaskDocumentVersionData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? documentId = null,Object? number = null,Object? markdown = null,Object? author = null,Object? baseVersionId = freezed,Object? changeSummary = freezed,Object? changeSetId = freezed,Object? changeItemId = freezed,Object? restoredFromVersionId = freezed,}) {
  return _then(_TaskDocumentVersionData(
documentId: null == documentId ? _self.documentId : documentId // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,markdown: null == markdown ? _self.markdown : markdown // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as TaskDocumentAuthor,baseVersionId: freezed == baseVersionId ? _self.baseVersionId : baseVersionId // ignore: cast_nullable_to_non_nullable
as String?,changeSummary: freezed == changeSummary ? _self.changeSummary : changeSummary // ignore: cast_nullable_to_non_nullable
as String?,changeSetId: freezed == changeSetId ? _self.changeSetId : changeSetId // ignore: cast_nullable_to_non_nullable
as String?,changeItemId: freezed == changeItemId ? _self.changeItemId : changeItemId // ignore: cast_nullable_to_non_nullable
as String?,restoredFromVersionId: freezed == restoredFromVersionId ? _self.restoredFromVersionId : restoredFromVersionId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
