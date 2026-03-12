import 'package:freezed_annotation/freezed_annotation.dart';

part 'skill_assignment.freezed.dart';
part 'skill_assignment.g.dart';

@freezed
abstract class SkillAssignment with _$SkillAssignment {
  const factory SkillAssignment({
    required String skillId,
    @Default(false) bool automate,
  }) = _SkillAssignment;

  factory SkillAssignment.fromJson(Map<String, dynamic> json) =>
      _$SkillAssignmentFromJson(json);
}
