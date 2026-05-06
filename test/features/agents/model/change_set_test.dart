import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';

class _GeneratedChangeItemStatuses {
  const _GeneratedChangeItemStatuses(this.statuses);

  final List<ChangeItemStatus> statuses;

  List<ChangeItem> get items => [
    for (var index = 0; index < statuses.length; index++)
      ChangeItem(
        toolName: 'generated_tool',
        args: {'index': index},
        humanSummary: 'Generated item $index',
        status: statuses[index],
      ),
  ];

  ChangeSetStatus get expectedSetStatus {
    final anyResolved = statuses.any(
      (status) => status != ChangeItemStatus.pending,
    );
    if (!anyResolved) return ChangeSetStatus.pending;

    final allResolved = statuses.every(
      (status) => status != ChangeItemStatus.pending,
    );
    return allResolved
        ? ChangeSetStatus.resolved
        : ChangeSetStatus.partiallyResolved;
  }

  @override
  String toString() => '_GeneratedChangeItemStatuses($statuses)';
}

class _GeneratedResolvedAtScenario {
  const _GeneratedResolvedAtScenario({
    required this.status,
    required this.hasExistingResolvedAt,
  });

  static final now = DateTime(2026, 5, 6, 10);
  static final existingResolvedAt = DateTime(2026, 5, 5, 9);

  final ChangeSetStatus status;
  final bool hasExistingResolvedAt;

  DateTime? get existing => hasExistingResolvedAt ? existingResolvedAt : null;

  DateTime? get expected => switch (status) {
    ChangeSetStatus.resolved => existing ?? now,
    _ => null,
  };

  @override
  String toString() {
    return '_GeneratedResolvedAtScenario('
        'status: $status, '
        'existing: $existing)';
  }
}

extension _AnyChangeSetScenarios on glados.Any {
  glados.Generator<ChangeItemStatus> get changeItemStatus =>
      glados.AnyUtils(this).choose(ChangeItemStatus.values);

  glados.Generator<ChangeSetStatus> get changeSetStatus =>
      glados.AnyUtils(this).choose(ChangeSetStatus.values);

  glados.Generator<_GeneratedChangeItemStatuses> get changeItemStatuses =>
      glados.ListAnys(
            this,
          )
          .listWithLengthInRange(0, 8, changeItemStatus)
          .map(
            _GeneratedChangeItemStatuses.new,
          );

  glados.Generator<_GeneratedResolvedAtScenario> get resolvedAtScenario =>
      glados.CombinableAny(this).combine2(
        changeSetStatus,
        glados.AnyUtils(this).choose([true, false]),
        (
          ChangeSetStatus status,
          bool hasExistingResolvedAt,
        ) => _GeneratedResolvedAtScenario(
          status: status,
          hasExistingResolvedAt: hasExistingResolvedAt,
        ),
      );
}

void main() {
  group('ChangeItem', () {
    glados.Glados(
      glados.any.changeItemStatuses,
      glados.ExploreConfig(numRuns: 160),
    ).test('derives set status from generated item states', (scenario) {
      final result = ChangeItem.deriveSetStatus(scenario.items);

      expect(result, scenario.expectedSetStatus, reason: '$scenario');
    });

    glados.Glados(
      glados.any.resolvedAtScenario,
      glados.ExploreConfig(numRuns: 80),
    ).test('derives resolvedAt from generated set status transitions', (
      scenario,
    ) {
      final result = ChangeItem.deriveResolvedAt(
        newStatus: scenario.status,
        existingResolvedAt: scenario.existing,
        now: _GeneratedResolvedAtScenario.now,
      );

      expect(result, scenario.expected, reason: '$scenario');
    });
  });
}
