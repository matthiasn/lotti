import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/state/sequence_log_populate_controller.dart';
import 'package:lotti/features/sync/ui/sequence_log_populate_progress.dart';
import 'package:lotti/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget(SequenceLogPopulateState state) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            child: SequenceLogPopulateProgress(state: state),
          ),
        ),
      ),
    );
  }

  group('SequenceLogPopulateProgress', () {
    testWidgets('shows error icon when error is present', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const SequenceLogPopulateState(
            error: 'Test error message',
            progress: 0.5,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Test error message'), findsOneWidget);
    });

    testWidgets('shows check icon when completed', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const SequenceLogPopulateState(
            progress: 1,
            populatedCount: 100,
            populatedLinksCount: 50,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      // Should show total (100 + 50 = 150)
      expect(find.textContaining('150'), findsOneWidget);
    });

    testWidgets('shows progress indicator when running', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const SequenceLogPopulateState(
            progress: 0.5,
            isRunning: true,
            phase: SequenceLogPopulatePhase.populatingJournal,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('Processing journal entries...'), findsOneWidget);
    });

    testWidgets('shows entry links phase message', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const SequenceLogPopulateState(
            progress: 0.75,
            isRunning: true,
            phase: SequenceLogPopulatePhase.populatingLinks,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('Processing entry links...'), findsOneWidget);
    });

    testWidgets('shows idle state when not running and not completed',
        (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const SequenceLogPopulateState(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      // Should not show phase message when not running
      expect(find.text('Processing journal entries...'), findsNothing);
      expect(find.text('Processing entry links...'), findsNothing);
    });

    testWidgets('shows 100% but still running state', (tester) async {
      // Edge case: progress is 1.0 but isRunning is still true
      await tester.pumpWidget(
        buildTestWidget(
          const SequenceLogPopulateState(
            progress: 1,
            isRunning: true,
            phase: SequenceLogPopulatePhase.populatingLinks,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show progress UI, not completed
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    });

    testWidgets('error state takes precedence over progress', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const SequenceLogPopulateState(
            error: 'Something went wrong',
            progress: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Error should be shown, not completion
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    });

    testWidgets('shows zero count when null values', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const SequenceLogPopulateState(
            progress: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      // Total should be 0 when both counts are null
      expect(find.textContaining('0'), findsOneWidget);
    });

    testWidgets('handles partial counts correctly', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const SequenceLogPopulateState(
            progress: 1,
            populatedCount: 75,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.textContaining('75'), findsOneWidget);
    });

    testWidgets('shows correct percentage rounding', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const SequenceLogPopulateState(
            progress: 0.333,
            isRunning: true,
            phase: SequenceLogPopulatePhase.populatingJournal,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('33%'), findsOneWidget);
    });

    testWidgets('error icon has correct color', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const SequenceLogPopulateState(
            error: 'Error',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
      expect(icon.size, 48);
    });

    testWidgets('check icon has correct size', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const SequenceLogPopulateState(
            progress: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle_outline));
      expect(icon.size, 48);
    });
  });
}
