import 'package:lotti/features/agents/util/agent_error_logging.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_service.dart';
import 'package:lotti/features/ai_consumption/service/ai_interaction_capture.dart';
import 'package:lotti/get_it.dart';

/// Whether this process can both record an AI interaction and attribute it.
///
/// Both services are optional registrations, and consumption accounting needs
/// the pair: capture supplies the interaction rows, attribution the wake-level
/// envelope that owns them. Attributing without capture would leave an envelope
/// over nothing.
bool get canRecordAgentConsumption =>
    getIt.isRegistered<AiInteractionCapture>() &&
    getIt.isRegistered<AiAttributionService>();

/// Opens a wake's attribution envelope over the report it is about to write.
///
/// Returns `null` when there is no report to attribute ([reportId] is `null`),
/// or when [canRecordAgentConsumption] is false. Both halves matter: the
/// envelope exists to own the interaction rows capture records, so preparing one
/// while capture is unregistered attributes a wake whose cost was never
/// measured — an envelope over nothing, which is the same reason
/// [canRecordAgentConsumption] requires the pair rather than either service
/// alone.
Future<AiWorkAttribution?> prepareAgentReportAttribution({
  required String runKey,
  required String? reportId,
}) async {
  if (reportId == null || !canRecordAgentConsumption) return null;
  return getIt<AiAttributionService>().prepareCompletion(
    attributionId: agentWakeAttributionId(runKey),
    outputs: [
      AiArtifactReference(type: AiArtifactType.agentReport, id: reportId),
    ],
  );
}

/// Terminalizes a wake's attribution envelope when no *carrier* interaction ever
/// recorded against it.
///
/// A wake normally closes its envelope as a side effect of the inference call it
/// made. When the wake fails before reaching inference — or takes a branch that
/// makes no call at all — the envelope would otherwise stay open forever and the
/// wake would look perpetually in-flight in the consumption surfaces. This
/// closes it explicitly with [status] and [errorCode].
///
/// A no-op when [canRecordAgentConsumption] is false, and contained on failure:
/// bookkeeping must never turn an otherwise-successful wake into a failed one,
/// so [logger] reports the failure and the wake proceeds.
Future<void> finalizeCarrierlessAgentAttribution({
  required String runKey,
  required AiWorkStatus status,
  required String errorCode,
  required AgentErrorLogging logger,
  String? errorSummary,
}) async {
  if (!canRecordAgentConsumption) return;
  try {
    final service = getIt<AiAttributionService>();
    final attribution = await service.prepareCompletion(
      attributionId: agentWakeAttributionId(runKey),
      outputs: const [],
      status: status,
      errorCode: errorCode,
      errorSummary: errorSummary,
    );
    await service.finalize(attribution);
  } catch (error, stackTrace) {
    logger.logError(
      'failed to terminalize carrier-less attribution',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
