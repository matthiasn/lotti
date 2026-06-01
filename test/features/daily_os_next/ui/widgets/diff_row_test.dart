import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/diff_row.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../widget_test_utils.dart';

const _category = DayAgentCategory(
  id: 'cat-work',
  name: 'Work',
  colorHex: '3366CC',
);

final _change = PlanDiffChange(
  id: 'diff_0',
  kind: PlanDiffChangeKind.added,
  title: 'Gym session',
  category: _category,
  reason: 'User requested a gym session.',
  affectedBlockId: 'block-1',
  toStart: DateTime(2026, 5, 25, 20),
  toEnd: DateTime(2026, 5, 25, 21, 45),
);

Widget _wrap(Widget child) => makeTestableWidget2(
  Material(child: child),
  mediaQueryData: const MediaQueryData(size: Size(420, 500)),
);

/// Build a [DiffRow] for each [PlanDiffChangeKind] and return the element.
Future<BuildContext> _pumpKind(
  WidgetTester tester,
  PlanDiffChangeKind kind, {
  DateTime? fromStart,
  DateTime? fromEnd,
  DateTime? toStart,
  DateTime? toEnd,
}) async {
  final change = PlanDiffChange(
    id: 'diff_kind',
    kind: kind,
    title: 'Task title',
    category: _category,
    reason: 'Some reason.',
    affectedBlockId: 'block-1',
    fromStart: fromStart,
    fromEnd: fromEnd,
    toStart: toStart,
    toEnd: toEnd,
  );
  await tester.pumpWidget(
    _wrap(
      DiffRow(
        change: change,
        decision: PlanDiffChangeDecision.pending,
        onAccept: () {},
        onReject: () {},
      ),
    ),
  );
  await tester.pump();
  return tester.element(find.byType(DiffRow));
}

void main() {
  group('DiffRow', () {
    testWidgets('shows per-change accept and reject actions', (tester) async {
      var accepted = 0;
      var rejected = 0;
      await tester.pumpWidget(
        _wrap(
          DiffRow(
            change: _change,
            decision: PlanDiffChangeDecision.pending,
            onAccept: () => accepted++,
            onReject: () => rejected++,
          ),
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(DiffRow));
      final messages = context.messages;
      expect(find.text(messages.dailyOsNextRefineAccept), findsOneWidget);
      expect(find.text(messages.changeSetSwipeReject), findsOneWidget);

      await tester.tap(find.text(messages.dailyOsNextRefineAccept));
      await tester.tap(find.text(messages.changeSetSwipeReject));

      expect(accepted, 1);
      expect(rejected, 1);
    });

    testWidgets('collapses accepted rows into a confirmation pill', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DiffRow(
            change: _change,
            decision: PlanDiffChangeDecision.accepted,
            onAccept: () {},
            onReject: () {},
          ),
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(DiffRow));
      final messages = context.messages;
      expect(find.text(messages.changeSetItemConfirmed), findsOneWidget);
      expect(find.text(messages.dailyOsNextRefineAccept), findsNothing);
      expect(find.text(messages.changeSetSwipeReject), findsNothing);
    });

    group('badge label per diff kind', () {
      // Covers _overlineFor branches for all three kinds
      for (final kind in PlanDiffChangeKind.values) {
        testWidgets('shows correct badge overline for $kind', (tester) async {
          final context = await _pumpKind(tester, kind);
          final messages = context.messages;
          final expected = switch (kind) {
            PlanDiffChangeKind.moved => messages.dailyOsNextRefineDiffMoved,
            PlanDiffChangeKind.added => messages.dailyOsNextRefineDiffAdded,
            PlanDiffChangeKind.dropped => messages.dailyOsNextRefineDiffDropped,
          };
          expect(find.text(expected), findsOneWidget);
        });
      }
    });

    group('badge icon per diff kind', () {
      // Covers _iconFor branches for all three kinds
      for (final kind in PlanDiffChangeKind.values) {
        testWidgets('shows correct icon for $kind', (tester) async {
          await _pumpKind(tester, kind);
          final expectedIcon = switch (kind) {
            PlanDiffChangeKind.moved => Icons.swap_vert_rounded,
            PlanDiffChangeKind.added => Icons.add_rounded,
            PlanDiffChangeKind.dropped => Icons.close_rounded,
          };
          expect(
            find.byWidgetPredicate(
              (w) => w is Icon && w.icon == expectedIcon && w.size == 12,
            ),
            findsWidgets,
          );
        });
      }
    });

    testWidgets('shows rejected decision pill when decision is rejected', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DiffRow(
            change: _change,
            decision: PlanDiffChangeDecision.rejected,
            onAccept: () {},
            onReject: () {},
          ),
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(DiffRow));
      final messages = context.messages;
      expect(find.text(messages.changeSetItemRejected), findsOneWidget);
      expect(find.text(messages.dailyOsNextRefineAccept), findsNothing);
      expect(find.text(messages.changeSetSwipeReject), findsNothing);
    });

    testWidgets(
      'shows CircularProgressIndicator when resolving=true (no action buttons)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            DiffRow(
              change: _change,
              decision: PlanDiffChangeDecision.pending,
              onAccept: () {},
              onReject: () {},
              resolving: true,
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        final context = tester.element(find.byType(DiffRow));
        final messages = context.messages;
        expect(find.text(messages.dailyOsNextRefineAccept), findsNothing);
        expect(find.text(messages.changeSetSwipeReject), findsNothing);
      },
    );

    group('_TimeChipsRow', () {
      testWidgets(
        'shows from-chip with strikethrough and arrow when both from and to are set',
        (tester) async {
          // from + to times — moved kind shows the arrow + both chips
          final context = await _pumpKind(
            tester,
            PlanDiffChangeKind.moved,
            fromStart: DateTime(2026, 5, 25, 9),
            fromEnd: DateTime(2026, 5, 25, 10),
            toStart: DateTime(2026, 5, 25, 14),
            toEnd: DateTime(2026, 5, 25, 15),
          );
          final messages = context.messages;
          // from-chip label: 9am–10am (exact-hour format: no minutes)
          final amShort = messages.dailyOsNextTimelineMeridiemAmShort;
          final pmShort = messages.dailyOsNextTimelineMeridiemPmShort;
          expect(find.text('9$amShort–10$amShort'), findsOneWidget);
          expect(find.text('2$pmShort–3$pmShort'), findsOneWidget);
          // Arrow icon
          expect(
            find.byWidgetPredicate(
              (w) =>
                  w is Icon &&
                  w.icon == Icons.arrow_forward_rounded &&
                  w.size == 12,
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'shows only to-chip when no from times, uses interactive accent for added kind',
        (tester) async {
          // added kind, only toStart/toEnd — no from chip, no arrow
          await _pumpKind(
            tester,
            PlanDiffChangeKind.added,
            toStart: DateTime(2026, 5, 25, 14),
            toEnd: DateTime(2026, 5, 25, 15),
          );
          final context = tester.element(find.byType(DiffRow));
          final messages = context.messages;
          final pmShort = messages.dailyOsNextTimelineMeridiemPmShort;
          expect(find.text('2$pmShort–3$pmShort'), findsOneWidget);
          expect(
            find.byWidgetPredicate(
              (w) => w is Icon && w.icon == Icons.arrow_forward_rounded,
            ),
            findsNothing,
          );
        },
      );

      testWidgets(
        'formats time with minutes when not on the hour (HH:MM format)',
        (tester) async {
          // 9:30am – 10:45am to exercise the non-zero-minute branch
          final context = await _pumpKind(
            tester,
            PlanDiffChangeKind.added,
            toStart: DateTime(2026, 5, 25, 9, 30),
            toEnd: DateTime(2026, 5, 25, 10, 45),
          );
          final messages = context.messages;
          final amShort = messages.dailyOsNextTimelineMeridiemAmShort;
          expect(find.text('9:30$amShort–10:45$amShort'), findsOneWidget);
        },
      );

      testWidgets(
        'formats PM times correctly (noon boundary and after)',
        (tester) async {
          // 12:00pm (noon — h12 == 12 because 12 % 12 == 0) to 1:15pm
          final context = await _pumpKind(
            tester,
            PlanDiffChangeKind.added,
            toStart: DateTime(2026, 5, 25, 12),
            toEnd: DateTime(2026, 5, 25, 13, 15),
          );
          final messages = context.messages;
          final pmShort = messages.dailyOsNextTimelineMeridiemPmShort;
          expect(find.text('12$pmShort–1:15$pmShort'), findsOneWidget);
        },
      );

      testWidgets(
        'shows from-only strikethrough chip without to-chip when toStart is null',
        (tester) async {
          // dropped change: fromStart + fromEnd set, toStart/toEnd null
          final context = await _pumpKind(
            tester,
            PlanDiffChangeKind.dropped,
            fromStart: DateTime(2026, 5, 25, 10),
            fromEnd: DateTime(2026, 5, 25, 11),
          );
          final messages = context.messages;
          final amShort = messages.dailyOsNextTimelineMeridiemAmShort;
          expect(find.text('10$amShort–11$amShort'), findsOneWidget);
          // No arrow icon since toStart is null
          expect(
            find.byWidgetPredicate(
              (w) => w is Icon && w.icon == Icons.arrow_forward_rounded,
            ),
            findsNothing,
          );
        },
      );
    });
  });
}
