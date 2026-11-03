import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/skill_type.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/helpers/image_analysis_framing.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';

void main() {
  final at = DateTime(2026, 7, 16, 18, 30);
  Metadata meta(String id) => Metadata(
    id: id,
    createdAt: at,
    updatedAt: at,
    dateFrom: at,
    dateTo: at.add(const Duration(hours: 3)),
  );

  final taskSkill = findBuiltInSkill(skillImageAnalysisContextId)!;
  final plainSkill = findBuiltInSkill(skillImageAnalysisId)!;

  JournalEvent event({String? languageCode, String? note}) =>
      JournalEntity.event(
            meta: meta('event-1'),
            data: EventData(
              title: ' Ice garden picnic ',
              stars: 5,
              status: EventStatus.completed,
              languageCode: languageCode,
            ),
            entryText: note == null
                ? null
                : EntryText(plainText: note, markdown: note),
          )
          as JournalEvent;

  final task = Task(
    meta: meta('task-1'),
    data: TaskData(
      title: 'Fix the sled',
      status: TaskStatus.open(id: 's', createdAt: at, utcOffset: 0),
      dateFrom: at,
      dateTo: at,
      statusHistory: const [],
    ),
  );

  test('a task keeps the assigned task-context skill and reads its task', () {
    final framing = frameImageAnalysis(skill: taskSkill, subject: task);

    expect(framing.skill, same(taskSkill));
    expect(framing.taskFramed, isTrue);
    expect(framing.subjectContext, isNull);
    // A task carries its language inside the task JSON instead.
    expect(framing.languageCode, isNull);
  });

  test('an event runs the plain skill, framed by the event in its '
      'language', () {
    final framing = frameImageAnalysis(
      skill: taskSkill,
      subject: event(languageCode: 'de', note: 'Wir picknickten auf dem Eis.'),
    );

    expect(framing.skill, same(plainSkill));
    expect(framing.taskFramed, isFalse);
    expect(framing.contextLabel, 'Event');
    expect(framing.languageCode, 'de');
    expect(
      framing.subjectContext,
      '- Title: Ice garden picnic\n'
      '- When: ${at.toIso8601String()} → '
      '${at.add(const Duration(hours: 3)).toIso8601String()}\n'
      '- Note: Wir picknickten auf dem Eis.',
    );
    // The user's rating is never handed to a model.
    expect(framing.subjectContext, isNot(contains('5')));
  });

  test('an event without a language leaves the skill to its default', () {
    final framing = frameImageAnalysis(
      skill: taskSkill,
      subject: event(languageCode: '  '),
    );

    expect(framing.languageCode, isNull);
    expect(framing.subjectContext, isNot(contains('Note:')));
  });

  for (final (label, subject) in [
    ('nothing', null),
    (
      'a note',
      JournalEntity.journalEntry(meta: meta('note-1')),
    ),
  ]) {
    test('an image added to $label runs the plain skill, unframed', () {
      final framing = frameImageAnalysis(skill: taskSkill, subject: subject);

      expect(framing.skill, same(plainSkill));
      expect(framing.taskFramed, isFalse);
      expect(framing.subjectContext, isNull);
      expect(framing.languageCode, isNull);
    });
  }

  test('a skill without task context runs as assigned anywhere', () {
    final custom = plainSkill.copyWith(id: 'custom-image-skill');

    expect(
      frameImageAnalysis(skill: custom, subject: event()).skill,
      same(custom),
    );
    expect(
      frameImageAnalysis(skill: custom, subject: null).skill,
      same(custom),
    );
  });

  test('a task-context skill of another kind is never swapped', () {
    final summary = taskSkill.copyWith(skillType: SkillType.audioSummary);

    expect(
      frameImageAnalysis(skill: summary, subject: event()).skill,
      same(summary),
    );
  });

  test('a long event note is capped', () {
    final context = eventImageContext(
      event(note: 'x' * (imageAnalysisEventNoteMaxChars + 50)),
    );

    final note = context.split('\n').last;
    expect(note, startsWith('- Note: '));
    expect(note, endsWith('…'));
    expect(
      note.length,
      '- Note: '.length + imageAnalysisEventNoteMaxChars + 1,
    );
  });

  test('the plain skill no longer frames images by tasks and projects', () {
    expect(plainSkill.contextPolicy, isNot(ContextPolicy.fullTask));
    expect(
      plainSkill.systemInstructions,
      isNot(contains('tasks and projects')),
    );
  });
}
