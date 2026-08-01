import 'package:flutter/foundation.dart';
import 'package:lotti/features/agents/model/agent_report_provenance.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';

enum TaskAgentIdentityPresentation {
  currentOnly,
  combined,
  split,
  disabled,
  broken,
}

/// Framework-free presentation model for the task-agent identity header.
@immutable
class TaskAgentModelIdentityViewData {
  const TaskAgentModelIdentityViewData({
    required this.presentation,
    this.currentRoute,
    this.reportRoute,
    this.reportAttributionUnavailable = false,
  });

  factory TaskAgentModelIdentityViewData.fromResolution({
    required ResolvedAgentSetup? setup,
    required ReportInferenceProvenance? reportProvenance,
    required bool hasReport,
  }) {
    if (setup == null || setup.status == AgentSetupResolutionStatus.broken) {
      return TaskAgentModelIdentityViewData(
        presentation: TaskAgentIdentityPresentation.broken,
        reportRoute: reportProvenance?.finalAuthorRoute,
        reportAttributionUnavailable: hasReport && reportProvenance == null,
      );
    }
    if (setup.status == AgentSetupResolutionStatus.disabled) {
      return TaskAgentModelIdentityViewData(
        presentation: TaskAgentIdentityPresentation.disabled,
        reportRoute: reportProvenance?.finalAuthorRoute,
        reportAttributionUnavailable: hasReport && reportProvenance == null,
      );
    }

    final profile = setup.profile;
    if (profile == null) {
      return TaskAgentModelIdentityViewData(
        presentation: TaskAgentIdentityPresentation.broken,
        reportRoute: reportProvenance?.finalAuthorRoute,
        reportAttributionUnavailable: hasReport && reportProvenance == null,
      );
    }
    final currentRoute = InferenceRouteSnapshot.fromResolvedProfile(profile);
    if (!hasReport) {
      return TaskAgentModelIdentityViewData(
        presentation: TaskAgentIdentityPresentation.currentOnly,
        currentRoute: currentRoute,
      );
    }
    if (reportProvenance == null) {
      return TaskAgentModelIdentityViewData(
        presentation: TaskAgentIdentityPresentation.split,
        currentRoute: currentRoute,
        reportAttributionUnavailable: true,
      );
    }
    final reportRoute = reportProvenance.finalAuthorRoute;
    return TaskAgentModelIdentityViewData(
      presentation: currentRoute.fingerprint == reportRoute.fingerprint
          ? TaskAgentIdentityPresentation.combined
          : TaskAgentIdentityPresentation.split,
      currentRoute: currentRoute,
      reportRoute: reportRoute,
    );
  }

  final TaskAgentIdentityPresentation presentation;
  final InferenceRouteSnapshot? currentRoute;
  final InferenceRouteSnapshot? reportRoute;
  final bool reportAttributionUnavailable;
}

/// Human-readable model publisher and serving-provider identity.
String formatInferenceRouteIdentity(
  InferenceRouteSnapshot route, {
  required String viaLabel,
}) => inferenceRouteIdentityTiers(route, viaLabel: viaLabel).first;

/// The identity string at each width tier, longest first.
///
/// A route is structured, so it degrades by shedding whole segments rather
/// than characters: an ellipsis eats the serving provider — the one fact the
/// row exists to disclose — and leaves the connective word behind
/// ("Qwen 3.5 Plus · Alibaba · via Meliou…"). The model name is the payload
/// and survives every tier.
List<String> inferenceRouteIdentityTiers(
  InferenceRouteSnapshot route, {
  required String viaLabel,
}) {
  final model = route.modelName;
  final publisher = route.publisherName?.trim();
  final hasPublisher = publisher != null && publisher.isNotEmpty;
  final provider = route.servingProviderName;
  return [
    if (hasPublisher)
      '$model · $publisher · $viaLabel $provider'
    else
      '$model · $viaLabel $provider',
    // Drops the publisher and the connective word, keeping both names.
    '$model · $provider',
    model,
  ];
}
