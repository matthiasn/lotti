// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'checklist_item_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChecklistItemData {

 String get title; bool get isChecked; List<String> get linkedChecklists; bool get isArchived; String? get id;@JsonKey(unknownEnumValue: ChangeSource.user) ChangeSource get checkedBy; DateTime? get checkedAt; List<ChecklistItemProvenance> get approvalHistory;
/// Create a copy of ChecklistItemData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChecklistItemDataCopyWith<ChecklistItemData> get copyWith => _$ChecklistItemDataCopyWithImpl<ChecklistItemData>(this as ChecklistItemData, _$identity);

  /// Serializes this ChecklistItemData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChecklistItemData&&(identical(other.title, title) || other.title == title)&&(identical(other.isChecked, isChecked) || other.isChecked == isChecked)&&const DeepCollectionEquality().equals(other.linkedChecklists, linkedChecklists)&&(identical(other.isArchived, isArchived) || other.isArchived == isArchived)&&(identical(other.id, id) || other.id == id)&&(identical(other.checkedBy, checkedBy) || other.checkedBy == checkedBy)&&(identical(other.checkedAt, checkedAt) || other.checkedAt == checkedAt)&&const DeepCollectionEquality().equals(other.approvalHistory, approvalHistory));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,isChecked,const DeepCollectionEquality().hash(linkedChecklists),isArchived,id,checkedBy,checkedAt,const DeepCollectionEquality().hash(approvalHistory));

@override
String toString() {
  return 'ChecklistItemData(title: $title, isChecked: $isChecked, linkedChecklists: $linkedChecklists, isArchived: $isArchived, id: $id, checkedBy: $checkedBy, checkedAt: $checkedAt, approvalHistory: $approvalHistory)';
}


}

/// @nodoc
abstract mixin class $ChecklistItemDataCopyWith<$Res>  {
  factory $ChecklistItemDataCopyWith(ChecklistItemData value, $Res Function(ChecklistItemData) _then) = _$ChecklistItemDataCopyWithImpl;
@useResult
$Res call({
 String title, bool isChecked, List<String> linkedChecklists, bool isArchived, String? id,@JsonKey(unknownEnumValue: ChangeSource.user) ChangeSource checkedBy, DateTime? checkedAt, List<ChecklistItemProvenance> approvalHistory
});




}
/// @nodoc
class _$ChecklistItemDataCopyWithImpl<$Res>
    implements $ChecklistItemDataCopyWith<$Res> {
  _$ChecklistItemDataCopyWithImpl(this._self, this._then);

  final ChecklistItemData _self;
  final $Res Function(ChecklistItemData) _then;

/// Create a copy of ChecklistItemData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? isChecked = null,Object? linkedChecklists = null,Object? isArchived = null,Object? id = freezed,Object? checkedBy = null,Object? checkedAt = freezed,Object? approvalHistory = null,}) {
  return _then(_self.copyWith(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,isChecked: null == isChecked ? _self.isChecked : isChecked // ignore: cast_nullable_to_non_nullable
as bool,linkedChecklists: null == linkedChecklists ? _self.linkedChecklists : linkedChecklists // ignore: cast_nullable_to_non_nullable
as List<String>,isArchived: null == isArchived ? _self.isArchived : isArchived // ignore: cast_nullable_to_non_nullable
as bool,id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,checkedBy: null == checkedBy ? _self.checkedBy : checkedBy // ignore: cast_nullable_to_non_nullable
as ChangeSource,checkedAt: freezed == checkedAt ? _self.checkedAt : checkedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,approvalHistory: null == approvalHistory ? _self.approvalHistory : approvalHistory // ignore: cast_nullable_to_non_nullable
as List<ChecklistItemProvenance>,
  ));
}

}


/// Adds pattern-matching-related methods to [ChecklistItemData].
extension ChecklistItemDataPatterns on ChecklistItemData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChecklistItemData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChecklistItemData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChecklistItemData value)  $default,){
final _that = this;
switch (_that) {
case _ChecklistItemData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChecklistItemData value)?  $default,){
final _that = this;
switch (_that) {
case _ChecklistItemData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String title,  bool isChecked,  List<String> linkedChecklists,  bool isArchived,  String? id, @JsonKey(unknownEnumValue: ChangeSource.user)  ChangeSource checkedBy,  DateTime? checkedAt,  List<ChecklistItemProvenance> approvalHistory)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChecklistItemData() when $default != null:
return $default(_that.title,_that.isChecked,_that.linkedChecklists,_that.isArchived,_that.id,_that.checkedBy,_that.checkedAt,_that.approvalHistory);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String title,  bool isChecked,  List<String> linkedChecklists,  bool isArchived,  String? id, @JsonKey(unknownEnumValue: ChangeSource.user)  ChangeSource checkedBy,  DateTime? checkedAt,  List<ChecklistItemProvenance> approvalHistory)  $default,) {final _that = this;
switch (_that) {
case _ChecklistItemData():
return $default(_that.title,_that.isChecked,_that.linkedChecklists,_that.isArchived,_that.id,_that.checkedBy,_that.checkedAt,_that.approvalHistory);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String title,  bool isChecked,  List<String> linkedChecklists,  bool isArchived,  String? id, @JsonKey(unknownEnumValue: ChangeSource.user)  ChangeSource checkedBy,  DateTime? checkedAt,  List<ChecklistItemProvenance> approvalHistory)?  $default,) {final _that = this;
switch (_that) {
case _ChecklistItemData() when $default != null:
return $default(_that.title,_that.isChecked,_that.linkedChecklists,_that.isArchived,_that.id,_that.checkedBy,_that.checkedAt,_that.approvalHistory);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChecklistItemData extends ChecklistItemData {
  const _ChecklistItemData({required this.title, required this.isChecked, required final  List<String> linkedChecklists, this.isArchived = false, this.id, @JsonKey(unknownEnumValue: ChangeSource.user) this.checkedBy = ChangeSource.user, this.checkedAt, final  List<ChecklistItemProvenance> approvalHistory = const []}): _linkedChecklists = linkedChecklists,_approvalHistory = approvalHistory,super._();
  factory _ChecklistItemData.fromJson(Map<String, dynamic> json) => _$ChecklistItemDataFromJson(json);

@override final  String title;
@override final  bool isChecked;
 final  List<String> _linkedChecklists;
@override List<String> get linkedChecklists {
  if (_linkedChecklists is EqualUnmodifiableListView) return _linkedChecklists;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_linkedChecklists);
}

@override@JsonKey() final  bool isArchived;
@override final  String? id;
@override@JsonKey(unknownEnumValue: ChangeSource.user) final  ChangeSource checkedBy;
@override final  DateTime? checkedAt;
 final  List<ChecklistItemProvenance> _approvalHistory;
@override@JsonKey() List<ChecklistItemProvenance> get approvalHistory {
  if (_approvalHistory is EqualUnmodifiableListView) return _approvalHistory;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_approvalHistory);
}


/// Create a copy of ChecklistItemData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChecklistItemDataCopyWith<_ChecklistItemData> get copyWith => __$ChecklistItemDataCopyWithImpl<_ChecklistItemData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChecklistItemDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChecklistItemData&&(identical(other.title, title) || other.title == title)&&(identical(other.isChecked, isChecked) || other.isChecked == isChecked)&&const DeepCollectionEquality().equals(other._linkedChecklists, _linkedChecklists)&&(identical(other.isArchived, isArchived) || other.isArchived == isArchived)&&(identical(other.id, id) || other.id == id)&&(identical(other.checkedBy, checkedBy) || other.checkedBy == checkedBy)&&(identical(other.checkedAt, checkedAt) || other.checkedAt == checkedAt)&&const DeepCollectionEquality().equals(other._approvalHistory, _approvalHistory));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,isChecked,const DeepCollectionEquality().hash(_linkedChecklists),isArchived,id,checkedBy,checkedAt,const DeepCollectionEquality().hash(_approvalHistory));

@override
String toString() {
  return 'ChecklistItemData(title: $title, isChecked: $isChecked, linkedChecklists: $linkedChecklists, isArchived: $isArchived, id: $id, checkedBy: $checkedBy, checkedAt: $checkedAt, approvalHistory: $approvalHistory)';
}


}

/// @nodoc
abstract mixin class _$ChecklistItemDataCopyWith<$Res> implements $ChecklistItemDataCopyWith<$Res> {
  factory _$ChecklistItemDataCopyWith(_ChecklistItemData value, $Res Function(_ChecklistItemData) _then) = __$ChecklistItemDataCopyWithImpl;
@override @useResult
$Res call({
 String title, bool isChecked, List<String> linkedChecklists, bool isArchived, String? id,@JsonKey(unknownEnumValue: ChangeSource.user) ChangeSource checkedBy, DateTime? checkedAt, List<ChecklistItemProvenance> approvalHistory
});




}
/// @nodoc
class __$ChecklistItemDataCopyWithImpl<$Res>
    implements _$ChecklistItemDataCopyWith<$Res> {
  __$ChecklistItemDataCopyWithImpl(this._self, this._then);

  final _ChecklistItemData _self;
  final $Res Function(_ChecklistItemData) _then;

/// Create a copy of ChecklistItemData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? isChecked = null,Object? linkedChecklists = null,Object? isArchived = null,Object? id = freezed,Object? checkedBy = null,Object? checkedAt = freezed,Object? approvalHistory = null,}) {
  return _then(_ChecklistItemData(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,isChecked: null == isChecked ? _self.isChecked : isChecked // ignore: cast_nullable_to_non_nullable
as bool,linkedChecklists: null == linkedChecklists ? _self._linkedChecklists : linkedChecklists // ignore: cast_nullable_to_non_nullable
as List<String>,isArchived: null == isArchived ? _self.isArchived : isArchived // ignore: cast_nullable_to_non_nullable
as bool,id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,checkedBy: null == checkedBy ? _self.checkedBy : checkedBy // ignore: cast_nullable_to_non_nullable
as ChangeSource,checkedAt: freezed == checkedAt ? _self.checkedAt : checkedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,approvalHistory: null == approvalHistory ? _self._approvalHistory : approvalHistory // ignore: cast_nullable_to_non_nullable
as List<ChecklistItemProvenance>,
  ));
}


}


/// @nodoc
mixin _$ChecklistItemProvenance {

 String get approvedBy; String get approvalHost; DateTime get approvedAt; ChecklistApprovalMode get approvalMode; String get originatingMessageId; String get conversationId; String get changeSetId; String get decisionId; String get agentId; String get source; String get appliedBy; bool? get isChecked;
/// Create a copy of ChecklistItemProvenance
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChecklistItemProvenanceCopyWith<ChecklistItemProvenance> get copyWith => _$ChecklistItemProvenanceCopyWithImpl<ChecklistItemProvenance>(this as ChecklistItemProvenance, _$identity);

  /// Serializes this ChecklistItemProvenance to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChecklistItemProvenance&&(identical(other.approvedBy, approvedBy) || other.approvedBy == approvedBy)&&(identical(other.approvalHost, approvalHost) || other.approvalHost == approvalHost)&&(identical(other.approvedAt, approvedAt) || other.approvedAt == approvedAt)&&(identical(other.approvalMode, approvalMode) || other.approvalMode == approvalMode)&&(identical(other.originatingMessageId, originatingMessageId) || other.originatingMessageId == originatingMessageId)&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.changeSetId, changeSetId) || other.changeSetId == changeSetId)&&(identical(other.decisionId, decisionId) || other.decisionId == decisionId)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.source, source) || other.source == source)&&(identical(other.appliedBy, appliedBy) || other.appliedBy == appliedBy)&&(identical(other.isChecked, isChecked) || other.isChecked == isChecked));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,approvedBy,approvalHost,approvedAt,approvalMode,originatingMessageId,conversationId,changeSetId,decisionId,agentId,source,appliedBy,isChecked);

@override
String toString() {
  return 'ChecklistItemProvenance(approvedBy: $approvedBy, approvalHost: $approvalHost, approvedAt: $approvedAt, approvalMode: $approvalMode, originatingMessageId: $originatingMessageId, conversationId: $conversationId, changeSetId: $changeSetId, decisionId: $decisionId, agentId: $agentId, source: $source, appliedBy: $appliedBy, isChecked: $isChecked)';
}


}

/// @nodoc
abstract mixin class $ChecklistItemProvenanceCopyWith<$Res>  {
  factory $ChecklistItemProvenanceCopyWith(ChecklistItemProvenance value, $Res Function(ChecklistItemProvenance) _then) = _$ChecklistItemProvenanceCopyWithImpl;
@useResult
$Res call({
 String approvedBy, String approvalHost, DateTime approvedAt, ChecklistApprovalMode approvalMode, String originatingMessageId, String conversationId, String changeSetId, String decisionId, String agentId, String source, String appliedBy, bool? isChecked
});




}
/// @nodoc
class _$ChecklistItemProvenanceCopyWithImpl<$Res>
    implements $ChecklistItemProvenanceCopyWith<$Res> {
  _$ChecklistItemProvenanceCopyWithImpl(this._self, this._then);

  final ChecklistItemProvenance _self;
  final $Res Function(ChecklistItemProvenance) _then;

/// Create a copy of ChecklistItemProvenance
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? approvedBy = null,Object? approvalHost = null,Object? approvedAt = null,Object? approvalMode = null,Object? originatingMessageId = null,Object? conversationId = null,Object? changeSetId = null,Object? decisionId = null,Object? agentId = null,Object? source = null,Object? appliedBy = null,Object? isChecked = freezed,}) {
  return _then(_self.copyWith(
approvedBy: null == approvedBy ? _self.approvedBy : approvedBy // ignore: cast_nullable_to_non_nullable
as String,approvalHost: null == approvalHost ? _self.approvalHost : approvalHost // ignore: cast_nullable_to_non_nullable
as String,approvedAt: null == approvedAt ? _self.approvedAt : approvedAt // ignore: cast_nullable_to_non_nullable
as DateTime,approvalMode: null == approvalMode ? _self.approvalMode : approvalMode // ignore: cast_nullable_to_non_nullable
as ChecklistApprovalMode,originatingMessageId: null == originatingMessageId ? _self.originatingMessageId : originatingMessageId // ignore: cast_nullable_to_non_nullable
as String,conversationId: null == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as String,changeSetId: null == changeSetId ? _self.changeSetId : changeSetId // ignore: cast_nullable_to_non_nullable
as String,decisionId: null == decisionId ? _self.decisionId : decisionId // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,appliedBy: null == appliedBy ? _self.appliedBy : appliedBy // ignore: cast_nullable_to_non_nullable
as String,isChecked: freezed == isChecked ? _self.isChecked : isChecked // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}


/// Adds pattern-matching-related methods to [ChecklistItemProvenance].
extension ChecklistItemProvenancePatterns on ChecklistItemProvenance {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChecklistItemProvenance value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChecklistItemProvenance() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChecklistItemProvenance value)  $default,){
final _that = this;
switch (_that) {
case _ChecklistItemProvenance():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChecklistItemProvenance value)?  $default,){
final _that = this;
switch (_that) {
case _ChecklistItemProvenance() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String approvedBy,  String approvalHost,  DateTime approvedAt,  ChecklistApprovalMode approvalMode,  String originatingMessageId,  String conversationId,  String changeSetId,  String decisionId,  String agentId,  String source,  String appliedBy,  bool? isChecked)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChecklistItemProvenance() when $default != null:
return $default(_that.approvedBy,_that.approvalHost,_that.approvedAt,_that.approvalMode,_that.originatingMessageId,_that.conversationId,_that.changeSetId,_that.decisionId,_that.agentId,_that.source,_that.appliedBy,_that.isChecked);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String approvedBy,  String approvalHost,  DateTime approvedAt,  ChecklistApprovalMode approvalMode,  String originatingMessageId,  String conversationId,  String changeSetId,  String decisionId,  String agentId,  String source,  String appliedBy,  bool? isChecked)  $default,) {final _that = this;
switch (_that) {
case _ChecklistItemProvenance():
return $default(_that.approvedBy,_that.approvalHost,_that.approvedAt,_that.approvalMode,_that.originatingMessageId,_that.conversationId,_that.changeSetId,_that.decisionId,_that.agentId,_that.source,_that.appliedBy,_that.isChecked);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String approvedBy,  String approvalHost,  DateTime approvedAt,  ChecklistApprovalMode approvalMode,  String originatingMessageId,  String conversationId,  String changeSetId,  String decisionId,  String agentId,  String source,  String appliedBy,  bool? isChecked)?  $default,) {final _that = this;
switch (_that) {
case _ChecklistItemProvenance() when $default != null:
return $default(_that.approvedBy,_that.approvalHost,_that.approvedAt,_that.approvalMode,_that.originatingMessageId,_that.conversationId,_that.changeSetId,_that.decisionId,_that.agentId,_that.source,_that.appliedBy,_that.isChecked);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChecklistItemProvenance implements ChecklistItemProvenance {
  const _ChecklistItemProvenance({required this.approvedBy, required this.approvalHost, required this.approvedAt, required this.approvalMode, required this.originatingMessageId, required this.conversationId, required this.changeSetId, required this.decisionId, required this.agentId, this.source = 'chat_suggestion', this.appliedBy = 'task_agent', this.isChecked});
  factory _ChecklistItemProvenance.fromJson(Map<String, dynamic> json) => _$ChecklistItemProvenanceFromJson(json);

@override final  String approvedBy;
@override final  String approvalHost;
@override final  DateTime approvedAt;
@override final  ChecklistApprovalMode approvalMode;
@override final  String originatingMessageId;
@override final  String conversationId;
@override final  String changeSetId;
@override final  String decisionId;
@override final  String agentId;
@override@JsonKey() final  String source;
@override@JsonKey() final  String appliedBy;
@override final  bool? isChecked;

/// Create a copy of ChecklistItemProvenance
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChecklistItemProvenanceCopyWith<_ChecklistItemProvenance> get copyWith => __$ChecklistItemProvenanceCopyWithImpl<_ChecklistItemProvenance>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChecklistItemProvenanceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChecklistItemProvenance&&(identical(other.approvedBy, approvedBy) || other.approvedBy == approvedBy)&&(identical(other.approvalHost, approvalHost) || other.approvalHost == approvalHost)&&(identical(other.approvedAt, approvedAt) || other.approvedAt == approvedAt)&&(identical(other.approvalMode, approvalMode) || other.approvalMode == approvalMode)&&(identical(other.originatingMessageId, originatingMessageId) || other.originatingMessageId == originatingMessageId)&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.changeSetId, changeSetId) || other.changeSetId == changeSetId)&&(identical(other.decisionId, decisionId) || other.decisionId == decisionId)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.source, source) || other.source == source)&&(identical(other.appliedBy, appliedBy) || other.appliedBy == appliedBy)&&(identical(other.isChecked, isChecked) || other.isChecked == isChecked));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,approvedBy,approvalHost,approvedAt,approvalMode,originatingMessageId,conversationId,changeSetId,decisionId,agentId,source,appliedBy,isChecked);

@override
String toString() {
  return 'ChecklistItemProvenance(approvedBy: $approvedBy, approvalHost: $approvalHost, approvedAt: $approvedAt, approvalMode: $approvalMode, originatingMessageId: $originatingMessageId, conversationId: $conversationId, changeSetId: $changeSetId, decisionId: $decisionId, agentId: $agentId, source: $source, appliedBy: $appliedBy, isChecked: $isChecked)';
}


}

/// @nodoc
abstract mixin class _$ChecklistItemProvenanceCopyWith<$Res> implements $ChecklistItemProvenanceCopyWith<$Res> {
  factory _$ChecklistItemProvenanceCopyWith(_ChecklistItemProvenance value, $Res Function(_ChecklistItemProvenance) _then) = __$ChecklistItemProvenanceCopyWithImpl;
@override @useResult
$Res call({
 String approvedBy, String approvalHost, DateTime approvedAt, ChecklistApprovalMode approvalMode, String originatingMessageId, String conversationId, String changeSetId, String decisionId, String agentId, String source, String appliedBy, bool? isChecked
});




}
/// @nodoc
class __$ChecklistItemProvenanceCopyWithImpl<$Res>
    implements _$ChecklistItemProvenanceCopyWith<$Res> {
  __$ChecklistItemProvenanceCopyWithImpl(this._self, this._then);

  final _ChecklistItemProvenance _self;
  final $Res Function(_ChecklistItemProvenance) _then;

/// Create a copy of ChecklistItemProvenance
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? approvedBy = null,Object? approvalHost = null,Object? approvedAt = null,Object? approvalMode = null,Object? originatingMessageId = null,Object? conversationId = null,Object? changeSetId = null,Object? decisionId = null,Object? agentId = null,Object? source = null,Object? appliedBy = null,Object? isChecked = freezed,}) {
  return _then(_ChecklistItemProvenance(
approvedBy: null == approvedBy ? _self.approvedBy : approvedBy // ignore: cast_nullable_to_non_nullable
as String,approvalHost: null == approvalHost ? _self.approvalHost : approvalHost // ignore: cast_nullable_to_non_nullable
as String,approvedAt: null == approvedAt ? _self.approvedAt : approvedAt // ignore: cast_nullable_to_non_nullable
as DateTime,approvalMode: null == approvalMode ? _self.approvalMode : approvalMode // ignore: cast_nullable_to_non_nullable
as ChecklistApprovalMode,originatingMessageId: null == originatingMessageId ? _self.originatingMessageId : originatingMessageId // ignore: cast_nullable_to_non_nullable
as String,conversationId: null == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as String,changeSetId: null == changeSetId ? _self.changeSetId : changeSetId // ignore: cast_nullable_to_non_nullable
as String,decisionId: null == decisionId ? _self.decisionId : decisionId // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,appliedBy: null == appliedBy ? _self.appliedBy : appliedBy // ignore: cast_nullable_to_non_nullable
as String,isChecked: freezed == isChecked ? _self.isChecked : isChecked // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}

// dart format on
