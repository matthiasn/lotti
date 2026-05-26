import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/lock_in_scene.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../widget_test_utils.dart';

Widget _wrap(Widget child) => makeTestableWidget2(
  Scaffold(body: child),
  mediaQueryData: const MediaQueryData(size: Size(800, 1000)),
);

void main() {
  group('LockInScene', () {
    testWidgets('initial frame shows lock icon and "Locking in…" caption', (
      tester,
    ) async {
      var completed = false;
      await tester.pumpWidget(
        _wrap(LockInScene(onComplete: () => completed = true)),
      );
      await tester.pump();

      final messages = tester.element(find.byType(LockInScene)).messages;
      // Caption schedule: < 0.18 progress → "Locking in…".
      expect(find.text(messages.dailyOsNextCommitLockingIn), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      expect(completed, isFalse);
    });

    testWidgets(
      'mid-animation swaps to check icon and "Today is yours." caption',
      (tester) async {
        var completed = false;
        await tester.pumpWidget(
          _wrap(
            LockInScene(
              onComplete: () => completed = true,
              totalDuration: const Duration(milliseconds: 1000),
            ),
          ),
        );
        await tester.pump();
        // 40% in: past 0.25 (check icon) and past 0.18 (caption swap).
        await tester.pump(const Duration(milliseconds: 400));

        final messages = tester.element(find.byType(LockInScene)).messages;
        expect(
          find.text(messages.dailyOsNextCommitTodayIsYours),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
        expect(completed, isFalse);
      },
    );

    testWidgets('past the halfway mark the shepherd sub-line fades in', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          LockInScene(
            onComplete: () {},
            totalDuration: const Duration(milliseconds: 1000),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      final messages = tester.element(find.byType(LockInScene)).messages;
      expect(
        find.text(messages.dailyOsNextCommitShepherdSubline),
        findsOneWidget,
      );
    });

    testWidgets('animation completion invokes onComplete exactly once', (
      tester,
    ) async {
      var completedCount = 0;
      await tester.pumpWidget(
        _wrap(
          LockInScene(
            onComplete: () => completedCount++,
            totalDuration: const Duration(milliseconds: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(completedCount, 1);
    });

    testWidgets(
      'IgnorePointer wraps the overlay so taps fall through to widgets below',
      (tester) async {
        var underlyingTaps = 0;
        await tester.pumpWidget(
          _wrap(
            Stack(
              children: [
                GestureDetector(
                  onTap: () => underlyingTaps++,
                  behavior: HitTestBehavior.opaque,
                  child: const SizedBox.expand(),
                ),
                LockInScene(onComplete: () {}),
              ],
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.byType(LockInScene));
        await tester.pump();

        expect(underlyingTaps, 1);
      },
    );

    testWidgets(
      'disposing the widget mid-animation does not invoke onComplete',
      (
        tester,
      ) async {
        var completed = false;
        await tester.pumpWidget(
          _wrap(
            LockInScene(
              onComplete: () => completed = true,
              totalDuration: const Duration(milliseconds: 5000),
            ),
          ),
        );
        await tester.pump();
        // Replace the widget to trigger dispose mid-animation.
        await tester.pumpWidget(_wrap(const SizedBox.shrink()));
        await tester.pump(const Duration(milliseconds: 1000));

        expect(completed, isFalse);
      },
    );
  });
}
