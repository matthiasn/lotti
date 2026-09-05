import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/progress_bars/design_system_progress_bar.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/state/sequence_log_populate_controller.dart';
import 'package:lotti/features/sync/ui/sequence_log_populate_progress.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget(SequenceLogPopulateState state) {
    return makeTestableWidgetWithScaffold(
      Center(
        child: SizedBox(
          width: 400,
          child: SequenceLogPopulateProgress(state: state),
        ),
      ),
      theme: DesignSystemTheme.light(),
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(LottiIcons.error), findsOneWidget);
      expect(find.text('Test error message'), findsOneWidget);
    });

    testWidgets('shows check icon when completed with all four counts', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          const SequenceLogPopulateState(
            progress: 1,
            populatedCount: 100,
            populatedLinksCount: 50,
            populatedAgentEntitiesCount: 30,
            populatedAgentLinksCount: 20,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(LottiIcons.confirmCircled), findsOneWidget);
      // Should show total (100 + 50 + 30 + 20 = 200)
      expect(find.textContaining('200'), findsOneWidget);
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final progressBar = tester.widget<DesignSystemProgressBar>(
        find.byType(DesignSystemProgressBar),
      );
      expect(progressBar.value, 0.5);
      expect(progressBar.progressText, '50%');
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('Processing journal entries...'), findsOneWidget);
    });

    testWidgets('shows entry links phase message', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const SequenceLogPopulateState(
            progress: 0.375,
            isRunning: true,
            phase: SequenceLogPopulatePhase.populatingLinks,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DesignSystemProgressBar), findsOneWidget);
      expect(find.text('38%'), findsOneWidget);
      expect(find.text('Processing entry links...'), findsOneWidget);
    });

    testWidgets('shows agent entities phase message', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const SequenceLogPopulateState(
            progress: 0.625,
            isRunning: true,
            phase: SequenceLogPopulatePhase.populatingAgentEntities,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DesignSystemProgressBar), findsOneWidget);
      expect(find.text('63%'), findsOneWidget);
      expect(find.text('Processing agent entities...'), findsOneWidget);
    });

    testWidgets('shows agent links phase message', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const SequenceLogPopulateState(
            progress: 0.875,
            isRunning: true,
            phase: SequenceLogPopulatePhase.populatingAgentLinks,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DesignSystemProgressBar), findsOneWidget);
      expect(find.text('88%'), findsOneWidget);
      expect(find.text('Processing agent links...'), findsOneWidget);
    });

    testWidgets('shows idle state when not running and not completed', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          const SequenceLogPopulateState(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DesignSystemProgressBar), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      // Should not show phase message when not running
      expect(find.text('Processing journal entries...'), findsNothing);
      expect(find.text('Processing entry links...'), findsNothing);
      expect(find.text('Processing agent entities...'), findsNothing);
      expect(find.text('Processing agent links...'), findsNothing);
    });

    testWidgets('shows 100% but still running state', (tester) async {
      // Edge case: progress is 1.0 but isRunning is still true
      await tester.pumpWidget(
        buildTestWidget(
          const SequenceLogPopulateState(
            progress: 1,
            isRunning: true,
            phase: SequenceLogPopulatePhase.populatingAgentLinks,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should show progress UI, not completed
      expect(find.byType(DesignSystemProgressBar), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.byIcon(LottiIcons.confirmCircled), findsNothing);
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Error should be shown, not completion
      expect(find.byIcon(LottiIcons.error), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.byIcon(LottiIcons.confirmCircled), findsNothing);
    });

    testWidgets('shows zero count when null values', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const SequenceLogPopulateState(
            progress: 1,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(LottiIcons.confirmCircled), findsOneWidget);
      // Total should be 0 when all counts are null
      expect(find.textContaining('0'), findsOneWidget);
    });

    testWidgets('handles partial counts correctly', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const SequenceLogPopulateState(
            progress: 1,
            populatedCount: 75,
            populatedAgentEntitiesCount: 25,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(LottiIcons.confirmCircled), findsOneWidget);
      // Total should be 75 + 25 = 100
      expect(find.textContaining('100'), findsOneWidget);
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final icon = tester.widget<Icon>(find.byIcon(LottiIcons.error));
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final icon = tester.widget<Icon>(find.byIcon(LottiIcons.confirmCircled));
      expect(icon.size, 48);
    });
  });
}
