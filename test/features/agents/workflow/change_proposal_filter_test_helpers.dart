import 'package:glados/glados.dart' as glados;

enum GeneratedRedundancyToolKind { priority, status, title, language }

enum GeneratedRedundancyArgShape {
  exact,
  padded,
  lowerOrUpper,
  different,
  wrongType,
}

class GeneratedRedundancyScenario {
  const GeneratedRedundancyScenario({
    required this.toolKind,
    required this.argShape,
  });

  final GeneratedRedundancyToolKind toolKind;
  final GeneratedRedundancyArgShape argShape;

  String get toolName => switch (toolKind) {
    GeneratedRedundancyToolKind.priority => 'update_task_priority',
    GeneratedRedundancyToolKind.status => 'set_task_status',
    GeneratedRedundancyToolKind.title => 'set_task_title',
    GeneratedRedundancyToolKind.language => 'set_task_language',
  };

  String get argName => switch (toolKind) {
    GeneratedRedundancyToolKind.priority => 'priority',
    GeneratedRedundancyToolKind.status => 'status',
    GeneratedRedundancyToolKind.title => 'title',
    GeneratedRedundancyToolKind.language => 'languageCode',
  };

  Object? get argValue {
    return switch (toolKind) {
      GeneratedRedundancyToolKind.priority => switch (argShape) {
        GeneratedRedundancyArgShape.exact => 'P1',
        GeneratedRedundancyArgShape.padded => ' P1 ',
        GeneratedRedundancyArgShape.lowerOrUpper => 'p1',
        GeneratedRedundancyArgShape.different => 'P2',
        GeneratedRedundancyArgShape.wrongType => 1,
      },
      GeneratedRedundancyToolKind.status => switch (argShape) {
        GeneratedRedundancyArgShape.exact => 'IN PROGRESS',
        GeneratedRedundancyArgShape.padded => ' IN PROGRESS ',
        GeneratedRedundancyArgShape.lowerOrUpper => 'in progress',
        GeneratedRedundancyArgShape.different => 'GROOMED',
        GeneratedRedundancyArgShape.wrongType => 1,
      },
      GeneratedRedundancyToolKind.title => switch (argShape) {
        GeneratedRedundancyArgShape.exact => 'Fix login bug',
        GeneratedRedundancyArgShape.padded => ' Fix login bug ',
        GeneratedRedundancyArgShape.lowerOrUpper => 'fix login bug',
        GeneratedRedundancyArgShape.different => 'New title',
        GeneratedRedundancyArgShape.wrongType => 1,
      },
      GeneratedRedundancyToolKind.language => switch (argShape) {
        GeneratedRedundancyArgShape.exact => 'en',
        GeneratedRedundancyArgShape.padded => ' en ',
        GeneratedRedundancyArgShape.lowerOrUpper => 'EN',
        GeneratedRedundancyArgShape.different => 'de',
        GeneratedRedundancyArgShape.wrongType => 1,
      },
    };
  }

  Map<String, dynamic> get args => {argName: argValue};

  bool get shouldSkip {
    return switch (toolKind) {
      GeneratedRedundancyToolKind.priority =>
        argShape == GeneratedRedundancyArgShape.exact ||
            argShape == GeneratedRedundancyArgShape.padded ||
            argShape == GeneratedRedundancyArgShape.lowerOrUpper,
      GeneratedRedundancyToolKind.status =>
        argShape == GeneratedRedundancyArgShape.exact ||
            argShape == GeneratedRedundancyArgShape.padded ||
            argShape == GeneratedRedundancyArgShape.lowerOrUpper,
      GeneratedRedundancyToolKind.title =>
        argShape == GeneratedRedundancyArgShape.exact ||
            argShape == GeneratedRedundancyArgShape.padded,
      GeneratedRedundancyToolKind.language =>
        argShape == GeneratedRedundancyArgShape.exact ||
            argShape == GeneratedRedundancyArgShape.padded ||
            argShape == GeneratedRedundancyArgShape.lowerOrUpper,
    };
  }

  @override
  String toString() {
    return 'GeneratedRedundancyScenario('
        'toolKind: $toolKind, '
        'argShape: $argShape, '
        'args: $args, '
        'shouldSkip: $shouldSkip)';
  }
}

extension AnyChangeProposalFilterScenario on glados.Any {
  glados.Generator<GeneratedRedundancyToolKind> get redundancyToolKind =>
      glados.AnyUtils(this).choose(GeneratedRedundancyToolKind.values);

  glados.Generator<GeneratedRedundancyArgShape> get redundancyArgShape =>
      glados.AnyUtils(this).choose(GeneratedRedundancyArgShape.values);

  glados.Generator<GeneratedRedundancyScenario> get redundancyScenario =>
      glados.CombinableAny(this).combine2(
        redundancyToolKind,
        redundancyArgShape,
        (
          GeneratedRedundancyToolKind toolKind,
          GeneratedRedundancyArgShape argShape,
        ) => GeneratedRedundancyScenario(
          toolKind: toolKind,
          argShape: argShape,
        ),
      );
}
