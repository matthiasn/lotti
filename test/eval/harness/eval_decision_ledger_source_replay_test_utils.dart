import 'dart:convert';
import 'dart:io';

import 'eval_harness.dart';
import 'eval_tuning_source_replay_test_utils.dart';

List<Map<String, dynamic>> evalReadDecisionLedgerSourceManifestFiles(
  String paths,
) {
  return [
    for (final path in _csv(paths))
      ..._manifestJson(File(path).readAsStringSync()),
  ];
}

Future<List<Map<String, dynamic>>> evalReplayDecisionLedgerSourceManifests({
  required List<Map<String, dynamic>> ledgers,
  required List<Map<String, dynamic>> manifests,
  required EvalTuningSourceReplayConfig config,
}) async {
  if (ledgers.length != manifests.length) {
    throw StateError(
      'Decision ledger source manifest count must match decision ledger count.',
    );
  }
  final replayed = <Map<String, dynamic>>[];
  final replayedByDigest = <String, Map<String, dynamic>>{};
  for (final (index, manifest) in manifests.indexed) {
    final ledger = ledgers[index];
    _verifyOptionalLedgerBinding(ledger, manifest);
    final matrix = _readRequiredJsonMap(manifest, 'matrix');
    final matrixReports = _readRequiredJsonMaps(manifest, 'matrixReports');
    final matrixSourceChecks = await evalSourceChecksForReports(
      matrixReports,
      config: config,
    );
    EvalUseCaseTuningMatrix.assertMatchesSources(
      matrix,
      reports: matrixReports,
      sourceChecksByReportDigest: matrixSourceChecks,
    );

    Map<String, dynamic>? campaign;
    final campaignPath = _optionalString(manifest['campaign']);
    if (campaignPath.isNotEmpty) {
      campaign = _readJsonMap(campaignPath);
      final campaignPlan = _readRequiredJsonMap(
        manifest,
        'campaignExperimentPlan',
      );
      final campaignReports = _readRequiredJsonMaps(
        manifest,
        'campaignReports',
      );
      final campaignSourceChecks = await evalSourceChecksForReports(
        campaignReports,
        config: config,
      );
      final campaignHasModelClassCoverage = _mapList(
        campaign['inputModelClassExecutionCoverages'],
      ).isNotEmpty;
      if (campaignHasModelClassCoverage &&
          _stringList(manifest['campaignModelClassCoverages']).isEmpty) {
        throw StateError(
          'Decision ledger source replay requires '
          'campaignModelClassCoverages for campaigns that contain '
          'model-class execution coverage.',
        );
      }
      final coverages = _readJsonMaps(
        _stringList(manifest['campaignModelClassCoverages']),
      );
      Map<String, dynamic>? coverageWorkOrder;
      if (coverages.isNotEmpty) {
        coverageWorkOrder = _readRequiredJsonMap(
          manifest,
          'campaignModelClassCoverageWorkOrder',
        );
        final coverageExperimentPlan = _readRequiredJsonMap(
          manifest,
          'campaignModelClassExecutionExperimentPlan',
        );
        final evidenceBundles = _readRequiredJsonMaps(
          manifest,
          'campaignModelClassExecutionEvidence',
        );
        if (evidenceBundles.length != 1) {
          throw StateError(
            'Decision ledger source replay requires exactly one '
            'model-class execution-evidence bundle.',
          );
        }
        final runs = await evalLoadModelClassExecutionRuns(
          config: config,
          runIds: _stringList(manifest['campaignModelClassExecutionRuns']),
        );
        if (runs.isEmpty) {
          throw StateError(
            'Decision ledger source replay requires '
            'campaignModelClassExecutionRuns when coverage is supplied.',
          );
        }
        for (final coverage in coverages) {
          EvalUseCaseModelClassExecutionCoverage.assertMatchesSources(
            coverage,
            workOrder: coverageWorkOrder,
            sourceExecutionEvidenceBundles: evidenceBundles,
            runs: runs,
            sourceExperimentPlan: coverageExperimentPlan,
          );
        }
      }
      EvalUseCaseTuningCampaign.assertMatchesSources(
        campaign,
        experimentPlan: campaignPlan,
        reports: campaignReports,
        sourceChecksByReportDigest: campaignSourceChecks,
        modelClassExecutionCoverages: coverages,
        modelClassExecutionWorkOrders: [
          ?coverageWorkOrder,
        ],
      );
    }

    final previousLedgerPath = _optionalString(manifest['previousLedger']);
    final previousLedger = previousLedgerPath.isEmpty
        ? null
        : _replayedPreviousLedger(
            _readJsonMap(previousLedgerPath),
            replayedByDigest,
          );
    final reviewAttestations = _readReviewAttestations(
      _stringList(manifest['reviewAttestations']),
    );
    EvalUseCaseTuningDecisionLedger.assertMatchesSources(
      ledger,
      matrix: matrix,
      campaign: campaign,
      previousLedger: previousLedger,
      reviewAttestations: reviewAttestations,
      requirePreviousLedgerSourceReplay: previousLedger != null,
    );
    replayed.add(ledger);
    replayedByDigest[EvalProvenance.digestJson(ledger)] = ledger;
  }
  return replayed;
}

List<Map<String, dynamic>> _manifestJson(String source) {
  final decoded = jsonDecode(source);
  if (decoded is Map<String, dynamic>) {
    final manifests = decoded['decisionLedgers'];
    if (manifests is List) {
      return [
        for (final manifest in manifests)
          if (manifest is Map<String, dynamic>) manifest,
      ];
    }
    return [decoded];
  }
  if (decoded is List) {
    return [
      for (final manifest in decoded)
        if (manifest is Map<String, dynamic>) manifest,
    ];
  }
  throw StateError('Expected a decision ledger source manifest JSON object.');
}

void _verifyOptionalLedgerBinding(
  Map<String, dynamic> ledger,
  Map<String, dynamic> manifest,
) {
  final ledgerPath = _optionalString(manifest['decisionLedger']);
  if (ledgerPath.isNotEmpty) {
    final boundLedger = _readJsonMap(ledgerPath);
    if (EvalProvenance.digestJson(boundLedger) !=
        EvalProvenance.digestJson(ledger)) {
      throw StateError(
        'Decision ledger source manifest ledger path does not match input '
        'decision ledger.',
      );
    }
  }
  final expectedDigest = _optionalString(manifest['decisionLedgerDigest']);
  if (expectedDigest.isNotEmpty &&
      expectedDigest != EvalProvenance.digestJson(ledger)) {
    throw StateError(
      'Decision ledger source manifest digest does not match input decision '
      'ledger.',
    );
  }
  final expectedRef = _optionalString(manifest['decisionLedgerRef']);
  if (expectedRef.isNotEmpty &&
      expectedRef != _optionalString(ledger['decisionLedgerRef'])) {
    throw StateError(
      'Decision ledger source manifest ref does not match input decision '
      'ledger.',
    );
  }
}

Map<String, dynamic> _replayedPreviousLedger(
  Map<String, dynamic> previousLedger,
  Map<String, Map<String, dynamic>> replayedByDigest,
) {
  final digest = EvalProvenance.digestJson(previousLedger);
  final replayed = replayedByDigest[digest];
  if (replayed != null) return replayed;
  throw StateError(
    'Decision ledger source replay requires previousLedger to be replayed '
    'earlier in the decision ledger source manifest list.',
  );
}

Map<String, dynamic> _readRequiredJsonMap(
  Map<String, dynamic> manifest,
  String field,
) {
  final path = _optionalString(manifest[field]);
  if (path.isEmpty) {
    throw StateError('Decision ledger source manifest requires $field.');
  }
  return _readJsonMap(path);
}

List<Map<String, dynamic>> _readRequiredJsonMaps(
  Map<String, dynamic> manifest,
  String field,
) {
  final paths = _stringList(manifest[field]);
  if (paths.isEmpty) {
    throw StateError('Decision ledger source manifest requires $field.');
  }
  return _readJsonMaps(paths);
}

Map<String, dynamic> _readJsonMap(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

List<Map<String, dynamic>> _readJsonMaps(List<String> paths) => [
  for (final path in paths) _readJsonMap(path),
];

List<Map<String, dynamic>> _readReviewAttestations(List<String> paths) {
  return [
    for (final path in paths)
      ...EvalUseCaseAdversarialReview.approvedAttestationsFromValidBundles([
        _readJsonMap(path),
      ]),
  ];
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return [
    for (final item in value)
      if (item is Map<String, dynamic>) item,
  ];
}

List<String> _stringList(Object? value) {
  if (value is String) return _csv(value);
  if (value is! List) return const <String>[];
  return [
    for (final item in value)
      if (item is String && item.trim().isNotEmpty) item.trim(),
  ];
}

List<String> _csv(String value) => [
  for (final part in value.split(',').map((part) => part.trim()))
    if (part.isNotEmpty) part,
];

String _optionalString(Object? value) => value is String ? value.trim() : '';
