// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'change_set.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChangeItem {

/// The tool name for this mutation (e.g., `add_checklist_item`).
 String get toolName;/// The arguments to pass to the tool handler.
 Map<String, dynamic> get args;/// A user-facing plain-text description of what this change does.
 String get humanSummary;/// Current status of this item within the change set.
 ChangeItemStatus get status;/// Optional group identifier for related items (e.g., a task-split
/// operation produces a create + N migrate items sharing the same group).
/// Used by the approval UI to visually group related items.
 String? get groupId;/// How many times this item has changed — its status, or its arguments
/// when a follow-up task's placeholder is resolved. Every write bumps it
/// by one on top of the version it read, so when two devices change the
/// set concurrently, the resolver keeps, item by item, the version that
/// changed the item last (`mergeConcurrentChangeSets`,
/// `specs/tla/ChangeSetLifecycle.tla`).
///
/// `null` for an item no build that knows the field has changed — and
/// for every item an older build wrote, since it drops the field when it
/// rewrites a set. Such an item carries no ordering, so a merge judges it
/// by status alone rather than as revision 0, which would lose a
/// decision an older build made to any newer-build change.
 int? get revision;/// The identity of this proposal's effect, when it differs from its
/// position — see [ChangeItemEffect.effectKeyIn]. Set only on a copy a
/// wake consolidates into a newer set, to its original's key, so that
/// confirming the copy on one device and the original on another
/// creates one entity, not two.
 String? get effectKey;/// The task fields this proposal was made against, keyed as in
/// `TaskMetadataSnapshot` (`title`, `status`, `priority`,
/// `estimateMinutes`, `dueDate`, `languageCode`). Confirming applies the
/// change only while the task still holds these values, so a late second
/// application — the same item confirmed on two devices — cannot
/// overwrite an edit the user made after the first. `null` when nothing
/// was recorded; the change then applies unconditionally.
 Map<String, dynamic>? get base;
/// Create a copy of ChangeItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChangeItemCopyWith<ChangeItem> get copyWith => _$ChangeItemCopyWithImpl<ChangeItem>(this as ChangeItem, _$identity);

  /// Serializes this ChangeItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChangeItem&&(identical(other.toolName, toolName) || other.toolName == toolName)&&const DeepCollectionEquality().equals(other.args, args)&&(identical(other.humanSummary, humanSummary) || other.humanSummary == humanSummary)&&(identical(other.status, status) || other.status == status)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.effectKey, effectKey) || other.effectKey == effectKey)&&const DeepCollectionEquality().equals(other.base, base));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,toolName,const DeepCollectionEquality().hash(args),humanSummary,status,groupId,revision,effectKey,const DeepCollectionEquality().hash(base));

@override
String toString() {
  return 'ChangeItem(toolName: $toolName, args: $args, humanSummary: $humanSummary, status: $status, groupId: $groupId, revision: $revision, effectKey: $effectKey, base: $base)';
}


}

/// @nodoc
abstract mixin class $ChangeItemCopyWith<$Res>  {
  factory $ChangeItemCopyWith(ChangeItem value, $Res Function(ChangeItem) _then) = _$ChangeItemCopyWithImpl;
@useResult
$Res call({
 String toolName, Map<String, dynamic> args, String humanSummary, ChangeItemStatus status, String? groupId, int? revision, String? effectKey, Map<String, dynamic>? base
});




}
/// @nodoc
class _$ChangeItemCopyWithImpl<$Res>
    implements $ChangeItemCopyWith<$Res> {
  _$ChangeItemCopyWithImpl(this._self, this._then);

  final ChangeItem _self;
  final $Res Function(ChangeItem) _then;

/// Create a copy of ChangeItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? toolName = null,Object? args = null,Object? humanSummary = null,Object? status = null,Object? groupId = freezed,Object? revision = freezed,Object? effectKey = freezed,Object? base = freezed,}) {
  return _then(_self.copyWith(
toolName: null == toolName ? _self.toolName : toolName // ignore: cast_nullable_to_non_nullable
as String,args: null == args ? _self.args : args // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,humanSummary: null == humanSummary ? _self.humanSummary : humanSummary // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ChangeItemStatus,groupId: freezed == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String?,revision: freezed == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int?,effectKey: freezed == effectKey ? _self.effectKey : effectKey // ignore: cast_nullable_to_non_nullable
as String?,base: freezed == base ? _self.base : base // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}

}


/// Adds pattern-matching-related methods to [ChangeItem].
extension ChangeItemPatterns on ChangeItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChangeItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChangeItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChangeItem value)  $default,){
final _that = this;
switch (_that) {
case _ChangeItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChangeItem value)?  $default,){
final _that = this;
switch (_that) {
case _ChangeItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String toolName,  Map<String, dynamic> args,  String humanSummary,  ChangeItemStatus status,  String? groupId,  int? revision,  String? effectKey,  Map<String, dynamic>? base)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChangeItem() when $default != null:
return $default(_that.toolName,_that.args,_that.humanSummary,_that.status,_that.groupId,_that.revision,_that.effectKey,_that.base);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String toolName,  Map<String, dynamic> args,  String humanSummary,  ChangeItemStatus status,  String? groupId,  int? revision,  String? effectKey,  Map<String, dynamic>? base)  $default,) {final _that = this;
switch (_that) {
case _ChangeItem():
return $default(_that.toolName,_that.args,_that.humanSummary,_that.status,_that.groupId,_that.revision,_that.effectKey,_that.base);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String toolName,  Map<String, dynamic> args,  String humanSummary,  ChangeItemStatus status,  String? groupId,  int? revision,  String? effectKey,  Map<String, dynamic>? base)?  $default,) {final _that = this;
switch (_that) {
case _ChangeItem() when $default != null:
return $default(_that.toolName,_that.args,_that.humanSummary,_that.status,_that.groupId,_that.revision,_that.effectKey,_that.base);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChangeItem implements ChangeItem {
  const _ChangeItem({required this.toolName, required final  Map<String, dynamic> args, required this.humanSummary, this.status = ChangeItemStatus.pending, this.groupId, this.revision, this.effectKey, final  Map<String, dynamic>? base}): _args = args,_base = base;
  factory _ChangeItem.fromJson(Map<String, dynamic> json) => _$ChangeItemFromJson(json);

/// The tool name for this mutation (e.g., `add_checklist_item`).
@override final  String toolName;
/// The arguments to pass to the tool handler.
 final  Map<String, dynamic> _args;
/// The arguments to pass to the tool handler.
@override Map<String, dynamic> get args {
  if (_args is EqualUnmodifiableMapView) return _args;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_args);
}

/// A user-facing plain-text description of what this change does.
@override final  String humanSummary;
/// Current status of this item within the change set.
@override@JsonKey() final  ChangeItemStatus status;
/// Optional group identifier for related items (e.g., a task-split
/// operation produces a create + N migrate items sharing the same group).
/// Used by the approval UI to visually group related items.
@override final  String? groupId;
/// How many times this item has changed — its status, or its arguments
/// when a follow-up task's placeholder is resolved. Every write bumps it
/// by one on top of the version it read, so when two devices change the
/// set concurrently, the resolver keeps, item by item, the version that
/// changed the item last (`mergeConcurrentChangeSets`,
/// `specs/tla/ChangeSetLifecycle.tla`).
///
/// `null` for an item no build that knows the field has changed — and
/// for every item an older build wrote, since it drops the field when it
/// rewrites a set. Such an item carries no ordering, so a merge judges it
/// by status alone rather than as revision 0, which would lose a
/// decision an older build made to any newer-build change.
@override final  int? revision;
/// The identity of this proposal's effect, when it differs from its
/// position — see [ChangeItemEffect.effectKeyIn]. Set only on a copy a
/// wake consolidates into a newer set, to its original's key, so that
/// confirming the copy on one device and the original on another
/// creates one entity, not two.
@override final  String? effectKey;
/// The task fields this proposal was made against, keyed as in
/// `TaskMetadataSnapshot` (`title`, `status`, `priority`,
/// `estimateMinutes`, `dueDate`, `languageCode`). Confirming applies the
/// change only while the task still holds these values, so a late second
/// application — the same item confirmed on two devices — cannot
/// overwrite an edit the user made after the first. `null` when nothing
/// was recorded; the change then applies unconditionally.
 final  Map<String, dynamic>? _base;
/// The task fields this proposal was made against, keyed as in
/// `TaskMetadataSnapshot` (`title`, `status`, `priority`,
/// `estimateMinutes`, `dueDate`, `languageCode`). Confirming applies the
/// change only while the task still holds these values, so a late second
/// application — the same item confirmed on two devices — cannot
/// overwrite an edit the user made after the first. `null` when nothing
/// was recorded; the change then applies unconditionally.
@override Map<String, dynamic>? get base {
  final value = _base;
  if (value == null) return null;
  if (_base is EqualUnmodifiableMapView) return _base;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of ChangeItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChangeItemCopyWith<_ChangeItem> get copyWith => __$ChangeItemCopyWithImpl<_ChangeItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChangeItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChangeItem&&(identical(other.toolName, toolName) || other.toolName == toolName)&&const DeepCollectionEquality().equals(other._args, _args)&&(identical(other.humanSummary, humanSummary) || other.humanSummary == humanSummary)&&(identical(other.status, status) || other.status == status)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.effectKey, effectKey) || other.effectKey == effectKey)&&const DeepCollectionEquality().equals(other._base, _base));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,toolName,const DeepCollectionEquality().hash(_args),humanSummary,status,groupId,revision,effectKey,const DeepCollectionEquality().hash(_base));

@override
String toString() {
  return 'ChangeItem(toolName: $toolName, args: $args, humanSummary: $humanSummary, status: $status, groupId: $groupId, revision: $revision, effectKey: $effectKey, base: $base)';
}


}

/// @nodoc
abstract mixin class _$ChangeItemCopyWith<$Res> implements $ChangeItemCopyWith<$Res> {
  factory _$ChangeItemCopyWith(_ChangeItem value, $Res Function(_ChangeItem) _then) = __$ChangeItemCopyWithImpl;
@override @useResult
$Res call({
 String toolName, Map<String, dynamic> args, String humanSummary, ChangeItemStatus status, String? groupId, int? revision, String? effectKey, Map<String, dynamic>? base
});




}
/// @nodoc
class __$ChangeItemCopyWithImpl<$Res>
    implements _$ChangeItemCopyWith<$Res> {
  __$ChangeItemCopyWithImpl(this._self, this._then);

  final _ChangeItem _self;
  final $Res Function(_ChangeItem) _then;

/// Create a copy of ChangeItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? toolName = null,Object? args = null,Object? humanSummary = null,Object? status = null,Object? groupId = freezed,Object? revision = freezed,Object? effectKey = freezed,Object? base = freezed,}) {
  return _then(_ChangeItem(
toolName: null == toolName ? _self.toolName : toolName // ignore: cast_nullable_to_non_nullable
as String,args: null == args ? _self._args : args // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,humanSummary: null == humanSummary ? _self.humanSummary : humanSummary // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ChangeItemStatus,groupId: freezed == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String?,revision: freezed == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int?,effectKey: freezed == effectKey ? _self.effectKey : effectKey // ignore: cast_nullable_to_non_nullable
as String?,base: freezed == base ? _self._base : base // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}


}

// dart format on
