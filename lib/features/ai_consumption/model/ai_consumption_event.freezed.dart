// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ai_consumption_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AiConsumptionEvent {

/// Globally-unique id (uuid), minted once at capture time.
 String get id;/// When the backend call happened.
 DateTime get createdAt;/// Which backend provider served the call.
 InferenceProviderType get providerType;/// What kind of call this was.
 AiConsumptionResponseType get responseType;/// CRDT clock stamped by the sync-aware write path; null until stamped.
 VectorClock? get vectorClock;/// The causal parent call/context ("the call that made it"). For agent
/// turns this is the wake's run key; top-level single calls leave it null.
 String? get parentId;// ── Denormalized owners (snapshot at call time) ──────────────────────────
 String? get taskId; String? get categoryId; String? get entryId; String? get agentId; String? get wakeRunKey; String? get threadId; int? get turnIndex; String? get promptId; String? get skillId; String? get configId;// ── Provider / model / timing ────────────────────────────────────────────
 String? get modelId; String? get providerModelId; int? get durationMs;// ── Token metrics ────────────────────────────────────────────────────────
 int? get inputTokens; int? get outputTokens; int? get cachedInputTokens; int? get thoughtsTokens; int? get totalTokens;// ── Cost + environmental impact (Melious-only; null elsewhere) ───────────
/// Billing cost in Melious credits (≈ EUR).
 double? get credits;/// Energy in kilowatt-hours, as delivered by Melious.
 double? get energyKwh;/// Carbon in grams of CO₂, as delivered by Melious.
 double? get carbonGCo2;/// Water in litres, as delivered by Melious.
 double? get waterLiters;/// Percentage of the serving data centre's energy from renewables (0–100).
 double? get renewablePercent;/// Power-usage-effectiveness of the serving data centre.
 double? get pue;/// The serving data-centre location (Melious `location`, e.g. `"FI"`).
 String? get dataCenter;/// The upstream provider that actually served the call (Melious
/// `provider_id`).
 String? get upstreamProviderId;
/// Create a copy of AiConsumptionEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiConsumptionEventCopyWith<AiConsumptionEvent> get copyWith => _$AiConsumptionEventCopyWithImpl<AiConsumptionEvent>(this as AiConsumptionEvent, _$identity);

  /// Serializes this AiConsumptionEvent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiConsumptionEvent&&(identical(other.id, id) || other.id == id)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.providerType, providerType) || other.providerType == providerType)&&(identical(other.responseType, responseType) || other.responseType == responseType)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.entryId, entryId) || other.entryId == entryId)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.wakeRunKey, wakeRunKey) || other.wakeRunKey == wakeRunKey)&&(identical(other.threadId, threadId) || other.threadId == threadId)&&(identical(other.turnIndex, turnIndex) || other.turnIndex == turnIndex)&&(identical(other.promptId, promptId) || other.promptId == promptId)&&(identical(other.skillId, skillId) || other.skillId == skillId)&&(identical(other.configId, configId) || other.configId == configId)&&(identical(other.modelId, modelId) || other.modelId == modelId)&&(identical(other.providerModelId, providerModelId) || other.providerModelId == providerModelId)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&(identical(other.inputTokens, inputTokens) || other.inputTokens == inputTokens)&&(identical(other.outputTokens, outputTokens) || other.outputTokens == outputTokens)&&(identical(other.cachedInputTokens, cachedInputTokens) || other.cachedInputTokens == cachedInputTokens)&&(identical(other.thoughtsTokens, thoughtsTokens) || other.thoughtsTokens == thoughtsTokens)&&(identical(other.totalTokens, totalTokens) || other.totalTokens == totalTokens)&&(identical(other.credits, credits) || other.credits == credits)&&(identical(other.energyKwh, energyKwh) || other.energyKwh == energyKwh)&&(identical(other.carbonGCo2, carbonGCo2) || other.carbonGCo2 == carbonGCo2)&&(identical(other.waterLiters, waterLiters) || other.waterLiters == waterLiters)&&(identical(other.renewablePercent, renewablePercent) || other.renewablePercent == renewablePercent)&&(identical(other.pue, pue) || other.pue == pue)&&(identical(other.dataCenter, dataCenter) || other.dataCenter == dataCenter)&&(identical(other.upstreamProviderId, upstreamProviderId) || other.upstreamProviderId == upstreamProviderId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,createdAt,providerType,responseType,vectorClock,parentId,taskId,categoryId,entryId,agentId,wakeRunKey,threadId,turnIndex,promptId,skillId,configId,modelId,providerModelId,durationMs,inputTokens,outputTokens,cachedInputTokens,thoughtsTokens,totalTokens,credits,energyKwh,carbonGCo2,waterLiters,renewablePercent,pue,dataCenter,upstreamProviderId]);

@override
String toString() {
  return 'AiConsumptionEvent(id: $id, createdAt: $createdAt, providerType: $providerType, responseType: $responseType, vectorClock: $vectorClock, parentId: $parentId, taskId: $taskId, categoryId: $categoryId, entryId: $entryId, agentId: $agentId, wakeRunKey: $wakeRunKey, threadId: $threadId, turnIndex: $turnIndex, promptId: $promptId, skillId: $skillId, configId: $configId, modelId: $modelId, providerModelId: $providerModelId, durationMs: $durationMs, inputTokens: $inputTokens, outputTokens: $outputTokens, cachedInputTokens: $cachedInputTokens, thoughtsTokens: $thoughtsTokens, totalTokens: $totalTokens, credits: $credits, energyKwh: $energyKwh, carbonGCo2: $carbonGCo2, waterLiters: $waterLiters, renewablePercent: $renewablePercent, pue: $pue, dataCenter: $dataCenter, upstreamProviderId: $upstreamProviderId)';
}


}

/// @nodoc
abstract mixin class $AiConsumptionEventCopyWith<$Res>  {
  factory $AiConsumptionEventCopyWith(AiConsumptionEvent value, $Res Function(AiConsumptionEvent) _then) = _$AiConsumptionEventCopyWithImpl;
@useResult
$Res call({
 String id, DateTime createdAt, InferenceProviderType providerType, AiConsumptionResponseType responseType, VectorClock? vectorClock, String? parentId, String? taskId, String? categoryId, String? entryId, String? agentId, String? wakeRunKey, String? threadId, int? turnIndex, String? promptId, String? skillId, String? configId, String? modelId, String? providerModelId, int? durationMs, int? inputTokens, int? outputTokens, int? cachedInputTokens, int? thoughtsTokens, int? totalTokens, double? credits, double? energyKwh, double? carbonGCo2, double? waterLiters, double? renewablePercent, double? pue, String? dataCenter, String? upstreamProviderId
});




}
/// @nodoc
class _$AiConsumptionEventCopyWithImpl<$Res>
    implements $AiConsumptionEventCopyWith<$Res> {
  _$AiConsumptionEventCopyWithImpl(this._self, this._then);

  final AiConsumptionEvent _self;
  final $Res Function(AiConsumptionEvent) _then;

/// Create a copy of AiConsumptionEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? createdAt = null,Object? providerType = null,Object? responseType = null,Object? vectorClock = freezed,Object? parentId = freezed,Object? taskId = freezed,Object? categoryId = freezed,Object? entryId = freezed,Object? agentId = freezed,Object? wakeRunKey = freezed,Object? threadId = freezed,Object? turnIndex = freezed,Object? promptId = freezed,Object? skillId = freezed,Object? configId = freezed,Object? modelId = freezed,Object? providerModelId = freezed,Object? durationMs = freezed,Object? inputTokens = freezed,Object? outputTokens = freezed,Object? cachedInputTokens = freezed,Object? thoughtsTokens = freezed,Object? totalTokens = freezed,Object? credits = freezed,Object? energyKwh = freezed,Object? carbonGCo2 = freezed,Object? waterLiters = freezed,Object? renewablePercent = freezed,Object? pue = freezed,Object? dataCenter = freezed,Object? upstreamProviderId = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,providerType: null == providerType ? _self.providerType : providerType // ignore: cast_nullable_to_non_nullable
as InferenceProviderType,responseType: null == responseType ? _self.responseType : responseType // ignore: cast_nullable_to_non_nullable
as AiConsumptionResponseType,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,taskId: freezed == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String?,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,entryId: freezed == entryId ? _self.entryId : entryId // ignore: cast_nullable_to_non_nullable
as String?,agentId: freezed == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String?,wakeRunKey: freezed == wakeRunKey ? _self.wakeRunKey : wakeRunKey // ignore: cast_nullable_to_non_nullable
as String?,threadId: freezed == threadId ? _self.threadId : threadId // ignore: cast_nullable_to_non_nullable
as String?,turnIndex: freezed == turnIndex ? _self.turnIndex : turnIndex // ignore: cast_nullable_to_non_nullable
as int?,promptId: freezed == promptId ? _self.promptId : promptId // ignore: cast_nullable_to_non_nullable
as String?,skillId: freezed == skillId ? _self.skillId : skillId // ignore: cast_nullable_to_non_nullable
as String?,configId: freezed == configId ? _self.configId : configId // ignore: cast_nullable_to_non_nullable
as String?,modelId: freezed == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String?,providerModelId: freezed == providerModelId ? _self.providerModelId : providerModelId // ignore: cast_nullable_to_non_nullable
as String?,durationMs: freezed == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int?,inputTokens: freezed == inputTokens ? _self.inputTokens : inputTokens // ignore: cast_nullable_to_non_nullable
as int?,outputTokens: freezed == outputTokens ? _self.outputTokens : outputTokens // ignore: cast_nullable_to_non_nullable
as int?,cachedInputTokens: freezed == cachedInputTokens ? _self.cachedInputTokens : cachedInputTokens // ignore: cast_nullable_to_non_nullable
as int?,thoughtsTokens: freezed == thoughtsTokens ? _self.thoughtsTokens : thoughtsTokens // ignore: cast_nullable_to_non_nullable
as int?,totalTokens: freezed == totalTokens ? _self.totalTokens : totalTokens // ignore: cast_nullable_to_non_nullable
as int?,credits: freezed == credits ? _self.credits : credits // ignore: cast_nullable_to_non_nullable
as double?,energyKwh: freezed == energyKwh ? _self.energyKwh : energyKwh // ignore: cast_nullable_to_non_nullable
as double?,carbonGCo2: freezed == carbonGCo2 ? _self.carbonGCo2 : carbonGCo2 // ignore: cast_nullable_to_non_nullable
as double?,waterLiters: freezed == waterLiters ? _self.waterLiters : waterLiters // ignore: cast_nullable_to_non_nullable
as double?,renewablePercent: freezed == renewablePercent ? _self.renewablePercent : renewablePercent // ignore: cast_nullable_to_non_nullable
as double?,pue: freezed == pue ? _self.pue : pue // ignore: cast_nullable_to_non_nullable
as double?,dataCenter: freezed == dataCenter ? _self.dataCenter : dataCenter // ignore: cast_nullable_to_non_nullable
as String?,upstreamProviderId: freezed == upstreamProviderId ? _self.upstreamProviderId : upstreamProviderId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AiConsumptionEvent].
extension AiConsumptionEventPatterns on AiConsumptionEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiConsumptionEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiConsumptionEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiConsumptionEvent value)  $default,){
final _that = this;
switch (_that) {
case _AiConsumptionEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiConsumptionEvent value)?  $default,){
final _that = this;
switch (_that) {
case _AiConsumptionEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  DateTime createdAt,  InferenceProviderType providerType,  AiConsumptionResponseType responseType,  VectorClock? vectorClock,  String? parentId,  String? taskId,  String? categoryId,  String? entryId,  String? agentId,  String? wakeRunKey,  String? threadId,  int? turnIndex,  String? promptId,  String? skillId,  String? configId,  String? modelId,  String? providerModelId,  int? durationMs,  int? inputTokens,  int? outputTokens,  int? cachedInputTokens,  int? thoughtsTokens,  int? totalTokens,  double? credits,  double? energyKwh,  double? carbonGCo2,  double? waterLiters,  double? renewablePercent,  double? pue,  String? dataCenter,  String? upstreamProviderId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiConsumptionEvent() when $default != null:
return $default(_that.id,_that.createdAt,_that.providerType,_that.responseType,_that.vectorClock,_that.parentId,_that.taskId,_that.categoryId,_that.entryId,_that.agentId,_that.wakeRunKey,_that.threadId,_that.turnIndex,_that.promptId,_that.skillId,_that.configId,_that.modelId,_that.providerModelId,_that.durationMs,_that.inputTokens,_that.outputTokens,_that.cachedInputTokens,_that.thoughtsTokens,_that.totalTokens,_that.credits,_that.energyKwh,_that.carbonGCo2,_that.waterLiters,_that.renewablePercent,_that.pue,_that.dataCenter,_that.upstreamProviderId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  DateTime createdAt,  InferenceProviderType providerType,  AiConsumptionResponseType responseType,  VectorClock? vectorClock,  String? parentId,  String? taskId,  String? categoryId,  String? entryId,  String? agentId,  String? wakeRunKey,  String? threadId,  int? turnIndex,  String? promptId,  String? skillId,  String? configId,  String? modelId,  String? providerModelId,  int? durationMs,  int? inputTokens,  int? outputTokens,  int? cachedInputTokens,  int? thoughtsTokens,  int? totalTokens,  double? credits,  double? energyKwh,  double? carbonGCo2,  double? waterLiters,  double? renewablePercent,  double? pue,  String? dataCenter,  String? upstreamProviderId)  $default,) {final _that = this;
switch (_that) {
case _AiConsumptionEvent():
return $default(_that.id,_that.createdAt,_that.providerType,_that.responseType,_that.vectorClock,_that.parentId,_that.taskId,_that.categoryId,_that.entryId,_that.agentId,_that.wakeRunKey,_that.threadId,_that.turnIndex,_that.promptId,_that.skillId,_that.configId,_that.modelId,_that.providerModelId,_that.durationMs,_that.inputTokens,_that.outputTokens,_that.cachedInputTokens,_that.thoughtsTokens,_that.totalTokens,_that.credits,_that.energyKwh,_that.carbonGCo2,_that.waterLiters,_that.renewablePercent,_that.pue,_that.dataCenter,_that.upstreamProviderId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  DateTime createdAt,  InferenceProviderType providerType,  AiConsumptionResponseType responseType,  VectorClock? vectorClock,  String? parentId,  String? taskId,  String? categoryId,  String? entryId,  String? agentId,  String? wakeRunKey,  String? threadId,  int? turnIndex,  String? promptId,  String? skillId,  String? configId,  String? modelId,  String? providerModelId,  int? durationMs,  int? inputTokens,  int? outputTokens,  int? cachedInputTokens,  int? thoughtsTokens,  int? totalTokens,  double? credits,  double? energyKwh,  double? carbonGCo2,  double? waterLiters,  double? renewablePercent,  double? pue,  String? dataCenter,  String? upstreamProviderId)?  $default,) {final _that = this;
switch (_that) {
case _AiConsumptionEvent() when $default != null:
return $default(_that.id,_that.createdAt,_that.providerType,_that.responseType,_that.vectorClock,_that.parentId,_that.taskId,_that.categoryId,_that.entryId,_that.agentId,_that.wakeRunKey,_that.threadId,_that.turnIndex,_that.promptId,_that.skillId,_that.configId,_that.modelId,_that.providerModelId,_that.durationMs,_that.inputTokens,_that.outputTokens,_that.cachedInputTokens,_that.thoughtsTokens,_that.totalTokens,_that.credits,_that.energyKwh,_that.carbonGCo2,_that.waterLiters,_that.renewablePercent,_that.pue,_that.dataCenter,_that.upstreamProviderId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AiConsumptionEvent implements AiConsumptionEvent {
  const _AiConsumptionEvent({required this.id, required this.createdAt, required this.providerType, required this.responseType, required this.vectorClock, this.parentId, this.taskId, this.categoryId, this.entryId, this.agentId, this.wakeRunKey, this.threadId, this.turnIndex, this.promptId, this.skillId, this.configId, this.modelId, this.providerModelId, this.durationMs, this.inputTokens, this.outputTokens, this.cachedInputTokens, this.thoughtsTokens, this.totalTokens, this.credits, this.energyKwh, this.carbonGCo2, this.waterLiters, this.renewablePercent, this.pue, this.dataCenter, this.upstreamProviderId});
  factory _AiConsumptionEvent.fromJson(Map<String, dynamic> json) => _$AiConsumptionEventFromJson(json);

/// Globally-unique id (uuid), minted once at capture time.
@override final  String id;
/// When the backend call happened.
@override final  DateTime createdAt;
/// Which backend provider served the call.
@override final  InferenceProviderType providerType;
/// What kind of call this was.
@override final  AiConsumptionResponseType responseType;
/// CRDT clock stamped by the sync-aware write path; null until stamped.
@override final  VectorClock? vectorClock;
/// The causal parent call/context ("the call that made it"). For agent
/// turns this is the wake's run key; top-level single calls leave it null.
@override final  String? parentId;
// ── Denormalized owners (snapshot at call time) ──────────────────────────
@override final  String? taskId;
@override final  String? categoryId;
@override final  String? entryId;
@override final  String? agentId;
@override final  String? wakeRunKey;
@override final  String? threadId;
@override final  int? turnIndex;
@override final  String? promptId;
@override final  String? skillId;
@override final  String? configId;
// ── Provider / model / timing ────────────────────────────────────────────
@override final  String? modelId;
@override final  String? providerModelId;
@override final  int? durationMs;
// ── Token metrics ────────────────────────────────────────────────────────
@override final  int? inputTokens;
@override final  int? outputTokens;
@override final  int? cachedInputTokens;
@override final  int? thoughtsTokens;
@override final  int? totalTokens;
// ── Cost + environmental impact (Melious-only; null elsewhere) ───────────
/// Billing cost in Melious credits (≈ EUR).
@override final  double? credits;
/// Energy in kilowatt-hours, as delivered by Melious.
@override final  double? energyKwh;
/// Carbon in grams of CO₂, as delivered by Melious.
@override final  double? carbonGCo2;
/// Water in litres, as delivered by Melious.
@override final  double? waterLiters;
/// Percentage of the serving data centre's energy from renewables (0–100).
@override final  double? renewablePercent;
/// Power-usage-effectiveness of the serving data centre.
@override final  double? pue;
/// The serving data-centre location (Melious `location`, e.g. `"FI"`).
@override final  String? dataCenter;
/// The upstream provider that actually served the call (Melious
/// `provider_id`).
@override final  String? upstreamProviderId;

/// Create a copy of AiConsumptionEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiConsumptionEventCopyWith<_AiConsumptionEvent> get copyWith => __$AiConsumptionEventCopyWithImpl<_AiConsumptionEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AiConsumptionEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiConsumptionEvent&&(identical(other.id, id) || other.id == id)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.providerType, providerType) || other.providerType == providerType)&&(identical(other.responseType, responseType) || other.responseType == responseType)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.entryId, entryId) || other.entryId == entryId)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.wakeRunKey, wakeRunKey) || other.wakeRunKey == wakeRunKey)&&(identical(other.threadId, threadId) || other.threadId == threadId)&&(identical(other.turnIndex, turnIndex) || other.turnIndex == turnIndex)&&(identical(other.promptId, promptId) || other.promptId == promptId)&&(identical(other.skillId, skillId) || other.skillId == skillId)&&(identical(other.configId, configId) || other.configId == configId)&&(identical(other.modelId, modelId) || other.modelId == modelId)&&(identical(other.providerModelId, providerModelId) || other.providerModelId == providerModelId)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&(identical(other.inputTokens, inputTokens) || other.inputTokens == inputTokens)&&(identical(other.outputTokens, outputTokens) || other.outputTokens == outputTokens)&&(identical(other.cachedInputTokens, cachedInputTokens) || other.cachedInputTokens == cachedInputTokens)&&(identical(other.thoughtsTokens, thoughtsTokens) || other.thoughtsTokens == thoughtsTokens)&&(identical(other.totalTokens, totalTokens) || other.totalTokens == totalTokens)&&(identical(other.credits, credits) || other.credits == credits)&&(identical(other.energyKwh, energyKwh) || other.energyKwh == energyKwh)&&(identical(other.carbonGCo2, carbonGCo2) || other.carbonGCo2 == carbonGCo2)&&(identical(other.waterLiters, waterLiters) || other.waterLiters == waterLiters)&&(identical(other.renewablePercent, renewablePercent) || other.renewablePercent == renewablePercent)&&(identical(other.pue, pue) || other.pue == pue)&&(identical(other.dataCenter, dataCenter) || other.dataCenter == dataCenter)&&(identical(other.upstreamProviderId, upstreamProviderId) || other.upstreamProviderId == upstreamProviderId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,createdAt,providerType,responseType,vectorClock,parentId,taskId,categoryId,entryId,agentId,wakeRunKey,threadId,turnIndex,promptId,skillId,configId,modelId,providerModelId,durationMs,inputTokens,outputTokens,cachedInputTokens,thoughtsTokens,totalTokens,credits,energyKwh,carbonGCo2,waterLiters,renewablePercent,pue,dataCenter,upstreamProviderId]);

@override
String toString() {
  return 'AiConsumptionEvent(id: $id, createdAt: $createdAt, providerType: $providerType, responseType: $responseType, vectorClock: $vectorClock, parentId: $parentId, taskId: $taskId, categoryId: $categoryId, entryId: $entryId, agentId: $agentId, wakeRunKey: $wakeRunKey, threadId: $threadId, turnIndex: $turnIndex, promptId: $promptId, skillId: $skillId, configId: $configId, modelId: $modelId, providerModelId: $providerModelId, durationMs: $durationMs, inputTokens: $inputTokens, outputTokens: $outputTokens, cachedInputTokens: $cachedInputTokens, thoughtsTokens: $thoughtsTokens, totalTokens: $totalTokens, credits: $credits, energyKwh: $energyKwh, carbonGCo2: $carbonGCo2, waterLiters: $waterLiters, renewablePercent: $renewablePercent, pue: $pue, dataCenter: $dataCenter, upstreamProviderId: $upstreamProviderId)';
}


}

/// @nodoc
abstract mixin class _$AiConsumptionEventCopyWith<$Res> implements $AiConsumptionEventCopyWith<$Res> {
  factory _$AiConsumptionEventCopyWith(_AiConsumptionEvent value, $Res Function(_AiConsumptionEvent) _then) = __$AiConsumptionEventCopyWithImpl;
@override @useResult
$Res call({
 String id, DateTime createdAt, InferenceProviderType providerType, AiConsumptionResponseType responseType, VectorClock? vectorClock, String? parentId, String? taskId, String? categoryId, String? entryId, String? agentId, String? wakeRunKey, String? threadId, int? turnIndex, String? promptId, String? skillId, String? configId, String? modelId, String? providerModelId, int? durationMs, int? inputTokens, int? outputTokens, int? cachedInputTokens, int? thoughtsTokens, int? totalTokens, double? credits, double? energyKwh, double? carbonGCo2, double? waterLiters, double? renewablePercent, double? pue, String? dataCenter, String? upstreamProviderId
});




}
/// @nodoc
class __$AiConsumptionEventCopyWithImpl<$Res>
    implements _$AiConsumptionEventCopyWith<$Res> {
  __$AiConsumptionEventCopyWithImpl(this._self, this._then);

  final _AiConsumptionEvent _self;
  final $Res Function(_AiConsumptionEvent) _then;

/// Create a copy of AiConsumptionEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? createdAt = null,Object? providerType = null,Object? responseType = null,Object? vectorClock = freezed,Object? parentId = freezed,Object? taskId = freezed,Object? categoryId = freezed,Object? entryId = freezed,Object? agentId = freezed,Object? wakeRunKey = freezed,Object? threadId = freezed,Object? turnIndex = freezed,Object? promptId = freezed,Object? skillId = freezed,Object? configId = freezed,Object? modelId = freezed,Object? providerModelId = freezed,Object? durationMs = freezed,Object? inputTokens = freezed,Object? outputTokens = freezed,Object? cachedInputTokens = freezed,Object? thoughtsTokens = freezed,Object? totalTokens = freezed,Object? credits = freezed,Object? energyKwh = freezed,Object? carbonGCo2 = freezed,Object? waterLiters = freezed,Object? renewablePercent = freezed,Object? pue = freezed,Object? dataCenter = freezed,Object? upstreamProviderId = freezed,}) {
  return _then(_AiConsumptionEvent(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,providerType: null == providerType ? _self.providerType : providerType // ignore: cast_nullable_to_non_nullable
as InferenceProviderType,responseType: null == responseType ? _self.responseType : responseType // ignore: cast_nullable_to_non_nullable
as AiConsumptionResponseType,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,taskId: freezed == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String?,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,entryId: freezed == entryId ? _self.entryId : entryId // ignore: cast_nullable_to_non_nullable
as String?,agentId: freezed == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String?,wakeRunKey: freezed == wakeRunKey ? _self.wakeRunKey : wakeRunKey // ignore: cast_nullable_to_non_nullable
as String?,threadId: freezed == threadId ? _self.threadId : threadId // ignore: cast_nullable_to_non_nullable
as String?,turnIndex: freezed == turnIndex ? _self.turnIndex : turnIndex // ignore: cast_nullable_to_non_nullable
as int?,promptId: freezed == promptId ? _self.promptId : promptId // ignore: cast_nullable_to_non_nullable
as String?,skillId: freezed == skillId ? _self.skillId : skillId // ignore: cast_nullable_to_non_nullable
as String?,configId: freezed == configId ? _self.configId : configId // ignore: cast_nullable_to_non_nullable
as String?,modelId: freezed == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String?,providerModelId: freezed == providerModelId ? _self.providerModelId : providerModelId // ignore: cast_nullable_to_non_nullable
as String?,durationMs: freezed == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int?,inputTokens: freezed == inputTokens ? _self.inputTokens : inputTokens // ignore: cast_nullable_to_non_nullable
as int?,outputTokens: freezed == outputTokens ? _self.outputTokens : outputTokens // ignore: cast_nullable_to_non_nullable
as int?,cachedInputTokens: freezed == cachedInputTokens ? _self.cachedInputTokens : cachedInputTokens // ignore: cast_nullable_to_non_nullable
as int?,thoughtsTokens: freezed == thoughtsTokens ? _self.thoughtsTokens : thoughtsTokens // ignore: cast_nullable_to_non_nullable
as int?,totalTokens: freezed == totalTokens ? _self.totalTokens : totalTokens // ignore: cast_nullable_to_non_nullable
as int?,credits: freezed == credits ? _self.credits : credits // ignore: cast_nullable_to_non_nullable
as double?,energyKwh: freezed == energyKwh ? _self.energyKwh : energyKwh // ignore: cast_nullable_to_non_nullable
as double?,carbonGCo2: freezed == carbonGCo2 ? _self.carbonGCo2 : carbonGCo2 // ignore: cast_nullable_to_non_nullable
as double?,waterLiters: freezed == waterLiters ? _self.waterLiters : waterLiters // ignore: cast_nullable_to_non_nullable
as double?,renewablePercent: freezed == renewablePercent ? _self.renewablePercent : renewablePercent // ignore: cast_nullable_to_non_nullable
as double?,pue: freezed == pue ? _self.pue : pue // ignore: cast_nullable_to_non_nullable
as double?,dataCenter: freezed == dataCenter ? _self.dataCenter : dataCenter // ignore: cast_nullable_to_non_nullable
as String?,upstreamProviderId: freezed == upstreamProviderId ? _self.upstreamProviderId : upstreamProviderId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
