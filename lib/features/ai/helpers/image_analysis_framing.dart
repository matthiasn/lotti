import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/ai/skill_type.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';

/// How an image analysis is framed by what the image was added to.
///
/// The automated image skill of every seeded profile is the task-context one
/// ([ContextPolicy.fullTask]): it asks the model what the image means *for
/// the task*, and to say so — "nothing related to a task", with a salty tone —
/// when it does not fit. That is the right question under a task and the
/// wrong one anywhere else, so [frameImageAnalysis] keeps it for a task and
/// answers every other subject with the plain image skill, framed by the
/// subject where it has something to say: an event lends its title, its time
/// and its note, and the language its record is kept in.
class ImageAnalysisFraming {
  const ImageAnalysisFraming({
    required this.skill,
    required this.taskFramed,
    this.subjectContext,
    this.contextLabel = 'Task',
    this.languageCode,
  });

  /// The skill that actually runs — the assigned one, or the plain image
  /// skill standing in for a task-context skill outside a task.
  final AiConfigSkill skill;

  /// Whether the subject is a task, so the task's details, its linked tasks
  /// and its report are read into the prompt.
  final bool taskFramed;

  /// What the subject says about the scene, as prompt text, or null.
  final String? subjectContext;

  /// Names what [subjectContext] describes ("Event").
  final String contextLabel;

  /// The language the analysis is written in, or null for the skill's
  /// default. A task carries its own inside the task JSON instead.
  final String? languageCode;
}

/// The longest event note read into an image analysis, in characters — the
/// scene is what the model needs, not the whole diary of the day.
const imageAnalysisEventNoteMaxChars = 1500;

/// Frames an analysis of an image that was added to [subject] (null when it
/// belongs to nothing), running [skill] as assigned.
ImageAnalysisFraming frameImageAnalysis({
  required AiConfigSkill skill,
  required JournalEntity? subject,
}) {
  if (subject is Task) {
    return ImageAnalysisFraming(skill: skill, taskFramed: true);
  }

  final effectiveSkill =
      skill.skillType == SkillType.imageAnalysis &&
          skill.contextPolicy == ContextPolicy.fullTask
      ? findBuiltInSkill(skillImageAnalysisId) ?? skill
      : skill;

  if (subject is JournalEvent) {
    final languageCode = subject.data.languageCode?.trim();
    return ImageAnalysisFraming(
      skill: effectiveSkill,
      taskFramed: false,
      subjectContext: eventImageContext(subject),
      contextLabel: 'Event',
      languageCode: languageCode == null || languageCode.isEmpty
          ? null
          : languageCode,
    );
  }

  return ImageAnalysisFraming(skill: effectiveSkill, taskFramed: false);
}

/// The event an image was added to, as the analysis reads it: its title,
/// when it happened, and its note (capped at [imageAnalysisEventNoteMaxChars]).
/// Rating and cover are the user's own and are left out, as everywhere the
/// event reaches a model.
String eventImageContext(JournalEvent event) {
  final buffer = StringBuffer()
    ..writeln('- Title: ${event.data.title.trim()}')
    ..writeln(
      '- When: ${event.meta.dateFrom.toIso8601String()} → '
      '${event.meta.dateTo.toIso8601String()}',
    );
  final note = event.entryText?.plainText.trim();
  if (note != null && note.isNotEmpty) {
    final capped = note.length > imageAnalysisEventNoteMaxChars
        ? '${note.substring(0, imageAnalysisEventNoteMaxChars).trimRight()}…'
        : note;
    buffer.writeln('- Note: $capped');
  }
  return buffer.toString().trimRight();
}
