// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'agent_report_section.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AgentReportSection {

 AgentReportSectionKind get kind;/// Heading in the task language; empty for an untitled lead paragraph.
 String get title;/// The paragraph of a [AgentReportSectionKind.text] section.
 String get text;/// The rows of a points or checklist section.
 List<AgentReportSectionItem> get items;
/// Create a copy of AgentReportSection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentReportSectionCopyWith<AgentReportSection> get copyWith => _$AgentReportSectionCopyWithImpl<AgentReportSection>(this as AgentReportSection, _$identity);

  /// Serializes this AgentReportSection to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentReportSection&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.title, title) || other.title == title)&&(identical(other.text, text) || other.text == text)&&const DeepCollectionEquality().equals(other.items, items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,title,text,const DeepCollectionEquality().hash(items));

@override
String toString() {
  return 'AgentReportSection(kind: $kind, title: $title, text: $text, items: $items)';
}


}

/// @nodoc
abstract mixin class $AgentReportSectionCopyWith<$Res>  {
  factory $AgentReportSectionCopyWith(AgentReportSection value, $Res Function(AgentReportSection) _then) = _$AgentReportSectionCopyWithImpl;
@useResult
$Res call({
 AgentReportSectionKind kind, String title, String text, List<AgentReportSectionItem> items
});




}
/// @nodoc
class _$AgentReportSectionCopyWithImpl<$Res>
    implements $AgentReportSectionCopyWith<$Res> {
  _$AgentReportSectionCopyWithImpl(this._self, this._then);

  final AgentReportSection _self;
  final $Res Function(AgentReportSection) _then;

/// Create a copy of AgentReportSection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? title = null,Object? text = null,Object? items = null,}) {
  return _then(_self.copyWith(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as AgentReportSectionKind,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<AgentReportSectionItem>,
  ));
}

}


/// Adds pattern-matching-related methods to [AgentReportSection].
extension AgentReportSectionPatterns on AgentReportSection {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentReportSection value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentReportSection() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentReportSection value)  $default,){
final _that = this;
switch (_that) {
case _AgentReportSection():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentReportSection value)?  $default,){
final _that = this;
switch (_that) {
case _AgentReportSection() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AgentReportSectionKind kind,  String title,  String text,  List<AgentReportSectionItem> items)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentReportSection() when $default != null:
return $default(_that.kind,_that.title,_that.text,_that.items);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AgentReportSectionKind kind,  String title,  String text,  List<AgentReportSectionItem> items)  $default,) {final _that = this;
switch (_that) {
case _AgentReportSection():
return $default(_that.kind,_that.title,_that.text,_that.items);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AgentReportSectionKind kind,  String title,  String text,  List<AgentReportSectionItem> items)?  $default,) {final _that = this;
switch (_that) {
case _AgentReportSection() when $default != null:
return $default(_that.kind,_that.title,_that.text,_that.items);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentReportSection implements AgentReportSection {
  const _AgentReportSection({required this.kind, this.title = '', this.text = '', final  List<AgentReportSectionItem> items = const <AgentReportSectionItem>[]}): _items = items;
  factory _AgentReportSection.fromJson(Map<String, dynamic> json) => _$AgentReportSectionFromJson(json);

@override final  AgentReportSectionKind kind;
/// Heading in the task language; empty for an untitled lead paragraph.
@override@JsonKey() final  String title;
/// The paragraph of a [AgentReportSectionKind.text] section.
@override@JsonKey() final  String text;
/// The rows of a points or checklist section.
 final  List<AgentReportSectionItem> _items;
/// The rows of a points or checklist section.
@override@JsonKey() List<AgentReportSectionItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of AgentReportSection
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentReportSectionCopyWith<_AgentReportSection> get copyWith => __$AgentReportSectionCopyWithImpl<_AgentReportSection>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentReportSectionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentReportSection&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.title, title) || other.title == title)&&(identical(other.text, text) || other.text == text)&&const DeepCollectionEquality().equals(other._items, _items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,title,text,const DeepCollectionEquality().hash(_items));

@override
String toString() {
  return 'AgentReportSection(kind: $kind, title: $title, text: $text, items: $items)';
}


}

/// @nodoc
abstract mixin class _$AgentReportSectionCopyWith<$Res> implements $AgentReportSectionCopyWith<$Res> {
  factory _$AgentReportSectionCopyWith(_AgentReportSection value, $Res Function(_AgentReportSection) _then) = __$AgentReportSectionCopyWithImpl;
@override @useResult
$Res call({
 AgentReportSectionKind kind, String title, String text, List<AgentReportSectionItem> items
});




}
/// @nodoc
class __$AgentReportSectionCopyWithImpl<$Res>
    implements _$AgentReportSectionCopyWith<$Res> {
  __$AgentReportSectionCopyWithImpl(this._self, this._then);

  final _AgentReportSection _self;
  final $Res Function(_AgentReportSection) _then;

/// Create a copy of AgentReportSection
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? title = null,Object? text = null,Object? items = null,}) {
  return _then(_AgentReportSection(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as AgentReportSectionKind,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<AgentReportSectionItem>,
  ));
}


}


/// @nodoc
mixin _$AgentReportSectionItem {

 String get text;/// Only meaningful in a checklist section.
 bool get done;
/// Create a copy of AgentReportSectionItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentReportSectionItemCopyWith<AgentReportSectionItem> get copyWith => _$AgentReportSectionItemCopyWithImpl<AgentReportSectionItem>(this as AgentReportSectionItem, _$identity);

  /// Serializes this AgentReportSectionItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentReportSectionItem&&(identical(other.text, text) || other.text == text)&&(identical(other.done, done) || other.done == done));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text,done);

@override
String toString() {
  return 'AgentReportSectionItem(text: $text, done: $done)';
}


}

/// @nodoc
abstract mixin class $AgentReportSectionItemCopyWith<$Res>  {
  factory $AgentReportSectionItemCopyWith(AgentReportSectionItem value, $Res Function(AgentReportSectionItem) _then) = _$AgentReportSectionItemCopyWithImpl;
@useResult
$Res call({
 String text, bool done
});




}
/// @nodoc
class _$AgentReportSectionItemCopyWithImpl<$Res>
    implements $AgentReportSectionItemCopyWith<$Res> {
  _$AgentReportSectionItemCopyWithImpl(this._self, this._then);

  final AgentReportSectionItem _self;
  final $Res Function(AgentReportSectionItem) _then;

/// Create a copy of AgentReportSectionItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? text = null,Object? done = null,}) {
  return _then(_self.copyWith(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,done: null == done ? _self.done : done // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AgentReportSectionItem].
extension AgentReportSectionItemPatterns on AgentReportSectionItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentReportSectionItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentReportSectionItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentReportSectionItem value)  $default,){
final _that = this;
switch (_that) {
case _AgentReportSectionItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentReportSectionItem value)?  $default,){
final _that = this;
switch (_that) {
case _AgentReportSectionItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String text,  bool done)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentReportSectionItem() when $default != null:
return $default(_that.text,_that.done);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String text,  bool done)  $default,) {final _that = this;
switch (_that) {
case _AgentReportSectionItem():
return $default(_that.text,_that.done);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String text,  bool done)?  $default,) {final _that = this;
switch (_that) {
case _AgentReportSectionItem() when $default != null:
return $default(_that.text,_that.done);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentReportSectionItem implements AgentReportSectionItem {
  const _AgentReportSectionItem({required this.text, this.done = false});
  factory _AgentReportSectionItem.fromJson(Map<String, dynamic> json) => _$AgentReportSectionItemFromJson(json);

@override final  String text;
/// Only meaningful in a checklist section.
@override@JsonKey() final  bool done;

/// Create a copy of AgentReportSectionItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentReportSectionItemCopyWith<_AgentReportSectionItem> get copyWith => __$AgentReportSectionItemCopyWithImpl<_AgentReportSectionItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentReportSectionItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentReportSectionItem&&(identical(other.text, text) || other.text == text)&&(identical(other.done, done) || other.done == done));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text,done);

@override
String toString() {
  return 'AgentReportSectionItem(text: $text, done: $done)';
}


}

/// @nodoc
abstract mixin class _$AgentReportSectionItemCopyWith<$Res> implements $AgentReportSectionItemCopyWith<$Res> {
  factory _$AgentReportSectionItemCopyWith(_AgentReportSectionItem value, $Res Function(_AgentReportSectionItem) _then) = __$AgentReportSectionItemCopyWithImpl;
@override @useResult
$Res call({
 String text, bool done
});




}
/// @nodoc
class __$AgentReportSectionItemCopyWithImpl<$Res>
    implements _$AgentReportSectionItemCopyWith<$Res> {
  __$AgentReportSectionItemCopyWithImpl(this._self, this._then);

  final _AgentReportSectionItem _self;
  final $Res Function(_AgentReportSectionItem) _then;

/// Create a copy of AgentReportSectionItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = null,Object? done = null,}) {
  return _then(_AgentReportSectionItem(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,done: null == done ? _self.done : done // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
