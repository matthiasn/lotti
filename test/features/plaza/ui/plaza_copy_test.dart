import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/ui/plaza_copy.dart';
import 'package:lotti/l10n/app_localizations_de.dart';

void main() {
  final now = DateTime.utc(2026, 9, 8);
  PlazaTask task(PlazaTaskState state, {DateTime? due}) => PlazaTask(
    id: 'waddle',
    createdAt: now.subtract(const Duration(days: 30)),
    title: 'Pack the shuttle',
    state: state,
    due: due,
    progress: 0,
    checklistItems: 0,
    linkedTaskIds: const ['peer'],
    categoryColor: 0,
  );
  final english = PlazaCopy.english;
  final german = PlazaCopy(AppLocalizationsDe());

  test(
    'status uses the active locale and completion overrides a past due date',
    () {
      for (final (state, label) in [
        (PlazaTaskState.open, 'Open'),
        (PlazaTaskState.inProgress, 'In Progress'),
        (PlazaTaskState.blocked, 'Blocked'),
        (PlazaTaskState.done, 'Done'),
        (PlazaTaskState.cancelled, 'Cancelled'),
      ]) {
        expect(english.state(attentionFor(task(state), now)), label);
      }
      final done = attentionFor(
        task(PlazaTaskState.done, due: now.subtract(const Duration(days: 1))),
        now,
      );
      expect(german.state(done), 'Erledigt');
      expect(german.reason(done), isEmpty);
      expect(
        english.reason(attentionFor(task(PlazaTaskState.cancelled), now)),
        isEmpty,
      );
    },
  );

  test('reasons are composed from facts, including blocked overdue tasks', () {
    final late = now.subtract(const Duration(days: 1));
    expect(
      english.reason(
        attentionFor(task(PlazaTaskState.blocked, due: late), now),
      ),
      'blocked — needs a decision',
    );
    final overdue = attentionFor(task(PlazaTaskState.open, due: late), now);
    expect(english.state(overdue), 'Overdue');
    expect(english.reason(overdue), 'overdue since Sep 7 — finish or move it');
    expect(german.reason(overdue), contains('überfällig seit'));
    expect(
      english.reason(attentionFor(task(PlazaTaskState.inProgress), now)),
      'quiet for 30 days — pick it back up',
    );
    expect(
      english.reason(attentionFor(task(PlazaTaskState.open, due: now), now)),
      'due Sep 8 — finish it',
    );
    expect(
      english.reason(attentionFor(task(PlazaTaskState.open), now)),
      isEmpty,
    );
  });

  test('metadata and week markers format dates in the viewer locale', () {
    final t = task(PlazaTaskState.open, due: now);
    expect(english.metaBits(t), ['due Sep 8', 'links 1']);
    expect(german.metaBits(t).first, startsWith('fällig am'));
    expect(english.week(DateTime.utc(2026, 9, 7), 1), 'W2 · Sep 14');
    expect(german.week(DateTime.utc(2026, 9, 7), 1), contains('14. Sept.'));
  });
}
