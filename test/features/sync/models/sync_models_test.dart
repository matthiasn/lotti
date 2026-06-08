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

    test('copyWith always clears error unless explicitly re-supplied', () {
      // SyncState.copyWith does NOT coalesce `error` with `??` the way the
      // other fields do — it assigns `error: error` directly. That is
      // deliberate: every no-arg copyWith resets the error to null so a stale
      // failure cannot leak into the next state transition. Pin both halves of
      // that asymmetry so a future refactor to `error ?? this.error` is caught.
      final withError = const SyncState().copyWith(error: 'some error');
      expect(
        withError.error,
        'some error',
        reason: 'explicitly supplied error must be retained',
      );

      final cleared = withError.copyWith();
      expect(
        cleared.error,
        isNull,
        reason: 'no-arg copyWith must drop the previous error, not preserve it',
      );

      final replaced = withError.copyWith(error: 'new error');
      expect(
        replaced.error,
        'new error',
        reason: 'a newly supplied error must overwrite the previous one',
      );
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

    test('no-arg copyWith preserves nested stepProgress and selectedSteps', () {
      // This is the controller's most common transition: it builds a mid-sync
      // state with a populated stepProgress map and selectedSteps set, then
      // re-emits via copyWith() to clear the transient error while keeping the
      // accumulated progress. Verify the nested collections survive by identity
      // (same instance, not a copy) and by content.
      final stepProgress = {
        SyncStep.measurables: const StepProgress(processed: 3, total: 10),
        SyncStep.labels: const StepProgress(processed: 7, total: 7),
      };
      final selectedSteps = {SyncStep.measurables, SyncStep.labels};
      final state = const SyncState().copyWith(
        isSyncing: true,
        currentStep: SyncStep.labels,
        progress: 40,
        stepProgress: stepProgress,
        selectedSteps: selectedSteps,
      );

      final next = state.copyWith();

      expect(next.isSyncing, isTrue);
      expect(next.currentStep, SyncStep.labels);
      expect(next.progress, 40);
      // Map/Set are passed through unchanged (?? this.field), so the exact
      // instance is retained — no defensive copy, no content loss.
      expect(identical(next.stepProgress, stepProgress), isTrue);
      expect(identical(next.selectedSteps, selectedSteps), isTrue);
      expect(
        next.stepProgress[SyncStep.measurables],
        isA<StepProgress>()
            .having((p) => p.processed, 'processed', 3)
            .having((p) => p.total, 'total', 10),
      );
      expect(
        next.stepProgress[SyncStep.labels],
        isA<StepProgress>()
            .having((p) => p.processed, 'processed', 7)
            .having((p) => p.total, 'total', 7),
      );
      expect(next.selectedSteps, {SyncStep.measurables, SyncStep.labels});
    });
  });
}
