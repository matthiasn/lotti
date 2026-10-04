import 'package:freezed_annotation/freezed_annotation.dart';

part 'skill_assignment.freezed.dart';
part 'skill_assignment.g.dart';

/// Binds a built-in skill (by [skillId]) to an inference profile.
///
/// When [automate] is true, the profile is eligible to run that skill
/// automatically (e.g. auto-transcribe new audio) rather than only on explicit
/// user action — the profile-automation resolver looks for automated
/// assignments when deciding whether to trigger inference without a tap.
@freezed
abstract class SkillAssignment with _$SkillAssignment {
  const factory SkillAssignment({
    required String skillId,
    @Default(false) bool automate,
  }) = _SkillAssignment;

  factory SkillAssignment.fromJson(Map<String, dynamic> json) =>
      _$SkillAssignmentFromJson(json);
}
