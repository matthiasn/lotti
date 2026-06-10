import 'dart:convert';
import 'dart:io';

import '../harness/eval_harness.dart';
import 'eval_scenarios.dart';

const kEvalScenarioCatalogPathEnv = 'EVAL_SCENARIOS';
const kEvalScenarioCatalogModeEnv = 'EVAL_SCENARIOS_MODE';
const kEvalScenarioIdsEnv = 'EVAL_SCENARIO_IDS';

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
    String dartDefineMode = '',
    String dartDefineScenarioIds = '',
    List<EvalScenario>? publicScenarios,
  }) {
    final requestedScenarioIds = _scenarioIds(
      environment,
      dartDefineScenarioIds,
    );
    final path = _scenarioPath(environment, dartDefinePath);
    final mode = _scenarioCatalogMode(environment, dartDefineMode);
    if (path == null && mode == _ScenarioCatalogMode.replace) {
      throw StateError(
        '$kEvalScenarioCatalogModeEnv=replace requires '
        '$kEvalScenarioCatalogPathEnv.',
      );
    }
    final baseScenarios = mode == _ScenarioCatalogMode.replace
        ? const <EvalScenario>[]
        : (publicScenarios ?? allEvalScenarios);
    if (path == null) {
      final scenarios = _selectScenarios(
        publicScenarios: baseScenarios,
        externalScenarios: const [],
        requestedScenarioIds: requestedScenarioIds,
      );
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
        sourceDescription: _sourceDescription(
          'public catalog',
          requestedScenarioIds,
        ),
      );
    }

    final external = _loadExternal(path);
    final unfilteredScenarios = [
      ...baseScenarios,
      ...external.scenarios,
    ];
    final issues = validateEvalScenarioCatalog(unfilteredScenarios);
    if (issues.isNotEmpty) {
      throw FormatException(
        'Invalid eval scenario catalog:\n${issues.join('\n')}',
      );
    }
    final selected = _selectScenarioParts(
      publicScenarios: baseScenarios,
      externalScenarios: external.scenarios,
      requestedScenarioIds: requestedScenarioIds,
    );
    final scenarios = selected.scenarios;
    final protectedScenarioIds = external.protectedHoldout
        ? selected.externalScenarios.map((scenario) => scenario.id).toList()
        : const <String>[];
    final protectedHoldoutScenarioIds = external.protectedHoldout
        ? selected.externalScenarios
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
        publicScenarioCount: selected.publicScenarios.length,
        externalScenarioCount: selected.externalScenarios.length,
        externalCatalogDigest: selected.externalScenarios.isEmpty
            ? null
            : external.catalogDigest,
        externalCatalogId: selected.externalScenarios.isEmpty
            ? null
            : external.catalogId,
        externalSourceLabel: selected.externalScenarios.isEmpty
            ? null
            : external.sourceLabel,
        protectedHoldout: protectedHoldoutScenarioIds.isNotEmpty,
        protectedScenarioIds: protectedScenarioIds,
        protectedHoldoutScenarioIds: protectedHoldoutScenarioIds,
      ),
      sourceDescription: _sourceDescription(
        switch (mode) {
          _ScenarioCatalogMode.append =>
            'public catalog + ${external.sourceLabel}',
          _ScenarioCatalogMode.replace => external.sourceLabel,
        },
        requestedScenarioIds,
      ),
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

  static _ScenarioCatalogMode _scenarioCatalogMode(
    Map<String, String> environment,
    String dartDefineMode,
  ) {
    final fromDefine = dartDefineMode.trim();
    final configured = fromDefine.isNotEmpty
        ? fromDefine
        : (environment[kEvalScenarioCatalogModeEnv]?.trim() ?? '');
    if (configured.isEmpty || configured == 'append') {
      return _ScenarioCatalogMode.append;
    }
    if (configured == 'replace') {
      return _ScenarioCatalogMode.replace;
    }
    throw StateError(
      '$kEvalScenarioCatalogModeEnv must be "append" or "replace"; '
      'got "$configured".',
    );
  }

  static List<String>? _scenarioIds(
    Map<String, String> environment,
    String dartDefineScenarioIds,
  ) {
    final fromDefine = dartDefineScenarioIds.trim();
    final configured = fromDefine.isNotEmpty
        ? fromDefine
        : (environment[kEvalScenarioIdsEnv]?.trim() ?? '');
    if (configured.isEmpty) return null;
    return _parseCsvSelection(configured, label: kEvalScenarioIdsEnv);
  }

  static List<String> _parseCsvSelection(
    String value, {
    required String label,
  }) {
    final selected = value.split(',').map((entry) => entry.trim()).toList();
    if (selected.any((entry) => entry.isEmpty)) {
      throw StateError('$label must not contain empty entries.');
    }
    final seen = <String>{};
    for (final entry in selected) {
      if (!seen.add(entry)) {
        throw StateError('$label contains duplicate entry: $entry');
      }
    }
    return List.unmodifiable(selected);
  }

  static List<EvalScenario> _selectScenarios({
    required List<EvalScenario> publicScenarios,
    required List<EvalScenario> externalScenarios,
    required List<String>? requestedScenarioIds,
  }) {
    final selected = _selectScenarioParts(
      publicScenarios: publicScenarios,
      externalScenarios: externalScenarios,
      requestedScenarioIds: requestedScenarioIds,
    );
    return List<EvalScenario>.unmodifiable([
      ...selected.publicScenarios,
      ...selected.externalScenarios,
    ]);
  }

  static ({
    List<EvalScenario> scenarios,
    List<EvalScenario> publicScenarios,
    List<EvalScenario> externalScenarios,
  })
  _selectScenarioParts({
    required List<EvalScenario> publicScenarios,
    required List<EvalScenario> externalScenarios,
    required List<String>? requestedScenarioIds,
  }) {
    if (requestedScenarioIds == null) {
      return (
        scenarios: List<EvalScenario>.unmodifiable([
          ...publicScenarios,
          ...externalScenarios,
        ]),
        publicScenarios: List<EvalScenario>.unmodifiable(publicScenarios),
        externalScenarios: List<EvalScenario>.unmodifiable(externalScenarios),
      );
    }

    final publicById = {
      for (final scenario in publicScenarios) scenario.id: scenario,
    };
    final externalById = {
      for (final scenario in externalScenarios) scenario.id: scenario,
    };
    final allIds = {...publicById.keys, ...externalById.keys};
    final missing = [
      for (final id in requestedScenarioIds)
        if (!allIds.contains(id)) id,
    ];
    if (missing.isNotEmpty) {
      throw StateError(
        'Unknown eval scenario id(s): ${missing.join(', ')}. '
        'Available scenario ids: ${_sortedList(allIds).join(', ')}',
      );
    }

    return (
      scenarios: List<EvalScenario>.unmodifiable([
        for (final id in requestedScenarioIds)
          publicById[id] ?? externalById[id]!,
      ]),
      publicScenarios: [
        for (final id in requestedScenarioIds)
          if (publicById[id] case final EvalScenario scenario) scenario,
      ],
      externalScenarios: [
        for (final id in requestedScenarioIds)
          if (externalById[id] case final EvalScenario scenario) scenario,
      ],
    );
  }

  static String _sourceDescription(
    String source,
    List<String>? requestedScenarioIds,
  ) {
    if (requestedScenarioIds == null) return source;
    return '$source filtered to ${requestedScenarioIds.join(', ')}';
  }

  static List<String> _sortedList(Iterable<String> values) =>
      values.toList()..sort();

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

enum _ScenarioCatalogMode { append, replace }

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
