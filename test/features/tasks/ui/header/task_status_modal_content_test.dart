import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/tasks/ui/header/task_status_modal_content.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _testDate = DateTime(2024, 3, 15);

TaskStatus _makeStatus(String s) => switch (s) {
  'OPEN' => TaskStatus.open(id: 'id', createdAt: _testDate, utcOffset: 0),
  'GROOMED' => TaskStatus.groomed(id: 'id', createdAt: _testDate, utcOffset: 0),
  'IN PROGRESS' => TaskStatus.inProgress(
    id: 'id',
    createdAt: _testDate,
    utcOffset: 0,
  ),
  'BLOCKED' => TaskStatus.blocked(
    id: 'id',
    createdAt: _testDate,
    utcOffset: 0,
    reason: 'test',
  ),
  'ON HOLD' => TaskStatus.onHold(
    id: 'id',
    createdAt: _testDate,
    utcOffset: 0,
    reason: 'test',
  ),
  'DONE' => TaskStatus.done(id: 'id', createdAt: _testDate, utcOffset: 0),
  _ => TaskStatus.rejected(id: 'id', createdAt: _testDate, utcOffset: 0),
};

MockTask _makeTask(String status) => MockTask(
  data: TaskData(
    status: _makeStatus(status),
    dateFrom: _testDate,
    dateTo: _testDate,
    statusHistory: const [],
    title: 'Test Task',
  ),
);

/// Label resolver that returns the raw status string — no l10n needed.
String _labelOf(String status, BuildContext _) => status;

Future<void> _pump(
  WidgetTester tester, {
  required String currentStatus,
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      // resolveTestTheme adds the DsTokens extension (the modal rows read
      // `context.designTokens`) while preserving the requested brightness.
      theme: resolveTestTheme(
        brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light(),
      ),
      home: Scaffold(
        body: Material(
          child: TaskStatusModalContent(
            task: _makeTask(currentStatus),
            labelResolver: _labelOf,
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TaskStatusModalContent', () {
    // ── Rendering ─────────────────────────────────────────────────────────────

    testWidgets('renders a row for every status', (tester) async {
      await _pump(tester, currentStatus: 'OPEN');
      for (final status in allTaskStatuses) {
        expect(find.text(status), findsOneWidget);
      }
    });

    testWidgets(
      'renders the localized label for every status with the default '
      'resolver',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            Material(
              child: TaskStatusModalContent(task: _makeTask('OPEN')),
            ),
          ),
        );

        final context = tester.element(find.byType(TaskStatusModalContent));
        final messages = context.messages;
        for (final expected in [
          messages.taskStatusOpen,
          messages.taskStatusGroomed,
          messages.taskStatusInProgress,
          messages.taskStatusBlocked,
          messages.taskStatusOnHold,
          messages.taskStatusDone,
          messages.taskStatusRejected,
        ]) {
          expect(find.text(expected), findsOneWidget, reason: expected);
        }
      },
    );

    testWidgets('shows the correct icon for each status', (tester) async {
      await _pump(tester, currentStatus: 'OPEN');

      for (final status in allTaskStatuses) {
        final expectedIcon = taskIconFromStatusString(status);
        final rowFinder = find.ancestor(
          of: find.text(status),
          matching: find.byType(Row),
        );
        final iconsInRow = tester
            .widgetList<Icon>(
              find.descendant(
                of: rowFinder.first,
                matching: find.byType(Icon),
              ),
            )
            .map((i) => i.icon)
            .toList();

        expect(
          iconsInRow,
          contains(expectedIcon),
          reason: 'Row for $status should contain icon $expectedIcon',
        );
      }
    });

    testWidgets(
      'blocked row uses warning_sharp (triangle), not block_rounded',
      (tester) async {
        await _pump(tester, currentStatus: 'OPEN');

        final rowFinder = find.ancestor(
          of: find.text('BLOCKED'),
          matching: find.byType(Row),
        );
        final iconsInRow = tester
            .widgetList<Icon>(
              find.descendant(
                of: rowFinder.first,
                matching: find.byType(Icon),
              ),
            )
            .map((i) => i.icon)
            .toList();

        expect(iconsInRow, contains(Icons.warning_sharp));
        expect(iconsInRow, isNot(contains(Icons.block_rounded)));
      },
    );

    // ── Selection indicator ───────────────────────────────────────────────────

    testWidgets('trailing checkmark shown only on the current status row', (
      tester,
    ) async {
      await _pump(tester, currentStatus: 'IN PROGRESS');

      // Exactly one check_rounded in the whole list.
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // That checkmark is inside the IN PROGRESS row.
      final selectedRow = find.ancestor(
        of: find.text('IN PROGRESS'),
        matching: find.byType(Row),
      );
      expect(
        find.descendant(
          of: selectedRow.first,
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('no checkmark on any unselected row', (tester) async {
      await _pump(tester, currentStatus: 'DONE');

      for (final status in allTaskStatuses.where((s) => s != 'DONE')) {
        final rowFinder = find.ancestor(
          of: find.text(status),
          matching: find.byType(Row),
        );
        expect(
          find.descendant(
            of: rowFinder.first,
            matching: find.byIcon(Icons.check_rounded),
          ),
          findsNothing,
          reason: 'Unselected row "$status" must not show check_rounded',
        );
      }
    });

    testWidgets('selected label renders with bold weight', (tester) async {
      await _pump(tester, currentStatus: 'GROOMED');
      final text = tester.widget<Text>(find.text('GROOMED'));
      expect(text.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('unselected label renders with normal weight', (tester) async {
      await _pump(tester, currentStatus: 'GROOMED');
      final text = tester.widget<Text>(find.text('OPEN'));
      expect(text.style?.fontWeight, FontWeight.normal);
    });

    // ── Icon colors ───────────────────────────────────────────────────────────

    for (final brightness in Brightness.values) {
      for (final status in allTaskStatuses) {
        testWidgets(
          '$status row icon uses the correct color (${brightness.name})',
          (tester) async {
            await _pump(
              tester,
              currentStatus: 'OPEN',
              brightness: brightness,
            );

            final expectedColor = taskColorFromStatusString(
              status,
              brightness: brightness,
            );
            final rowFinder = find.ancestor(
              of: find.text(status),
              matching: find.byType(Row),
            );

            // First Icon in the row is the status icon (the trailing
            // checkmark comes last and only for the selected row).
            final statusIcon = tester
                .widgetList<Icon>(
                  find.descendant(
                    of: rowFinder.first,
                    matching: find.byType(Icon),
                  ),
                )
                .first;

            expect(
              statusIcon.color,
              expectedColor,
              reason: '$status icon should use its ${brightness.name} color',
            );
          },
        );
      }
    }

    // ── Interaction ───────────────────────────────────────────────────────────

    testWidgets('tapping a row pops the dialog with the correct status', (
      tester,
    ) async {
      String? popped;

      await tester.pumpWidget(
        MaterialApp(
          theme: resolveTestTheme(),
          home: Scaffold(
            body: Material(
              child: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    popped = await showDialog<String>(
                      context: context,
                      builder: (_) => Dialog(
                        child: TaskStatusModalContent(
                          task: _makeTask('OPEN'),
                          labelResolver: _labelOf,
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('DONE'));
      await tester.pumpAndSettle();

      expect(popped, 'DONE');
    });

    for (final statusToTap in allTaskStatuses) {
      testWidgets('tapping $statusToTap pops with its own string', (
        tester,
      ) async {
        String? popped;

        await tester.pumpWidget(
          MaterialApp(
            theme: resolveTestTheme(),
            home: Scaffold(
              body: Material(
                child: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () async {
                      popped = await showDialog<String>(
                        context: context,
                        builder: (_) => Dialog(
                          child: TaskStatusModalContent(
                            task: _makeTask('OPEN'),
                            labelResolver: _labelOf,
                          ),
                        ),
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(statusToTap));
        await tester.pumpAndSettle();

        expect(popped, statusToTap);
      });
    }
  });
}
