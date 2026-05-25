import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/features/agents/ui/templates/template_view_model.dart';

import '../../test_utils.dart';

enum _GeneratedTemplateEntitySlot { alpha, beta, gamma, delta, nonTemplate }

enum _GeneratedTemplateKindSlot {
  taskAgent,
  dayAgent,
  projectAgent,
  templateImprover,
}

enum _GeneratedTemplateVersionSlot { none, first, seventh, wrongEntity }

AgentTemplateKind _generatedTemplateKind(_GeneratedTemplateKindSlot slot) {
  return switch (slot) {
    _GeneratedTemplateKindSlot.taskAgent => AgentTemplateKind.taskAgent,
    _GeneratedTemplateKindSlot.dayAgent => AgentTemplateKind.dayAgent,
    _GeneratedTemplateKindSlot.projectAgent => AgentTemplateKind.projectAgent,
    _GeneratedTemplateKindSlot.templateImprover =>
      AgentTemplateKind.templateImprover,
  };
}

int? _expectedTemplateVersion(_GeneratedTemplateVersionSlot slot) {
  return switch (slot) {
    _GeneratedTemplateVersionSlot.none => null,
    _GeneratedTemplateVersionSlot.first => 1,
    _GeneratedTemplateVersionSlot.seventh => 7,
    _GeneratedTemplateVersionSlot.wrongEntity => null,
  };
}

class _GeneratedTemplateRowSpec {
  const _GeneratedTemplateRowSpec({
    required this.entitySlot,
    required this.kindSlot,
    required this.versionSlot,
    required this.pendingReview,
  });

  final _GeneratedTemplateEntitySlot entitySlot;
  final _GeneratedTemplateKindSlot kindSlot;
  final _GeneratedTemplateVersionSlot versionSlot;
  final bool pendingReview;

  bool get isTemplate => entitySlot != _GeneratedTemplateEntitySlot.nonTemplate;

  @override
  String toString() {
    return '_GeneratedTemplateRowSpec('
        'entitySlot: $entitySlot, kindSlot: $kindSlot, '
        'versionSlot: $versionSlot, pendingReview: $pendingReview)';
  }
}

class _GeneratedTemplateRowsScenario {
  const _GeneratedTemplateRowsScenario({required this.specs});

  final List<_GeneratedTemplateRowSpec> specs;

  @override
  String toString() {
    return '_GeneratedTemplateRowsScenario(specs: $specs)';
  }
}

extension _AnyGeneratedTemplateRowsScenario on glados.Any {
  glados.Generator<_GeneratedTemplateEntitySlot> get templateEntitySlot =>
      glados.AnyUtils(this).choose(_GeneratedTemplateEntitySlot.values);

  glados.Generator<_GeneratedTemplateKindSlot> get templateKindSlot =>
      glados.AnyUtils(this).choose(_GeneratedTemplateKindSlot.values);

  glados.Generator<_GeneratedTemplateVersionSlot> get templateVersionSlot =>
      glados.AnyUtils(this).choose(_GeneratedTemplateVersionSlot.values);

  glados.Generator<_GeneratedTemplateRowSpec> get templateRowSpec =>
      glados.CombinableAny(this).combine4(
        templateEntitySlot,
        templateKindSlot,
        templateVersionSlot,
        glados.any.bool,
        (
          _GeneratedTemplateEntitySlot entitySlot,
          _GeneratedTemplateKindSlot kindSlot,
          _GeneratedTemplateVersionSlot versionSlot,
          bool pendingReview,
        ) => _GeneratedTemplateRowSpec(
          entitySlot: entitySlot,
          kindSlot: kindSlot,
          versionSlot: versionSlot,
          pendingReview: pendingReview,
        ),
      );

  glados.Generator<_GeneratedTemplateRowsScenario> get templateRowsScenario =>
      glados.ListAnys(this)
          .listWithLengthInRange(0, 30, templateRowSpec)
          .map((specs) => _GeneratedTemplateRowsScenario(specs: specs));
}

void main() {
  group('agentTemplateRowVmsProvider', () {
    glados.Glados(
      glados.any.templateRowsScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'maps generated template rows with versions and pending flags',
      (
        scenario,
      ) async {
        final entities = <AgentDomainEntity>[];
        final versionsByTemplateId = <String, AgentDomainEntity?>{};
        final pendingTemplateIds = <String>{};
        final expectedSpecs =
            <
              ({String id, int originalIndex, _GeneratedTemplateRowSpec spec})
            >[];

        for (final (index, spec) in scenario.specs.indexed) {
          final id = spec.isTemplate
              ? 'tpl-$index-${spec.entitySlot.name}'
              : 'non-template-$index';

          if (spec.isTemplate) {
            entities.add(
              makeTestTemplate(
                id: id,
                agentId: id,
                displayName: 'Template $index ${spec.entitySlot.name}',
                kind: _generatedTemplateKind(spec.kindSlot),
                modelId: 'model-$index',
                updatedAt: DateTime(2026, 4, 1, index % 24),
              ),
            );
            versionsByTemplateId[id] = _templateVersionFor(
              id,
              spec.versionSlot,
            );
            if (spec.pendingReview) {
              pendingTemplateIds.add(id);
            }
            expectedSpecs.add((id: id, originalIndex: index, spec: spec));
          } else {
            entities.add(
              makeTestSoulDocument(
                id: id,
                agentId: id,
                displayName: 'Not a template $index',
              ),
            );
          }
        }

        final vms = await _readTemplateVms(
          entities: entities,
          versionsByTemplateId: versionsByTemplateId,
          pendingTemplateIds: pendingTemplateIds,
        );

        expect(vms, hasLength(expectedSpecs.length), reason: '$scenario');
        for (final (rowIndex, expected) in expectedSpecs.indexed) {
          final vm = vms[rowIndex];
          final spec = expected.spec;
          expect(vm.id, expected.id, reason: '$scenario');
          expect(
            vm.displayName,
            'Template ${expected.originalIndex} ${spec.entitySlot.name}',
          );
          expect(vm.kind, _generatedTemplateKind(spec.kindSlot));
          expect(vm.modelId, 'model-${expected.originalIndex}');
          expect(
            vm.updatedAt,
            DateTime(2026, 4, 1, expected.originalIndex % 24),
          );
          expect(vm.hasPendingReview, spec.pendingReview);
          expect(vm.activeVersion, _expectedTemplateVersion(spec.versionSlot));
        }
      },
      tags: 'glados',
    );

    test('returns an empty list when no templates are present', () async {
      final vms = await _readTemplateVms(
        entities: const [],
        versionsByTemplateId: const {},
        pendingTemplateIds: const {},
      );

      expect(vms, isEmpty);
    });
  });
}

Future<List<TemplateVm>> _readTemplateVms({
  required List<AgentDomainEntity> entities,
  required Map<String, AgentDomainEntity?> versionsByTemplateId,
  required Set<String> pendingTemplateIds,
}) async {
  final container = ProviderContainer(
    overrides: [
      agentTemplatesProvider.overrideWith((ref) async => entities),
      activeTemplateVersionProvider.overrideWith(
        (ref, templateId) async => versionsByTemplateId[templateId],
      ),
      templatesPendingReviewProvider.overrideWith(
        (ref) async => pendingTemplateIds,
      ),
    ],
  );

  try {
    container.read(agentTemplateRowVmsProvider);
    await container.read(agentTemplatesProvider.future);
    await container.read(templatesPendingReviewProvider.future);
    for (final template in entities.whereType<AgentTemplateEntity>()) {
      await container.read(activeTemplateVersionProvider(template.id).future);
    }

    return container.read(agentTemplateRowVmsProvider).requireValue;
  } finally {
    container.dispose();
  }
}

AgentDomainEntity? _templateVersionFor(
  String templateId,
  _GeneratedTemplateVersionSlot slot,
) {
  return switch (slot) {
    _GeneratedTemplateVersionSlot.none => null,
    _GeneratedTemplateVersionSlot.first => makeTestTemplateVersion(
      id: 'version-$templateId',
      agentId: templateId,
    ),
    _GeneratedTemplateVersionSlot.seventh => makeTestTemplateVersion(
      id: 'version-$templateId',
      agentId: templateId,
      version: 7,
    ),
    _GeneratedTemplateVersionSlot.wrongEntity => makeTestSoulDocument(
      id: 'wrong-version-$templateId',
      agentId: 'wrong-version-$templateId',
    ),
  };
}
