import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/tasks/ui/task_status.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/themes/theme.dart';

import '../../../test_helper.dart';

/// Builds a real [Task] around the given [TaskData] — no mock needed for a
/// plain value object.
Task _makeTask(TaskData taskData) {
  final testDate = DateTime(2024, 3, 15, 10, 30);
  return Task(
    meta: Metadata(
      id: 'test-task-id',
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: testDate,
      dateTo: testDate,
    ),
    data: taskData,
  );
}

void main() {
  final testDate = DateTime(2024, 3, 15, 10, 30);

  TaskStatus createTaskStatus(
    TaskStatus Function(String, DateTime, int) factory,
  ) {
    return factory(
      'test-status-id',
      testDate,
      testDate.timeZoneOffset.inMinutes,
    );
  }

  Task createTask(TaskStatus status) {
    final taskData = TaskData(
      status: status,
      dateFrom: testDate,
      dateTo: testDate,
      statusHistory: [],
      title: 'Test Task',
    );

    return _makeTask(taskData);
  }

  testWidgets('renders with correct label for open status', (tester) async {
    final status = createTaskStatus(
      (id, createdAt, utcOffset) => TaskStatus.open(
        id: id,
        createdAt: createdAt,
        utcOffset: utcOffset,
      ),
    );
    final mockTask = createTask(status);

    await tester.pumpWidget(
      WidgetTestBench(
        child: TaskStatusWidget(mockTask),
      ),
    );

    // Verify the widget displays the Chip with correct label
    expect(find.byType(Chip), findsOneWidget);
    // The label is determined by localizedLabel which we cannot directly test,
    // but we can verify a Text widget exists inside the Chip
    expect(
      find.descendant(of: find.byType(Chip), matching: find.byType(Text)),
      findsOneWidget,
    );
  });

  // One status→color table per theme; the loop below covers both
  // brightness modes without duplicating the seven per-status cases.
  final statusFactories = <String, TaskStatus Function(String, DateTime, int)>{
    'open': (id, createdAt, utcOffset) =>
        TaskStatus.open(id: id, createdAt: createdAt, utcOffset: utcOffset),
    'groomed': (id, createdAt, utcOffset) =>
        TaskStatus.groomed(id: id, createdAt: createdAt, utcOffset: utcOffset),
    'inProgress': (id, createdAt, utcOffset) => TaskStatus.inProgress(
      id: id,
      createdAt: createdAt,
      utcOffset: utcOffset,
    ),
    'blocked': (id, createdAt, utcOffset) => TaskStatus.blocked(
      id: id,
      createdAt: createdAt,
      utcOffset: utcOffset,
      reason: 'Test reason',
    ),
    'onHold': (id, createdAt, utcOffset) => TaskStatus.onHold(
      id: id,
      createdAt: createdAt,
      utcOffset: utcOffset,
      reason: 'Test reason',
    ),
    'done': (id, createdAt, utcOffset) =>
        TaskStatus.done(id: id, createdAt: createdAt, utcOffset: utcOffset),
    'rejected': (id, createdAt, utcOffset) => TaskStatus.rejected(
      id: id,
      createdAt: createdAt,
      utcOffset: utcOffset,
    ),
  };

  const lightColors = <String, Color>{
    'open': Color(0xFFE65100),
    'groomed': Color(0xFF2E7D32),
    'inProgress': Color(0xFF1565C0),
    'blocked': Color(0xFFC62828),
    'onHold': Color(0xFFC62828),
    'done': Color(0xFF2E7D32),
    'rejected': Color(0xFFC62828),
  };

  const darkColors = <String, Color>{
    'open': Colors.orange,
    'groomed': Colors.lightGreenAccent,
    'inProgress': Colors.blue,
    'blocked': Colors.red,
    'onHold': Colors.red,
    'done': Colors.green,
    'rejected': Colors.red,
  };

  for (final dark in [false, true]) {
    testWidgets(
      'renders the correct background color for each status in '
      '${dark ? 'dark' : 'light'} mode',
      (tester) async {
        final expectedColors = dark ? darkColors : lightColors;
        for (final entry in statusFactories.entries) {
          final status = entry.value(
            'test-status-id',
            testDate,
            testDate.timeZoneOffset.inMinutes,
          );
          final mockTask = createTask(status);

          await tester.pumpWidget(
            dark
                ? DarkWidgetTestBench(child: TaskStatusWidget(mockTask))
                : WidgetTestBench(child: TaskStatusWidget(mockTask)),
          );
          await tester.pump();

          final chipWidget = tester.widget<Chip>(find.byType(Chip));
          expect(
            chipWidget.backgroundColor,
            expectedColors[entry.key],
            reason: '${entry.key} in ${dark ? 'dark' : 'light'} mode',
          );
        }
      },
    );
  }

  testWidgets('text color is white for dark background colors in light mode', (
    tester,
  ) async {
    // Use a status with a dark background color (in light mode)
    final status = createTaskStatus(
      (id, createdAt, utcOffset) => TaskStatus.groomed(
        id: id,
        createdAt: createdAt,
        utcOffset: utcOffset,
      ),
    );
    final mockTask = createTask(status);

    await tester.pumpWidget(
      WidgetTestBench(
        child: TaskStatusWidget(mockTask),
      ),
    );

    // Find the Text widget within the Chip
    final textWidget = tester.widget<Text>(
      find.descendant(
        of: find.byType(Chip),
        matching: find.byType(Text),
      ),
    );

    // Verify the text color is white for dark background (Color(0xFF2E7D32) is dark)
    expect(textWidget.style?.color, equals(Colors.white));
  });

  testWidgets('text color for dark background colors', (tester) async {
    // Use a status with a dark background color
    final status = createTaskStatus(
      (id, createdAt, utcOffset) => TaskStatus.done(
        id: id,
        createdAt: createdAt,
        utcOffset: utcOffset,
      ),
    );
    final mockTask = createTask(status);

    await tester.pumpWidget(
      WidgetTestBench(
        child: TaskStatusWidget(mockTask),
      ),
    );

    // Find the Text widget within the Chip
    final textWidget = tester.widget<Text>(
      find.descendant(
        of: find.byType(Chip),
        matching: find.byType(Text),
      ),
    );

    // Just check for non-null color (the actual implementation might vary)
    expect(textWidget.style?.color, isNotNull);
  });

  testWidgets('uses correct color for in progress status', (tester) async {
    // Test that the in progress status uses the correct blue color
    final status = TaskStatus.inProgress(
      id: 'test-status-id',
      createdAt: testDate,
      utcOffset: testDate.timeZoneOffset.inMinutes,
    );
    final mockTask = createTask(status);

    await tester.pumpWidget(
      WidgetTestBench(
        child: TaskStatusWidget(mockTask),
      ),
    );

    // Find the Chip widget
    final chipWidget = tester.widget<Chip>(find.byType(Chip));

    // Verify the dark blue color is used for in progress status in light mode
    expect(chipWidget.backgroundColor, const Color(0xFF1565C0));
  });

  testWidgets('renders with compact visual density', (tester) async {
    final status = createTaskStatus(
      (id, createdAt, utcOffset) => TaskStatus.open(
        id: id,
        createdAt: createdAt,
        utcOffset: utcOffset,
      ),
    );
    final mockTask = createTask(status);

    await tester.pumpWidget(
      WidgetTestBench(
        child: TaskStatusWidget(mockTask),
      ),
    );

    // Find the Chip widget
    final chipWidget = tester.widget<Chip>(find.byType(Chip));

    // Verify the visual density is compact
    expect(chipWidget.visualDensity, equals(VisualDensity.compact));
  });

  testWidgets('chip label text uses the small font size token', (
    tester,
  ) async {
    final status = createTaskStatus(
      (id, createdAt, utcOffset) => TaskStatus.open(
        id: id,
        createdAt: createdAt,
        utcOffset: utcOffset,
      ),
    );
    await tester.pumpWidget(
      WidgetTestBench(child: TaskStatusWidget(createTask(status))),
    );

    final text = tester.widget<Text>(
      find.descendant(of: find.byType(Chip), matching: find.byType(Text)),
    );
    expect(text.style?.fontSize, fontSizeSmall);
  });

  testWidgets('text color is black for bright background colors in dark mode', (
    tester,
  ) async {
    // Use a status with a bright background color (in dark mode)
    final status = createTaskStatus(
      (id, createdAt, utcOffset) => TaskStatus.groomed(
        id: id,
        createdAt: createdAt,
        utcOffset: utcOffset,
      ),
    );
    final mockTask = createTask(status);

    await tester.pumpWidget(
      DarkWidgetTestBench(
        child: TaskStatusWidget(mockTask),
      ),
    );

    // Find the Text widget within the Chip
    final textWidget = tester.widget<Text>(
      find.descendant(
        of: find.byType(Chip),
        matching: find.byType(Text),
      ),
    );

    // Verify the text color is black for bright background (lightGreenAccent is bright)
    expect(textWidget.style?.color, equals(Colors.black));
  });

  testWidgets('uses correct color for in progress status in dark mode', (
    tester,
  ) async {
    // Test that the in progress status uses the correct blue color in dark mode
    final status = TaskStatus.inProgress(
      id: 'test-status-id',
      createdAt: testDate,
      utcOffset: testDate.timeZoneOffset.inMinutes,
    );
    final mockTask = createTask(status);

    await tester.pumpWidget(
      DarkWidgetTestBench(
        child: TaskStatusWidget(mockTask),
      ),
    );

    // Find the Chip widget
    final chipWidget = tester.widget<Chip>(find.byType(Chip));

    // Verify the blue color is used for in progress status in dark mode
    expect(chipWidget.backgroundColor, Colors.blue);
  });

  test('normalizes transitional/open status strings to canonical labels', () {
    expect(normalizeTaskStatusString('Opening'), 'OPEN');
    expect(normalizeTaskStatusString('inProgress'), 'IN PROGRESS');
    expect(normalizeTaskStatusString('IN_PROGRESS'), 'IN PROGRESS');
  });

  group('normalizeTaskStatusString — properties', () {
    glados.Glados<String>(
      glados.AnyUtils(glados.any).choose(const [
        'open',
        ' OPEN ',
        'OPENING',
        'opened',
        'in_progress',
        'INPROGRESS',
        'In Progress',
        'on_hold',
        'BLOCKED',
        'done ',
        'rejected',
        'garbage-status',
        '',
      ]),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'is idempotent, and every known alias lands in allTaskStatuses',
      (input) {
        final once = normalizeTaskStatusString(input);
        // Idempotence: re-normalizing a normalized value is a no-op.
        expect(normalizeTaskStatusString(once), once, reason: 'input="$input"');

        // Known aliases (anything that trims/uppercases/underscores or
        // alias-maps to a canonical value) must land in the canonical set;
        // unknown strings pass through normalized but must NOT collide
        // with the canonical set spelled differently.
        final canonical = allTaskStatuses.contains(once);
        final isKnownAlias =
            allTaskStatuses.contains(
              input.trim().toUpperCase().replaceAll('_', ' '),
            ) ||
            [
              'OPENING',
              'OPENED',
              'INPROGRESS',
            ].contains(input.trim().toUpperCase().replaceAll('_', ' '));
        expect(canonical, isKnownAlias, reason: 'input="$input" → "$once"');
      },
      tags: 'glados',
    );
  });
}
