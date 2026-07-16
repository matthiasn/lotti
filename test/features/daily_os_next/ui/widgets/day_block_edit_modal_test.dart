import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_block_edit_modal.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/time_pickers/design_system_picker_wheels.dart';
import 'package:lotti/widgets/settings/settings_picker_field.dart';

import '../../../../widget_test_utils.dart';
import '../../../categories/test_utils.dart';

const _focus = DayAgentCategory(
  id: 'focus',
  name: 'Deep Work',
  colorHex: '6750A4',
);

TimeBlock _block({
  String title = 'Rehearse emergency penguin briefing',
  String? taskId,
  TimeBlockType type = TimeBlockType.ai,
  DateTime? start,
  DateTime? end,
  String? reason = 'The penguins are most diplomatic before lunch.',
}) => TimeBlock(
  id: 'block-1',
  title: title,
  start: start ?? DateTime(2024, 3, 15, 9),
  end: end ?? DateTime(2024, 3, 15, 10, 30),
  type: type,
  state: TimeBlockState.drafted,
  category: _focus,
  taskId: taskId,
  reason: reason,
);

class _Launcher extends StatelessWidget {
  const _Launcher({
    required this.block,
    required this.onResult,
    required this.categories,
    this.onOpenTask,
  });

  final TimeBlock block;
  final ValueChanged<DayBlockEditResult?> onResult;
  final List<CategoryDefinition> categories;
  final VoidCallback? onOpenTask;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async => onResult(
        await DayBlockEditModal.show(
          context: context,
          block: block,
          categoryOptions: categories,
          onOpenTask: onOpenTask,
        ),
      ),
      child: const Text('Open'),
    );
  }
}

void main() {
  final focusDefinition = CategoryTestUtils.createTestCategory(
    id: _focus.id,
    name: _focus.name,
    color: '#${_focus.colorHex}',
    isAvailableForDayPlan: true,
  );
  final comedyDefinition = CategoryTestUtils.createTestCategory(
    id: 'comedy',
    name: 'Strategic Nonsense',
    color: '#FF8A65',
    isAvailableForDayPlan: true,
  );
  final invalidColorDefinition = CategoryTestUtils.createTestCategory(
    id: 'mystery',
    name: 'Mysterious Operations',
    color: '#NOPE',
    isAvailableForDayPlan: true,
  );
  final longColorDefinition = CategoryTestUtils.createTestCategory(
    id: 'long-color',
    name: 'Chromatic Research',
    color: '#A1B2C3FF',
    isAvailableForDayPlan: true,
  );
  final shorthandColorDefinition = CategoryTestUtils.createTestCategory(
    id: 'shorthand-color',
    name: 'Tiny Paint Department',
    color: '#a5F',
    isAvailableForDayPlan: true,
  );

  void useWideView(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(1600, 1800)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  Future<void> openModal(
    WidgetTester tester, {
    required TimeBlock block,
    required ValueChanged<DayBlockEditResult?> onResult,
    VoidCallback? onOpenTask,
    MediaQueryData? mediaQueryData,
  }) async {
    useWideView(tester);
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        _Launcher(
          block: block,
          onResult: onResult,
          categories: [
            focusDefinition,
            comedyDefinition,
            invalidColorDefinition,
            longColorDefinition,
            shorthandColorDefinition,
          ],
          onOpenTask: onOpenTask,
        ),
        mediaQueryData: mediaQueryData,
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  DesignSystemButton button(WidgetTester tester, String label) =>
      tester.widget<DesignSystemButton>(
        find.widgetWithText(DesignSystemButton, label),
      );

  Finder timeField() => find.byWidgetPredicate(
    (widget) => widget is SettingsPickerField && widget.label == 'Start & end',
  );

  String timeValue(WidgetTester tester) =>
      tester.widget<SettingsPickerField>(timeField()).valueText!;

  testWidgets('overview uses the design-system editor and explains placement', (
    tester,
  ) async {
    await openModal(tester, block: _block(), onResult: (_) {});

    expect(find.text('Edit block'), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Start & end'), findsOneWidget);
    expect(find.text('Why this time'), findsOneWidget);
    expect(
      find.text('The penguins are most diplomatic before lunch.'),
      findsOneWidget,
    );
    expect(timeValue(tester), contains('9:00'));
    expect(timeValue(tester), contains('10:30'));
    expect(button(tester, 'Save changes').onPressed, isNull);
  });

  testWidgets('time page reuses wheels and only commits from the overview', (
    tester,
  ) async {
    DayBlockEditResult? result;
    await openModal(
      tester,
      block: _block(),
      onResult: (value) => result = value,
    );

    await tester.tap(timeField());
    await tester.pumpAndSettle();

    expect(find.byType(DesignSystemTimeWheel), findsNWidgets(2));
    expect(find.text('Pick a separate end date'), findsNothing);
    expect(find.text('Done'), findsOneWidget);

    final wheels = tester
        .widgetList<DesignSystemTimeWheel>(find.byType(DesignSystemTimeWheel))
        .toList();
    wheels.first.onDateTimeChanged(DateTime(2024, 3, 15, 8, 30));
    wheels.last.onDateTimeChanged(DateTime(2024, 3, 15, 10));
    await tester.pump();

    expect(result, isNull);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(timeValue(tester), contains('8:30'));
    expect(timeValue(tester), contains('10:00'));

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(result?.start, DateTime(2024, 3, 15, 8, 30));
    expect(result?.end, DateTime(2024, 3, 15, 10));
    expect(result?.title, _block().title);
    expect(result?.category, _focus);
  });

  testWidgets('time-page Back discards only that navigation step', (
    tester,
  ) async {
    DayBlockEditResult? result;
    await openModal(
      tester,
      block: _block(),
      onResult: (value) => result = value,
    );

    final originalRange = timeValue(tester);
    await tester.tap(timeField());
    await tester.pumpAndSettle();
    expect(find.byType(DesignSystemTimeWheel), findsNWidgets(2));

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Edit block'), findsOneWidget);
    expect(timeValue(tester), originalRange);
    expect(result, isNull);
  });

  testWidgets('standalone title and category changes are returned atomically', (
    tester,
  ) async {
    DayBlockEditResult? result;
    await openModal(
      tester,
      block: _block(),
      onResult: (value) => result = value,
    );

    await tester.enterText(
      find.byType(TextField),
      'Negotiate fish budget with the penguins',
    );
    await tester.tap(find.text('Deep Work'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Strategic Nonsense'));
    await tester.pumpAndSettle();

    expect(button(tester, 'Save changes').onPressed, isNotNull);
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(result?.title, 'Negotiate fish budget with the penguins');
    expect(result?.category.id, 'comedy');
    expect(result?.category.name, 'Strategic Nonsense');
    expect(result?.category.colorHex, 'FF8A65');
    expect(result?.start, _block().start);
    expect(result?.end, _block().end);
  });

  testWidgets('task-owned fields stay read-only and can open the task', (
    tester,
  ) async {
    var openTaskCalls = 0;
    await openModal(
      tester,
      block: _block(taskId: 'task-1'),
      onResult: (_) {},
      onOpenTask: () => openTaskCalls += 1,
    );

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Rehearse emergency penguin briefing'), findsOneWidget);
    expect(find.text('Deep Work'), findsOneWidget);

    await tester.tap(find.text('Open task'));
    await tester.pump();
    expect(openTaskCalls, 1);
  });

  testWidgets('task-owned overview works without an open-task route', (
    tester,
  ) async {
    await openModal(
      tester,
      block: _block(taskId: 'task-1', reason: null),
      onResult: (_) {},
    );

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Open task'), findsNothing);
    expect(find.text('Why this time'), findsNothing);
    expect(timeField(), findsOneWidget);
  });

  testWidgets('buffer overview exposes only its editable time range', (
    tester,
  ) async {
    DayBlockEditResult? result;
    final block = _block(
      title: '',
      type: TimeBlockType.buffer,
      reason: null,
    );
    await openModal(
      tester,
      block: block,
      onResult: (value) => result = value,
    );

    expect(find.text('Title'), findsNothing);
    expect(find.text('Category'), findsNothing);
    expect(find.text('Why this time'), findsNothing);
    expect(timeField(), findsOneWidget);

    await tester.tap(timeField());
    await tester.pumpAndSettle();
    final wheels = tester
        .widgetList<DesignSystemTimeWheel>(find.byType(DesignSystemTimeWheel))
        .toList();
    wheels.first.onDateTimeChanged(DateTime(2024, 3, 15, 10));
    wheels.last.onDateTimeChanged(DateTime(2024, 3, 15, 11));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(result?.title, isEmpty);
    expect(result?.category, _focus);
    expect(result?.start, DateTime(2024, 3, 15, 10));
    expect(result?.end, DateTime(2024, 3, 15, 11));
  });

  testWidgets('closing the overview returns no partial draft', (tester) async {
    DayBlockEditResult? result = DayBlockEditResult(
      title: 'sentinel',
      category: _focus,
      start: DateTime(2024),
      end: DateTime(2024, 1, 1, 1),
    );
    await openModal(
      tester,
      block: _block(),
      onResult: (value) => result = value,
    );

    await tester.enterText(find.byType(TextField), 'Unsaved fish protocol');
    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('blank title and a cancelled category picker cannot save', (
    tester,
  ) async {
    await openModal(tester, block: _block(), onResult: (_) {});

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(button(tester, 'Save changes').onPressed, isNull);

    await tester.enterText(find.byType(TextField), _block().title);
    await tester.tap(find.text('Deep Work'));
    await tester.pumpAndSettle();
    expect(find.text('Mysterious Operations'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();

    expect(find.text('Edit block'), findsOneWidget);
    expect(find.text('Mysterious Operations'), findsNothing);
    expect(button(tester, 'Save changes').onPressed, isNull);
  });

  testWidgets('category colors normalize or fall back without visual errors', (
    tester,
  ) async {
    DayBlockEditResult? result;
    await openModal(
      tester,
      block: _block(),
      onResult: (value) => result = value,
    );

    await tester.tap(find.text('Deep Work'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mysterious Operations'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(result?.category.id, 'mystery');
    expect(result?.category.colorHex, _focus.colorHex);

    result = null;
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deep Work'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chromatic Research'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(result?.category.id, 'long-color');
    expect(result?.category.colorHex, 'A1B2C3');

    result = null;
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deep Work'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiny Paint Department'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(result?.category.id, 'shorthand-color');
    expect(result?.category.colorHex, 'AA55FF');
  });

  testWidgets('same-day constraint disables overnight edits', (tester) async {
    await openModal(tester, block: _block(), onResult: (_) {});
    await tester.tap(timeField());
    await tester.pumpAndSettle();

    final wheels = tester
        .widgetList<DesignSystemTimeWheel>(find.byType(DesignSystemTimeWheel))
        .toList();
    wheels.last.onDateTimeChanged(DateTime(2024, 3, 15, 8));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(button(tester, 'Save changes').onPressed, isNull);
  });

  testWidgets('the plan-day boundary permits an end exactly at midnight', (
    tester,
  ) async {
    DayBlockEditResult? result;
    await openModal(
      tester,
      block: _block(),
      onResult: (value) => result = value,
    );
    await tester.tap(timeField());
    await tester.pumpAndSettle();

    final wheels = tester
        .widgetList<DesignSystemTimeWheel>(find.byType(DesignSystemTimeWheel))
        .toList();
    wheels.first.onDateTimeChanged(DateTime(2024, 3, 15, 23));
    wheels.last.onDateTimeChanged(DateTime(2024, 3, 16));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(button(tester, 'Save changes').onPressed, isNotNull);
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(result?.start, DateTime(2024, 3, 15, 23));
    expect(result?.end, DateTime(2024, 3, 16));
  });

  testWidgets('UTC blocks retain UTC at the plan-day boundary', (tester) async {
    DayBlockEditResult? result;
    await openModal(
      tester,
      block: _block(
        start: DateTime.utc(2024, 3, 15, 22),
        end: DateTime.utc(2024, 3, 15, 23),
      ),
      onResult: (value) => result = value,
    );
    await tester.tap(timeField());
    await tester.pumpAndSettle();

    final wheels = tester
        .widgetList<DesignSystemTimeWheel>(find.byType(DesignSystemTimeWheel))
        .toList();
    wheels.first.onDateTimeChanged(DateTime.utc(2024, 3, 15, 23));
    wheels.last.onDateTimeChanged(DateTime.utc(2024, 3, 16));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(result?.start, DateTime.utc(2024, 3, 15, 23));
    expect(result?.end, DateTime.utc(2024, 3, 16));
    expect(result?.start.isUtc, isTrue);
  });

  testWidgets('large text stacks the shared time wheels without overflow', (
    tester,
  ) async {
    await openModal(
      tester,
      block: _block(),
      onResult: (_) {},
      mediaQueryData: const MediaQueryData(
        size: Size(800, 900),
        textScaler: TextScaler.linear(1.6),
      ),
    );
    await tester.tap(timeField());
    await tester.pumpAndSettle();

    final wheels = find.byType(DesignSystemTimeWheel);
    expect(wheels, findsNWidgets(2));
    expect(
      tester.getTopLeft(wheels.first).dx,
      tester.getTopLeft(wheels.last).dx,
    );
    expect(tester.takeException(), isNull);
  });
}
