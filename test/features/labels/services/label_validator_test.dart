// ignore_for_file: avoid_redundant_argument_values
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/labels/services/label_validator.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockJournalDb mockDb;

  setUp(() {
    mockDb = MockJournalDb();
  });

  final testDate = DateTime(2024, 3, 15, 10, 30);
  final testDeletedDate = DateTime(2024, 3, 15, 11);

  LabelDefinition makeLabel(
    String id, {
    bool deleted = false,
    List<String>? applicableCategoryIds,
  }) => LabelDefinition(
    id: id,
    name: id,
    color: '#000',
    description: null,
    sortOrder: null,
    createdAt: testDate,
    updatedAt: testDate,
    vectorClock: null,
    private: false,
    deletedAt: deleted ? testDeletedDate : null,
    applicableCategoryIds: applicableCategoryIds,
  );

  group('validateForTask', () {
    test('separates suppressed from invalid/valid', () async {
      when(
        () => mockDb.getLabelDefinitionById('a'),
      ).thenAnswer((_) async => makeLabel('a'));
      when(
        () => mockDb.getLabelDefinitionById('e1'),
      ).thenAnswer(
        (_) async => makeLabel('e1', applicableCategoryIds: ['engineering']),
      );
      when(
        () => mockDb.getLabelDefinitionById('d1'),
      ).thenAnswer(
        (_) async => makeLabel('d1', applicableCategoryIds: ['design']),
      );
      when(
        () => mockDb.getLabelDefinitionById('z'),
      ).thenAnswer((_) async => makeLabel('z', deleted: true));

      final validator = LabelValidator(db: mockDb);

      final res = await validator.validateForTask(
        const ['a', 'e1', 'd1', 'z'],
        categoryId: 'engineering',
        suppressedIds: const {'e1'},
      );

      expect(res.valid.toSet(), {'a'});
      expect(res.suppressed.toSet(), {'e1'});
      expect(res.invalid.toSet(), {'d1', 'z'});
    });

    test('deleted label in suppressed set is treated as invalid', () async {
      when(
        () => mockDb.getLabelDefinitionById('z'),
      ).thenAnswer((_) async => makeLabel('z', deleted: true));

      final validator = LabelValidator(db: mockDb);

      final res = await validator.validateForTask(
        const ['z'],
        categoryId: 'engineering',
        suppressedIds: const {'z'},
      );

      expect(res.invalid, contains('z'));
      expect(res.suppressed, isEmpty);
      expect(res.valid, isEmpty);
    });
  });

  glados.Glados(
    glados.any.generatedLabelValidationScenario,
    glados.ExploreConfig(numRuns: 160),
  ).test('classifies generated label validation scenarios', (scenario) async {
    when(
      () => mockDb.getLabelDefinitionById(any()),
    ).thenAnswer((invocation) async {
      final id = invocation.positionalArguments.first as String;
      return scenario.definitionFor(id);
    });

    final validator = LabelValidator(db: mockDb);

    final task = await validator.validateForTask(
      scenario.requestedIds,
      categoryId: scenario.categoryId,
      suppressedIds: scenario.suppressedIds,
    );
    expect(task.valid, scenario.expectedTaskValid, reason: '$scenario');
    expect(task.invalid, scenario.expectedTaskInvalid, reason: '$scenario');
    expect(
      task.suppressed,
      scenario.expectedTaskSuppressed,
      reason: '$scenario',
    );
  }, tags: 'glados');
}

enum _GeneratedKnownLabelId { alpha, beta, gamma, delta }

enum _GeneratedRequestedLabelId { alpha, beta, gamma, delta, unknown, empty }

enum _GeneratedLabelState {
  missing,
  activeGlobalNull,
  activeGlobalEmpty,
  activeCatA,
  activeCatB,
  activeBothCategories,
  deleted,
}

enum _GeneratedCategoryId { none, catA, catB, other }

class _GeneratedLabelDefinitionStates {
  const _GeneratedLabelDefinitionStates({
    required this.alpha,
    required this.beta,
    required this.gamma,
    required this.delta,
  });

  final _GeneratedLabelState alpha;
  final _GeneratedLabelState beta;
  final _GeneratedLabelState gamma;
  final _GeneratedLabelState delta;

  _GeneratedLabelState stateFor(_GeneratedKnownLabelId id) => switch (id) {
    _GeneratedKnownLabelId.alpha => alpha,
    _GeneratedKnownLabelId.beta => beta,
    _GeneratedKnownLabelId.gamma => gamma,
    _GeneratedKnownLabelId.delta => delta,
  };

  @override
  String toString() {
    return '_GeneratedLabelDefinitionStates('
        'alpha: $alpha, '
        'beta: $beta, '
        'gamma: $gamma, '
        'delta: $delta)';
  }
}

class _GeneratedLabelValidationScenario {
  const _GeneratedLabelValidationScenario({
    required this.states,
    required this.requested,
    required this.category,
    required this.suppressed,
  });

  final _GeneratedLabelDefinitionStates states;
  final List<_GeneratedRequestedLabelId> requested;
  final _GeneratedCategoryId category;
  final List<_GeneratedRequestedLabelId> suppressed;

  String? get categoryId => category.id;

  List<String> get requestedIds =>
      requested.map((labelId) => labelId.id).toList();

  Set<String> get suppressedIds =>
      suppressed.map((labelId) => labelId.id).toSet();

  LabelDefinition? definitionFor(String id) {
    final knownId = _GeneratedKnownLabelIdExtension.fromId(id);
    if (knownId == null) {
      return null;
    }

    final state = states.stateFor(knownId);
    if (state == _GeneratedLabelState.missing) {
      return null;
    }

    final date = DateTime(2024, 3, 15, 10, 30);
    return LabelDefinition(
      id: id,
      name: id,
      color: '#000',
      description: null,
      sortOrder: null,
      createdAt: date,
      updatedAt: date,
      vectorClock: null,
      private: false,
      deletedAt: state == _GeneratedLabelState.deleted
          ? DateTime(2024, 3, 15, 11)
          : null,
      applicableCategoryIds: state.applicableCategoryIds,
    );
  }

  List<String> get expectedTaskValid => requestedIds
      .where((id) => _isActiveInCategory(id) && !suppressedIds.contains(id))
      .toList();

  List<String> get expectedTaskInvalid =>
      requestedIds.where((id) => !_isActiveInCategory(id)).toList();

  List<String> get expectedTaskSuppressed => requestedIds
      .where((id) => _isActiveInCategory(id) && suppressedIds.contains(id))
      .toList();

  bool _isActiveInCategory(String id) {
    final def = definitionFor(id);
    if (def == null || def.deletedAt != null) {
      return false;
    }

    final cats = def.applicableCategoryIds;
    final isGlobal = cats == null || cats.isEmpty;
    final inCategory =
        categoryId != null && (cats?.contains(categoryId) ?? false);
    return isGlobal || inCategory;
  }

  @override
  String toString() {
    return '_GeneratedLabelValidationScenario('
        'states: $states, '
        'requested: $requestedIds, '
        'categoryId: $categoryId, '
        'suppressedIds: $suppressedIds)';
  }
}

extension _GeneratedRequestedLabelIdExtension on _GeneratedRequestedLabelId {
  String get id => switch (this) {
    _GeneratedRequestedLabelId.alpha => 'alpha',
    _GeneratedRequestedLabelId.beta => 'beta',
    _GeneratedRequestedLabelId.gamma => 'gamma',
    _GeneratedRequestedLabelId.delta => 'delta',
    _GeneratedRequestedLabelId.unknown => 'unknown',
    _GeneratedRequestedLabelId.empty => '',
  };
}

extension _GeneratedKnownLabelIdExtension on _GeneratedKnownLabelId {
  String get id => switch (this) {
    _GeneratedKnownLabelId.alpha => 'alpha',
    _GeneratedKnownLabelId.beta => 'beta',
    _GeneratedKnownLabelId.gamma => 'gamma',
    _GeneratedKnownLabelId.delta => 'delta',
  };

  static _GeneratedKnownLabelId? fromId(String id) {
    for (final knownId in _GeneratedKnownLabelId.values) {
      if (knownId.id == id) {
        return knownId;
      }
    }
    return null;
  }
}

extension on _GeneratedLabelState {
  List<String>? get applicableCategoryIds => switch (this) {
    _GeneratedLabelState.activeGlobalNull ||
    _GeneratedLabelState.deleted ||
    _GeneratedLabelState.missing => null,
    _GeneratedLabelState.activeGlobalEmpty => const <String>[],
    _GeneratedLabelState.activeCatA => const ['cat-a'],
    _GeneratedLabelState.activeCatB => const ['cat-b'],
    _GeneratedLabelState.activeBothCategories => const ['cat-a', 'cat-b'],
  };
}

extension on _GeneratedCategoryId {
  String? get id => switch (this) {
    _GeneratedCategoryId.none => null,
    _GeneratedCategoryId.catA => 'cat-a',
    _GeneratedCategoryId.catB => 'cat-b',
    _GeneratedCategoryId.other => 'other',
  };
}

extension _AnyLabelValidator on glados.Any {
  glados.Generator<_GeneratedLabelState> get _labelState =>
      glados.AnyUtils(this).choose(_GeneratedLabelState.values);

  glados.Generator<_GeneratedRequestedLabelId> get _requestedLabelId =>
      glados.AnyUtils(this).choose(_GeneratedRequestedLabelId.values);

  glados.Generator<_GeneratedCategoryId> get _categoryId =>
      glados.AnyUtils(this).choose(_GeneratedCategoryId.values);

  glados.Generator<_GeneratedLabelDefinitionStates> get _definitionStates =>
      glados.CombinableAny(this).combine4(
        _labelState,
        _labelState,
        _labelState,
        _labelState,
        (
          _GeneratedLabelState alpha,
          _GeneratedLabelState beta,
          _GeneratedLabelState gamma,
          _GeneratedLabelState delta,
        ) => _GeneratedLabelDefinitionStates(
          alpha: alpha,
          beta: beta,
          gamma: gamma,
          delta: delta,
        ),
      );

  glados.Generator<_GeneratedLabelValidationScenario>
  get generatedLabelValidationScenario => glados.CombinableAny(this).combine4(
    _definitionStates,
    glados.ListAnys(this).listWithLengthInRange(
      0,
      12,
      _requestedLabelId,
    ),
    _categoryId,
    glados.ListAnys(this).listWithLengthInRange(
      0,
      8,
      _requestedLabelId,
    ),
    (
      _GeneratedLabelDefinitionStates states,
      List<_GeneratedRequestedLabelId> requested,
      _GeneratedCategoryId category,
      List<_GeneratedRequestedLabelId> suppressed,
    ) => _GeneratedLabelValidationScenario(
      states: states,
      requested: requested,
      category: category,
      suppressed: suppressed,
    ),
  );
}
