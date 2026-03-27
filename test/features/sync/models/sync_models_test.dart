import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/models/sync_models.dart';

void main() {
  group('SyncStep', () {
    test('has expected values in order', () {
      expect(
        SyncStep.values,
        [
          SyncStep.measurables,
          SyncStep.labels,
          SyncStep.categories,
          SyncStep.dashboards,
          SyncStep.habits,
          SyncStep.aiSettings,
          SyncStep.backfillAgentEntityClocks,
          SyncStep.backfillAgentLinkClocks,
          SyncStep.agentEntities,
          SyncStep.agentLinks,
          SyncStep.complete,
        ],
      );
    });
  });

  group('StepProgress', () {
    test('constructor sets fields', () {
      const progress = StepProgress(processed: 5, total: 10);

      expect(progress.processed, 5);
      expect(progress.total, 10);
    });

    test('copyWith overrides processed', () {
      const original = StepProgress(processed: 5, total: 10);
      final updated = original.copyWith(processed: 8);

      expect(updated.processed, 8);
      expect(updated.total, 10);
    });

    test('copyWith overrides total', () {
      const original = StepProgress(processed: 5, total: 10);
      final updated = original.copyWith(total: 20);

      expect(updated.processed, 5);
      expect(updated.total, 20);
    });

    test('copyWith with no args preserves values', () {
      const original = StepProgress(processed: 5, total: 10);
      final copied = original.copyWith();

      expect(copied.processed, 5);
      expect(copied.total, 10);
    });
  });

  group('SyncState', () {
    test('default constructor has expected defaults', () {
      const state = SyncState();

      expect(state.isSyncing, isFalse);
      expect(state.progress, 0);
      expect(state.currentStep, SyncStep.measurables);
      expect(state.error, isNull);
      expect(state.stepProgress, isEmpty);
      expect(state.selectedSteps, isEmpty);
    });

    test('copyWith overrides individual fields', () {
      const state = SyncState();
      final updated = state.copyWith(
        isSyncing: true,
        progress: 50,
        currentStep: SyncStep.labels,
        error: 'test error',
        stepProgress: {
          SyncStep.measurables: const StepProgress(processed: 5, total: 5),
        },
        selectedSteps: {SyncStep.measurables, SyncStep.labels},
      );

      expect(updated.isSyncing, isTrue);
      expect(updated.progress, 50);
      expect(updated.currentStep, SyncStep.labels);
      expect(updated.error, 'test error');
      expect(updated.stepProgress, hasLength(1));
      expect(updated.selectedSteps, hasLength(2));
    });

    test('copyWith without error clears it', () {
      final state = const SyncState().copyWith(error: 'some error');
      final cleared = state.copyWith();

      // error parameter defaults to null in copyWith, clearing previous error
      expect(cleared.error, isNull);
    });

    test('copyWith preserves unmodified fields', () {
      final state = const SyncState().copyWith(
        isSyncing: true,
        progress: 75,
      );
      final updated = state.copyWith(progress: 80);

      expect(updated.isSyncing, isTrue);
      expect(updated.progress, 80);
      expect(updated.currentStep, SyncStep.measurables);
    });
  });
}
