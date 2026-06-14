import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/ui/widgets/insights_kpi_row.dart';

import '../../../../widget_test_utils.dart';
import '../../../categories/test_utils.dart';

void main() {
  const desktopMq = MediaQueryData(size: Size(1280, 900));

  final categories = [
    CategoryTestUtils.createTestCategory(id: 'cat-a', name: 'Client Work'),
    CategoryTestUtils.createTestCategory(id: 'cat-b', name: 'Admin'),
  ];

  Future<void> pumpRow(
    WidgetTester tester, {
    required InsightsKpis kpis,
    Set<String> focusIds = const {},
    ValueChanged<String>? onToggle,
  }) {
    return tester.pumpWidget(
      makeTestableWidget(
        mediaQueryData: desktopMq,
        InsightsKpiRow(
          kpis: kpis,
          categories: categories,
          focusCategoryIds: focusIds,
          onToggleFocusCategory: onToggle ?? (_) {},
        ),
      ),
    );
  }

  testWidgets(
    'unconfigured: shows only the total tile plus the focus affordance — '
    'no dead zero tiles',
    (tester) async {
      await pumpRow(
        tester,
        kpis: const InsightsKpis(
          totalSeconds: 9 * 3600 + 30 * 60,
          focusSeconds: null,
          otherSeconds: null,
        ),
      );

      expect(find.text('TOTAL'), findsOneWidget);
      expect(find.text('9h 30m'), findsOneWidget);
      expect(find.text('FOCUS'), findsNothing);
      expect(find.text('OTHER'), findsNothing);
      expect(find.text('Choose focus categories'), findsOneWidget);
    },
  );

  testWidgets('configured: renders total, focus, and other values', (
    tester,
  ) async {
    await pumpRow(
      tester,
      kpis: const InsightsKpis(
        totalSeconds: 10 * 3600,
        focusSeconds: 7 * 3600,
        otherSeconds: 3 * 3600,
      ),
      focusIds: const {'cat-a'},
    );

    expect(find.text('TOTAL'), findsOneWidget);
    expect(find.text('10h'), findsOneWidget);
    expect(find.text('FOCUS'), findsOneWidget);
    expect(find.text('7h'), findsOneWidget);
    expect(find.text('OTHER'), findsOneWidget);
    expect(find.text('3h'), findsOneWidget);
    expect(find.text('Choose focus categories'), findsNothing);
  });

  testWidgets(
    'the affordance opens the picker dialog and toggling a category '
    'reports the id',
    (tester) async {
      final toggled = <String>[];
      await pumpRow(
        tester,
        kpis: const InsightsKpis(
          totalSeconds: 3600,
          focusSeconds: null,
          otherSeconds: null,
        ),
        onToggle: toggled.add,
      );

      await tester.tap(find.text('Choose focus categories'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Focus categories'), findsOneWidget);
      expect(find.text('Client Work'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);

      await tester.tap(find.text('Client Work'));
      await tester.pump();
      expect(toggled, ['cat-a']);

      // The checkbox reflects the local selection immediately.
      final checkbox = tester.widget<CheckboxListTile>(
        find.ancestor(
          of: find.text('Client Work'),
          matching: find.byType(CheckboxListTile),
        ),
      );
      expect(checkbox.value, isTrue);

      await tester.tap(find.text('Done'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Focus categories'), findsNothing);
    },
  );

  testWidgets('the picker explains itself when no categories exist yet', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidget(
        mediaQueryData: desktopMq,
        InsightsKpiRow(
          kpis: const InsightsKpis(
            totalSeconds: 3600,
            focusSeconds: null,
            otherSeconds: null,
          ),
          categories: const [],
          focusCategoryIds: const {},
          onToggleFocusCategory: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('Choose focus categories'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('No active categories yet.'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
  });

  testWidgets(
    'focus/other tiles carry plain-language helper glosses for newcomers',
    (tester) async {
      await pumpRow(
        tester,
        kpis: const InsightsKpis(
          totalSeconds: 10 * 3600,
          focusSeconds: 7 * 3600,
          otherSeconds: 3 * 3600,
        ),
        focusIds: const {'cat-a'},
      );

      // The terse FOCUS/OTHER eyebrows are glossed so a first-time user knows
      // what each counts; the focus tile also still names the chosen category.
      expect(find.text("Categories you're watching"), findsOneWidget);
      expect(find.text('Everything else'), findsOneWidget);
      expect(find.text('Client Work'), findsOneWidget);
    },
  );

  testWidgets('configured row exposes an edit affordance on the focus tile', (
    tester,
  ) async {
    await pumpRow(
      tester,
      kpis: const InsightsKpis(
        totalSeconds: 7200,
        focusSeconds: 3600,
        otherSeconds: 3600,
      ),
      focusIds: const {'cat-a'},
    );

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Focus categories'), findsOneWidget);
  });
}
