import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/util/known_models.dart';

import 'eval_provenance.dart';
import 'eval_use_case_runtime_resolver_snapshot.dart';
import 'eval_use_case_tuning_release_gate.dart';
import 'eval_use_case_tuning_release_plan.dart';

/// Read-only mapper from observed production runtime rows to resolver bindings.
///
/// This lives in the eval harness so production code never depends on tuning
/// artifacts. It mirrors the runtime profile precedence used by
/// `ProfileResolver` and emits only digests plus private opaque IDs for the
/// private resolver snapshot import.
abstract final class EvalUseCaseRuntimeStateResolver {
  static const schemaVersion = 1;
  static const kind = 'lotti.evalUseCaseRuntimeStateResolver';
  static const locatorPacketSchemaVersion = 1;
  static const locatorPacketKind = 'lotti.evalRuntimeBindingLocatorPacket';
  static const privateRuntimeStateSchemaVersion = 1;
  static const privateRuntimeStateKind = 'lotti.evalPrivateRuntimeStateExport';
  static const _allowedResolverPacketStatuses = {
    'invalidReleasePlan',
    'invalidReleaseGate',
    'blockedReleaseGate',
    'noRuntimeBindings',
    'readyForRuntimeResolution',
  };

  static final _privatePathPattern = RegExp(
    r'(?:^|\s|=|file://)/(?:Users|home|private|var|tmp|Volumes)/',
  );
  static final _privateEnvTokenPattern = RegExp(
    r'\b(?:EVAL_SCENARIO_IDS|EVAL_PROFILE_NAMES|EVAL_PROFILES|'
    'EVAL_SCENARIOS|EVAL_RUNS_ROOT|EVAL_CALIBRATION|'
    'EVAL_CALIBRATION_TEMPLATE|EVAL_PAIRWISE_[A-Z0-9_]+|'
    r'EVAL_USE_CASE_[A-Z0-9_]+)\b',
  );
  static final _urlPattern = RegExp('https?://');
  static final _dangerousCommandTokenPattern = RegExp(
    r'(?:^|[^A-Za-z0-9_./-])(?:bash\s+-lc|fvm\s+flutter|'
    r'fvm\s+dart|dart\s+run|sqlite3|TaskAgentService\.updateAgentProfile|'
    r'AgentTemplateService\.(?:update|save)|AiConfigRepository\.(?:save|update))'
    r'(?=$|[^A-Za-z0-9_-])',
  );
  static final _digestPattern = RegExp(r'^sha256:[a-f0-9]{64}$');

  static Map<String, dynamic> buildLocatorPacket({
    required Map<String, dynamic> resolverPacket,
    required List<EvalRuntimeBindingLocator> locators,
    DateTime? generatedAt,
  }) {
    EvalUseCaseRuntimeResolverSnapshot.assertValidPacket(resolverPacket);
    if (!EvalUseCaseRuntimeResolverSnapshot.hasVerifiedPacketSources(
      resolverPacket,
    )) {
      throw StateError(
        'Runtime locator packet requires verified packet sources.',
      );
    }
    final templates = _mapList(resolverPacket['bindingTemplates']);
    final requiredRefs = [
      for (final template in templates) _string(template['assignmentRef']),
    ]..sort();
    final packet = <String, dynamic>{
      'schemaVersion': locatorPacketSchemaVersion,
      'kind': locatorPacketKind,
      'locatorPacketRef': '',
      'generatedAt': (generatedAt ?? DateTime.now().toUtc())
          .toUtc()
          .toIso8601String(),
      'sourceResolverPacket': <String, dynamic>{
        'kind': EvalUseCaseRuntimeResolverSnapshot.packetKind,
        'schemaVersion': EvalUseCaseRuntimeResolverSnapshot.packetSchemaVersion,
        'status': _string(resolverPacket['status']),
        'resolverPacketDigest': EvalProvenance.digestJson(resolverPacket),
        'sourceReleasePlanDigest': _string(
          _map(resolverPacket['sourceReleasePlan'])['releasePlanDigest'],
        ),
        'sourceReleaseGateRef': _string(
          _map(resolverPacket['sourceReleaseGate'])['releaseGateRef'],
        ),
        'sourceReleaseGateDigest': _string(
          _map(resolverPacket['sourceReleaseGate'])['releaseGateDigest'],
        ),
        'approvedAssignmentRefsDigest': _string(
          _map(
            resolverPacket['sourceReleaseGate'],
          )['approvedAssignmentRefsDigest'],
        ),
        'requiredAssignmentRefsDigest': EvalProvenance.digestJson(
          requiredRefs,
        ),
        'requiredRuntimeBindingCount': templates.length,
      },
      'summary': <String, dynamic>{
        'requiredRuntimeBindingCount': requiredRefs.length,
        'locatorCount': locators.length,
      },
      'privacy': const <String, dynamic>{
        'privateRuntimeIdsAllowed': true,
        'scenarioIdsOmitted': true,
        'profileNamesOmitted': true,
        'providerBaseUrlsOmitted': true,
        'apiKeysOmitted': true,
        'rawPromptTextOmitted': true,
        'rawDirectiveTextOmitted': true,
        'privatePathsOmitted': true,
        'envValuesOmitted': true,
      },
      'limitations': const <String, dynamic>{
        'privateLocatorPacket': true,
        'runtimeStateObservedOnly': true,
        'runtimeConfigurationAppliedByHarness': false,
        'aiConfigMutationsWrittenByHarness': false,
        'liveCommandsCreated': false,
      },
      'requiredAssignmentRefs': requiredRefs,
      'locators': [
        for (final locator in locators) locator.toJson(),
      ],
    };
    packet['locatorPacketRef'] = locatorPacketRef(packet);
    assertValidLocatorPacket(packet);
    return packet;
  }

  static String locatorPacketRef(Map<String, dynamic> locatorPacket) =>
      EvalProvenance.digestJson(_locatorPacketSubject(locatorPacket));

  static List<String> validateLocatorPacket(Map<String, dynamic> packet) {
    final issues = <String>[];
    _expectEquals(
      issues,
      packet['schemaVersion'],
      locatorPacketSchemaVersion,
      'schemaVersion',
    );
    _expectEquals(issues, packet['kind'], locatorPacketKind, 'kind');
    _expectDigest(issues, packet['locatorPacketRef'], 'locatorPacketRef');
    _expectIsoDate(issues, packet['generatedAt'], 'generatedAt');
    final source = _expectMap(
      issues,
      packet['sourceResolverPacket'],
      'sourceResolverPacket',
    );
    if (source != null) {
      _expectEquals(
        issues,
        source['kind'],
        EvalUseCaseRuntimeResolverSnapshot.packetKind,
        'sourceResolverPacket.kind',
      );
      _expectEquals(
        issues,
        source['schemaVersion'],
        EvalUseCaseRuntimeResolverSnapshot.packetSchemaVersion,
        'sourceResolverPacket.schemaVersion',
      );
      final status = _expectNonEmptyString(
        issues,
        source['status'],
        'sourceResolverPacket.status',
      );
      if (status != null && !_allowedResolverPacketStatuses.contains(status)) {
        issues.add(
          'sourceResolverPacket.status must be a supported resolver packet status',
        );
      }
      _expectDigest(
        issues,
        source['resolverPacketDigest'],
        'sourceResolverPacket.resolverPacketDigest',
      );
      _expectDigest(
        issues,
        source['sourceReleasePlanDigest'],
        'sourceResolverPacket.sourceReleasePlanDigest',
      );
      _expectDigest(
        issues,
        source['sourceReleaseGateDigest'],
        'sourceResolverPacket.sourceReleaseGateDigest',
      );
      _expectDigest(
        issues,
        source['sourceReleaseGateRef'],
        'sourceResolverPacket.sourceReleaseGateRef',
      );
      _expectDigest(
        issues,
        source['approvedAssignmentRefsDigest'],
        'sourceResolverPacket.approvedAssignmentRefsDigest',
      );
      _expectDigest(
        issues,
        source['requiredAssignmentRefsDigest'],
        'sourceResolverPacket.requiredAssignmentRefsDigest',
      );
      _expectNonNegativeInt(
        issues,
        source['requiredRuntimeBindingCount'],
        'sourceResolverPacket.requiredRuntimeBindingCount',
      );
    }
    final summary = _expectMap(issues, packet['summary'], 'summary');
    if (summary != null) {
      _expectNonNegativeInt(
        issues,
        summary['requiredRuntimeBindingCount'],
        'summary.requiredRuntimeBindingCount',
      );
      _expectNonNegativeInt(
        issues,
        summary['locatorCount'],
        'summary.locatorCount',
      );
    }
    if (source != null && summary != null) {
      final sourceCount = source['requiredRuntimeBindingCount'];
      final summaryCount = summary['requiredRuntimeBindingCount'];
      if (sourceCount is int &&
          summaryCount is int &&
          sourceCount != summaryCount) {
        issues.add(
          'summary.requiredRuntimeBindingCount must match sourceResolverPacket.requiredRuntimeBindingCount',
        );
      }
      final locatorCount = summary['locatorCount'];
      final locators = packet['locators'];
      if (locatorCount is int &&
          locators is List &&
          locatorCount != locators.length) {
        issues.add('summary.locatorCount must match locators.length');
      }
    }
    _validateLocatorPrivacy(
      issues,
      _expectMap(issues, packet['privacy'], 'privacy'),
    );
    _validateLocatorLimitations(
      issues,
      _expectMap(issues, packet['limitations'], 'limitations'),
    );
    final requiredRefs = _expectStringList(
      issues,
      packet['requiredAssignmentRefs'],
      'requiredAssignmentRefs',
    );
    if (source != null && requiredRefs != null) {
      final expectedRequiredRefsDigest = EvalProvenance.digestJson(
        [...requiredRefs]..sort(),
      );
      if (_string(source['requiredAssignmentRefsDigest']) !=
          expectedRequiredRefsDigest) {
        issues.add(
          'sourceResolverPacket.requiredAssignmentRefsDigest must match requiredAssignmentRefs',
        );
      }
      final sourceCount = source['requiredRuntimeBindingCount'];
      if (sourceCount is int && sourceCount != requiredRefs.length) {
        issues.add(
          'sourceResolverPacket.requiredRuntimeBindingCount must match requiredAssignmentRefs.length',
        );
      }
    }
    final locators = _expectList(issues, packet['locators'], 'locators');
    _validateLocatorRows(issues, requiredRefs, locators);
    _validateNoLocatorPayloadLeaks(issues, packet, 'locatorPacket');
    _validateLocatorPacketRef(issues, packet);
    return issues;
  }

  static void assertValidLocatorPacket(Map<String, dynamic> packet) {
    final issues = validateLocatorPacket(packet);
    if (issues.isEmpty) return;
    throw StateError(
      'Invalid runtime binding locator packet:\n${issues.join('\n')}',
    );
  }

  static void assertLocatorPacketMatchesResolverPacket({
    required Map<String, dynamic> locatorPacket,
    required Map<String, dynamic> resolverPacket,
  }) {
    EvalUseCaseRuntimeResolverSnapshot.assertValidPacket(resolverPacket);
    assertValidLocatorPacket(locatorPacket);
    final expected = EvalProvenance.digestJson(resolverPacket);
    final source = _map(locatorPacket['sourceResolverPacket']);
    final observed = _string(source['resolverPacketDigest']);
    final expectedRequiredRefs = [
      for (final template in _mapList(resolverPacket['bindingTemplates']))
        _string(template['assignmentRef']),
    ]..sort();
    final locatorRequiredRefs = _stringList(
      locatorPacket['requiredAssignmentRefs'],
    )..sort();
    if (observed != expected ||
        _string(source['status']) != _string(resolverPacket['status']) ||
        _string(source['sourceReleasePlanDigest']) !=
            _string(
              _map(resolverPacket['sourceReleasePlan'])['releasePlanDigest'],
            ) ||
        _string(source['sourceReleaseGateRef']) !=
            _string(
              _map(resolverPacket['sourceReleaseGate'])['releaseGateRef'],
            ) ||
        _string(source['sourceReleaseGateDigest']) !=
            _string(
              _map(resolverPacket['sourceReleaseGate'])['releaseGateDigest'],
            ) ||
        _string(source['approvedAssignmentRefsDigest']) !=
            _string(
              _map(
                resolverPacket['sourceReleaseGate'],
              )['approvedAssignmentRefsDigest'],
            ) ||
        _string(source['requiredAssignmentRefsDigest']) !=
            EvalProvenance.digestJson(expectedRequiredRefs) ||
        !_stringListsEqual(locatorRequiredRefs, expectedRequiredRefs)) {
      throw StateError('Runtime locator packet source resolver digest drift.');
    }
  }

  static List<EvalRuntimeBindingLocator> locatorsFromPacket(
    Map<String, dynamic> locatorPacket,
  ) {
    assertValidLocatorPacket(locatorPacket);
    return locatorsFromInputRows(locatorPacket['locators']);
  }

  static List<EvalRuntimeBindingLocator> locatorsFromInputRows(Object? rows) {
    final issues = <String>[];
    final values = _expectList(issues, rows, 'locators') ?? const <dynamic>[];
    for (final (index, value) in values.indexed) {
      final row = _expectMap(issues, value, 'locators[$index]');
      if (row == null) continue;
      _validateLocatorRow(issues, row, 'locators[$index]');
      _validateNoLocatorPayloadLeaks(issues, row, 'locators[$index]');
    }
    if (issues.isNotEmpty) {
      throw StateError('Invalid runtime locator input:\n${issues.join('\n')}');
    }
    return [
      for (final item in values.cast<Map<String, dynamic>>())
        EvalRuntimeBindingLocator.fromJson(item),
    ];
  }

  static List<Map<String, dynamic>> buildCompletedBindings({
    required Map<String, dynamic> resolverPacket,
    required List<EvalRuntimeStateObservation> observations,
  }) {
    EvalUseCaseRuntimeResolverSnapshot.assertValidPacket(resolverPacket);
    final templates = _mapList(resolverPacket['bindingTemplates']);
    final observationsByRef = <String, List<EvalRuntimeStateObservation>>{};
    for (final observation in observations) {
      observationsByRef
          .putIfAbsent(observation.assignmentRef, () => [])
          .add(observation);
    }

    return [
      for (final template in templates)
        _completedBinding(
          template: template,
          observations:
              observationsByRef[_string(template['assignmentRef'])] ??
              const <EvalRuntimeStateObservation>[],
        ),
    ];
  }

  static List<EvalRuntimeStateObservation> resolveObservations({
    required List<EvalRuntimeBindingLocator> locators,
    required List<AgentIdentityEntity> agents,
    required List<AgentTemplateEntity> templates,
    required List<AgentTemplateVersionEntity> activeVersions,
    required List<AgentLink> links,
    required List<AiConfig> aiConfigs,
  }) {
    final observations = <EvalRuntimeStateObservation>[];
    for (final locator in locators) {
      final observation = _resolveObservation(
        locator: locator,
        agents: agents,
        templates: templates,
        activeVersions: activeVersions,
        links: links,
        aiConfigs: aiConfigs,
      );
      if (observation != null) {
        observations.add(observation);
      }
    }
    return observations;
  }

  static List<EvalRuntimeStateObservation>
  resolveObservationsFromLocatorPacket({
    required Map<String, dynamic> resolverPacket,
    required Map<String, dynamic> locatorPacket,
    required List<AgentIdentityEntity> agents,
    required List<AgentTemplateEntity> templates,
    required List<AgentTemplateVersionEntity> activeVersions,
    required List<AgentLink> links,
    required List<AiConfig> aiConfigs,
  }) {
    assertLocatorPacketMatchesResolverPacket(
      locatorPacket: locatorPacket,
      resolverPacket: resolverPacket,
    );
    return resolveObservations(
      locators: locatorsFromPacket(locatorPacket),
      agents: agents,
      templates: templates,
      activeVersions: activeVersions,
      links: links,
      aiConfigs: aiConfigs,
    );
  }

  static List<EvalRuntimeStateObservation>
  resolveObservationsFromPrivateRuntimeState({
    required Map<String, dynamic> resolverPacket,
    required Map<String, dynamic> locatorPacket,
    required Map<String, dynamic> privateRuntimeState,
  }) {
    assertLocatorPacketMatchesResolverPacket(
      locatorPacket: locatorPacket,
      resolverPacket: resolverPacket,
    );
    final rows = _parsePrivateRuntimeState(privateRuntimeState);
    final observations = resolveObservations(
      locators: locatorsFromPacket(locatorPacket),
      agents: rows.agents,
      templates: rows.templates,
      activeVersions: rows.activeVersions,
      links: rows.links,
      aiConfigs: rows.aiConfigs,
    );
    _assertAllLocatorTargetsObserved(
      locatorPacket: locatorPacket,
      observations: observations,
    );
    return observations;
  }

  static Map<String, dynamic> buildResolverSnapshot({
    required Map<String, dynamic> releasePlan,
    required Map<String, dynamic> releaseGate,
    required List<EvalRuntimeStateObservation> observations,
    DateTime? capturedAt,
  }) {
    final packet = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      generatedAt: capturedAt,
    );
    final completedBindings = buildCompletedBindings(
      resolverPacket: packet,
      observations: observations,
    );
    return EvalUseCaseRuntimeResolverSnapshot.buildSnapshot(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      completedBindings: completedBindings,
      runtimeObservationSource:
          EvalUseCaseRuntimeResolverSnapshot.runtimeObservationSourceForDirectObservation(
            resolverPacket: packet,
          ),
      capturedAt: capturedAt,
    );
  }

  static Map<String, dynamic> buildResolverSnapshotFromPrivateRuntimeState({
    required Map<String, dynamic> releasePlan,
    required Map<String, dynamic> releaseGate,
    required Map<String, dynamic> resolverPacket,
    required Map<String, dynamic> locatorPacket,
    required Map<String, dynamic> privateRuntimeState,
    DateTime? capturedAt,
  }) {
    _assertResolverPacketMatchesReleaseSources(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      resolverPacket: resolverPacket,
    );
    final observations = resolveObservationsFromPrivateRuntimeState(
      resolverPacket: resolverPacket,
      locatorPacket: locatorPacket,
      privateRuntimeState: privateRuntimeState,
    );
    final completedBindings = buildCompletedBindings(
      resolverPacket: resolverPacket,
      observations: observations,
    );
    return EvalUseCaseRuntimeResolverSnapshot.buildSnapshot(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      completedBindings: completedBindings,
      runtimeObservationSource:
          EvalUseCaseRuntimeResolverSnapshot.runtimeObservationSourceForPrivateRuntimeStateLocator(
            resolverPacket: resolverPacket,
            locatorPacket: locatorPacket,
          ),
      capturedAt: capturedAt,
    );
  }

  static Map<String, dynamic> buildResolverReport({
    required Map<String, dynamic> releasePlan,
    required Map<String, dynamic> releaseGate,
    required List<EvalRuntimeStateObservation> observations,
    DateTime? generatedAt,
  }) {
    final releasePlanIssues = EvalUseCaseTuningReleasePlan.validate(
      releasePlan,
    );
    final releaseGateIssues = EvalUseCaseTuningReleaseGate.validate(
      releaseGate,
    );
    final releasePlanDigest = EvalProvenance.digestJson(releasePlan);
    final releaseGateDigest = EvalProvenance.digestJson(releaseGate);
    final packet = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      generatedAt: generatedAt,
    );
    final completedBindings = buildCompletedBindings(
      resolverPacket: packet,
      observations: observations,
    );
    final resolvedCount = completedBindings
        .where((binding) => binding['resolutionStatus'] == 'applied')
        .length;
    final unsupportedCount = completedBindings
        .where((binding) => binding['resolutionStatus'] == 'unsupported')
        .length;
    final duplicateObservationCount = completedBindings
        .where((binding) => binding['status'] == 'duplicateObservation')
        .length;
    final missingObservationCount = completedBindings
        .where((binding) => binding['status'] == 'missingObservation')
        .length;
    final report = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'kind': kind,
      'generatedAt': (generatedAt ?? DateTime.now().toUtc())
          .toUtc()
          .toIso8601String(),
      'sourceReleasePlan': <String, dynamic>{
        'kind': EvalUseCaseTuningReleasePlan.kind,
        'schemaVersion': EvalUseCaseTuningReleasePlan.schemaVersion,
        'status': _string(releasePlan['status']),
        'releasePlanDigest': releasePlanDigest,
        'contractIssueCount': releasePlanIssues.length,
      },
      'sourceReleaseGate': <String, dynamic>{
        'kind': EvalUseCaseTuningReleaseGate.kind,
        'schemaVersion': EvalUseCaseTuningReleaseGate.schemaVersion,
        'status': _string(releaseGate['status']),
        'releaseGateRef': _string(releaseGate['releaseGateRef']),
        'releaseGateDigest': releaseGateDigest,
        'contractIssueCount': releaseGateIssues.length,
      },
      'summary': <String, dynamic>{
        'requiredRuntimeBindingCount': completedBindings.length,
        'observationCount': observations.length,
        'resolvedBindingCount': resolvedCount,
        'unsupportedBindingCount': unsupportedCount,
        'duplicateObservationCount': duplicateObservationCount,
        'missingObservationCount': missingObservationCount,
      },
      'privacy': const <String, dynamic>{
        'scenarioIdsOmitted': true,
        'profileNamesOmitted': true,
        'privateRuntimeIdsOmitted': true,
        'providerBaseUrlsOmitted': true,
        'apiKeysOmitted': true,
        'rawPromptTextOmitted': true,
        'rawDirectiveTextOmitted': true,
        'privatePathsOmitted': true,
        'envValuesOmitted': true,
      },
      'limitations': const <String, dynamic>{
        'runtimeStateObservedOnly': true,
        'runtimeConfigurationAppliedByHarness': false,
        'aiConfigMutationsWrittenByHarness': false,
        'liveCommandsCreated': false,
      },
      'observedAssignmentRefs': [
        for (final binding in completedBindings)
          <String, dynamic>{
            'assignmentRef': binding['assignmentRef'],
            'resolutionStatus': binding['resolutionStatus'],
            'productionAgentKind': binding['productionAgentKind'],
            'shadowedTemplateOverride':
                binding['shadowedTemplateOverride'] == true,
          },
      ],
    };
    _assertNoReportLeaks(report);
    return report;
  }

  static Map<String, dynamic> _completedBinding({
    required Map<String, dynamic> template,
    required List<EvalRuntimeStateObservation> observations,
  }) {
    if (observations.length != 1) {
      return _unresolvedBinding(
        template: template,
        status: observations.isEmpty
            ? 'missingObservation'
            : 'duplicateObservation',
        resolutionStatus: observations.isEmpty ? 'notApplied' : 'unsupported',
      );
    }

    final observation = observations.single;
    final resolution = _resolveRuntime(observation);
    final observed = _digestRuntime(
      template: template,
      observation: observation,
      resolution: resolution,
    );
    final expected = observation.expectedDigests ?? observed;
    final shadowedTemplateOverride =
        observation.shadowedTemplateOverride ??
        _agentProfileShadowsTemplate(
          observation.agent,
          observation.template,
          observation.activeVersion,
        );
    return <String, dynamic>{
      ...template,
      'status': resolution.slot == null ? 'unresolved' : 'resolved',
      'productionAgentKind': observation.agent.kind,
      'resolutionStatus': observation.resolutionStatus ?? resolution.status,
      'runtimeTargetRef': _runtimeTargetRef(observation, resolution),
      'expected': expected,
      'observed': observed,
      'privateRuntimeIds': _privateRuntimeIds(observation, resolution),
      'shadowedTemplateOverride': shadowedTemplateOverride,
    };
  }

  static Map<String, dynamic> _unresolvedBinding({
    required Map<String, dynamic> template,
    required String status,
    required String resolutionStatus,
  }) {
    final assignmentRef = _string(template['assignmentRef']);
    final digests = {
      for (final field
          in EvalUseCaseRuntimeResolverSnapshot.runtimeDigestFields)
        field: EvalProvenance.digestJson(<String, dynamic>{
          'assignmentRef': assignmentRef,
          'field': field,
          'status': status,
        }),
    };
    return <String, dynamic>{
      ...template,
      'status': status,
      'resolutionStatus': resolutionStatus,
      'runtimeTargetRef': EvalProvenance.digestJson(<String, dynamic>{
        'assignmentRef': assignmentRef,
        'status': status,
      }),
      'expected': digests,
      'observed': digests,
      'shadowedTemplateOverride': false,
    };
  }

  static _RuntimeResolution _resolveRuntime(
    EvalRuntimeStateObservation observation,
  ) {
    final profileCandidate = _profileCandidate(
      observation.agent,
      observation.template,
      observation.activeVersion,
    );
    if (profileCandidate != null) {
      final profile = _configById(observation.aiConfigs, profileCandidate.id);
      if (profile is AiConfigInferenceProfile) {
        final slot = _resolveProfileSlot(
          modelId: profile.thinkingModelId,
          aiConfigs: observation.aiConfigs,
        );
        if (slot != null) {
          return _RuntimeResolution(
            status: 'applied',
            source: profileCandidate.source,
            profile: profile,
            slot: slot,
            unresolvedProfileId: null,
            legacyModelId: null,
          );
        }
        return _RuntimeResolution(
          status: 'unsupported',
          source: profileCandidate.source,
          profile: profile,
          slot: null,
          unresolvedProfileId: null,
          legacyModelId: null,
        );
      }
    }

    final legacyModelId =
        observation.activeVersion.modelId ?? observation.template.modelId;
    final legacySlot = _resolveProviderModel(
      providerModelId: legacyModelId,
      aiConfigs: observation.aiConfigs,
    );
    return _RuntimeResolution(
      status: legacySlot == null ? 'unsupported' : 'applied',
      source: profileCandidate == null
          ? 'legacyModelId'
          : 'legacyModelIdAfterMissingProfile',
      profile: null,
      slot: legacySlot,
      unresolvedProfileId: profileCandidate?.id,
      legacyModelId: legacyModelId,
    );
  }

  static EvalRuntimeStateObservation? _resolveObservation({
    required EvalRuntimeBindingLocator locator,
    required List<AgentIdentityEntity> agents,
    required List<AgentTemplateEntity> templates,
    required List<AgentTemplateVersionEntity> activeVersions,
    required List<AgentLink> links,
    required List<AiConfig> aiConfigs,
  }) {
    final agent = _agentForLocator(
      locator: locator,
      agents: agents,
      links: links,
    );
    if (agent == null || agent.deletedAt != null) return null;
    final primaryTemplateLink = _primaryTemplateAssignmentLink(
      links,
      agent.agentId,
    );
    _validateRuntimeLocatorLinks(
      locator: locator,
      agent: agent,
      links: links,
      primaryTemplateLink: primaryTemplateLink,
    );
    final templateId = locator.templateId ?? primaryTemplateLink?.fromId;
    if (templateId == null) return null;
    final template = _templateById(templates, templateId);
    if (template == null || template.deletedAt != null) return null;
    _validateRuntimeLocatorVersion(
      locator: locator,
      templateId: template.id,
      versions: activeVersions,
    );
    final version = _activeVersionForTemplate(
      templateId: template.id,
      versionId: locator.activeTemplateVersionId,
      versions: activeVersions,
    );
    if (version == null || version.deletedAt != null) return null;
    return EvalRuntimeStateObservation(
      assignmentRef: locator.assignmentRef,
      agent: agent,
      template: template,
      activeVersion: version,
      aiConfigs: aiConfigs,
    );
  }

  static void _validateRuntimeLocatorLinks({
    required EvalRuntimeBindingLocator locator,
    required AgentIdentityEntity agent,
    required List<AgentLink> links,
    required TemplateAssignmentLink? primaryTemplateLink,
  }) {
    if (locator.taskId != null) {
      final taskAgentId = _primaryTaskLink(links, locator.taskId!)?.fromId;
      if (taskAgentId != null && taskAgentId != agent.agentId) {
        throw StateError(
          'Runtime locator taskId resolves to a different agent.',
        );
      }
    }
    if (locator.templateId != null &&
        (primaryTemplateLink == null ||
            primaryTemplateLink.fromId != locator.templateId)) {
      throw StateError(
        'Runtime locator templateId is not the primary assigned template.',
      );
    }
  }

  static void _validateRuntimeLocatorVersion({
    required EvalRuntimeBindingLocator locator,
    required String templateId,
    required List<AgentTemplateVersionEntity> versions,
  }) {
    if (locator.activeTemplateVersionId != null && templateId.isNotEmpty) {
      final explicit = _activeVersionForTemplate(
        templateId: templateId,
        versionId: locator.activeTemplateVersionId,
        versions: versions,
      );
      final active = _activeVersionForTemplate(
        templateId: templateId,
        versionId: null,
        versions: versions,
      );
      if (explicit == null ||
          explicit.deletedAt != null ||
          explicit.status.name != 'active' ||
          active == null ||
          explicit.id != active.id) {
        throw StateError(
          'Runtime locator activeTemplateVersionId is not the active version.',
        );
      }
    }
  }

  static AgentIdentityEntity? _agentForLocator({
    required EvalRuntimeBindingLocator locator,
    required List<AgentIdentityEntity> agents,
    required List<AgentLink> links,
  }) {
    final agentId =
        locator.agentId ??
        (locator.taskId == null
            ? null
            : _primaryTaskLink(links, locator.taskId!)?.fromId);
    if (agentId == null) return null;
    return _agentById(agents, agentId);
  }

  static AgentTaskLink? _primaryTaskLink(
    List<AgentLink> links,
    String taskId,
  ) {
    final taskLinks = [
      for (final link in links)
        if (link is AgentTaskLink &&
            link.toId == taskId &&
            link.deletedAt == null)
          link,
    ];
    if (taskLinks.isEmpty) return null;
    return taskLinks.selectPrimary() as AgentTaskLink;
  }

  static TemplateAssignmentLink? _primaryTemplateAssignmentLink(
    List<AgentLink> links,
    String agentId,
  ) {
    final templateLinks = [
      for (final link in links)
        if (link is TemplateAssignmentLink &&
            link.toId == agentId &&
            link.deletedAt == null)
          link,
    ];
    if (templateLinks.isEmpty) return null;
    return templateLinks.selectPrimary() as TemplateAssignmentLink;
  }

  static AgentIdentityEntity? _agentById(
    List<AgentIdentityEntity> agents,
    String agentId,
  ) {
    for (final agent in agents) {
      if (agent.agentId == agentId) return agent;
    }
    return null;
  }

  static AgentTemplateEntity? _templateById(
    List<AgentTemplateEntity> templates,
    String templateId,
  ) {
    for (final template in templates) {
      if (template.id == templateId) return template;
    }
    return null;
  }

  static AgentTemplateVersionEntity? _activeVersionForTemplate({
    required String templateId,
    required String? versionId,
    required List<AgentTemplateVersionEntity> versions,
  }) {
    if (versionId != null) {
      for (final version in versions) {
        if (version.id == versionId && version.agentId == templateId) {
          return version;
        }
      }
      return null;
    }
    final candidates =
        [
          for (final version in versions)
            if (version.agentId == templateId &&
                version.status.name == 'active' &&
                version.deletedAt == null)
              version,
        ]..sort((a, b) {
          final byVersion = b.version.compareTo(a.version);
          if (byVersion != 0) return byVersion;
          return b.id.compareTo(a.id);
        });
    return candidates.isEmpty ? null : candidates.first;
  }

  static _ResolvedProviderSlot? _resolveProfileSlot({
    required String modelId,
    required List<AiConfig> aiConfigs,
  }) {
    for (final config in aiConfigs.whereType<AiConfigModel>()) {
      if (config.id == modelId) {
        return _resolveProviderForModel(config, aiConfigs);
      }
    }
    return _resolveProviderModel(
      providerModelId: modelId,
      aiConfigs: aiConfigs,
    );
  }

  static _ResolvedProviderSlot? _resolveProviderModel({
    required String providerModelId,
    required List<AiConfig> aiConfigs,
  }) {
    final matchingModels = aiConfigs
        .whereType<AiConfigModel>()
        .where((model) => model.providerModelId == providerModelId)
        .toList(growable: false);
    if (matchingModels.isEmpty) return null;

    final preferredProviderTypes = {
      for (final entry in knownModelsByProvider.entries)
        if (entry.value.any(
          (model) => model.providerModelId == providerModelId,
        ))
          entry.key,
    };
    _ResolvedProviderSlot? usableFallback;
    for (final model in matchingModels) {
      final slot = _resolveProviderForModel(model, aiConfigs);
      if (slot == null) continue;
      if (preferredProviderTypes.isEmpty ||
          preferredProviderTypes.contains(
            slot.provider.inferenceProviderType,
          )) {
        return slot;
      }
      usableFallback ??= slot;
    }
    return usableFallback;
  }

  static _ResolvedProviderSlot? _resolveProviderForModel(
    AiConfigModel model,
    List<AiConfig> aiConfigs,
  ) {
    final provider = _configById(aiConfigs, model.inferenceProviderId);
    if (provider is! AiConfigInferenceProvider || !provider.isUsable) {
      return null;
    }
    return _ResolvedProviderSlot(model: model, provider: provider);
  }

  static AiConfig? _configById(List<AiConfig> aiConfigs, String id) {
    for (final config in aiConfigs) {
      if (config.id == id) return config;
    }
    return null;
  }

  static _ProfileCandidate? _profileCandidate(
    AgentIdentityEntity agent,
    AgentTemplateEntity template,
    AgentTemplateVersionEntity version,
  ) {
    final agentProfileId = agent.config.profileId;
    if (agentProfileId != null) {
      return _ProfileCandidate(
        id: agentProfileId,
        source: 'agentConfig.profileId',
      );
    }
    final versionProfileId = version.profileId;
    if (versionProfileId != null) {
      return _ProfileCandidate(
        id: versionProfileId,
        source: 'templateVersion.profileId',
      );
    }
    final templateProfileId = template.profileId;
    if (templateProfileId != null) {
      return _ProfileCandidate(
        id: templateProfileId,
        source: 'template.profileId',
      );
    }
    return null;
  }

  static bool _agentProfileShadowsTemplate(
    AgentIdentityEntity agent,
    AgentTemplateEntity template,
    AgentTemplateVersionEntity version,
  ) {
    final agentProfileId = agent.config.profileId;
    if (agentProfileId == null) return false;
    final templateProfileId = version.profileId ?? template.profileId;
    return templateProfileId != null && agentProfileId != templateProfileId;
  }

  static Map<String, dynamic> _digestRuntime({
    required Map<String, dynamic> template,
    required EvalRuntimeStateObservation observation,
    required _RuntimeResolution resolution,
  }) {
    final slot = resolution.slot;
    final unresolvedProfileDigest = resolution.unresolvedProfileId == null
        ? ''
        : EvalProvenance.digestText(resolution.unresolvedProfileId!);
    return <String, dynamic>{
      'resolvedProfileDigest': EvalProvenance.digestJson(<String, dynamic>{
        'source': resolution.source,
        'profileDigest': resolution.profile == null
            ? ''
            : EvalProvenance.digestText(resolution.profile!.id),
        'unresolvedProfileDigest': unresolvedProfileDigest,
        'legacyModelId': resolution.legacyModelId,
        'thinkingModelDigest': slot == null
            ? ''
            : EvalProvenance.digestText(slot.model.id),
        'thinkingProviderDigest': slot == null
            ? ''
            : EvalProvenance.digestText(slot.provider.id),
      }),
      'providerModelBindingDigest': EvalProvenance.digestJson(
        slot == null
            ? _unresolvedDigestSubject(observation, resolution)
            : <String, dynamic>{
                'providerDigest': EvalProvenance.digestText(slot.provider.id),
                'providerType': slot.provider.inferenceProviderType.name,
                'modelDigest': EvalProvenance.digestText(slot.model.id),
                'providerModelId': slot.model.providerModelId,
              },
      ),
      'thinkingModelBindingDigest': EvalProvenance.digestJson(
        slot == null
            ? _unresolvedDigestSubject(observation, resolution)
            : <String, dynamic>{
                'modelDigest': EvalProvenance.digestText(slot.model.id),
                'providerModelId': slot.model.providerModelId,
                'inputModalities': _modalityNames(slot.model.inputModalities),
                'outputModalities': _modalityNames(slot.model.outputModalities),
                'isReasoningModel': slot.model.isReasoningModel,
                'supportsFunctionCalling': slot.model.supportsFunctionCalling,
                'geminiThinkingMode': slot.model.geminiThinkingMode.name,
                'maxCompletionTokens': slot.model.maxCompletionTokens,
              },
      ),
      'promptVariantDigest': EvalProvenance.digestJson(<String, dynamic>{
        'promptVariantName': _string(template['promptVariantName']),
        'modelClass': _string(template['modelClass']),
        'agentKind': _string(template['agentKind']),
        'productionAgentKind': observation.agent.kind,
        'templateKind': observation.template.kind.name,
        'templateModelDigest': EvalProvenance.digestText(
          observation.template.modelId,
        ),
        'versionModelDigest': observation.activeVersion.modelId == null
            ? ''
            : EvalProvenance.digestText(observation.activeVersion.modelId!),
        'resolutionSource': resolution.source,
      }),
      'promptDirectiveDigest': EvalProvenance.digestJson(<String, dynamic>{
        'templateVersionDigest': EvalProvenance.digestText(
          observation.activeVersion.id,
        ),
        'templateVersionStatus': observation.activeVersion.status.name,
        'directivesDigest': EvalProvenance.digestText(
          observation.activeVersion.directives,
        ),
        'generalDirectiveDigest': EvalProvenance.digestText(
          observation.activeVersion.generalDirective,
        ),
        'reportDirectiveDigest': EvalProvenance.digestText(
          observation.activeVersion.reportDirective,
        ),
      }),
    };
  }

  static Map<String, dynamic> _unresolvedDigestSubject(
    EvalRuntimeStateObservation observation,
    _RuntimeResolution resolution,
  ) {
    return <String, dynamic>{
      'agentDigest': EvalProvenance.digestText(observation.agent.agentId),
      'templateDigest': EvalProvenance.digestText(observation.template.id),
      'source': resolution.source,
      'status': resolution.status,
    };
  }

  static String _runtimeTargetRef(
    EvalRuntimeStateObservation observation,
    _RuntimeResolution resolution,
  ) {
    return EvalProvenance.digestJson(<String, dynamic>{
      'assignmentRef': observation.assignmentRef,
      'agentId': observation.agent.agentId,
      'templateId': observation.template.id,
      'templateVersionId': observation.activeVersion.id,
      'profileId': resolution.profile?.id ?? resolution.unresolvedProfileId,
      'thinkingModelId': resolution.slot?.model.id,
      'thinkingProviderId': resolution.slot?.provider.id,
    });
  }

  static Map<String, dynamic> _privateRuntimeIds(
    EvalRuntimeStateObservation observation,
    _RuntimeResolution resolution,
  ) {
    return <String, dynamic>{
      'agentId': observation.agent.agentId,
      'templateId': observation.template.id,
      'templateVersionId': observation.activeVersion.id,
      if (resolution.profile != null) 'profileId': resolution.profile!.id,
      if (resolution.unresolvedProfileId != null)
        'unresolvedProfileId': resolution.unresolvedProfileId,
      if (resolution.slot != null) ...{
        'thinkingModelConfigId': resolution.slot!.model.id,
        'thinkingProviderId': resolution.slot!.provider.id,
      },
    };
  }

  static List<String> _modalityNames(List<Modality> modalities) {
    return [for (final modality in modalities) modality.name]..sort();
  }

  static void _assertNoReportLeaks(Map<String, dynamic> report) {
    final encoded = report.toString();
    for (final token in const [
      'apiKey:',
      'baseUrl:',
      'rawPrompt:',
      'rawDirective:',
      'systemPrompt:',
      'directiveText:',
    ]) {
      if (encoded.contains(token)) {
        throw StateError('Runtime state resolver report leaked $token.');
      }
    }
  }

  static _PrivateRuntimeStateRows _parsePrivateRuntimeState(
    Map<String, dynamic> state,
  ) {
    final issues = <String>[];
    _expectEquals(
      issues,
      state['schemaVersion'],
      privateRuntimeStateSchemaVersion,
      'schemaVersion',
    );
    _expectEquals(issues, state['kind'], privateRuntimeStateKind, 'kind');
    if (state['capturedAt'] != null) {
      _expectIsoDate(issues, state['capturedAt'], 'capturedAt');
    }
    _validatePrivateRuntimeStateTopLevel(issues, state);
    _validateNoPrivateRuntimeStateProofFields(
      issues,
      state,
      'privateRuntimeState',
    );

    final entityRows =
        _expectList(
          issues,
          state['agentEntities'] ?? state['entities'],
          'agentEntities',
        ) ??
        const <dynamic>[];
    final linkRows =
        _expectList(issues, state['links'], 'links') ?? const <dynamic>[];
    final aiConfigRows =
        _expectList(issues, state['aiConfigs'], 'aiConfigs') ??
        const <dynamic>[];

    final entities = <AgentDomainEntity>[];
    for (final (index, row) in entityRows.indexed) {
      final json = _expectMap(issues, row, 'agentEntities[$index]');
      if (json == null) continue;
      final runtimeType = _expectNonEmptyString(
        issues,
        json['runtimeType'],
        'agentEntities[$index].runtimeType',
      );
      if (runtimeType != null &&
          !const {
            'agent',
            'agentTemplate',
            'agentTemplateVersion',
          }.contains(runtimeType)) {
        issues.add(
          'agentEntities[$index].runtimeType must be agent, '
          'agentTemplate, or agentTemplateVersion',
        );
        continue;
      }
      try {
        entities.add(AgentDomainEntity.fromJson(json));
      } catch (error) {
        issues.add('agentEntities[$index] failed to parse: $error');
      }
    }

    final links = <AgentLink>[];
    for (final (index, row) in linkRows.indexed) {
      final json = _expectMap(issues, row, 'links[$index]');
      if (json == null) continue;
      final runtimeType = _expectNonEmptyString(
        issues,
        json['runtimeType'],
        'links[$index].runtimeType',
      );
      if (runtimeType != null &&
          !const {
            'agentTask',
            'templateAssignment',
          }.contains(runtimeType)) {
        issues.add(
          'links[$index].runtimeType must be agentTask or templateAssignment',
        );
        continue;
      }
      try {
        links.add(AgentLink.fromJson(json));
      } catch (error) {
        issues.add('links[$index] failed to parse: $error');
      }
    }

    final aiConfigs = <AiConfig>[];
    for (final (index, row) in aiConfigRows.indexed) {
      final json = _expectMap(issues, row, 'aiConfigs[$index]');
      if (json == null) continue;
      final runtimeType = _expectNonEmptyString(
        issues,
        json['runtimeType'],
        'aiConfigs[$index].runtimeType',
      );
      if (runtimeType != null &&
          !const {
            'inferenceProvider',
            'model',
            'inferenceProfile',
          }.contains(runtimeType)) {
        issues.add(
          'aiConfigs[$index].runtimeType must be inferenceProvider, '
          'model, or inferenceProfile',
        );
        continue;
      }
      try {
        aiConfigs.add(AiConfig.fromJson(json));
      } catch (error) {
        issues.add('aiConfigs[$index] failed to parse: $error');
      }
    }
    _validatePrivateRuntimeStateRowUniqueness(
      issues,
      entities: entities,
      links: links,
      aiConfigs: aiConfigs,
    );

    if (issues.isNotEmpty) {
      throw StateError(
        'Invalid private runtime state export:\n${issues.join('\n')}',
      );
    }

    return _PrivateRuntimeStateRows(
      agents: entities.whereType<AgentIdentityEntity>().toList(),
      templates: entities.whereType<AgentTemplateEntity>().toList(),
      activeVersions: entities.whereType<AgentTemplateVersionEntity>().toList(),
      links: links,
      aiConfigs: aiConfigs,
    );
  }

  static void _validatePrivateRuntimeStateTopLevel(
    List<String> issues,
    Map<String, dynamic> state,
  ) {
    const allowedFields = {
      'schemaVersion',
      'kind',
      'capturedAt',
      'agentEntities',
      'entities',
      'links',
      'aiConfigs',
    };
    for (final key in state.keys) {
      if (!allowedFields.contains(key)) {
        issues.add('$key is not supported in private runtime state export');
      }
    }
    if (state.containsKey('agentEntities') && state.containsKey('entities')) {
      issues.add('Use agentEntities or entities, not both');
    }
  }

  static void _validateNoPrivateRuntimeStateProofFields(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        if (const {
          'expected',
          'observed',
          'expectedDigests',
          'resolutionStatus',
          'shadowedTemplateOverride',
          'runtimeTargetRef',
          'resolverBindingDigest',
          'locator',
          'locators',
          'agentLocator',
          'templateLocator',
        }.contains(key)) {
          issues.add('$path.$key must not be supplied by runtime state export');
        }
        _validateNoPrivateRuntimeStateProofFields(
          issues,
          entry.value,
          '$path.$key',
        );
      }
      return;
    }
    if (value is Iterable) {
      var index = 0;
      for (final item in value) {
        _validateNoPrivateRuntimeStateProofFields(
          issues,
          item,
          '$path[$index]',
        );
        index++;
      }
    }
  }

  static void _assertAllLocatorTargetsObserved({
    required Map<String, dynamic> locatorPacket,
    required List<EvalRuntimeStateObservation> observations,
  }) {
    final observedRefs = {
      for (final observation in observations) observation.assignmentRef,
    };
    final missingRefs = [
      for (final locator in locatorsFromPacket(locatorPacket))
        if (!observedRefs.contains(locator.assignmentRef))
          locator.assignmentRef,
    ];
    if (missingRefs.isEmpty) return;
    throw StateError(
      'Private runtime state export did not contain runtime rows for '
      'assignment refs: ${missingRefs.join(', ')}',
    );
  }

  static void _assertResolverPacketMatchesReleaseSources({
    required Map<String, dynamic> releasePlan,
    required Map<String, dynamic> releaseGate,
    required Map<String, dynamic> resolverPacket,
  }) {
    EvalUseCaseRuntimeResolverSnapshot.assertValidPacket(resolverPacket);
    if (!EvalUseCaseRuntimeResolverSnapshot.hasVerifiedPacketSources(
      resolverPacket,
    )) {
      throw StateError('Runtime resolver packet sources must be verified.');
    }
    final sourcePlan = _map(resolverPacket['sourceReleasePlan']);
    final sourceGate = _map(resolverPacket['sourceReleaseGate']);
    final approvedRefs = _stringList(releaseGate['approvedAssignmentRefs'])
      ..sort();
    if (_string(sourcePlan['releasePlanDigest']) !=
            EvalProvenance.digestJson(releasePlan) ||
        _string(sourceGate['releaseGateRef']) !=
            _string(releaseGate['releaseGateRef']) ||
        _string(sourceGate['releaseGateDigest']) !=
            EvalProvenance.digestJson(releaseGate) ||
        _string(sourceGate['approvedAssignmentRefsDigest']) !=
            EvalProvenance.digestJson(approvedRefs)) {
      throw StateError(
        'Runtime resolver packet source release plan/gate digest drift.',
      );
    }
    final requiredRefs = [
      for (final template in _mapList(resolverPacket['bindingTemplates']))
        _string(template['assignmentRef']),
    ]..sort();
    if (requiredRefs.length != approvedRefs.length ||
        requiredRefs.indexed.any(
          (entry) => entry.$2 != approvedRefs[entry.$1],
        )) {
      throw StateError('Runtime resolver packet binding template drift.');
    }
  }

  static void _validatePrivateRuntimeStateRowUniqueness(
    List<String> issues, {
    required List<AgentDomainEntity> entities,
    required List<AgentLink> links,
    required List<AiConfig> aiConfigs,
  }) {
    _expectUniquePrivateRows(
      issues,
      'privateRuntimeState.agentEntities.agent.agentId',
      [
        for (final entity in entities.whereType<AgentIdentityEntity>())
          entity.agentId,
      ],
    );
    _expectUniquePrivateRows(
      issues,
      'privateRuntimeState.agentEntities.agentTemplate.id',
      [
        for (final entity in entities.whereType<AgentTemplateEntity>())
          entity.id,
      ],
    );
    _expectUniquePrivateRows(
      issues,
      'privateRuntimeState.agentEntities.agentTemplateVersion.id',
      [
        for (final entity in entities.whereType<AgentTemplateVersionEntity>())
          entity.id,
      ],
    );
    _expectUniquePrivateRows(
      issues,
      'privateRuntimeState.agentEntities.agentTemplateVersion.active.agentId',
      [
        for (final entity in entities.whereType<AgentTemplateVersionEntity>())
          if (entity.status.name == 'active' && entity.deletedAt == null)
            entity.agentId,
      ],
    );
    _expectUniquePrivateRows(
      issues,
      'privateRuntimeState.links.id',
      [for (final link in links) link.id],
    );
    _expectUniquePrivateRows(
      issues,
      'privateRuntimeState.aiConfigs.id',
      [for (final config in aiConfigs) config.id],
    );
  }

  static void _expectUniquePrivateRows(
    List<String> issues,
    String path,
    Iterable<String> values,
  ) {
    final seen = <String>{};
    for (final value in values) {
      if (value.isEmpty || seen.add(value)) continue;
      issues.add('$path must not contain duplicate private row identities');
    }
  }

  static void _validateLocatorPacketRef(
    List<String> issues,
    Map<String, dynamic> packet,
  ) {
    if (packet['locatorPacketRef'] != locatorPacketRef(packet)) {
      issues.add(
        'locatorPacketRef must match runtime locator packet subject digest',
      );
    }
  }

  static Map<String, dynamic> _locatorPacketSubject(
    Map<String, dynamic> packet,
  ) => <String, dynamic>{
    'kind': locatorPacketKind,
    'schemaVersion': locatorPacketSchemaVersion,
    'generatedAt': _string(packet['generatedAt']),
    'sourceResolverPacket': _map(packet['sourceResolverPacket']),
    'summary': _map(packet['summary']),
    'privacy': _map(packet['privacy']),
    'limitations': _map(packet['limitations']),
    'requiredAssignmentRefs': _stringList(packet['requiredAssignmentRefs']),
    'locators': _mapList(packet['locators']),
  };

  static void _validateLocatorPrivacy(
    List<String> issues,
    Map<String, dynamic>? privacy,
  ) {
    if (privacy == null) return;
    const expected = <String, Object>{
      'privateRuntimeIdsAllowed': true,
      'scenarioIdsOmitted': true,
      'profileNamesOmitted': true,
      'providerBaseUrlsOmitted': true,
      'apiKeysOmitted': true,
      'rawPromptTextOmitted': true,
      'rawDirectiveTextOmitted': true,
      'privatePathsOmitted': true,
      'envValuesOmitted': true,
    };
    for (final entry in expected.entries) {
      _expectEquals(
        issues,
        privacy[entry.key],
        entry.value,
        'privacy.${entry.key}',
      );
    }
  }

  static void _validateLocatorLimitations(
    List<String> issues,
    Map<String, dynamic>? limitations,
  ) {
    if (limitations == null) return;
    const expected = <String, Object>{
      'privateLocatorPacket': true,
      'runtimeStateObservedOnly': true,
      'runtimeConfigurationAppliedByHarness': false,
      'aiConfigMutationsWrittenByHarness': false,
      'liveCommandsCreated': false,
    };
    for (final entry in expected.entries) {
      _expectEquals(
        issues,
        limitations[entry.key],
        entry.value,
        'limitations.${entry.key}',
      );
    }
  }

  static void _validateLocatorRows(
    List<String> issues,
    List<String>? requiredRefs,
    List<dynamic>? locators,
  ) {
    if (requiredRefs == null || locators == null) return;
    for (final ref in requiredRefs) {
      _expectDigest(issues, ref, 'requiredAssignmentRefs[]');
    }
    final requiredRefSet = requiredRefs.toSet();
    final locatorsByRef = <String, int>{};
    for (final (index, value) in locators.indexed) {
      final locator = _expectMap(issues, value, 'locators[$index]');
      if (locator == null) continue;
      _validateLocatorRow(issues, locator, 'locators[$index]');
      final ref = _string(locator['assignmentRef']);
      locatorsByRef[ref] = (locatorsByRef[ref] ?? 0) + 1;
      if (!requiredRefSet.contains(ref)) {
        issues.add('locators[$index].assignmentRef is not required');
      }
    }
    for (final ref in requiredRefs) {
      final count = locatorsByRef[ref] ?? 0;
      if (count == 0) {
        issues.add('locator missing for assignmentRef $ref');
      } else if (count > 1) {
        issues.add('locator duplicated for assignmentRef $ref');
      }
    }
  }

  static void _validateLocatorRow(
    List<String> issues,
    Map<String, dynamic> locator,
    String path,
  ) {
    const allowedFields = {
      'assignmentRef',
      'agentId',
      'taskId',
      'templateId',
      'activeTemplateVersionId',
    };
    const proofFields = {
      'expected',
      'observed',
      'expectedDigests',
      'resolutionStatus',
      'shadowedTemplateOverride',
    };
    for (final key in locator.keys) {
      if (!allowedFields.contains(key) && !proofFields.contains(key)) {
        issues.add('$path.$key is not supported');
      }
    }
    _expectDigest(issues, locator['assignmentRef'], '$path.assignmentRef');
    final agentId = _optionalString(
      issues,
      locator['agentId'],
      '$path.agentId',
    );
    final taskId = _optionalString(issues, locator['taskId'], '$path.taskId');
    _optionalString(issues, locator['templateId'], '$path.templateId');
    _optionalString(
      issues,
      locator['activeTemplateVersionId'],
      '$path.activeTemplateVersionId',
    );
    if (agentId == null && taskId == null) {
      issues.add('$path needs agentId or taskId');
    }
    for (final field in proofFields) {
      if (locator.containsKey(field)) {
        issues.add('$path.$field must not be supplied by locator packets');
      }
    }
  }

  static void _validateNoLocatorPayloadLeaks(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        final normalized = key.toLowerCase();
        if (_forbiddenLocatorFieldReason(normalized) case final reason?) {
          issues.add('$path.$key must not expose $reason');
        }
        _validateNoLocatorPayloadLeaks(issues, entry.value, '$path.$key');
      }
      return;
    }
    if (value is Iterable) {
      var index = 0;
      for (final item in value) {
        _validateNoLocatorPayloadLeaks(issues, item, '$path[$index]');
        index++;
      }
      return;
    }
    if (value is String) {
      if (_privatePathPattern.hasMatch(value)) {
        issues.add('$path must not contain private paths');
      }
      if (_privateEnvTokenPattern.hasMatch(value)) {
        issues.add('$path must not contain private env value keys');
      }
      if (_urlPattern.hasMatch(value)) {
        issues.add('$path must not contain URLs');
      }
      if (_dangerousCommandTokenPattern.hasMatch(value)) {
        issues.add('$path must not contain mutation commands');
      }
    }
  }

  static String? _forbiddenLocatorFieldReason(String normalized) {
    if (normalized == 'apikey' ||
        normalized == 'providerapikey' ||
        normalized == 'secret' ||
        normalized == 'token') {
      return 'API keys or secrets';
    }
    if (normalized == 'baseurl' || normalized == 'providerbaseurl') {
      return 'provider base URLs';
    }
    if (normalized == 'rawprompt' ||
        normalized == 'rawprompts' ||
        normalized == 'prompttext' ||
        normalized == 'systemprompt') {
      return 'raw prompt text';
    }
    if (normalized == 'rawdirective' ||
        normalized == 'rawdirectives' ||
        normalized == 'directivetext') {
      return 'raw directive text';
    }
    return null;
  }

  static Map<String, dynamic> _map(Object? value) =>
      value is Map<String, dynamic> ? value : const <String, dynamic>{};

  static List<Map<String, dynamic>> _mapList(Object? value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return [
      for (final item in value)
        if (item is Map<String, dynamic>) item,
    ];
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const <String>[];
    return [
      for (final item in value)
        if (item is String) item,
    ];
  }

  static bool _stringListsEqual(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  static Map<String, dynamic>? _expectMap(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is Map<String, dynamic>) return value;
    issues.add('$path must be a JSON object');
    return null;
  }

  static List<dynamic>? _expectList(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is List) return value;
    issues.add('$path must be a JSON array');
    return null;
  }

  static List<String>? _expectStringList(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is! List) {
      issues.add('$path must be a JSON array');
      return null;
    }
    final values = <String>[];
    for (final (index, item) in value.indexed) {
      final text = _expectNonEmptyString(issues, item, '$path[$index]');
      if (text != null) values.add(text);
    }
    return values;
  }

  static String? _expectNonEmptyString(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is String && value.isNotEmpty) return value;
    issues.add('$path must be a non-empty string');
    return null;
  }

  static String? _optionalString(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value == null) return null;
    return _expectNonEmptyString(issues, value, path);
  }

  static void _expectDigest(List<String> issues, Object? value, String path) {
    if (value is String && _digestPattern.hasMatch(value)) return;
    issues.add('$path must be a sha256 digest');
  }

  static void _expectIsoDate(List<String> issues, Object? value, String path) {
    if (value is String && DateTime.tryParse(value) != null) return;
    issues.add('$path must be an ISO-8601 timestamp');
  }

  static void _expectNonNegativeInt(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is int && value >= 0) return;
    issues.add('$path must be a non-negative integer');
  }

  static void _expectEquals(
    List<String> issues,
    Object? value,
    Object? expected,
    String path,
  ) {
    if (value == expected) return;
    issues.add('$path must be $expected');
  }

  static String _string(Object? value) => value is String ? value : '';
}

final class EvalRuntimeStateObservation {
  const EvalRuntimeStateObservation({
    required this.assignmentRef,
    required this.agent,
    required this.template,
    required this.activeVersion,
    required this.aiConfigs,
    this.expectedDigests,
    this.resolutionStatus,
    this.shadowedTemplateOverride,
  });

  final String assignmentRef;
  final AgentIdentityEntity agent;
  final AgentTemplateEntity template;
  final AgentTemplateVersionEntity activeVersion;
  final List<AiConfig> aiConfigs;
  final Map<String, dynamic>? expectedDigests;
  final String? resolutionStatus;
  final bool? shadowedTemplateOverride;
}

final class _PrivateRuntimeStateRows {
  const _PrivateRuntimeStateRows({
    required this.agents,
    required this.templates,
    required this.activeVersions,
    required this.links,
    required this.aiConfigs,
  });

  final List<AgentIdentityEntity> agents;
  final List<AgentTemplateEntity> templates;
  final List<AgentTemplateVersionEntity> activeVersions;
  final List<AgentLink> links;
  final List<AiConfig> aiConfigs;
}

/// Private locator for mapping public assignment refs to local runtime rows.
///
/// The locator must never be exported as a public artifact. It is intentionally
/// separate from release plans because those plans omit local runtime IDs.
final class EvalRuntimeBindingLocator {
  const EvalRuntimeBindingLocator({
    required this.assignmentRef,
    this.agentId,
    this.taskId,
    this.templateId,
    this.activeTemplateVersionId,
  }) : assert(
         agentId != null || taskId != null,
         'Runtime locators need an agentId or taskId.',
       );

  factory EvalRuntimeBindingLocator.fromJson(Map<String, dynamic> json) {
    return EvalRuntimeBindingLocator(
      assignmentRef: EvalUseCaseRuntimeStateResolver._string(
        json['assignmentRef'],
      ),
      agentId: json['agentId'] as String?,
      taskId: json['taskId'] as String?,
      templateId: json['templateId'] as String?,
      activeTemplateVersionId: json['activeTemplateVersionId'] as String?,
    );
  }

  final String assignmentRef;
  final String? agentId;
  final String? taskId;
  final String? templateId;
  final String? activeTemplateVersionId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'assignmentRef': assignmentRef,
    if (agentId != null) 'agentId': agentId,
    if (taskId != null) 'taskId': taskId,
    if (templateId != null) 'templateId': templateId,
    if (activeTemplateVersionId != null)
      'activeTemplateVersionId': activeTemplateVersionId,
  };
}

final class _ProfileCandidate {
  const _ProfileCandidate({
    required this.id,
    required this.source,
  });

  final String id;
  final String source;
}

final class _ResolvedProviderSlot {
  const _ResolvedProviderSlot({
    required this.model,
    required this.provider,
  });

  final AiConfigModel model;
  final AiConfigInferenceProvider provider;
}

final class _RuntimeResolution {
  const _RuntimeResolution({
    required this.status,
    required this.source,
    required this.profile,
    required this.slot,
    required this.unresolvedProfileId,
    required this.legacyModelId,
  });

  final String status;
  final String source;
  final AiConfigInferenceProfile? profile;
  final _ResolvedProviderSlot? slot;
  final String? unresolvedProfileId;
  final String? legacyModelId;
}
