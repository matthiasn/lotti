import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/components/task_list_items/design_system_task_list_item.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../helpers/test_finders.dart';
import '../../../../widget_test_utils.dart';

void main() {
  TextStyle? richTextStyleFor(WidgetTester tester, String text) {
    final richText = tester
        .widgetList<RichText>(find.byType(RichText))
        .firstWhere((widget) => widget.text.toPlainText().contains(text));
    final span = _findTextSpan(richText.text as TextSpan, text);
    return span?.style;
  }

  group('DesignSystemTaskListItem', () {
    testWidgets('renders title, priority, and status', (tester) async {
      const key = Key('basic-task');

      await _pumpTaskListItem(
        tester,
        DesignSystemTaskListItem(
          key: key,
          title: 'User Testing',
          priority: DesignSystemTaskPriority.p2,
          status: DesignSystemTaskStatus.blocked,
          statusLabel: 'Blocked',
          onTap: () {},
        ),
      );

      expect(find.text('User Testing'), findsOneWidget);
      expect(findRichTextContaining('P2'), findsOneWidget);
      expect(find.text('Blocked'), findsOneWidget);
    });

    testWidgets('renders category badge when provided', (tester) async {
      const key = Key('category-task');

      await _pumpTaskListItem(
        tester,
        DesignSystemTaskListItem(
          key: key,
          title: 'Task',
          category: const DesignSystemTaskCategory(
            label: 'Study',
            badgeTone: DesignSystemBadgeTone.success,
          ),
          priority: DesignSystemTaskPriority.p1,
          status: DesignSystemTaskStatus.open,
          statusLabel: 'Open',
          onTap: () {},
        ),
      );

      expect(find.text('Study'), findsOneWidget);
    });

    testWidgets('renders time range when provided', (tester) async {
      const key = Key('time-task');

      await _pumpTaskListItem(
        tester,
        DesignSystemTaskListItem(
          key: key,
          title: 'Task',
          priority: DesignSystemTaskPriority.p2,
          status: DesignSystemTaskStatus.open,
          statusLabel: 'Open',
          timeRange: '8:00-9:30am',
          onTap: () {},
        ),
      );

      expect(findRichTextContaining('8:00-9:30am'), findsOneWidget);
      expect(find.byIcon(Icons.access_time), findsOneWidget);
    });

    testWidgets('does not render time icon when no time range', (
      tester,
    ) async {
      const key = Key('no-time-task');

      await _pumpTaskListItem(
        tester,
        DesignSystemTaskListItem(
          key: key,
          title: 'Task',
          priority: DesignSystemTaskPriority.p1,
          status: DesignSystemTaskStatus.open,
          statusLabel: 'Open',
          onTap: () {},
        ),
      );

      expect(find.byIcon(Icons.access_time), findsNothing);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;

      await _pumpTaskListItem(
        tester,
        DesignSystemTaskListItem(
          title: 'Task',
          priority: DesignSystemTaskPriority.p1,
          status: DesignSystemTaskStatus.open,
          statusLabel: 'Open',
          onTap: () => tapped = true,
        ),
      );

      await tester.tap(find.text('Task'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('shows divider when showDivider is true', (tester) async {
      const key = Key('divider-task');

      await _pumpTaskListItem(
        tester,
        DesignSystemTaskListItem(
          key: key,
          title: 'Task',
          priority: DesignSystemTaskPriority.p1,
          status: DesignSystemTaskStatus.open,
          statusLabel: 'Open',
          showDivider: true,
          onTap: () {},
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(Divider),
        ),
        findsOneWidget,
      );
    });

    testWidgets('does not show divider by default', (tester) async {
      const key = Key('no-divider-task');

      await _pumpTaskListItem(
        tester,
        DesignSystemTaskListItem(
          key: key,
          title: 'Task',
          priority: DesignSystemTaskPriority.p1,
          status: DesignSystemTaskStatus.open,
          statusLabel: 'Open',
          onTap: () {},
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(Divider),
        ),
        findsNothing,
      );
    });

    testWidgets('applies hover background via forcedState', (tester) async {
      const key = Key('hover-task');

      await _pumpTaskListItem(
        tester,
        DesignSystemTaskListItem(
          key: key,
          title: 'Task',
          priority: DesignSystemTaskPriority.p1,
          status: DesignSystemTaskStatus.open,
          statusLabel: 'Open',
          forcedState: DesignSystemTaskListItemVisualState.hover,
          onTap: () {},
        ),
      );

      final ink = tester.widget<Ink>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(Ink),
        ),
      );
      final decoration = ink.decoration! as BoxDecoration;

      expect(decoration.color, dsTokensLight.colors.surface.selected);
    });

    testWidgets('applies pressed background via forcedState', (tester) async {
      const key = Key('pressed-task');

      await _pumpTaskListItem(
        tester,
        DesignSystemTaskListItem(
          key: key,
          title: 'Task',
          priority: DesignSystemTaskPriority.p1,
          status: DesignSystemTaskStatus.open,
          statusLabel: 'Open',
          forcedState: DesignSystemTaskListItemVisualState.pressed,
          onTap: () {},
        ),
      );

      final ink = tester.widget<Ink>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(Ink),
        ),
      );
      final decoration = ink.decoration! as BoxDecoration;

      expect(decoration.color, dsTokensLight.colors.surface.focusPressed);
    });

    testWidgets('priority chip colour, weight, and icon per priority level', (
      tester,
    ) async {
      final cases = [
        (
          DesignSystemTaskPriority.p0,
          'P0',
          dsTokensLight.colors.alert.error.defaultColor,
          Icons.priority_high_rounded,
        ),
        (
          DesignSystemTaskPriority.p1,
          'P1',
          dsTokensLight.colors.alert.error.defaultColor,
          Icons.local_fire_department_rounded,
        ),
        (
          DesignSystemTaskPriority.p2,
          'P2',
          dsTokensLight.colors.alert.warning.defaultColor,
          Icons.circle,
        ),
        (
          DesignSystemTaskPriority.p3,
          'P3',
          dsTokensLight.colors.text.mediumEmphasis,
          Icons.circle,
        ),
      ];

      for (final (priority, label, expectedColor, expectedIcon) in cases) {
        await _pumpTaskListItem(
          tester,
          DesignSystemTaskListItem(
            title: 'Task',
            priority: priority,
            status: DesignSystemTaskStatus.open,
            statusLabel: 'Open',
            onTap: () {},
          ),
        );

        expect(
          richTextStyleFor(tester, label)?.color,
          expectedColor,
          reason: '$label colour',
        );
        expect(
          richTextStyleFor(tester, label)?.fontWeight,
          dsTokensLight.typography.weight.semiBold,
          reason: '$label weight',
        );
        expect(
          find.byIcon(expectedIcon),
          findsOneWidget,
          reason: '$label icon',
        );
      }
    });

    testWidgets('category badge renders on same line as title', (
      tester,
    ) async {
      const key = Key('category-layout-task');

      await _pumpTaskListItem(
        tester,
        const DesignSystemTaskListItem(
          key: key,
          title: 'Task Title',
          category: DesignSystemTaskCategory(
            label: 'Study',
            badgeTone: DesignSystemBadgeTone.success,
          ),
          priority: DesignSystemTaskPriority.p1,
          status: DesignSystemTaskStatus.open,
          statusLabel: 'Open',
        ),
      );

      final titleOffset = tester.getTopLeft(find.text('Task Title'));
      final badgeOffset = tester.getTopLeft(find.text('Study'));

      // Badge should be on the same row (same Y), to the right (higher X)
      expect(badgeOffset.dy, closeTo(titleOffset.dy, 4));
      expect(badgeOffset.dx, greaterThan(titleOffset.dx));
    });

    testWidgets('status text uses high emphasis color for all statuses', (
      tester,
    ) async {
      for (final (status, label) in [
        (DesignSystemTaskStatus.blocked, 'Blocked'),
        (DesignSystemTaskStatus.open, 'Open'),
        (DesignSystemTaskStatus.onHold, 'On Hold'),
      ]) {
        await _pumpTaskListItem(
          tester,
          DesignSystemTaskListItem(
            title: 'Task',
            priority: DesignSystemTaskPriority.p1,
            status: status,
            statusLabel: label,
            onTap: () {},
          ),
        );

        final statusText = tester.widget<Text>(find.text(label));

        expect(
          statusText.style?.color,
          dsTokensLight.colors.text.highEmphasis,
          reason: '$label status should use high emphasis',
        );
      }
    });

    testWidgets('provides semantics label', (tester) async {
      const key = Key('semantics-task');

      await _pumpTaskListItem(
        tester,
        DesignSystemTaskListItem(
          key: key,
          title: 'Task',
          priority: DesignSystemTaskPriority.p1,
          status: DesignSystemTaskStatus.open,
          statusLabel: 'Open',
          semanticsLabel: 'User Testing task',
          onTap: () {},
        ),
      );

      final semantics = tester.widget<Semantics>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'User Testing task',
          ),
        ),
      );

      expect(semantics.properties.label, 'User Testing task');
    });

    testWidgets('category badge renders as DesignSystemBadge', (
      tester,
    ) async {
      const key = Key('badge-category-task');

      await _pumpTaskListItem(
        tester,
        const DesignSystemTaskListItem(
          key: key,
          title: 'Task',
          category: DesignSystemTaskCategory(
            label: 'Study',
            badgeTone: DesignSystemBadgeTone.success,
          ),
          priority: DesignSystemTaskPriority.p1,
          status: DesignSystemTaskStatus.open,
          statusLabel: 'Open',
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(DesignSystemBadge),
        ),
        findsOneWidget,
      );
      expect(find.text('Study'), findsOneWidget);
    });

    testWidgets('renders the matching status icon per status', (tester) async {
      // The fire icon for P1 priority is covered by the priority loop above.
      final cases = [
        (
          DesignSystemTaskStatus.blocked,
          'Blocked',
          Icons.warning_amber_rounded,
        ),
        (DesignSystemTaskStatus.open, 'Open', Icons.circle_outlined),
        (DesignSystemTaskStatus.onHold, 'On Hold', Icons.pause_rounded),
      ];

      for (final (status, label, expectedIcon) in cases) {
        await _pumpTaskListItem(
          tester,
          DesignSystemTaskListItem(
            title: 'Task',
            priority: DesignSystemTaskPriority.p1,
            status: status,
            statusLabel: label,
            onTap: () {},
          ),
        );

        expect(find.byIcon(expectedIcon), findsOneWidget, reason: label);
      }
    });

    testWidgets('resets hover/pressed when forcedState changes', (
      tester,
    ) async {
      const key = Key('update-task');

      await _pumpTaskListItem(
        tester,
        DesignSystemTaskListItem(
          key: key,
          title: 'Task',
          priority: DesignSystemTaskPriority.p1,
          status: DesignSystemTaskStatus.open,
          statusLabel: 'Open',
          onTap: () {},
        ),
      );

      // Rebuild with a forced state to trigger didUpdateWidget
      await _pumpTaskListItem(
        tester,
        DesignSystemTaskListItem(
          key: key,
          title: 'Task',
          priority: DesignSystemTaskPriority.p1,
          status: DesignSystemTaskStatus.open,
          statusLabel: 'Open',
          forcedState: DesignSystemTaskListItemVisualState.hover,
          onTap: () {},
        ),
      );

      final ink = tester.widget<Ink>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(Ink),
        ),
      );
      final decoration = ink.decoration! as BoxDecoration;

      expect(decoration.color, dsTokensLight.colors.surface.selected);
    });

    testWidgets('resets hover/pressed when onTap changes to null', (
      tester,
    ) async {
      const key = Key('disable-task');

      await _pumpTaskListItem(
        tester,
        DesignSystemTaskListItem(
          key: key,
          title: 'Task',
          priority: DesignSystemTaskPriority.p1,
          status: DesignSystemTaskStatus.open,
          statusLabel: 'Open',
          onTap: () {},
        ),
      );

      // Rebuild with onTap = null to trigger didUpdateWidget reset
      await _pumpTaskListItem(
        tester,
        const DesignSystemTaskListItem(
          key: key,
          title: 'Task',
          priority: DesignSystemTaskPriority.p1,
          status: DesignSystemTaskStatus.open,
          statusLabel: 'Open',
        ),
      );

      final ink = tester.widget<Ink>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(Ink),
        ),
      );
      final decoration = ink.decoration! as BoxDecoration;

      // Should be idle (transparent) since disabled
      expect(decoration.color, Colors.transparent);
    });

    testWidgets('hover interaction changes background', (tester) async {
      const key = Key('hover-interact-task');

      await _pumpTaskListItem(
        tester,
        DesignSystemTaskListItem(
          key: key,
          title: 'Task',
          priority: DesignSystemTaskPriority.p1,
          status: DesignSystemTaskStatus.open,
          statusLabel: 'Open',
          onTap: () {},
        ),
      );

      // Simulate hover
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      await gesture.moveTo(tester.getCenter(find.byKey(key)));
      await tester.pump();

      final ink = tester.widget<Ink>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(Ink),
        ),
      );
      final decoration = ink.decoration! as BoxDecoration;

      expect(decoration.color, dsTokensLight.colors.surface.selected);
    });
  });
}

Future<void> _pumpTaskListItem(
  WidgetTester tester,
  Widget child,
) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      child,
      theme: DesignSystemTheme.light(),
    ),
  );
}

TextSpan? _findTextSpan(TextSpan span, String text) {
  if (span.text?.contains(text) ?? false) {
    return span;
  }

  for (final child in span.children ?? const <InlineSpan>[]) {
    if (child case final TextSpan textChild) {
      final match = _findTextSpan(textChild, text);
      if (match != null) {
        return match;
      }
    }
  }

  return null;
}
