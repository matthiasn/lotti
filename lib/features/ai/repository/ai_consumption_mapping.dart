import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_enums.dart';

/// Maps the AI feature's [AiResponseType] onto the consumption feature's
/// [AiConsumptionResponseType]. Lives in the AI feature so `ai_consumption`
/// stays decoupled from AI-response internals.
extension AiResponseTypeConsumptionMapping on AiResponseType {
  AiConsumptionResponseType get consumptionResponseType {
    switch (this) {
      case AiResponseType.imageAnalysis:
        return AiConsumptionResponseType.imageAnalysis;
      case AiResponseType.audioTranscription:
        return AiConsumptionResponseType.audioTranscription;
      case AiResponseType.promptGeneration:
      case AiResponseType.imagePromptGeneration:
        return AiConsumptionResponseType.promptGeneration;
      case AiResponseType.imageGeneration:
        return AiConsumptionResponseType.imageGeneration;
      // ignore: deprecated_member_use_from_same_package
      case AiResponseType.taskSummary:
      // ignore: deprecated_member_use_from_same_package
      case AiResponseType.checklistUpdates:
        return AiConsumptionResponseType.textGeneration;
    }
  }
}
