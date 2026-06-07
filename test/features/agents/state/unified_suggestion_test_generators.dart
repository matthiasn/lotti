/// Glados generator scaffolding for `unified_suggestion_providers_test.dart`.
///
/// Extracted from the test file so the scenario classes and `Any` extension
/// no longer dwarf the test logic. Helper library, not a test file (no
/// `main()`), so the one-test-file-per-source rule is unaffected.
library;

import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';

import '../test_utils.dart';

enum GeneratedSuggestionItemStatusSlot {
  pending,
  confirmed,
  rejected,
  deferred,
  retracted,
}

enum GeneratedSuggestionFingerprintSlot {
  title,
  priority,
  status,
  estimate,
  checklist,
}

enum GeneratedSuggestionCreatedAtSlot { oldest, older, middle, newer, newest }

enum GeneratedSuggestionVerdictSlot {
  confirmed,
  rejected,
  deferred,
  retracted,
}

typedef GeneratedOpenSuggestionExpectation = ({
  String changeSetId,
  int itemIndex,
  String toolName,
  Map<String, dynamic> args,
  String humanSummary,
  String fingerprint,
});

typedef GeneratedActivityExpectation = ({
  String changeSetId,
  String fingerprint,
  ChangeItemStatus status,
  ChangeDecisionVerdict? verdict,
  DecisionActor? resolvedBy,
});

final generatedSuggestionBase = DateTime(2026, 5, 24, 9);

ChangeItemStatus generatedSuggestionStatus(
  GeneratedSuggestionItemStatusSlot slot,
) {
  return switch (slot) {
    GeneratedSuggestionItemStatusSlot.pending => ChangeItemStatus.pending,
    GeneratedSuggestionItemStatusSlot.confirmed => ChangeItemStatus.confirmed,
    GeneratedSuggestionItemStatusSlot.rejected => ChangeItemStatus.rejected,
    GeneratedSuggestionItemStatusSlot.deferred => ChangeItemStatus.deferred,
    GeneratedSuggestionItemStatusSlot.retracted => ChangeItemStatus.retracted,
  };
}

ChangeDecisionVerdict generatedSuggestionVerdict(
  GeneratedSuggestionVerdictSlot slot,
) {
  return switch (slot) {
    GeneratedSuggestionVerdictSlot.confirmed => ChangeDecisionVerdict.confirmed,
    GeneratedSuggestionVerdictSlot.rejected => ChangeDecisionVerdict.rejected,
    GeneratedSuggestionVerdictSlot.deferred => ChangeDecisionVerdict.deferred,
    GeneratedSuggestionVerdictSlot.retracted => ChangeDecisionVerdict.retracted,
  };
}

ChangeItemStatus generatedSuggestionStatusForVerdict(
  ChangeDecisionVerdict verdict,
) {
  return switch (verdict) {
    ChangeDecisionVerdict.confirmed => ChangeItemStatus.confirmed,
    ChangeDecisionVerdict.rejected => ChangeItemStatus.rejected,
    ChangeDecisionVerdict.deferred => ChangeItemStatus.deferred,
    ChangeDecisionVerdict.retracted => ChangeItemStatus.retracted,
  };
}

DecisionActor generatedSuggestionActorForVerdict(
  ChangeDecisionVerdict verdict,
) {
  return switch (verdict) {
    ChangeDecisionVerdict.retracted => DecisionActor.agent,
    _ => DecisionActor.user,
  };
}

DateTime generatedSuggestionCreatedAt(
  GeneratedSuggestionCreatedAtSlot slot,
  int index,
) {
  final hours = switch (slot) {
    GeneratedSuggestionCreatedAtSlot.oldest => 0,
    GeneratedSuggestionCreatedAtSlot.older => 4,
    GeneratedSuggestionCreatedAtSlot.middle => 8,
    GeneratedSuggestionCreatedAtSlot.newer => 12,
    GeneratedSuggestionCreatedAtSlot.newest => 16,
  };
  return generatedSuggestionBase.add(Duration(hours: hours, seconds: index));
}

String generatedSuggestionToolName(
  GeneratedSuggestionFingerprintSlot slot,
) {
  return switch (slot) {
    GeneratedSuggestionFingerprintSlot.title => 'set_task_title',
    GeneratedSuggestionFingerprintSlot.priority => 'update_task_priority',
    GeneratedSuggestionFingerprintSlot.status => 'set_task_status',
    GeneratedSuggestionFingerprintSlot.estimate => 'update_task_estimate',
    GeneratedSuggestionFingerprintSlot.checklist => 'update_checklist_item',
  };
}

Map<String, dynamic> generatedSuggestionArgs(
  GeneratedSuggestionFingerprintSlot slot,
) {
  return switch (slot) {
    GeneratedSuggestionFingerprintSlot.title => const {
      'title': 'Generated title',
    },
    GeneratedSuggestionFingerprintSlot.priority => const {'priority': 'P1'},
    GeneratedSuggestionFingerprintSlot.status => const {
      'status': 'IN_PROGRESS',
    },
    GeneratedSuggestionFingerprintSlot.estimate => const {'minutes': 45},
    GeneratedSuggestionFingerprintSlot.checklist => const {
      'id': 'generated-checklist-item',
      'isChecked': true,
    },
  };
}

class GeneratedSuggestionItemSpec {
  const GeneratedSuggestionItemSpec({
    required this.fingerprintSlot,
    required this.statusSlot,
  });

  final GeneratedSuggestionFingerprintSlot fingerprintSlot;
  final GeneratedSuggestionItemStatusSlot statusSlot;

  ChangeItem item(int changeSetIndex, int itemIndex) {
    return ChangeItem(
      toolName: generatedSuggestionToolName(fingerprintSlot),
      args: generatedSuggestionArgs(fingerprintSlot),
      humanSummary:
          'Generated proposal ${fingerprintSlot.name} '
          '$changeSetIndex/$itemIndex/${statusSlot.name}',
      status: generatedSuggestionStatus(statusSlot),
    );
  }

  @override
  String toString() {
    return 'GeneratedSuggestionItemSpec('
        'fingerprintSlot: $fingerprintSlot, statusSlot: $statusSlot)';
  }
}

class GeneratedSuggestionChangeSetSpec {
  const GeneratedSuggestionChangeSetSpec({
    required this.createdAtSlot,
    required this.items,
  });

  final GeneratedSuggestionCreatedAtSlot createdAtSlot;
  final List<GeneratedSuggestionItemSpec> items;

  String id(int index) => 'generated-change-set-$index';

  DateTime createdAt(int index) => generatedSuggestionCreatedAt(
    createdAtSlot,
    index,
  );

  ChangeSetEntity changeSet(int index) {
    final changeItems = [
      for (final (itemIndex, item) in items.indexed)
        item.item(index, itemIndex),
    ];
    return makeTestChangeSet(
      id: id(index),
      agentId: 'generated-agent',
      taskId: 'task-abc',
      status: ChangeItem.deriveSetStatus(changeItems),
      items: changeItems,
      createdAt: createdAt(index),
    );
  }

  @override
  String toString() {
    return 'GeneratedSuggestionChangeSetSpec('
        'createdAtSlot: $createdAtSlot, items: $items)';
  }
}

class GeneratedSuggestionActivitySpec {
  const GeneratedSuggestionActivitySpec({
    required this.fingerprintSlot,
    required this.verdictSlot,
    required this.createdAtSlot,
  });

  final GeneratedSuggestionFingerprintSlot fingerprintSlot;
  final GeneratedSuggestionVerdictSlot verdictSlot;
  final GeneratedSuggestionCreatedAtSlot createdAtSlot;

  String id(int index) => 'generated-activity-change-set-$index';

  LedgerEntry entry(int index) {
    final verdict = generatedSuggestionVerdict(verdictSlot);
    final args = generatedSuggestionArgs(fingerprintSlot);
    final toolName = generatedSuggestionToolName(fingerprintSlot);
    return LedgerEntry(
      changeSetId: id(index),
      itemIndex: index,
      toolName: toolName,
      args: args,
      humanSummary:
          'Generated activity ${fingerprintSlot.name}/${verdictSlot.name}',
      fingerprint: ChangeItem.fingerprintFromParts(toolName, args),
      status: generatedSuggestionStatusForVerdict(verdict),
      createdAt: generatedSuggestionCreatedAt(createdAtSlot, index),
      resolvedAt: generatedSuggestionCreatedAt(createdAtSlot, index).add(
        const Duration(minutes: 1),
      ),
      resolvedBy: generatedSuggestionActorForVerdict(verdict),
      verdict: verdict,
    );
  }

  @override
  String toString() {
    return 'GeneratedSuggestionActivitySpec('
        'fingerprintSlot: $fingerprintSlot, verdictSlot: $verdictSlot, '
        'createdAtSlot: $createdAtSlot)';
  }
}

class GeneratedUnifiedSuggestionScenario {
  const GeneratedUnifiedSuggestionScenario({
    required this.changeSets,
    required this.activity,
  });

  final List<GeneratedSuggestionChangeSetSpec> changeSets;
  final List<GeneratedSuggestionActivitySpec> activity;

  List<ChangeSetEntity> get pendingSets => [
    for (final (index, spec) in changeSets.indexed) spec.changeSet(index),
  ];

  // Sorted newest-first to mirror the repository contract the provider
  // relies on (see unifiedSuggestionList): first occurrence of each
  // fingerprint after dedup is the most recent decision.
  List<LedgerEntry> get resolvedEntries {
    return [
      for (final (index, spec) in activity.indexed) spec.entry(index),
    ]..sort((a, b) => b.resolvedAt!.compareTo(a.resolvedAt!));
  }

  ProposalLedger get ledger => ProposalLedger(
    open: const [],
    resolved: resolvedEntries,
    pendingSets: pendingSets,
  );

  List<GeneratedOpenSuggestionExpectation> get expectedOpen {
    final seen = <String>{};
    final seenDisplayKeys = <String>{};
    final open = <GeneratedOpenSuggestionExpectation>[];
    for (final changeSet in pendingSets) {
      for (final (itemIndex, item) in changeSet.items.indexed) {
        if (item.status != ChangeItemStatus.pending) continue;
        final fingerprint = ChangeItem.fingerprint(item);
        if (!seen.add(fingerprint)) continue;
        final displayKey = ChangeItem.displayDuplicateKey(item);
        if (displayKey != null && !seenDisplayKeys.add(displayKey)) continue;
        open.add(
          (
            changeSetId: changeSet.id,
            itemIndex: itemIndex,
            toolName: item.toolName,
            args: item.args,
            humanSummary: item.humanSummary,
            fingerprint: fingerprint,
          ),
        );
      }
    }
    open.sort((a, b) {
      final aSet = pendingSets.singleWhere((set) => set.id == a.changeSetId);
      final bSet = pendingSets.singleWhere((set) => set.id == b.changeSetId);
      return bSet.createdAt.compareTo(aSet.createdAt);
    });
    return open;
  }

  List<GeneratedActivityExpectation> get expectedActivity {
    final seen = <String>{};
    return [
      for (final entry in resolvedEntries)
        if (seen.add(entry.fingerprint))
          (
            changeSetId: entry.changeSetId,
            fingerprint: entry.fingerprint,
            status: entry.status,
            verdict: entry.verdict,
            resolvedBy: entry.resolvedBy,
          ),
    ];
  }

  @override
  String toString() {
    return 'GeneratedUnifiedSuggestionScenario('
        'changeSets: $changeSets, activity: $activity)';
  }
}

/// Spec for one entry in the timer-dedup property input list
/// (see `debugKeepLatestRunningTimerUpdate`).
class GeneratedTimerDedupSpec {
  const GeneratedTimerDedupSpec({
    required this.isTimerUpdate,
    required this.timerSlot,
    required this.createdAtMinutes,
    required this.itemIndex,
  });

  final bool isTimerUpdate;
  final int timerSlot;
  final int createdAtMinutes;
  final int itemIndex;

  /// Raw args value: null (absent), distinct ids, or whitespace-only
  /// (which the implementation must treat as null).
  String? get rawTimerId => switch (timerSlot % 5) {
    0 => null,
    1 => 'timer-a',
    2 => 'timer-b',
    3 => 'timer-c',
    _ => '   ',
  };

  @override
  String toString() =>
      'GeneratedTimerDedupSpec(isTimerUpdate: $isTimerUpdate, '
      'rawTimerId: $rawTimerId, createdAtMinutes: $createdAtMinutes, '
      'itemIndex: $itemIndex)';
}

extension AnyGeneratedUnifiedSuggestionScenario on glados.Any {
  glados.Generator<GeneratedSuggestionItemStatusSlot>
  get suggestionItemStatusSlot =>
      glados.AnyUtils(this).choose(GeneratedSuggestionItemStatusSlot.values);

  glados.Generator<GeneratedSuggestionFingerprintSlot>
  get suggestionFingerprintSlot =>
      glados.AnyUtils(this).choose(GeneratedSuggestionFingerprintSlot.values);

  glados.Generator<GeneratedSuggestionCreatedAtSlot>
  get suggestionCreatedAtSlot =>
      glados.AnyUtils(this).choose(GeneratedSuggestionCreatedAtSlot.values);

  glados.Generator<GeneratedSuggestionVerdictSlot> get suggestionVerdictSlot =>
      glados.AnyUtils(this).choose(GeneratedSuggestionVerdictSlot.values);

  glados.Generator<GeneratedSuggestionItemSpec> get suggestionItemSpec =>
      glados.CombinableAny(this).combine2(
        suggestionFingerprintSlot,
        suggestionItemStatusSlot,
        (
          GeneratedSuggestionFingerprintSlot fingerprintSlot,
          GeneratedSuggestionItemStatusSlot statusSlot,
        ) => GeneratedSuggestionItemSpec(
          fingerprintSlot: fingerprintSlot,
          statusSlot: statusSlot,
        ),
      );

  glados.Generator<GeneratedSuggestionChangeSetSpec>
  get suggestionChangeSetSpec => glados.CombinableAny(this).combine2(
    suggestionCreatedAtSlot,
    glados.ListAnys(this).listWithLengthInRange(0, 6, suggestionItemSpec),
    (
      GeneratedSuggestionCreatedAtSlot createdAtSlot,
      List<GeneratedSuggestionItemSpec> items,
    ) => GeneratedSuggestionChangeSetSpec(
      createdAtSlot: createdAtSlot,
      items: items,
    ),
  );

  glados.Generator<GeneratedSuggestionActivitySpec>
  get suggestionActivitySpec => glados.CombinableAny(this).combine3(
    suggestionFingerprintSlot,
    suggestionVerdictSlot,
    suggestionCreatedAtSlot,
    (
      GeneratedSuggestionFingerprintSlot fingerprintSlot,
      GeneratedSuggestionVerdictSlot verdictSlot,
      GeneratedSuggestionCreatedAtSlot createdAtSlot,
    ) => GeneratedSuggestionActivitySpec(
      fingerprintSlot: fingerprintSlot,
      verdictSlot: verdictSlot,
      createdAtSlot: createdAtSlot,
    ),
  );

  glados.Generator<GeneratedTimerDedupSpec> get timerDedupSpec =>
      glados.CombinableAny(this).combine4(
        glados.AnyUtils(this).choose(const [false, true]),
        glados.IntAnys(this).intInRange(0, 5),
        glados.IntAnys(this).intInRange(0, 240),
        glados.IntAnys(this).intInRange(0, 5),
        (
          bool isTimerUpdate,
          int timerSlot,
          int createdAtMinutes,
          int itemIndex,
        ) => GeneratedTimerDedupSpec(
          isTimerUpdate: isTimerUpdate,
          timerSlot: timerSlot,
          createdAtMinutes: createdAtMinutes,
          itemIndex: itemIndex,
        ),
      );

  glados.Generator<List<GeneratedTimerDedupSpec>> get timerDedupSpecs =>
      glados.ListAnys(this).listWithLengthInRange(0, 12, timerDedupSpec);

  glados.Generator<GeneratedUnifiedSuggestionScenario>
  get unifiedSuggestionScenario => glados.CombinableAny(this).combine2(
    glados.ListAnys(
      this,
    ).listWithLengthInRange(0, 8, suggestionChangeSetSpec),
    glados.ListAnys(this).listWithLengthInRange(0, 10, suggestionActivitySpec),
    (
      List<GeneratedSuggestionChangeSetSpec> changeSets,
      List<GeneratedSuggestionActivitySpec> activity,
    ) => GeneratedUnifiedSuggestionScenario(
      changeSets: changeSets,
      activity: activity,
    ),
  );
}
