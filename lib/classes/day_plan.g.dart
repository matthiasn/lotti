// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'day_plan.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DayPlanStatusDraft _$DayPlanStatusDraftFromJson(Map<String, dynamic> json) =>
    DayPlanStatusDraft(
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$DayPlanStatusDraftToJson(DayPlanStatusDraft instance) =>
    <String, dynamic>{
      'runtimeType': instance.$type,
    };

DayPlanStatusAgreed _$DayPlanStatusAgreedFromJson(Map<String, dynamic> json) =>
    DayPlanStatusAgreed(
      agreedAt: DateTime.parse(json['agreedAt'] as String),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$DayPlanStatusAgreedToJson(
        DayPlanStatusAgreed instance) =>
    <String, dynamic>{
      'agreedAt': instance.agreedAt.toIso8601String(),
      'runtimeType': instance.$type,
    };

DayPlanStatusNeedsReview _$DayPlanStatusNeedsReviewFromJson(
        Map<String, dynamic> json) =>
    DayPlanStatusNeedsReview(
      triggeredAt: DateTime.parse(json['triggeredAt'] as String),
      reason: $enumDecode(_$DayPlanReviewReasonEnumMap, json['reason']),
      previouslyAgreedAt: json['previouslyAgreedAt'] == null
          ? null
          : DateTime.parse(json['previouslyAgreedAt'] as String),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$DayPlanStatusNeedsReviewToJson(
        DayPlanStatusNeedsReview instance) =>
    <String, dynamic>{
      'triggeredAt': instance.triggeredAt.toIso8601String(),
      'reason': _$DayPlanReviewReasonEnumMap[instance.reason]!,
      'previouslyAgreedAt': instance.previouslyAgreedAt?.toIso8601String(),
      'runtimeType': instance.$type,
    };

const _$DayPlanReviewReasonEnumMap = {
  DayPlanReviewReason.newDueTask: 'newDueTask',
  DayPlanReviewReason.blockModified: 'blockModified',
  DayPlanReviewReason.taskRescheduled: 'taskRescheduled',
  DayPlanReviewReason.manualReset: 'manualReset',
};

_PlannedBlock _$PlannedBlockFromJson(Map<String, dynamic> json) =>
    _PlannedBlock(
      id: json['id'] as String,
      categoryId: json['categoryId'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      note: json['note'] as String?,
    );

Map<String, dynamic> _$PlannedBlockToJson(_PlannedBlock instance) =>
    <String, dynamic>{
      'id': instance.id,
      'categoryId': instance.categoryId,
      'startTime': instance.startTime.toIso8601String(),
      'endTime': instance.endTime.toIso8601String(),
      'note': instance.note,
    };

_PinnedTaskRef _$PinnedTaskRefFromJson(Map<String, dynamic> json) =>
    _PinnedTaskRef(
      taskId: json['taskId'] as String,
      categoryId: json['categoryId'] as String,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$PinnedTaskRefToJson(_PinnedTaskRef instance) =>
    <String, dynamic>{
      'taskId': instance.taskId,
      'categoryId': instance.categoryId,
      'sortOrder': instance.sortOrder,
    };

_DayPlanData _$DayPlanDataFromJson(Map<String, dynamic> json) => _DayPlanData(
      planDate: DateTime.parse(json['planDate'] as String),
      status: DayPlanStatus.fromJson(json['status'] as Map<String, dynamic>),
      dayLabel: json['dayLabel'] as String?,
      agreedAt: json['agreedAt'] == null
          ? null
          : DateTime.parse(json['agreedAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      plannedBlocks: (json['plannedBlocks'] as List<dynamic>?)
              ?.map((e) => PlannedBlock.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      pinnedTasks: (json['pinnedTasks'] as List<dynamic>?)
              ?.map((e) => PinnedTaskRef.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$DayPlanDataToJson(_DayPlanData instance) =>
    <String, dynamic>{
      'planDate': instance.planDate.toIso8601String(),
      'status': instance.status,
      'dayLabel': instance.dayLabel,
      'agreedAt': instance.agreedAt?.toIso8601String(),
      'completedAt': instance.completedAt?.toIso8601String(),
      'plannedBlocks': instance.plannedBlocks,
      'pinnedTasks': instance.pinnedTasks,
    };
