import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/state/fts5_controller.dart';
import 'package:lotti/features/sync/ui/fts5_recreate_modal.dart';
import 'package:lotti/l10n/app_localizations.dart';

class TestFts5Controller extends StateNotifier<Fts5State>
    implements Fts5Controller {
  TestFts5Controller(super.state);

  @override
  Future<void> recreateFts5() async {}
}

Widget createTestApp(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  testWidgets('Fts5RecreateModal shows progress and handles states correctly',
      (WidgetTester tester) async {
    // Initial state: recreating, 50% progress
    final testController = TestFts5Controller(
      const Fts5State(
        isRecreating: true,
        progress: 0.5,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fts5ControllerProvider.overrideWith((ref) => testController),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Fts5RecreateModal.show(context),
              child: const Text('Show FTS5 Modal'),
            ),
          ),
        ),
      ),
    );

    // Tap the button to show the modal
    await tester.tap(find.text('Show FTS5 Modal'));
    await tester.pumpAndSettle();

    // Get the confirm button text from the localizations
    final BuildContext context = tester.element(find.text('Show FTS5 Modal'));
    final confirmText =
        AppLocalizations.of(context)!.maintenanceRecreateFts5Confirm;

    // Tap the confirm button
    await tester.tap(find.text(confirmText));
    await tester.pumpAndSettle();

    // Should show 50% progress in the modal
    expect(find.text('50%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);

    // Update state to error
    testController.state = const Fts5State(
      progress: 0.5,
      error: 'Failed to recreate FTS5',
    );
    await tester.pumpAndSettle();

    // Should show error message
    expect(find.text('Failed to recreate FTS5'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    // Update state to complete
    testController.state = const Fts5State(
      progress: 1,
    );
    await tester
        .pump(); // Only pump a single frame to catch the state before modal closes

    // Should show checkmark and 100% progress
    expect(find.text('100%'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('Fts5RecreateModal shows error state',
      (WidgetTester tester) async {
    // Initial state with error
    final testController = TestFts5Controller(
      const Fts5State(
        error: 'Test error',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fts5ControllerProvider.overrideWith((ref) => testController),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Fts5RecreateModal.show(context),
              child: const Text('Show FTS5 Modal'),
            ),
          ),
        ),
      ),
    );

    // Tap the button to show the modal
    await tester.tap(find.text('Show FTS5 Modal'));
    await tester.pumpAndSettle();

    // Get the confirm button text from the localizations
    final BuildContext context = tester.element(find.text('Show FTS5 Modal'));
    final confirmText =
        AppLocalizations.of(context)!.maintenanceRecreateFts5Confirm;

    // Tap the confirm button
    await tester.tap(find.text(confirmText));
    await tester.pumpAndSettle();

    // Debug print to inspect the widget tree
    debugDumpApp();

    // Should show error state
    expect(find.text('Test error'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
  });
}
