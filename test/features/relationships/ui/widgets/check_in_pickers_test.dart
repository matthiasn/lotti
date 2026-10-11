import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_pickers.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  final calls = <String>[];
  setUp(calls.clear);

  group('showCheckInTypePicker', () {
    /// Opens the picker and hands back a reader for what it resolved to,
    /// for the test to call once it has tapped or dismissed.
    Future<CheckInInteractionType? Function()> open(
      WidgetTester tester, {
      required CheckInInteractionType current,
    }) async {
      CheckInInteractionType? picked;
      var resolved = false;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                picked = await showCheckInTypePicker(
                  context: context,
                  current: current,
                );
                resolved = true;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(resolved, isFalse);
      return () {
        expect(resolved, isTrue, reason: 'the picker has resolved');
        return picked;
      };
    }

    testWidgets('lists every kind and resolves to the tapped one', (
      tester,
    ) async {
      final result = await open(tester, current: CheckInInteractionType.call);
      expect(find.text('How did you connect?'), findsOneWidget);
      for (final type in CheckInInteractionType.values) {
        expect(
          find.byKey(ValueKey('check-in-type-${type.name}')),
          findsOneWidget,
        );
      }
      await tester.tap(find.byKey(const ValueKey('check-in-type-message')));
      await tester.pumpAndSettle();
      expect(find.text('How did you connect?'), findsNothing);
      expect(result(), CheckInInteractionType.message);
    });

    testWidgets('dismissing resolves to nothing', (tester) async {
      final result = await open(tester, current: CheckInInteractionType.call);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('How did you connect?'), findsNothing);
      expect(result(), isNull);
    });
  });

  group('showCheckInSentimentPicker', () {
    Future<({CheckInSentiment? sentiment})? Function()> open(
      WidgetTester tester, {
      required CheckInSentiment? current,
    }) async {
      ({CheckInSentiment? sentiment})? picked;
      var resolved = false;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                picked = await showCheckInSentimentPicker(
                  context: context,
                  current: current,
                );
                resolved = true;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      return () {
        expect(resolved, isTrue, reason: 'the picker has resolved');
        return picked;
      };
    }

    testWidgets('resolves to the tapped feeling; nothing set offers no '
        'Clear', (tester) async {
      final result = await open(tester, current: null);
      expect(
        find.byKey(const ValueKey('check-in-sentiment-clear')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('check-in-sentiment-option-strained')),
      );
      await tester.pumpAndSettle();
      expect(result(), (sentiment: CheckInSentiment.strained));
    });

    testWidgets('says, under the feelings, that the choice is optional and '
        "never the agent's — where it is made, not as a row's value", (
      tester,
    ) async {
      await open(tester, current: null);
      final note = find.byKey(const ValueKey('check-in-sentiment-note'));
      expect(
        find.descendant(
          of: note,
          matching: find.text('Optional. Never filled in by the agent.'),
        ),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(note).dy,
        greaterThanOrEqualTo(
          tester
              .getBottomLeft(
                find.byKey(
                  const ValueKey('check-in-sentiment-option-difficult'),
                ),
              )
              .dy,
        ),
      );
    });

    // A cleared feeling and a dismissed sheet must not look alike.
    testWidgets('Clear resolves to no feeling; dismissing to nothing', (
      tester,
    ) async {
      var result = await open(tester, current: CheckInSentiment.good);
      await tester.tap(find.byKey(const ValueKey('check-in-sentiment-clear')));
      await tester.pumpAndSettle();
      expect(result(), (sentiment: null));

      result = await open(tester, current: CheckInSentiment.good);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(result(), isNull);
    });
  });

  group('checkInStartedLabelOf', () {
    final now = DateTime(2026, 8, 14, 14, 55, 30);

    testWidgets('says Now for the current minute, else the day and time', (
      tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      withClock(Clock.fixed(now), () {
        expect(
          checkInStartedLabelOf(context, DateTime(2026, 8, 14, 14, 55)),
          startsWith('Now · '),
        );
        expect(
          checkInStartedLabelOf(context, DateTime(2026, 8, 1, 12, 44)),
          isNot(startsWith('Now')),
        );
      });
    });
  });
}
