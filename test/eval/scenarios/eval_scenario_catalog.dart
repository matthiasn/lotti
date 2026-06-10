import 'dart:convert';
import 'dart:io';

import '../harness/eval_harness.dart';
import 'eval_scenarios.dart';

const kEvalScenarioCatalogPathEnv = 'EVAL_SCENARIOS';

class EvalScenarioCatalog {
  const EvalScenarioCatalog({
    required this.scenarios,
    required this.evidence,
    required this.sourceDescription,
  });

  final List<EvalScenario> scenarios;
  final EvalScenarioCatalogEvidence evidence;
  final String sourceDescription;

  bool get protectedHoldoutEvidence => evidence.hasProtectedHoldoutEvidence;
}

abstract final class EvalScenarioCatalogLoader {
  static EvalScenarioCatalog fromEnvironment(
    Map<String, String> environment, {
    String dartDefinePath = '',
    List<EvalScenario>? publicScenarios,
  }) {
    final baseScenarios = publicScenarios ?? allEvalScenarios;
    final path = _scenarioPath(environment, dartDefinePath);
    if (path == null) {
      final scenarios = List<EvalScenario>.unmodifiable(baseScenarios);
      return EvalScenarioCatalog(
        scenarios: scenarios,
        evidence: EvalScenarioCatalogEvidence(
          scenarioSetDigest: EvalProvenance.scenarioSetDigest(scenarios),
          publicScenarioCount: scenarios.length,
          externalScenarioCount: 0,
          protectedHoldout: false,
          protectedScenarioIds: const [],
          protectedHoldoutScenarioIds: const [],
        ),
        sourceDescription: 'public catalog',
      );
    }

    final external = _loadExternal(path);
    final scenarios = List<EvalScenario>.unmodifiable([
      ...baseScenarios,
      ...external.scenarios,
    ]);
    final issues = validateEvalScenarioCatalog(scenarios);
    if (issues.isNotEmpty) {
      throw FormatException(
        'Invalid eval scenario catalog:\n${issues.join('\n')}',
      );
    }
    final protectedScenarioIds = external.protectedHoldout
        ? external.scenarios.map((scenario) => scenario.id).toList()
        : const <String>[];
    final protectedHoldoutScenarioIds = external.protectedHoldout
        ? external.scenarios
              .where(
                (scenario) =>
                    scenario.metadata.split == EvalScenarioSplit.holdout,
              )
              .map((scenario) => scenario.id)
              .toList()
        : const <String>[];
    return EvalScenarioCatalog(
      scenarios: scenarios,
      evidence: EvalScenarioCatalogEvidence(
        scenarioSetDigest: EvalProvenance.scenarioSetDigest(scenarios),
        publicScenarioCount: baseScenarios.length,
        externalScenarioCount: external.scenarios.length,
        externalCatalogDigest: external.catalogDigest,
        externalCatalogId: external.catalogId,
        externalSourceLabel: external.sourceLabel,
        protectedHoldout: external.protectedHoldout,
        protectedScenarioIds: protectedScenarioIds,
        protectedHoldoutScenarioIds: protectedHoldoutScenarioIds,
      ),
      sourceDescription: 'public catalog + ${external.sourceLabel}',
    );
  }

  static String? _scenarioPath(
    Map<String, String> environment,
    String dartDefinePath,
  ) {
    final fromDefine = dartDefinePath.trim();
    if (fromDefine.isNotEmpty) return fromDefine;
    final fromEnvironment = environment[kEvalScenarioCatalogPathEnv]?.trim();
    if (fromEnvironment != null && fromEnvironment.isNotEmpty) {
      return fromEnvironment;
    }
    return null;
  }

  static _ExternalScenarioEnvelope _loadExternal(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException('Eval scenario catalog not found', path);
    }
    final decoded = jsonDecode(file.readAsStringSync());
    final envelope = _ExternalScenarioEnvelope.fromJson(
      decoded,
      path,
      sourceLabel: file.uri.pathSegments.last,
      catalogDigest: EvalProvenance.digestJson(decoded),
    );
    final issues = validateEvalScenarioCatalog(envelope.scenarios);
    if (issues.isNotEmpty) {
      throw FormatException(
        'Invalid external eval scenario catalog $path:\n${issues.join('\n')}',
      );
    }
    if (envelope.protectedHoldout &&
        !envelope.scenarios.any(
          (scenario) => scenario.metadata.split == EvalScenarioSplit.holdout,
        )) {
      throw FormatException(
        'External eval scenario catalog $path sets protectedHoldout=true '
        'but contains no holdout scenarios.',
      );
    }
    final nonProductionHoldoutIds = envelope.scenarios
        .where(
          (scenario) =>
              envelope.protectedHoldout &&
              scenario.metadata.split == EvalScenarioSplit.holdout &&
              scenario.metadata.source != EvalScenarioSource.productionReplay,
        )
        .map((scenario) => scenario.id)
        .toList();
    if (nonProductionHoldoutIds.isNotEmpty) {
      throw FormatException(
        'External eval scenario catalog $path sets protectedHoldout=true '
        'but holdout scenarios are not production replay: '
        '${nonProductionHoldoutIds.join(', ')}.',
      );
    }
    return envelope;
  }
}

class _ExternalScenarioEnvelope {
  const _ExternalScenarioEnvelope({
    required this.scenarios,
    required this.sourceLabel,
    required this.catalogDigest,
    required this.protectedHoldout,
    this.catalogId,
  });

  factory _ExternalScenarioEnvelope.fromJson(
    Object? json,
    String path, {
    required String sourceLabel,
    required String catalogDigest,
  }) {
    if (json is List) {
      return _ExternalScenarioEnvelope(
        scenarios: _scenarioList(json, path),
        sourceLabel: sourceLabel,
        catalogDigest: catalogDigest,
        protectedHoldout: false,
      );
    }
    if (json is! Map<String, dynamic>) {
      throw FormatException(
        'External eval scenario catalog $path must be a JSON object or list.',
      );
    }
    final schemaVersion = json['schemaVersion'];
    if (schemaVersion != 1) {
      throw FormatException(
        'External eval scenario catalog $path has schemaVersion '
        '$schemaVersion; expected 1.',
      );
    }
    final rawScenarios = json['scenarios'];
    if (rawScenarios is! List) {
      throw FormatException(
        'External eval scenario catalog $path must contain scenarios[].',
      );
    }
    final protectedHoldout = (json['protectedHoldout'] as bool?) ?? false;
    final catalogId = json['catalogId'];
    if (catalogId != null &&
        (catalogId is! String || catalogId.trim().isEmpty)) {
      throw FormatException(
        'External eval scenario catalog $path has invalid catalogId.',
      );
    }
    if (protectedHoldout && catalogId == null) {
      throw FormatException(
        'Protected eval scenario catalog $path must declare catalogId.',
      );
    }
    return _ExternalScenarioEnvelope(
      scenarios: _scenarioList(rawScenarios, path),
      sourceLabel: sourceLabel,
      catalogDigest: catalogDigest,
      catalogId: catalogId as String?,
      protectedHoldout: protectedHoldout,
    );
  }

  final List<EvalScenario> scenarios;
  final String sourceLabel;
  final String catalogDigest;
  final String? catalogId;
  final bool protectedHoldout;

  static List<EvalScenario> _scenarioList(List<dynamic> json, String path) {
    if (json.isEmpty) {
      throw FormatException(
        'External eval scenario catalog $path contains no scenarios.',
      );
    }
    final scenarios = <EvalScenario>[];
    for (var index = 0; index < json.length; index++) {
      final rawScenario = json[index];
      if (rawScenario is! Map<String, dynamic>) {
        throw FormatException(
          'External eval scenario catalog $path has invalid scenario at '
          'index $index: expected JSON object.',
        );
      }
      final scenario = switch (_tryParseScenario(rawScenario)) {
        _ParsedScenario(:final scenario) => scenario,
        _ScenarioParseError(:final error) => throw FormatException(
          'External eval scenario catalog $path has invalid scenario at '
          'index $index: $error.',
        ),
      };
      if (!_externalScenarioIdPattern.hasMatch(scenario.id)) {
        throw FormatException(
          'External eval scenario catalog $path has unsafe scenario id '
          '${scenario.id}; use only A-Z, a-z, 0-9, dot, underscore, '
          'or dash.',
        );
      }
      scenarios.add(scenario);
    }
    return scenarios.toList(growable: false);
  }

  static final _externalScenarioIdPattern = RegExp(r'^[A-Za-z0-9._-]+$');

  static _ScenarioParseResult _tryParseScenario(
    Map<String, dynamic> rawScenario,
  ) {
    try {
      return _ParsedScenario(EvalScenario.fromJson(rawScenario));
    } on FormatException catch (error) {
      return _ScenarioParseError(error.message);
    } on Object catch (error) {
      return _ScenarioParseError(error.toString());
    }
  }
}

sealed class _ScenarioParseResult {
  const _ScenarioParseResult();
}

class _ParsedScenario extends _ScenarioParseResult {
  const _ParsedScenario(this.scenario);

  final EvalScenario scenario;
}

class _ScenarioParseError extends _ScenarioParseResult {
  const _ScenarioParseError(this.error);

  final String error;
}
