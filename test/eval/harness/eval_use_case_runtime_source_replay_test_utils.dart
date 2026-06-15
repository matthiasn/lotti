import 'dart:convert';
import 'dart:io';

import 'eval_harness.dart';

List<Map<String, dynamic>> readJsonObjects(String paths) {
  return [
    for (final path in _pathList(paths))
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>,
  ];
}

List<List<Map<String, dynamic>>> readCompletedBindingSources(String paths) {
  return [
    for (final path in _pathList(paths))
      _completedBindingSource(jsonDecode(File(path).readAsStringSync())),
  ];
}

List<Map<String, dynamic>> readDirectObservationSources(String paths) {
  return [
    for (final path in _pathList(paths))
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>,
  ];
}

void assertRuntimeResolverSnapshotsMatchSources(
  List<Map<String, dynamic>> snapshots, {
  required Map<String, dynamic> releasePlan,
  required Map<String, dynamic> releaseGate,
  required List<Map<String, dynamic>> resolverPackets,
  required List<Map<String, dynamic>> locatorPackets,
  required List<List<Map<String, dynamic>>> completedBindingSources,
  required List<Map<String, dynamic>> privateRuntimeStates,
  List<Map<String, dynamic>> directObservationSources = const [],
}) {
  for (final snapshot in snapshots) {
    assertRuntimeResolverSnapshotMatchesSources(
      snapshot,
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      resolverPackets: resolverPackets,
      locatorPackets: locatorPackets,
      completedBindingSources: completedBindingSources,
      directObservationSources: directObservationSources,
      privateRuntimeStates: privateRuntimeStates,
    );
  }
}

void assertRuntimeResolverSnapshotMatchesSources(
  Map<String, dynamic> snapshot, {
  required Map<String, dynamic> releasePlan,
  required Map<String, dynamic> releaseGate,
  required List<Map<String, dynamic>> resolverPackets,
  required List<Map<String, dynamic>> locatorPackets,
  required List<List<Map<String, dynamic>>> completedBindingSources,
  required List<Map<String, dynamic>> privateRuntimeStates,
  List<Map<String, dynamic>> directObservationSources = const [],
}) {
  final observationSource = _map(snapshot['runtimeObservationSource']);
  final mode = _string(observationSource['mode']);
  final capturedAt = DateTime.tryParse(_string(snapshot['capturedAt']));
  if (capturedAt == null) {
    throw StateError('Runtime resolver snapshot capturedAt is invalid.');
  }
  final resolverPacket = _artifactByDigest(
    resolverPackets,
    _string(observationSource['sourceResolverPacketDigest']),
    'runtime resolver packet',
  );
  if (!EvalUseCaseRuntimeResolverSnapshot.hasVerifiedPacketSources(
    resolverPacket,
  )) {
    throw StateError('Runtime resolver packet sources must be verified.');
  }

  if (mode ==
      EvalUseCaseRuntimeResolverSnapshot
          .runtimeObservationModePrivateRuntimeStateLocator) {
    final locatorPacket = _artifactByDigest(
      locatorPackets,
      _string(observationSource['sourceLocatorPacketDigest']),
      'runtime locator packet',
    );
    _assertMatchesAnyExpectedSnapshot(
      snapshot,
      [
        for (final privateRuntimeState in privateRuntimeStates)
          () =>
              EvalUseCaseRuntimeStateResolver.buildResolverSnapshotFromPrivateRuntimeState(
                releasePlan: releasePlan,
                releaseGate: releaseGate,
                resolverPacket: resolverPacket,
                locatorPacket: locatorPacket,
                privateRuntimeState: privateRuntimeState,
                capturedAt: capturedAt,
              ),
      ],
    );
    return;
  }

  if (mode.isEmpty) {
    throw StateError('Runtime resolver snapshot observation mode is missing.');
  }
  if (mode ==
      EvalUseCaseRuntimeResolverSnapshot
          .runtimeObservationModeDirectRuntimeObservation) {
    _assertMatchesAnyExpectedSnapshot(
      snapshot,
      [
        for (final directObservationSource in directObservationSources)
          () {
            EvalUseCaseRuntimeResolverSnapshot.assertDirectObservationSourceMatchesSources(
              directObservationSource,
              releasePlan: releasePlan,
              releaseGate: releaseGate,
              resolverPacket: resolverPacket,
            );
            return EvalUseCaseRuntimeResolverSnapshot.buildSnapshot(
              releasePlan: releasePlan,
              releaseGate: releaseGate,
              completedBindings: _mapList(
                directObservationSource['completedBindings'],
              ),
              runtimeObservationSource: _map(
                directObservationSource['runtimeObservationSource'],
              ),
              capturedAt: DateTime.parse(
                _string(directObservationSource['observedAt']),
              ),
            );
          },
      ],
      missingEvidenceMessage:
          'Runtime resolver snapshot mode $mode requires direct source evidence.',
    );
    return;
  }
  if (mode !=
      EvalUseCaseRuntimeResolverSnapshot
          .runtimeObservationModeManualCompletedBindingImport) {
    throw StateError(
      'Runtime resolver snapshot mode $mode requires direct source evidence.',
    );
  }
  _assertMatchesAnyExpectedSnapshot(
    snapshot,
    [
      for (final completedBindings in completedBindingSources)
        () => EvalUseCaseRuntimeResolverSnapshot.buildSnapshot(
          releasePlan: releasePlan,
          releaseGate: releaseGate,
          completedBindings: completedBindings,
          runtimeObservationSource:
              EvalUseCaseRuntimeResolverSnapshot.runtimeObservationSourceFromResolverPacket(
                resolverPacket: resolverPacket,
                mode: mode,
              ),
          capturedAt: capturedAt,
        ),
    ],
  );
}

List<String> _pathList(String paths) => [
  for (final path in paths.split(',').map((path) => path.trim()))
    if (path.isNotEmpty) path,
];

List<Map<String, dynamic>> _completedBindingSource(Object? decoded) {
  if (decoded is List) {
    return [
      for (final item in decoded) (item as Map<String, dynamic>),
    ];
  }
  if (decoded is Map<String, dynamic>) {
    final kind = decoded['kind'];
    if (kind == EvalUseCaseRuntimeResolverSnapshot.packetKind ||
        kind ==
            EvalUseCaseRuntimeResolverSnapshot.directObservationSourceKind ||
        kind == EvalUseCaseRuntimeVerification.resolverSnapshotKind) {
      throw StateError(
        'Resolver packets, direct observation sources, and resolver snapshots '
        'are not completed-binding source evidence.',
      );
    }
    return [decoded];
  }
  throw StateError('Expected completed-binding source JSON object or list.');
}

Map<String, dynamic> _artifactByDigest(
  List<Map<String, dynamic>> artifacts,
  String digest,
  String description,
) {
  if (digest.isEmpty) {
    throw StateError('Missing $description digest.');
  }
  final matches = [
    for (final artifact in artifacts)
      if (EvalProvenance.digestJson(artifact) == digest) artifact,
  ];
  if (matches.length == 1) return matches.single;
  if (matches.isEmpty) {
    throw StateError('Missing $description source artifact: $digest.');
  }
  throw StateError('Duplicate $description source artifact: $digest.');
}

void _assertMatchesAnyExpectedSnapshot(
  Map<String, dynamic> snapshot,
  List<Map<String, dynamic> Function()> expectedSnapshotBuilders, {
  String missingEvidenceMessage =
      'Runtime resolver snapshot source evidence is missing.',
}) {
  if (expectedSnapshotBuilders.isEmpty) {
    throw StateError(missingEvidenceMessage);
  }
  final mismatches = <String>[];
  for (final buildExpected in expectedSnapshotBuilders) {
    try {
      final expectedSnapshot = buildExpected();
      final issues =
          EvalUseCaseRuntimeResolverSnapshot.validateSnapshotAgainstExpected(
            snapshot,
            expectedSnapshot: expectedSnapshot,
          );
      if (issues.isEmpty) {
        EvalUseCaseRuntimeResolverSnapshot.assertSnapshotMatchesExpected(
          snapshot,
          expectedSnapshot: expectedSnapshot,
        );
        return;
      }
      mismatches.addAll(issues);
    } catch (error) {
      mismatches.add('$error');
    }
  }
  throw StateError(
    'Runtime resolver snapshot must match source artifacts:\n'
    '${mismatches.join('\n')}',
  );
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

List<Map<String, dynamic>> _mapList(Object? value) => value is List
    ? [
        for (final item in value)
          if (item is Map<String, dynamic>) item,
      ]
    : const <Map<String, dynamic>>[];

String _string(Object? value) => value is String ? value : '';
