import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/workflow/task_state_markdown.dart';
import 'package:lotti/features/ai/model/ai_input.dart';

AiInputTaskObject _task({
  String title = 'Test task',
  String status = 'IN PROGRESS',
  String priority = 'P2',
  String estimatedDuration = '01:00',
  String timeSpent = '00:18',
  DateTime? dueDate,
  String? languageCode = 'en',
  List<AiActionItem> actionItems = const [],
}) => AiInputTaskObject(
  title: title,
  status: status,
  priority: priority,
  estimatedDuration: estimatedDuration,
  timeSpent: timeSpent,
  creationDate: DateTime.utc(2026, 6, 4, 11, 38),
  actionItems: actionItems,
  logEntries: const [],
  dueDate: dueDate,
  languageCode: languageCode,
);

extension _AnyActionItems on glados.Any {
  glados.Generator<List<AiActionItem>> get actionItems =>
      glados.ListAnys(this).listWithLengthInRange(0, 6, _actionItem);

  glados.Generator<AiActionItem> get _actionItem =>
      glados.CombinableAny(this).combine4(
        glados.IntAnys(this).intInRange(0, 1 << 20),
        glados.AnyUtils(this).choose(<bool>[true, false]),
        glados.AnyUtils(this).choose(<bool>[true, false]),
        glados.AnyUtils(this).choose(<String?>['agent', 'user', null]),
        (n, completed, archived, checkedBy) => AiActionItem(
          title: 'item $n',
          completed: completed,
          isArchived: archived,
          id: 'id-$n',
          checkedBy: checkedBy,
        ),
      );
}

void main() {
  group('renderTaskStateMarkdown', () {
    // ── generative properties ────────────────────────────────────────────────

    glados.Glados(
      glados.any.actionItems,
      glados.ExploreConfig(numRuns: 200),
    ).test(
      'every checklist item renders with its id and correct checkbox',
      (
        generated,
      ) {
        // Re-key ids by index: the generator can emit duplicate ids, which
        // would make the per-item `singleWhere` lookup ambiguous without
        // weakening what the property asserts.
        final items = [
          for (var i = 0; i < generated.length; i++)
            generated[i].copyWith(id: 'id-$i'),
        ];
        final text = renderTaskStateMarkdown(_task(actionItems: items));
        for (final item in items) {
          final line = text
              .split('\n')
              .singleWhere((l) => l.contains('(id: ${item.id}'));
          expect(line, startsWith(item.completed ? '- [x]' : '- [ ]'));
          expect(line, contains(item.title));
          expect(line.contains(', archived'), item.isArchived);
          expect(
            line.contains('checked by'),
            item.completed && item.checkedBy != null,
          );
        }
        // The checklist section exists exactly when there are items.
        expect(text.contains('### Checklist'), items.isNotEmpty);
      },
      tags: 'glados',
    );

    // ── examples ─────────────────────────────────────────────────────────────

    test('renders the core state lines', () {
      final text = renderTaskStateMarkdown(
        _task(dueDate: DateTime.utc(2026, 6, 10)),
      );
      expect(text, contains('- Title: Test task'));
      expect(text, contains('- Status: IN PROGRESS · Priority: P2'));
      expect(text, contains('- Estimate: 01:00 · Time spent: 00:18'));
      expect(text, contains('- Created: 2026-06-04T11:38:00.000Z'));
      expect(text, contains('· Due: 2026-06-10T00:00:00.000Z'));
      expect(text, contains('- Language: en'));
    });

    test('omits zero durations, and the whole line when both are zero', () {
      final estimateOnly = renderTaskStateMarkdown(
        _task(estimatedDuration: '02:00', timeSpent: '00:00'),
      );
      expect(estimateOnly, contains('- Estimate: 02:00'));
      expect(estimateOnly, isNot(contains('Time spent')));

      final neither = renderTaskStateMarkdown(
        _task(estimatedDuration: '00:00', timeSpent: '00:00'),
      );
      expect(neither, isNot(contains('Estimate')));
      expect(neither, isNot(contains('Time spent')));
    });

    test('omits due date, language, labels and suppressed ids when empty', () {
      final text = renderTaskStateMarkdown(_task(languageCode: null));
      expect(text, isNot(contains('Due:')));
      expect(text, isNot(contains('Language:')));
      expect(text, isNot(contains('Labels:')));
      expect(text, isNot(contains('suppressed')));
    });

    test('renders label names and suppressed label ids when present', () {
      final text = renderTaskStateMarkdown(
        _task(),
        labels: const [
          {'id': 'l1', 'name': 'deep work'},
          {'id': 'l2', 'name': 'research'},
        ],
        suppressedLabelIds: const ['l9'],
      );
      expect(text, contains('- Labels: deep work, research'));
      expect(text, contains('- AI-suppressed label ids: l9'));
    });

    test('renders a checklist item with due date and checked-by tags', () {
      final text = renderTaskStateMarkdown(
        _task(
          actionItems: [
            AiActionItem(
              title: 'Verify mechanism',
              completed: true,
              id: 'abc-123',
              deadline: DateTime.utc(2026, 6, 8),
              checkedBy: 'agent',
            ),
          ],
        ),
      );
      expect(
        text,
        contains(
          '- [x] Verify mechanism '
          '(id: abc-123, due 2026-06-08T00:00:00.000Z, checked by agent)',
        ),
      );
    });

    test('is dramatically more compact than the JSON it replaces', () {
      // Two open items, no nulls rendered, no 9-line item objects.
      final text = renderTaskStateMarkdown(
        _task(
          actionItems: const [
            AiActionItem(title: 'a', completed: false, id: 'i1'),
            AiActionItem(title: 'b', completed: false, id: 'i2'),
          ],
        ),
      );
      expect(text, isNot(contains('null')));
      expect(text.split('\n').length, lessThanOrEqualTo(9));
    });
  });
}
