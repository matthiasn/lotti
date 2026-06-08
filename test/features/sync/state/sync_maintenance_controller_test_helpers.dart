import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/models/sync_models.dart';

const generatedSyncStepOrder = <SyncStep>[
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
];

class GeneratedSyncMaintenanceScenario {
  const GeneratedSyncMaintenanceScenario({
    required this.selectionFlags,
    required this.fail,
    required this.failureSlot,
    required this.totalSeed,
  });

  final List<bool> selectionFlags;
  final bool fail;
  final int failureSlot;
  final int totalSeed;

  Set<SyncStep> get selectedSteps => {
    for (var i = 0; i < generatedSyncStepOrder.length; i++)
      if (selectionFlags[i]) generatedSyncStepOrder[i],
  };

  List<SyncStep> get orderedSteps =>
      generatedSyncStepOrder.where(selectedSteps.contains).toList();

  int? get failureIndex {
    if (!fail || orderedSteps.isEmpty) return null;
    return failureSlot % orderedSteps.length;
  }

  SyncStep? get failureStep {
    final index = failureIndex;
    return index == null ? null : orderedSteps[index];
  }

  bool get shouldFail => failureStep != null;

  int totalFor(SyncStep step) => ((totalSeed + step.index) % 5) + 1;

  List<SyncStep> get expectedCalls {
    final index = failureIndex;
    if (index == null) return orderedSteps;
    return orderedSteps.take(index + 1).toList();
  }

  /// Expected overall progress percentage once `syncAll` settles.
  ///
  /// Each step is weighted equally (1 / total). On success all steps complete
  /// and progress is pinned to 100. On failure the failing step still fires its
  /// terminal `onProgress(1)` before throwing, so the last progress update is
  /// `round(((failureIndex + 1) / total) * 100)`; the failing step never reaches
  /// the post-operation `totalProgress += weight` increment.
  int get expectedProgress {
    final total = orderedSteps.length;
    if (total == 0) return 0;
    final index = failureIndex;
    if (index == null) return 100;
    final weight = 1 / total;
    return ((index + 1) * weight * 100).round();
  }

  @override
  String toString() {
    return 'GeneratedSyncMaintenanceScenario('
        'selectionFlags: $selectionFlags, '
        'fail: $fail, '
        'failureSlot: $failureSlot, '
        'totalSeed: $totalSeed'
        ')';
  }
}

extension AnyGeneratedSyncMaintenanceScenario on glados.Any {
  glados.Generator<GeneratedSyncMaintenanceScenario>
  get syncMaintenanceScenario => glados.CombinableAny(this).combine4(
    glados.ListAnys(this).listWithLengthInRange(
      generatedSyncStepOrder.length,
      generatedSyncStepOrder.length,
      glados.BoolAny(this).bool,
    ),
    glados.BoolAny(this).bool,
    glados.IntAnys(this).intInRange(0, generatedSyncStepOrder.length),
    glados.IntAnys(this).intInRange(0, 20),
    (
      List<bool> selectionFlags,
      bool fail,
      int failureSlot,
      int totalSeed,
    ) => GeneratedSyncMaintenanceScenario(
      selectionFlags: selectionFlags,
      fail: fail,
      failureSlot: failureSlot,
      totalSeed: totalSeed,
    ),
  );
}
