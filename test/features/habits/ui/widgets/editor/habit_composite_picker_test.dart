import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/habits/model/habit_form_mapping.dart';
import 'package:lotti/features/habits/ui/widgets/editor/habit_composite_picker.dart';
import 'package:lotti/l10n/app_localizations_en.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  final changes = <(HabitCompositeRule, int)>[];

  Future<void> pump(
    WidgetTester tester, {
    HabitCompositeRule value = HabitCompositeRule.any,
    int required = 1,
    int count = 3,
  }) async {
    changes.clear();
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        HabitCompositePicker(
          value: value,
          requiredCount: required,
          signalCount: count,
          onChanged: (rule, n) => changes.add((rule, n)),
        ),
      ),
    );
    await tester.pump();
  }

  test('labels read as the card shows them', () {
    final m = AppLocalizationsEn();
    expect(habitCompositeLabel(m, HabitCompositeRule.any, 1, 3), 'Any signal');
    expect(habitCompositeLabel(m, HabitCompositeRule.all, 1, 3), 'All signals');
    expect(
      habitCompositeLabel(m, HabitCompositeRule.atLeast, 2, 3),
      'At least 2 of 3',
    );
  });

  testWidgets('a stale count is clamped to what exists', (tester) async {
    await pump(tester, value: HabitCompositeRule.atLeast, required: 9);
    expect(find.text('3 / 3'), findsOneWidget);
  });

  testWidgets('stepping adjusts the count without closing; Done commits', (
    tester,
  ) async {
    await pump(tester, value: HabitCompositeRule.atLeast, required: 2);
    await tester.tap(find.byKey(const ValueKey('habit-composite-decrease')));
    await tester.pump();
    expect(changes.last, (HabitCompositeRule.atLeast, 1));
    expect(find.byType(HabitCompositePicker), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('habit-composite-increase')));
    await tester.pump();
    expect(changes.last, (HabitCompositeRule.atLeast, 2));
    await tester.tap(find.byKey(const ValueKey('habit-composite-done')));
    await tester.pump();
    expect(changes.last, (HabitCompositeRule.atLeast, 2));
  });

  testWidgets('choosing another rule applies it immediately', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('habit-composite-all')));
    await tester.pump();
    expect(changes.last, (HabitCompositeRule.all, 1));
  });
}
