// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skill_assignment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SkillAssignment _$SkillAssignmentFromJson(Map<String, dynamic> json) =>
    _SkillAssignment(
      skillId: json['skillId'] as String,
      automate: json['automate'] as bool? ?? false,
    );

Map<String, dynamic> _$SkillAssignmentToJson(_SkillAssignment instance) =>
    <String, dynamic>{
      'skillId': instance.skillId,
      'automate': instance.automate,
    };
