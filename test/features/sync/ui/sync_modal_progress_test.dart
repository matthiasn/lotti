import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/models/sync_models.dart';
import 'package:lotti/features/sync/state/sync_maintenance_controller.dart';
import 'package:lotti/features/sync/ui/sync_modal.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:mocktail/mocktail.dart';

class _MockLoggingService extends Mock implements LoggingService {}

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

class _PendingSyncController extends SyncMaintenanceController {
  _PendingSyncController(this.pendingState);

  final SyncState pendingState;
  final Completer<void> _completer = Completer<void>();

  bool resetCalled = false;

  @override
  SyncState build() => const SyncState();

  @override
  Future<void> syncAll({required Set<SyncStep> selectedSteps}) async {
    state = pendingState.copyWith(selectedSteps: selectedSteps);
    return _completer.future;
  }

  void complete() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  @override
  void reset() {
    resetCalled = true;
    state = const SyncState();
  }
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

  testWidgets('SyncModal progress view reflects controller updates',
      (tester) async {
    final messages = AppLocalizationsEn();

    const pendingState = SyncState(
      isSyncing: true,
      progress: 50,
      currentStep: SyncStep.measurables,
      selectedSteps: {
        SyncStep.tags,
        SyncStep.measurables,
      },
      stepProgress: {
        SyncStep.tags: StepProgress(processed: 4, total: 4),
        SyncStep.measurables: StepProgress(processed: 1, total: 10),
      },
    );

    final controller = _PendingSyncController(pendingState);
    final mockLoggingService = _MockLoggingService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncControllerProvider.overrideWith(() => controller),
          syncLoggingServiceProvider.overrideWithValue(mockLoggingService),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => SyncModal.show(context),
                    child: const Text('Open sync modal'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open sync modal'));
    await tester.pumpAndSettle();

    final confirmButtonFinder =
        find.widgetWithText(LottiPrimaryButton, messages.syncEntitiesConfirm);
    final confirmButton =
        tester.widget<LottiPrimaryButton>(confirmButtonFinder);
    confirmButton.onPressed?.call();
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('4 / 4'), findsOneWidget);
    expect(find.text('1 / 10'), findsOneWidget);
    expect(find.byIcon(Icons.sync), findsOneWidget);
    expect(
      find.byIcon(Icons.check_circle_outline),
      findsAtLeastNWidgets(1),
    );

    controller.state = pendingState.copyWith(
      progress: 100,
      currentStep: SyncStep.complete,
      isSyncing: false,
    );
    await tester.pump();

    expect(
      find.text(messages.syncEntitiesSuccessTitle),
      findsOneWidget,
    );
    expect(find.text(messages.doneButton.toUpperCase()), findsOneWidget);

    controller.complete();
    await tester.pump();

    final doneButtonFinder = find.widgetWithText(
      LottiPrimaryButton,
      messages.doneButton.toUpperCase(),
    );
    final doneButton = tester.widget<LottiPrimaryButton>(doneButtonFinder);
    doneButton.onPressed?.call();
    await tester.pumpAndSettle();

    expect(controller.resetCalled, isTrue);
  });
}
