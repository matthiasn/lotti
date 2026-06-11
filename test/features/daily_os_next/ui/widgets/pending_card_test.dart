import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/pending_card.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../widget_test_utils.dart';

const _category = DayAgentCategory(
  id: 'work',
  name: 'Work',
  colorHex: '5ED4B7',
);

Widget _wrap(Widget child) => makeTestableWidget2(
  Material(child: child),
  mediaQueryData: const MediaQueryData(size: Size(500, 400)),
);

void main() {
  group('PendingCard', () {
    testWidgets('labels due items against the selected plan date', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PendingCard(
            item: PendingItem(
              taskId: 'task-1',
              title: 'Submit report',
              category: _category,
              reason: PendingItemReason.dueToday,
              referenceDate: DateTime(2026, 5, 30),
            ),
            onTriage: (_) {},
          ),
        ),
      );

      final messages = tester.element(find.byType(PendingCard)).messages;
      expect(
        find.text(messages.dailyOsNextStateDueOnDate('Sat, May 30')),
        findsOneWidget,
      );
      expect(find.text('Submit report'), findsOneWidget);
    });

    testWidgets('labels overdue items against the selected plan date', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PendingCard(
            item: PendingItem(
              taskId: 'task-1',
              title: 'Pay invoice',
              category: _category,
              reason: PendingItemReason.overdue,
              overdueByDays: 5,
              referenceDate: DateTime(2026, 5, 30),
            ),
            onTriage: (_) {},
          ),
        ),
      );

      final messages = tester.element(find.byType(PendingCard)).messages;
      expect(
        find.text(messages.dailyOsNextStateOverdueOnDate(5, 'Sat, May 30')),
        findsOneWidget,
      );
      expect(find.text('Pay invoice'), findsOneWidget);
    });

    testWidgets('uses today wording for due items without a reference date', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PendingCard(
            item: const PendingItem(
              taskId: 'task-1',
              title: 'Submit report',
              category: _category,
              reason: PendingItemReason.dueToday,
            ),
            onTriage: (_) {},
          ),
        ),
      );

      final messages = tester.element(find.byType(PendingCard)).messages;
      expect(find.text(messages.dailyOsNextStateDueToday), findsOneWidget);
    });

    testWidgets(
      'uses relative wording for overdue items without a reference date',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            PendingCard(
              item: const PendingItem(
                taskId: 'task-1',
                title: 'Pay invoice',
                category: _category,
                reason: PendingItemReason.overdue,
                overdueByDays: 5,
              ),
              onTriage: (_) {},
            ),
          ),
        );

        final messages = tester.element(find.byType(PendingCard)).messages;
        expect(
          find.text(messages.dailyOsNextStateOverdue(5)),
          findsOneWidget,
        );
      },
    );

    group('triage actions', () {
      // For each button in the triage row: the action it dispatches, its
      // localized label, and a finder that resolves to the rendered
      // ButtonStyleButton. `today` is a FilledButton, doNow/defer/done are
      // OutlinedButtons, and `drop` is an icon-only IconButton whose tooltip
      // carries the label. All extend ButtonStyleButton, so each finder is
      // narrowed to the button itself for direct callback invocation.
      final actions =
          <
            (
              TriageAction,
              String Function(AppLocalizations),
              Finder Function(String),
            )
          >[
            (
              TriageAction.today,
              (m) => m.dailyOsNextTriageToday,
              (label) => find.widgetWithText(FilledButton, label),
            ),
            (
              TriageAction.doNow,
              (m) => m.dailyOsNextTriageDoNow,
              (label) => find.widgetWithText(OutlinedButton, label),
            ),
            (
              TriageAction.defer,
              (m) => m.dailyOsNextTriageDefer,
              (label) => find.widgetWithText(OutlinedButton, label),
            ),
            (
              TriageAction.done,
              (m) => m.dailyOsNextTriageDone,
              (label) => find.widgetWithText(OutlinedButton, label),
            ),
            (
              TriageAction.drop,
              (m) => m.dailyOsNextTriageDrop,
              (label) => find.ancestor(
                of: find.byTooltip(label),
                matching: find.byType(IconButton),
              ),
            ),
          ];

      for (final (action, labelOf, finderFor) in actions) {
        testWidgets('tapping ${action.name} fires onTriage($action)', (
          tester,
        ) async {
          final fired = <TriageAction>[];
          await tester.pumpWidget(
            _wrap(
              PendingCard(
                item: const PendingItem(
                  taskId: 'task-1',
                  title: 'Submit report',
                  category: _category,
                  reason: PendingItemReason.dueToday,
                ),
                onTriage: fired.add,
              ),
            ),
          );

          final messages = tester.element(find.byType(PendingCard)).messages;
          final finder = finderFor(labelOf(messages));
          expect(finder, findsOneWidget);

          // Invoke the button's onPressed directly rather than via a hit-test
          // tap. The triage buttons live in a Wrap that can reflow/overflow
          // off-screen at the test surface size, which makes `tester.tap`
          // flaky in the batched suite. FilledButton/OutlinedButton expose
          // onPressed via ButtonStyleButton; the drop control is an IconButton.
          // Reading onPressed off the resolved widget exercises the same
          // onTriage wiring without depending on layout/surface state.
          final widget = tester.widget(finder);
          final onPressed = switch (widget) {
            final ButtonStyleButton b => b.onPressed,
            final IconButton b => b.onPressed,
            _ => fail('Unexpected triage control type: ${widget.runtimeType}'),
          };
          onPressed!.call();
          await tester.pump();

          expect(fired, [action]);
        });
      }
    });

    group('decision pill', () {
      // Each action maps to a distinct confirmation label rendered by
      // _DecisionPill once a decision has been made.
      final confirmations = <(TriageAction, String Function(AppLocalizations))>[
        (TriageAction.today, (m) => m.dailyOsNextTriageConfirmToday),
        (TriageAction.doNow, (m) => m.dailyOsNextTriageConfirmDoNow),
        (TriageAction.defer, (m) => m.dailyOsNextTriageConfirmDefer),
        (TriageAction.done, (m) => m.dailyOsNextTriageConfirmDone),
        (TriageAction.drop, (m) => m.dailyOsNextTriageConfirmDrop),
      ];

      for (final (action, confirmationOf) in confirmations) {
        testWidgets('renders the $action confirmation and hides the row', (
          tester,
        ) async {
          await tester.pumpWidget(
            _wrap(
              PendingCard(
                item: const PendingItem(
                  taskId: 'task-1',
                  title: 'Submit report',
                  category: _category,
                  reason: PendingItemReason.dueToday,
                ),
                decision: TriageResult(taskId: 'task-1', action: action),
                onTriage: (_) {},
              ),
            ),
          );

          final messages = tester.element(find.byType(PendingCard)).messages;
          expect(find.text(confirmationOf(messages)), findsOneWidget);
          // The triage button row collapses once a decision exists.
          expect(find.text(messages.dailyOsNextTriageToday), findsNothing);

          // The card fades to ~55% opacity when decided.
          final opacity = tester.widget<Opacity>(
            find.descendant(
              of: find.byType(PendingCard),
              matching: find.byType(Opacity),
            ),
          );
          expect(opacity.opacity, 0.55);
        });
      }

      testWidgets('strikes through the title only for the done action', (
        tester,
      ) async {
        Future<TextDecoration?> decorationFor(TriageAction action) async {
          await tester.pumpWidget(
            _wrap(
              PendingCard(
                item: const PendingItem(
                  taskId: 'task-1',
                  title: 'Submit report',
                  category: _category,
                  reason: PendingItemReason.dueToday,
                ),
                decision: TriageResult(taskId: 'task-1', action: action),
                onTriage: (_) {},
              ),
            ),
          );
          return tester
              .widget<Text>(find.text('Submit report'))
              .style
              ?.decoration;
        }

        expect(
          await decorationFor(TriageAction.done),
          TextDecoration.lineThrough,
        );
        expect(await decorationFor(TriageAction.drop), TextDecoration.none);
      });
    });
  });
}
