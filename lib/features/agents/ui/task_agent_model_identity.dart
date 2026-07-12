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
    this.brokenSelectionId,
  });

  factory TaskAgentModelIdentityViewData.fromResolution({
    required ResolvedAgentSetup? setup,
    required ReportInferenceProvenance? reportProvenance,
    required bool hasReport,
  }) {
    if (setup == null || setup.status == AgentSetupResolutionStatus.broken) {
      return TaskAgentModelIdentityViewData(
        presentation: TaskAgentIdentityPresentation.broken,
        brokenSelectionId: setup?.brokenSelectionId,
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
        brokenSelectionId: setup.brokenSelectionId,
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
  final String? brokenSelectionId;
}

/// Human-readable model publisher and serving-provider identity.
String formatInferenceRouteIdentity(InferenceRouteSnapshot route) {
  final parts = <String>[
    route.modelName,
    if (route.publisherName?.trim().isNotEmpty ?? false)
      route.publisherName!.trim(),
  ];
  return '${parts.join(' · ')} · via ${route.servingProviderName}';
}
