import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_persona_provider.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/plan_view_toggle.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/processing_category_filter_button.dart';

import '../../../../widget_test_utils.dart';
import 'day_page_test_helpers.dart';

/// Layout tests for the day header's custom render object
/// (`day_page_header.dart`): when the toggle rides the title row, when day
/// navigation takes a row of its own, and when the actions drop below the
/// toggle. Driven through [DayPage], which is what builds that header.
void main() {
  group('DayHeader layout', () {
    testWidgets('header stacks the three-view toggle when it needs room', (
      tester,
    ) async {
      setTestSurfaceSize(tester, const Size(640, 844));
      const label = 'May 31, 2026';
      await tester.pumpWidget(
        wrapDayPage(
          DayPage(
            draft: draftedPlan(),
            dateStrip: dateStripLike(label),
          ),
          mediaQueryData: phoneMediaQueryData.copyWith(
            size: const Size(640, 844),
          ),
        ),
      );
      await tester.pump();

      final dateBottom = tester.getBottomLeft(find.text(label)).dy;
      final toggleTop = tester.getTopLeft(find.byType(PlanViewToggle)).dy;

      expect(toggleTop, greaterThan(dateBottom));
      expect(tester.takeException(), isNull);
    });

    testWidgets('header moves the plan toggle below only when it cannot fit', (
      tester,
    ) async {
      setTestSurfaceSize(tester, phoneMediaQueryData.size);
      const label = 'May 31, 2026';
      await tester.pumpWidget(
        wrapDayPage(
          DayPage(
            draft: draftedPlan(),
            dateStrip: dateStripLike(label),
          ),
          mediaQueryData: phoneMediaQueryData,
        ),
      );
      await tester.pump();

      final dateBottom = tester.getBottomLeft(find.text(label)).dy;
      final toggleTop = tester.getTopLeft(find.byType(PlanViewToggle)).dy;

      expect(find.text(label), findsOneWidget);
      expect(toggleTop, greaterThan(dateBottom));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'a second row too narrow for both drops the actions below the toggle',
      (tester) async {
        // Narrow enough that the toggle and the trailing actions cannot sit
        // side by side. Pinning them to opposite edges without a fit check
        // overlapped them, hiding toggle segments behind the filter/menu
        // cluster.
        setTestSurfaceSize(tester, const Size(390, 900));
        const label = 'May 31, 2026';
        await tester.pumpWidget(
          wrapDayPage(
            DayPage(
              draft: draftedPlan(),
              dateStrip: dateStripLike(label),
            ),
            mediaQueryData: phoneMediaQueryData.copyWith(
              size: const Size(390, 900),
              textScaler: const TextScaler.linear(1.3),
            ),
            overrides: [
              // A non-idle agent renders the "Needs attention" pill, which is
              // what makes the actions cluster wide enough to collide.
              dayAgentPersonaStateProvider.overrideWith(
                (ref, date) async => DayAgentPersonaState.attention,
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        final toggle = tester.getRect(find.byType(PlanViewToggle));
        final actions = tester.getRect(
          find.byType(ProcessingCategoryFilterButton),
        );
        expect(
          toggle.overlaps(actions),
          isFalse,
          reason: 'the toggle and the header actions must never overlap',
        );
        // With no room for both, the actions take a row of their own rather
        // than the toggle being squeezed below its shrink-wrapped width.
        expect(
          actions.top,
          greaterThanOrEqualTo(toggle.bottom),
          reason: 'the actions must drop below the toggle, not beside it',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('header relayouts when design-system spacing changes', (
      tester,
    ) async {
      setTestSurfaceSize(tester, const Size(640, 844));
      const label = 'May 31, 2026';
      final mediaQueryData = phoneMediaQueryData.copyWith(
        size: const Size(640, 844),
      );
      await tester.pumpWidget(
        wrapDayPage(
          DayPage(
            draft: draftedPlan(),
            dateStrip: dateStripLike(label),
          ),
          mediaQueryData: mediaQueryData,
          theme: themeWithHeaderSpacing(20),
        ),
      );
      await tester.pump();
      final firstTop = tester.getTopLeft(find.text(label)).dy;

      await tester.pumpWidget(
        wrapDayPage(
          DayPage(
            draft: draftedPlan(),
            dateStrip: dateStripLike(label),
          ),
          mediaQueryData: mediaQueryData,
          theme: themeWithHeaderSpacing(32),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      final secondTop = tester.getTopLeft(find.text(label)).dy;

      expect(secondTop, greaterThan(firstTop));
      expect(tester.takeException(), isNull);
    });
  });
}
