import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_enums.dart';

enum _GeneratedAgentEnumFamily {
  lifecycle,
  interactionMode,
  runStatus,
  templateKind,
  templateVersionStatus,
  soulDocumentVersionStatus,
  observationTarget,
  wakeRunStatus,
  wakeReason,
  evolutionSessionStatus,
  evolutionNoteKind,
  changeSetStatus,
  changeItemStatus,
  changeDecisionVerdict,
  decisionActor,
  projectRecommendationStatus,
  feedbackSentiment,
  feedbackCategory,
  observationPriority,
  observationCategory,
  agentMessageKind,
  agentMilestone,
  parsedItemKind,
  parsedItemConfidence,
}

enum _GeneratedEnumNameStyle {
  exact,
  uppercase,
  snakeCase,
  paddedSnakeCase,
  screamingSnakeCase,
}

enum _GeneratedInvalidEnumNameKind {
  nullName,
  empty,
  suffix,
  hyphenated,
  unknown,
}

class _GeneratedEnumParseScenario {
  const _GeneratedEnumParseScenario({
    required this.family,
    required this.valueIndex,
    required this.nameStyle,
  });

  final _GeneratedAgentEnumFamily family;
  final int valueIndex;
  final _GeneratedEnumNameStyle nameStyle;

  List<Enum> get values => _agentEnumValues(family);

  Enum get value => values[valueIndex % values.length];

  String get inputName => _spellEnumName(value.name, nameStyle);

  @override
  String toString() {
    return '_GeneratedEnumParseScenario('
        'family: $family, value: $value, nameStyle: $nameStyle, '
        'inputName: $inputName)';
  }
}

class _GeneratedInvalidEnumParseScenario {
  const _GeneratedInvalidEnumParseScenario({
    required this.family,
    required this.valueIndex,
    required this.invalidNameKind,
  });

  final _GeneratedAgentEnumFamily family;
  final int valueIndex;
  final _GeneratedInvalidEnumNameKind invalidNameKind;

  List<Enum> get values => _agentEnumValues(family);

  Enum get value => values[valueIndex % values.length];

  String? get inputName => _invalidEnumName(
    family: family,
    value: value,
    kind: invalidNameKind,
  );

  @override
  String toString() {
    return '_GeneratedInvalidEnumParseScenario('
        'family: $family, value: $value, '
        'invalidNameKind: $invalidNameKind, inputName: $inputName)';
  }
}

extension _AnyGeneratedAgentEnumScenario on glados.Any {
  glados.Generator<_GeneratedAgentEnumFamily> get agentEnumFamily =>
      glados.AnyUtils(this).choose(_GeneratedAgentEnumFamily.values);

  glados.Generator<_GeneratedEnumNameStyle> get enumNameStyle =>
      glados.AnyUtils(this).choose(_GeneratedEnumNameStyle.values);

  glados.Generator<_GeneratedInvalidEnumNameKind> get invalidEnumNameKind =>
      glados.AnyUtils(this).choose(_GeneratedInvalidEnumNameKind.values);

  glados.Generator<_GeneratedEnumParseScenario> get enumParseScenario =>
      glados.CombinableAny(this).combine3(
        agentEnumFamily,
        glados.IntAnys(this).intInRange(0, 64),
        enumNameStyle,
        (
          _GeneratedAgentEnumFamily family,
          int valueIndex,
          _GeneratedEnumNameStyle nameStyle,
        ) => _GeneratedEnumParseScenario(
          family: family,
          valueIndex: valueIndex,
          nameStyle: nameStyle,
        ),
      );

  glados.Generator<_GeneratedInvalidEnumParseScenario>
  get invalidEnumParseScenario => glados.CombinableAny(this).combine3(
    agentEnumFamily,
    glados.IntAnys(this).intInRange(0, 64),
    invalidEnumNameKind,
    (
      _GeneratedAgentEnumFamily family,
      int valueIndex,
      _GeneratedInvalidEnumNameKind invalidNameKind,
    ) => _GeneratedInvalidEnumParseScenario(
      family: family,
      valueIndex: valueIndex,
      invalidNameKind: invalidNameKind,
    ),
  );
}

void main() {
  group('parseEnumByName', () {
    glados.Glados(
      glados.any.enumParseScenario,
      glados.ExploreConfig(numRuns: 260),
    ).test('resolves generated agent enum spellings', (scenario) {
      expect(
        _parseAgentEnum(scenario.family, scenario.inputName),
        equals(scenario.value),
        reason: '$scenario',
      );
    }, tags: 'glados');

    glados.Glados(
      glados.any.invalidEnumParseScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test('rejects generated invalid agent enum spellings', (scenario) {
      expect(
        _parseAgentEnum(scenario.family, scenario.inputName),
        isNull,
        reason: '$scenario',
      );
    }, tags: 'glados');

    test('resolves every agent enum value from exact and snake-case names', () {
      for (final family in _GeneratedAgentEnumFamily.values) {
        final values = _agentEnumValues(family);
        expect(values, isNotEmpty, reason: '$family');

        for (final value in values) {
          expect(
            _parseAgentEnum(family, value.name),
            equals(value),
            reason: '$family exact $value',
          );
          expect(
            _parseAgentEnum(family, _camelToSnakeCase(value.name)),
            equals(value),
            reason: '$family snake-case $value',
          );
        }
      }
    });
  });
}

List<Enum> _agentEnumValues(_GeneratedAgentEnumFamily family) {
  return switch (family) {
    _GeneratedAgentEnumFamily.lifecycle => List<Enum>.of(
      AgentLifecycle.values,
    ),
    _GeneratedAgentEnumFamily.interactionMode => List<Enum>.of(
      AgentInteractionMode.values,
    ),
    _GeneratedAgentEnumFamily.runStatus => List<Enum>.of(
      AgentRunStatus.values,
    ),
    _GeneratedAgentEnumFamily.templateKind => List<Enum>.of(
      AgentTemplateKind.values,
    ),
    _GeneratedAgentEnumFamily.templateVersionStatus => List<Enum>.of(
      AgentTemplateVersionStatus.values,
    ),
    _GeneratedAgentEnumFamily.soulDocumentVersionStatus => List<Enum>.of(
      SoulDocumentVersionStatus.values,
    ),
    _GeneratedAgentEnumFamily.observationTarget => List<Enum>.of(
      ObservationTarget.values,
    ),
    _GeneratedAgentEnumFamily.wakeRunStatus => List<Enum>.of(
      WakeRunStatus.values,
    ),
    _GeneratedAgentEnumFamily.wakeReason => List<Enum>.of(WakeReason.values),
    _GeneratedAgentEnumFamily.evolutionSessionStatus => List<Enum>.of(
      EvolutionSessionStatus.values,
    ),
    _GeneratedAgentEnumFamily.evolutionNoteKind => List<Enum>.of(
      EvolutionNoteKind.values,
    ),
    _GeneratedAgentEnumFamily.changeSetStatus => List<Enum>.of(
      ChangeSetStatus.values,
    ),
    _GeneratedAgentEnumFamily.changeItemStatus => List<Enum>.of(
      ChangeItemStatus.values,
    ),
    _GeneratedAgentEnumFamily.changeDecisionVerdict => List<Enum>.of(
      ChangeDecisionVerdict.values,
    ),
    _GeneratedAgentEnumFamily.decisionActor => List<Enum>.of(
      DecisionActor.values,
    ),
    _GeneratedAgentEnumFamily.projectRecommendationStatus => List<Enum>.of(
      ProjectRecommendationStatus.values,
    ),
    _GeneratedAgentEnumFamily.feedbackSentiment => List<Enum>.of(
      FeedbackSentiment.values,
    ),
    _GeneratedAgentEnumFamily.feedbackCategory => List<Enum>.of(
      FeedbackCategory.values,
    ),
    _GeneratedAgentEnumFamily.observationPriority => List<Enum>.of(
      ObservationPriority.values,
    ),
    _GeneratedAgentEnumFamily.observationCategory => List<Enum>.of(
      ObservationCategory.values,
    ),
    _GeneratedAgentEnumFamily.agentMessageKind => List<Enum>.of(
      AgentMessageKind.values,
    ),
    _GeneratedAgentEnumFamily.agentMilestone => List<Enum>.of(
      AgentMilestone.values,
    ),
    _GeneratedAgentEnumFamily.parsedItemKind => List<Enum>.of(
      ParsedItemKind.values,
    ),
    _GeneratedAgentEnumFamily.parsedItemConfidence => List<Enum>.of(
      ParsedItemConfidence.values,
    ),
  };
}

Enum? _parseAgentEnum(_GeneratedAgentEnumFamily family, String? name) {
  return parseEnumByName(_agentEnumValues(family), name);
}

String _spellEnumName(String name, _GeneratedEnumNameStyle style) {
  final snakeCase = _camelToSnakeCase(name);

  return switch (style) {
    _GeneratedEnumNameStyle.exact => name,
    _GeneratedEnumNameStyle.uppercase => name.toUpperCase(),
    _GeneratedEnumNameStyle.snakeCase => snakeCase,
    _GeneratedEnumNameStyle.paddedSnakeCase => '  $snakeCase  ',
    _GeneratedEnumNameStyle.screamingSnakeCase => snakeCase.toUpperCase(),
  };
}

String? _invalidEnumName({
  required _GeneratedAgentEnumFamily family,
  required Enum value,
  required _GeneratedInvalidEnumNameKind kind,
}) {
  return switch (kind) {
    _GeneratedInvalidEnumNameKind.nullName => null,
    _GeneratedInvalidEnumNameKind.empty => '   ___   ',
    _GeneratedInvalidEnumNameKind.suffix => '${value.name}x',
    _GeneratedInvalidEnumNameKind.hyphenated =>
      '${_camelToSnakeCase(value.name).replaceAll('_', '-')}-invalid',
    _GeneratedInvalidEnumNameKind.unknown => 'not_${family.name}_${value.name}',
  };
}

String _camelToSnakeCase(String name) {
  final buffer = StringBuffer();

  for (var i = 0; i < name.length; i++) {
    final char = name[i];
    final isUppercase =
        char.toUpperCase() == char && char.toLowerCase() != char;
    if (isUppercase && i > 0) {
      buffer.write('_');
    }
    buffer.write(char.toLowerCase());
  }

  return buffer.toString();
}
