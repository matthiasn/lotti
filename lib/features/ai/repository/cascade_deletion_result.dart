import 'package:lotti/classes/ai/ai_config.dart';

/// Result object for cascade deletion operations
class CascadeDeletionResult {
  const CascadeDeletionResult({
    required this.deletedModels,
  });

  final List<AiConfigModel> deletedModels;
}
