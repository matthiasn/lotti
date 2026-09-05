import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/progress_bars/design_system_progress_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/state/fts5_controller.dart';
import 'package:lotti/features/sync/ui/fts5_recreate_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

class TestFts5Controller extends Fts5Controller {
  TestFts5Controller(this._initialState);

  final Fts5State _initialState;

  @override
  Fts5State build() => _initialState;

  @override
  Future<void> recreateFts5() async {}
}

void main() {
  testWidgets('Fts5RecreateModal shows progress and handles states correctly', (
    WidgetTester tester,
  ) async {
    // Initial state: recreating, 50% progress
    final testController = TestFts5Controller(
      const Fts5State(
        isRecreating: true,
        progress: 0.5,
      ),
    );

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Fts5RecreateModal.show(context),
            child: const Text('Show FTS5 Modal'),
          ),
        ),
        overrides: [
          fts5ControllerProvider.overrideWith(() => testController),
        ],
      ),
    );

    // Tap the button to show the modal
    await tester.tap(find.text('Show FTS5 Modal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Get the confirm button text from the localizations
    final confirmText = tester
        .element(find.text('Show FTS5 Modal'))
        .messages
        .maintenanceRecreateFts5Confirm;

    // Tap the confirm button to proceed to progress page
    await tester.tap(find.text(confirmText));
    await tester.pump();

    // Should show 50% progress in the modal immediately
    expect(find.text('50%'), findsOneWidget);
    final progressBar = tester.widget<DesignSystemProgressBar>(
      find.byType(DesignSystemProgressBar),
    );
    expect(progressBar.value, 0.5);
    expect(progressBar.progressText, '50%');
    expect(find.byIcon(LottiIcons.confirmCircled), findsNothing);

    // Update state to error
    testController.state = const Fts5State(
      progress: 0.5,
      error: 'Failed to recreate FTS5',
    );
    await tester.pump();

    // Should show error message immediately
    expect(find.text('Failed to recreate FTS5'), findsOneWidget);
    expect(find.byIcon(LottiIcons.error), findsOneWidget);
    expect(find.byType(DesignSystemProgressBar), findsNothing);

    // Update state to complete
    testController.state = const Fts5State(
      progress: 1,
    );
    await tester.pump();

    // Should show checkmark and 100% progress immediately
    expect(find.text('100%'), findsOneWidget);
    expect(find.byIcon(LottiIcons.confirmCircled), findsOneWidget);
    expect(find.byType(DesignSystemProgressBar), findsNothing);
  });

  testWidgets('Fts5RecreateModal shows error state', (
    WidgetTester tester,
  ) async {
    // Initial state with error
    final testController = TestFts5Controller(
      const Fts5State(
        error: 'Test error',
      ),
    );

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Fts5RecreateModal.show(context),
            child: const Text('Show FTS5 Modal'),
          ),
        ),
        overrides: [
          fts5ControllerProvider.overrideWith(() => testController),
        ],
      ),
    );

    // Tap the button to show the modal
    await tester.tap(find.text('Show FTS5 Modal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Get the confirm button text from the localizations
    final confirmText = tester
        .element(find.text('Show FTS5 Modal'))
        .messages
        .maintenanceRecreateFts5Confirm;

    // Tap the confirm button to proceed to progress page
    await tester.tap(find.text(confirmText));
    await tester.pump();

    // Should show error state immediately
    expect(find.text('Test error'), findsOneWidget);
    expect(find.byType(DesignSystemProgressBar), findsNothing);
    expect(find.byIcon(LottiIcons.confirmCircled), findsNothing);
  });
}
