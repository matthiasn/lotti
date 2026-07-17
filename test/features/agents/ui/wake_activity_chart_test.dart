import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/hourly_wake_activity.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/agents/ui/wake_activity_chart.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../widget_test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  /// 24 hourly buckets starting 2026-04-04 00:00; [dataByHour] maps an
  /// hour index to its wake reasons.
  List<HourlyWakeActivity> makeBuckets({
    Map<int, Map<String, int>> dataByHour = const {},
  }) {
    return List.generate(24, (i) {
      final reasons = dataByHour[i] ?? const {};
      final count = reasons.values.fold<int>(0, (s, c) => s + c);
      return HourlyWakeActivity(
        hour: DateTime(2026, 4, 4, i),
        count: count,
        reasons: reasons,
      );
    });
  }

  Widget buildSubject({required List<HourlyWakeActivity> buckets}) {
    return makeTestableWidgetNoScroll(
      const Scaffold(body: SingleChildScrollView(child: WakeActivityChart())),
      theme: DesignSystemTheme.light(),
      overrides: [
        hourlyWakeActivityProvider.overrideWith((ref) async => buckets),
      ],
    );
  }

  /// The painted hour-bar containers, in render order (empty hours paint
  /// a zero-height fraction, so every hour has one).
  List<Container> barContainers(WidgetTester tester) => tester
      .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
      .map((f) => (f.child! as Center).child! as Container)
      .toList();

  DsTokens tokensOf(WidgetTester tester) =>
      tester.element(find.byType(WakeActivityChart)).designTokens;

  testWidgets('hides the whole section when no hour has wakes', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(buckets: makeBuckets()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(WakeActivityChart), findsOneWidget);
    final context = tester.element(find.byType(WakeActivityChart));
    expect(
      find.text(context.messages.agentPendingWakesActivityTitle),
      findsNothing,
    );
    expect(find.byType(FractionallySizedBox), findsNothing);
  });

  testWidgets('shows heading, total, and hour labels — no y-axis chrome', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        buckets: makeBuckets(
          dataByHour: {
            10: const {'subscription': 3, 'creation': 2},
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final context = tester.element(find.byType(WakeActivityChart));
    expect(
      find.text(context.messages.agentPendingWakesActivityTitle),
      findsOneWidget,
    );
    expect(
      find.text(context.messages.agentPendingWakesActivityTotal(5)),
      findsOneWidget,
    );

    // Sparse labels at 0/6/12/18 plus the final column, each in its own
    // Expanded slot so it sits under the hour it names.
    for (final label in ['00:00', '06:00', '12:00', '18:00', '23:00']) {
      expect(find.textContaining(label), findsWidgets, reason: label);
    }
    // The y-axis tick numbers are gone — height + tap detail carry the
    // magnitudes now.
    expect(find.text('5'), findsNothing);
    expect(find.text('0'), findsNothing);
  });

  testWidgets(
    'defaults to the most recent active hour — detail without any tap',
    (tester) async {
      await tester.pumpWidget(
        buildSubject(
          buckets: makeBuckets(
            dataByHour: {
              3: const {'scheduled': 4},
              9: const {'manual': 1},
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Hour 9 is not the peak (hour 3 has 4 wakes) but it is the newest
      // activity — the "default to now" anchor — and it is narrated
      // immediately, before any interaction.
      expect(find.textContaining('09:00'), findsOneWidget);
      expect(find.textContaining('manual\u00a01'), findsOneWidget);
    },
  );

  testWidgets('a tap retargets the detail and never clears it', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        buckets: makeBuckets(
          dataByHour: {
            3: const {'scheduled': 2},
            9: const {'manual': 5},
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Default = peak (09:00). Tap hour 3's bar: the detail retargets.
    await tester.tap(find.bySemanticsLabel('03:00: 2 wakes'));
    await tester.pump();
    expect(find.textContaining('Scheduled\u00a02'), findsOneWidget);

    // Re-tapping the same bar keeps the detail — retarget-only, so the
    // card never changes height under the pointer.
    await tester.tap(find.bySemanticsLabel('03:00: 2 wakes'));
    await tester.pump();
    expect(find.textContaining('Scheduled\u00a02'), findsOneWidget);
  });

  testWidgets('empty hours keep full-height, accessible tap targets', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        buckets: makeBuckets(
          dataByHour: {
            3: const {'scheduled': 2},
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Hour 7 recorded nothing but still announces itself. The default
    // detail narrates the busiest hour (03:00)…
    expect(find.textContaining('03:00'), findsOneWidget);

    // …and tapping the empty hour's full-column target genuinely
    // retargets the detail line to 07:00 (with zero wakes), rather than
    // being a dead zone.
    await tester.tap(find.bySemanticsLabel('07:00: 0 wakes'));
    await tester.pump();
    expect(find.textContaining('07:00'), findsOneWidget);
    expect(find.textContaining('03:00'), findsNothing);
  });

  testWidgets('arrow keys step the hour selection once focused', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        buckets: makeBuckets(
          dataByHour: {
            3: const {'scheduled': 2},
            9: const {'manual': 5},
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Default selection is the peak (09:00). Focus the chart via a
    // context below its FocusableActionDetector, then step left.
    Focus.of(
      tester.element(find.bySemanticsLabel('09:00: 5 wakes')),
    ).requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();

    // 08:00 is the neighbouring column (empty, but selectable — the
    // detail line reports its zero-wake state).
    expect(find.textContaining('08:00'), findsOneWidget);

    // Clamped at the left edge: stepping to 00:00 and beyond stays put.
    for (var i = 0; i < 12; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
    }
    expect(find.textContaining('00:00'), findsWidgets);
  });

  testWidgets('history is grey; the accent belongs to the selected hour', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        buckets: makeBuckets(
          dataByHour: {
            3: const {'scheduled': 2},
            9: const {'manual': 5},
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final tokens = tokensOf(tester);
    final context = tester.element(find.byType(WakeActivityChart));
    final decorations = barContainers(
      tester,
    ).map((c) => c.decoration! as BoxDecoration).toList();

    // Ring = selection, teal = today only — and an hour histogram has no
    // today, so every bar rides the shared grey ramp: the selected (peak)
    // hour 9 is one step brighter plus the hue-independent ring,
    // unselected hour 3 sits at the resting step.
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final selected = decorations[9];
    final unselected = decorations[3];
    expect(selected.color, onSurfaceVariant.withValues(alpha: 0.75));
    expect(
      (selected.border! as Border).top.color,
      tokens.colors.text.highEmphasis,
    );
    expect(unselected.color, onSurfaceVariant.withValues(alpha: 0.45));
    expect(unselected.border, isNull);
  });

  testWidgets('a horizontal scrub retargets the hour continuously', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        buckets: makeBuckets(
          dataByHour: {
            3: const {'scheduled': 2},
            9: const {'manual': 5},
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Default = peak (09:00). Drag from the left edge across the first
    // columns: the detail line follows the pointer instead of waiting
    // for a precise per-column tap.
    final chartBox = tester.getRect(find.bySemanticsLabel('00:00: 0 wakes'));
    final gesture = await tester.startGesture(
      Offset(chartBox.left + 2, chartBox.center.dy),
    );
    await tester.pump();
    await gesture.moveBy(Offset(chartBox.width * 3.5, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(find.textContaining('03:00'), findsOneWidget);
    expect(find.textContaining('09:00'), findsNothing);
  });
}
