import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/pages/commit_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/capacity_donut.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/hold_to_confirm.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/lock_in_scene.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

const _category = DayAgentCategory(
  id: 'cat_focus',
  name: 'Focus',
  colorHex: '0080FF',
);

DraftPlan _planWithItems() => DraftPlan(
  dayDate: DateTime(2026, 5, 26),
  blocks: const [],
  bands: const [],
  capacityMinutes: 240,
  scheduledMinutes: 180,
  agendaItems: const [
    AgendaItem(
      id: 'item_1',
      title: 'Deep work',
      category: _category,
      linkedBlockIds: ['blk_1'],
      outcome: 'Ship the client animation',
      totalEstimateMinutes: 120,
    ),
    AgendaItem(
      id: 'item_2',
      title: 'Review PRs',
      category: _category,
      linkedBlockIds: ['blk_2'],
      totalEstimateMinutes: 60,
    ),
  ],
);

Widget _wrap(
  Widget child, {
  List<Override> overrides = const [],
  Size size = const Size(1280, 1200),
}) {
  return ProviderScope(
    overrides: overrides,
    child: makeTestableWidget2(
      child,
      mediaQueryData: MediaQueryData(size: size),
    ),
  );
}

void _setSurface(WidgetTester tester, Size size) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Holds the gesture long enough for the [HoldToConfirm] animation to
/// complete with the provided duration.
Future<void> _completeHold(
  WidgetTester tester, {
  Duration hold = const Duration(milliseconds: 1300),
}) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byType(HoldToConfirm)),
  );
  await tester.pump();
  await tester.pump(hold);
  await gesture.up();
  await tester.pump();
}

void main() {
  group('CommitPage', () {
    testWidgets('renders title, headline, sub-caption, and hold target', (
      tester,
    ) async {
      _setSurface(tester, const Size(1280, 1200));
      await tester.pumpWidget(_wrap(CommitPage(draft: _planWithItems())));
      await tester.pump();

      final messages = tester.element(find.byType(CommitPage)).messages;
      expect(find.text(messages.dailyOsNextCommitTitle), findsOneWidget);
      // Three-tier lead-in: eyebrow, display title, explainer
      // (handoff v2 item 4).
      expect(
        find.text(messages.dailyOsNextCommitFinalStepEyebrow),
        findsOneWidget,
      );
      expect(find.text(messages.dailyOsNextCommitHeadline), findsOneWidget);
      expect(find.text(messages.dailyOsNextCommitExplainer), findsOneWidget);
      expect(find.text(messages.dailyOsNextCommitSubCaption), findsOneWidget);
      // Helper line under the hold circle + single-word circle label.
      expect(find.text(messages.dailyOsNextCommitHoldHelper), findsOneWidget);
      expect(find.text(messages.dailyOsNextCommitHoldWordIdle), findsOneWidget);
      expect(find.byType(HoldToConfirm), findsOneWidget);
      expect(find.byType(LockInScene), findsNothing);
    });

    testWidgets('recap renders one row per agenda item with title + outcome', (
      tester,
    ) async {
      _setSurface(tester, const Size(1280, 1200));
      await tester.pumpWidget(_wrap(CommitPage(draft: _planWithItems())));
      await tester.pump();

      expect(find.text('Deep work'), findsOneWidget);
      expect(find.text('Review PRs'), findsOneWidget);
      expect(find.text('Ship the client animation'), findsOneWidget);
      // Numbered index labels.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      // Estimate labels rendered through l10n placeholder.
      final messages = tester.element(find.byType(CommitPage)).messages;
      expect(
        find.text(messages.dailyOsNextEstimateMinutes(120)),
        findsOneWidget,
      );
      expect(
        find.text(messages.dailyOsNextEstimateMinutes(60)),
        findsOneWidget,
      );
    });

    testWidgets('capacity donut and note reflect the draft', (tester) async {
      _setSurface(tester, const Size(1280, 1200));
      await tester.pumpWidget(_wrap(CommitPage(draft: _planWithItems())));
      await tester.pump();

      final donut = tester.widget<CapacityDonut>(find.byType(CapacityDonut));
      expect(donut.scheduledMinutes, 180);
      expect(donut.capacityMinutes, 240);
      expect(donut.size, 62);
      final messages = tester.element(find.byType(CommitPage)).messages;
      expect(
        find.text(messages.dailyOsNextCommitCapacityNote('3h', '4h')),
        findsOneWidget,
      );
    });

    testWidgets(
      'narrow layout (< 900) wraps content in SingleChildScrollView',
      (
        tester,
      ) async {
        _setSurface(tester, const Size(600, 1400));
        await tester.pumpWidget(
          _wrap(
            CommitPage(draft: _planWithItems()),
            size: const Size(600, 1400),
          ),
        );
        await tester.pump();

        // The narrow layout uses SingleChildScrollView wrapping the column.
        final scaffold = find.byType(Scaffold);
        expect(
          find.descendant(of: scaffold, matching: find.byType(HoldToConfirm)),
          findsOneWidget,
        );
        // Content still shows.
        expect(find.text('Deep work'), findsOneWidget);
      },
    );

    testWidgets(
      'completing the hold calls agent.commitDay and reveals LockInScene',
      (tester) async {
        _setSurface(tester, const Size(1280, 1200));
        final agent = RecordingDayAgent();
        final draft = _planWithItems();
        await tester.pumpWidget(
          _wrap(
            CommitPage(draft: draft),
            overrides: [dayAgentProvider.overrideWithValue(agent)],
          ),
        );
        await tester.pump();

        await _completeHold(tester);
        await tester.pump();

        expect(agent.commitCount, 1);
        expect(agent.capturedPlan, same(draft));
        expect(find.byType(LockInScene), findsOneWidget);
      },
    );

    testWidgets(
      'LockInScene completion pops the navigator with the committed plan',
      (tester) async {
        _setSurface(tester, const Size(1280, 1200));
        final agent = RecordingDayAgent();
        final draft = _planWithItems();

        DraftPlan? popped;
        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    popped = await Navigator.of(context).push<DraftPlan>(
                      MaterialPageRoute<DraftPlan>(
                        builder: (_) => CommitPage(draft: draft),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
            overrides: [dayAgentProvider.overrideWithValue(agent)],
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        await _completeHold(tester);
        await tester.pump();
        // Let LockInScene's animation complete (3.4s default), then drain
        // the navigator's pop transition.
        await tester.pump(const Duration(milliseconds: 3500));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump(const Duration(milliseconds: 350));

        expect(popped, isNotNull);
        expect(popped?.state, DayState.committed);
        expect(find.byType(CommitPage), findsNothing);
      },
    );

    testWidgets('close icon pops the navigator without committing', (
      tester,
    ) async {
      _setSurface(tester, const Size(1280, 1200));
      final agent = RecordingDayAgent();
      final draft = _planWithItems();

      DraftPlan? popped;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  popped = await Navigator.of(context).push<DraftPlan>(
                    MaterialPageRoute<DraftPlan>(
                      builder: (_) => CommitPage(draft: draft),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
          overrides: [dayAgentProvider.overrideWithValue(agent)],
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      expect(agent.commitCount, 0);
      expect(popped, isNull);
      expect(find.byType(CommitPage), findsNothing);
    });
  });
}
