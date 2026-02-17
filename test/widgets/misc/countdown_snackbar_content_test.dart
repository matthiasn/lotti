import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/misc/countdown_snackbar_content.dart';

void main() {
  group('CountdownSnackBarContent', () {
    testWidgets('renders progress indicator and child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountdownSnackBarContent(
              duration: Duration(seconds: 3),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Test message'),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Test message'), findsOneWidget);
    });

    testWidgets('progress indicator starts at initialProgress and animates',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountdownSnackBarContent(
              duration: Duration(seconds: 2),
              child: Text('Animating'),
            ),
          ),
        ),
      );

      // Initially the progress bar should be at 1.0
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 1.0);

      // After half the duration, progress should be around 0.5
      await tester.pump(const Duration(seconds: 1));
      final midIndicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(midIndicator.value, closeTo(0.5, 0.05));

      // After full duration, progress should be at 0.0
      await tester.pump(const Duration(seconds: 1));
      final endIndicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(endIndicator.value, closeTo(0.0, 0.05));
    });

    testWidgets('respects custom initialProgress', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountdownSnackBarContent(
              duration: Duration(seconds: 4),
              initialProgress: 0.5,
              child: Text('Half started'),
            ),
          ),
        ),
      );

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, closeTo(0.5, 0.05));
    });

    testWidgets('clamps initialProgress to valid range', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountdownSnackBarContent(
              duration: Duration(seconds: 2),
              initialProgress: 1.5,
              child: Text('Clamped'),
            ),
          ),
        ),
      );

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 1.0);
    });
  });

  group('showCountdownSnackBar', () {
    testWidgets('shows floating SnackBar with progress indicator',
        (tester) async {
      late ScaffoldMessengerState messenger;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              messenger = ScaffoldMessenger.of(context);
              return const Scaffold(
                body: SizedBox.shrink(),
              );
            },
          ),
        ),
      );

      showCountdownSnackBar(
        messenger,
        message: 'Action performed',
        duration: const Duration(seconds: 2),
      );
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(CountdownSnackBarContent), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Action performed'), findsOneWidget);
    });

    testWidgets('shows action button when actionLabel and onAction provided',
        (tester) async {
      late ScaffoldMessengerState messenger;
      var actionCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              messenger = ScaffoldMessenger.of(context);
              return const Scaffold(
                body: SizedBox.shrink(),
              );
            },
          ),
        ),
      );

      showCountdownSnackBar(
        messenger,
        message: 'Item archived',
        duration: const Duration(seconds: 2),
        actionLabel: 'Undo',
        onAction: () => actionCalled = true,
      );
      // Let the SnackBar entry animation complete so it's tappable
      await tester.pumpAndSettle();

      expect(find.text('Undo'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      expect(actionCalled, isTrue);
    });

    testWidgets('hides action button when no actionLabel', (tester) async {
      late ScaffoldMessengerState messenger;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              messenger = ScaffoldMessenger.of(context);
              return const Scaffold(
                body: SizedBox.shrink(),
              );
            },
          ),
        ),
      );

      showCountdownSnackBar(
        messenger,
        message: 'Item deleted',
        duration: const Duration(seconds: 2),
      );
      await tester.pump();

      expect(find.text('Item deleted'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('replaces current SnackBar when called again', (tester) async {
      late ScaffoldMessengerState messenger;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              messenger = ScaffoldMessenger.of(context);
              return const Scaffold(
                body: SizedBox.shrink(),
              );
            },
          ),
        ),
      );

      showCountdownSnackBar(
        messenger,
        message: 'First action',
        duration: const Duration(seconds: 2),
      );
      await tester.pump();
      expect(find.text('First action'), findsOneWidget);

      showCountdownSnackBar(
        messenger,
        message: 'Second action',
        duration: const Duration(seconds: 2),
      );
      await tester.pump();
      // After replacement, only the second SnackBar should be visible
      // (the first is being dismissed)
      await tester.pumpAndSettle();
      expect(find.text('Second action'), findsOneWidget);
      expect(find.text('First action'), findsNothing);
    });
  });
}
