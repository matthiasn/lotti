import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/habits/model/habit_completion_record.dart';

/// Value semantics for [HabitCompletionRecord].
///
/// These are not decoration. `HabitsState.habitCompletions` is a
/// `List<HabitCompletionRecord>` compared with `DeepCollectionEquality`, which
/// falls back to identity when the element type has no `==`. Without value
/// equality every recomputation would produce a "different" state and rebuild
/// the habits tab even when nothing changed.
void main() {
  HabitCompletionRecord record({
    String habitId = 'habit-1',
    DateTime? dateFrom,
    HabitCompletionType? completionType = HabitCompletionType.success,
  }) {
    return HabitCompletionRecord(
      habitId: habitId,
      dateFrom: dateFrom ?? DateTime(2026, 3, 15),
      completionType: completionType,
    );
  }

  test('records with the same fields are equal and hash alike', () {
    expect(record(), record());
    expect(record().hashCode, record().hashCode);
  });

  test('each field participates in equality', () {
    expect(record(habitId: 'other'), isNot(record()));
    expect(record(dateFrom: DateTime(2026, 3, 16)), isNot(record()));
    expect(record(completionType: HabitCompletionType.fail), isNot(record()));
    expect(record(completionType: null), isNot(record()));
  });

  test('a null completion type is a value, not an absence', () {
    // Null means "counts as success" to every consumer, so two null-typed
    // records must still compare equal to each other.
    expect(record(completionType: null), record(completionType: null));
  });

  test(
    'lists of records compare deeply, which is what the state relies on',
    () {
      const equality = DeepCollectionEquality();

      expect(equality.equals([record()], [record()]), isTrue);
      expect(
        equality.equals([record()], [record(habitId: 'other')]),
        isFalse,
        reason: 'a changed completion must make the state compare unequal',
      );
    },
  );

  test('toString names the fields', () {
    expect(record().toString(), contains('habit-1'));
    expect(record().toString(), contains('success'));
  });

  test('identical instances short-circuit equality', () {
    final instance = record();
    expect(instance, instance);
  });

  test('a record exposes the three fields it was built with', () {
    final instance = record();
    expect(instance.habitId, 'habit-1');
    expect(instance.dateFrom, DateTime(2026, 3, 15));
    expect(instance.completionType, HabitCompletionType.success);
  });
}
