import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/features/agents/model/observation_record.dart';
import 'package:lotti/features/agents/workflow/task_observation_contract.dart';

void main() {
  ObservationRecord note(
    String text, {
    ObservationPriority priority = ObservationPriority.routine,
  }) => ObservationRecord(text: text, priority: priority);

  ObservationRecord critical(String text) =>
      note(text, priority: ObservationPriority.critical);

  List<String> texts(List<ObservationRecord> records) => [
    for (final record in records) record.text,
  ];

  test('keeps new, short notes untouched', () {
    final result = applyTaskObservationContract(
      [note('The fish count moved to Friday.')],
      earlier: const ['The colony prefers mornings.'],
    );
    expect(texts(result.kept), ['The fish count moved to Friday.']);
    expect(result.skipped, isEmpty);
  });

  test('drops a repeat of an earlier note, ignoring case, spacing and '
      'punctuation', () {
    final result = applyTaskObservationContract(
      [note('the project name  WADDLE is settled'), note('A new fact.')],
      earlier: const ['The project name "Waddle" is settled.'],
    );
    expect(texts(result.kept), ['A new fact.']);
    expect(result.skipped.single, contains('already recorded'));
  });

  test('drops a repeat within the same call', () {
    final result = applyTaskObservationContract(
      [note('Ice is thin.'), note('ice is thin')],
      earlier: const [],
    );
    expect(texts(result.kept), ['Ice is thin.']);
    expect(result.skipped, hasLength(1));
  });

  test('a critical repeat is dropped too', () {
    final result = applyTaskObservationContract(
      [critical('User was annoyed by the duplicate checklist.')],
      earlier: const ['User was annoyed by the duplicate checklist.'],
    );
    expect(result.kept, isEmpty);
  });

  test('drops an over-long routine note with the length to aim for, but '
      'keeps an over-long critical one', () {
    final long = 'x' * (taskObservationMaxChars + 1);
    final result = applyTaskObservationContract(
      [note(long), critical('y' * (taskObservationMaxChars + 200))],
      earlier: const [],
    );
    expect(result.kept.single.priority, ObservationPriority.critical);
    expect(
      result.skipped.single,
      contains(
        '${taskObservationMaxChars + 1} characters; shorten it to '
        '$taskObservationMaxChars',
      ),
    );
  });

  test('a note at exactly the limit is kept', () {
    final result = applyTaskObservationContract(
      [note('z' * taskObservationMaxChars)],
      earlier: const [],
    );
    expect(result.kept, hasLength(1));
  });

  test('caps non-critical notes per call, never critical ones', () {
    final result = applyTaskObservationContract(
      [
        for (var i = 0; i < taskObservationMaxItems + 1; i++) note('Fact $i.'),
        critical('Grievance after the cap.'),
      ],
      earlier: const [],
    );
    expect(texts(result.kept), [
      for (var i = 0; i < taskObservationMaxItems; i++) 'Fact $i.',
      'Grievance after the cap.',
    ]);
    expect(result.skipped.single, contains('past the limit'));
  });

  test('a note dropped for length is not counted as recorded', () {
    final long = 'Ice ${'very ' * 80}thin.';
    final first = applyTaskObservationContract([note(long)], earlier: const []);
    expect(first.kept, isEmpty);
    // Recorded as critical next time, the same text is accepted: it was
    // never stored, so it is no repeat.
    final second = applyTaskObservationContract(
      [critical(long)],
      earlier: texts(first.kept),
    );
    expect(second.kept, hasLength(1));
  });

  test('the rule states the length limit it is enforced with', () {
    expect(
      taskObservationRule,
      contains('$taskObservationMaxChars characters'),
    );
    expect(taskObservationRule, contains('[[supersedes:'));
  });
}
