import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/soul_query_providers.dart';
import 'package:lotti/features/agents/ui/souls/soul_view_model.dart';

import '../../test_utils.dart';

enum _GeneratedSoulEntitySlot { alpha, beta, gamma, nonSoul }

enum _GeneratedSoulVersionSlot { none, first, fourth, wrongEntity }

int? _expectedSoulVersion(_GeneratedSoulVersionSlot slot) {
  return switch (slot) {
    _GeneratedSoulVersionSlot.none => null,
    _GeneratedSoulVersionSlot.first => 1,
    _GeneratedSoulVersionSlot.fourth => 4,
    _GeneratedSoulVersionSlot.wrongEntity => null,
  };
}

class _GeneratedSoulRowSpec {
  const _GeneratedSoulRowSpec({
    required this.entitySlot,
    required this.versionSlot,
  });

  final _GeneratedSoulEntitySlot entitySlot;
  final _GeneratedSoulVersionSlot versionSlot;

  bool get isSoul => entitySlot != _GeneratedSoulEntitySlot.nonSoul;

  @override
  String toString() {
    return '_GeneratedSoulRowSpec('
        'entitySlot: $entitySlot, versionSlot: $versionSlot)';
  }
}

class _GeneratedSoulRowsScenario {
  const _GeneratedSoulRowsScenario({required this.specs});

  final List<_GeneratedSoulRowSpec> specs;

  @override
  String toString() {
    return '_GeneratedSoulRowsScenario(specs: $specs)';
  }
}

extension _AnyGeneratedSoulRowsScenario on glados.Any {
  glados.Generator<_GeneratedSoulEntitySlot> get soulEntitySlot =>
      glados.AnyUtils(this).choose(_GeneratedSoulEntitySlot.values);

  glados.Generator<_GeneratedSoulVersionSlot> get soulVersionSlot =>
      glados.AnyUtils(this).choose(_GeneratedSoulVersionSlot.values);

  glados.Generator<_GeneratedSoulRowSpec> get soulRowSpec =>
      glados.CombinableAny(this).combine2(
        soulEntitySlot,
        soulVersionSlot,
        (
          _GeneratedSoulEntitySlot entitySlot,
          _GeneratedSoulVersionSlot versionSlot,
        ) => _GeneratedSoulRowSpec(
          entitySlot: entitySlot,
          versionSlot: versionSlot,
        ),
      );

  glados.Generator<_GeneratedSoulRowsScenario> get soulRowsScenario =>
      glados.ListAnys(this)
          .listWithLengthInRange(0, 30, soulRowSpec)
          .map((specs) => _GeneratedSoulRowsScenario(specs: specs));
}

void main() {
  group('agentSoulRowVmsProvider', () {
    glados.Glados(
      glados.any.soulRowsScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test('maps generated soul rows with nullable active versions', (
      scenario,
    ) async {
      final entities = <AgentDomainEntity>[];
      final versionsBySoulId = <String, AgentDomainEntity?>{};
      final expectedSpecs =
          <({String id, int originalIndex, _GeneratedSoulRowSpec spec})>[];

      for (final (index, spec) in scenario.specs.indexed) {
        final id = spec.isSoul
            ? 'soul-$index-${spec.entitySlot.name}'
            : 'non-soul-$index';

        if (spec.isSoul) {
          entities.add(
            makeTestSoulDocument(
              id: id,
              agentId: id,
              displayName: 'Soul $index ${spec.entitySlot.name}',
              updatedAt: DateTime(2026, 4, 2, index % 24),
            ),
          );
          versionsBySoulId[id] = _soulVersionFor(id, spec.versionSlot);
          expectedSpecs.add((id: id, originalIndex: index, spec: spec));
        } else {
          entities.add(
            makeTestTemplate(
              id: id,
              agentId: id,
              displayName: 'Not a soul $index',
            ),
          );
        }
      }

      final vms = await _readSoulVms(
        entities: entities,
        versionsBySoulId: versionsBySoulId,
      );

      expect(vms, hasLength(expectedSpecs.length), reason: '$scenario');
      for (final (rowIndex, expected) in expectedSpecs.indexed) {
        final vm = vms[rowIndex];
        final spec = expected.spec;
        expect(vm.id, expected.id, reason: '$scenario');
        expect(
          vm.displayName,
          'Soul ${expected.originalIndex} ${spec.entitySlot.name}',
        );
        expect(
          vm.updatedAt,
          DateTime(2026, 4, 2, expected.originalIndex % 24),
        );
        expect(vm.activeVersion, _expectedSoulVersion(spec.versionSlot));
      }
    });

    test('returns an empty list when no souls are present', () async {
      final vms = await _readSoulVms(
        entities: const [],
        versionsBySoulId: const {},
      );

      expect(vms, isEmpty);
    });
  });
}

Future<List<SoulVm>> _readSoulVms({
  required List<AgentDomainEntity> entities,
  required Map<String, AgentDomainEntity?> versionsBySoulId,
}) async {
  final container = ProviderContainer(
    overrides: [
      allSoulDocumentsProvider.overrideWith((ref) async => entities),
      activeSoulVersionProvider.overrideWith(
        (ref, soulId) async => versionsBySoulId[soulId],
      ),
    ],
  );

  try {
    return await container.read(agentSoulRowVmsProvider.future);
  } finally {
    container.dispose();
  }
}

AgentDomainEntity? _soulVersionFor(
  String soulId,
  _GeneratedSoulVersionSlot slot,
) {
  return switch (slot) {
    _GeneratedSoulVersionSlot.none => null,
    _GeneratedSoulVersionSlot.first => makeTestSoulDocumentVersion(
      id: 'version-$soulId',
      agentId: soulId,
    ),
    _GeneratedSoulVersionSlot.fourth => makeTestSoulDocumentVersion(
      id: 'version-$soulId',
      agentId: soulId,
      version: 4,
    ),
    _GeneratedSoulVersionSlot.wrongEntity => makeTestTemplate(
      id: 'wrong-version-$soulId',
      agentId: 'wrong-version-$soulId',
    ),
  };
}
