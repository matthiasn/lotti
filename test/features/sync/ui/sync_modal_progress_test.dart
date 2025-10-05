import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/models/sync_models.dart';
import 'package:lotti/features/sync/state/sync_maintenance_controller.dart';
import 'package:lotti/features/sync/ui/sync_modal.dart';
import 'package:lotti/l10n/app_localizations.dart';

class TestSyncController extends SyncMaintenanceController {
  TestSyncController(this._initialState);

  final SyncState _initialState;

  @override
  SyncState build() => _initialState;

  @override
  Future<void> syncAll({required Set<SyncStep> selectedSteps}) async {}

  @override
  void reset() {}
}

void main() {
  testWidgets('SyncModal shows progress and checkmark (direct widget)',
      (tester) async {
    // Initial state: syncing, 50% progress, current step: measurables
    final testController = TestSyncController(
      const SyncState(
        isSyncing: true,
        currentStep: SyncStep.measurables,
        progress: 50,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncControllerProvider.overrideWith(() => testController),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => const SyncModal(),
          ),
        ),
      ),
    );

    // Should show nothing because SyncModal's build returns SizedBox.shrink()
    expect(find.text('50%'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
  });
}
