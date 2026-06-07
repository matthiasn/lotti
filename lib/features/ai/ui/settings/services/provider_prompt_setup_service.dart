import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/profile_seeding_service.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'alibaba_ftue_setup.dart';
part 'anthropic_ftue_setup.dart';
part 'ftue_helpers.dart';
part 'gemini_ftue_setup.dart';
part 'mistral_ftue_setup.dart';
part 'ollama_ftue_setup.dart';
part 'openai_ftue_setup.dart';
part 'provider_prompt_setup_service.g.dart';

/// Provider for [ProviderPromptSetupService].
@riverpod
ProviderPromptSetupService providerPromptSetupService(Ref ref) {
  return const ProviderPromptSetupService();
}

/// Service that handles automatic FTUE (First Time User Experience) setup
/// after creating inference providers.
///
/// The FTUE flow creates:
/// 1. Models (provider-specific known model configurations)
/// 2. A test category for quick experimentation
///
/// Prompts are no longer created during FTUE — all AI capabilities are
/// handled by the skill-based automation system via inference profiles.
class ProviderPromptSetupService {
  const ProviderPromptSetupService();
}

// =============================================================================
// FTUE (First Time User Experience) Setup
// =============================================================================

/// Common shape for every per-provider FTUE result.
///
/// Declared `sealed` so callers (`runFtueSetupForType`,
/// `AiProviderSetupResultData.from`) get exhaustive switch coverage when
/// a new provider is wired in — the analyzer will flag any missing arm.
sealed class AiFtueResult {
  const AiFtueResult({
    required this.modelsCreated,
    required this.modelsVerified,
    required this.categoryCreated,
    this.categoryReused = false,
    this.categoryName,
    this.errors = const [],
  });

  final int modelsCreated;
  final int modelsVerified;
  final bool categoryCreated;
  final bool categoryReused;
  final String? categoryName;
  final List<String> errors;

  int get totalModels => modelsCreated + modelsVerified;
}

/// Internal model-creation tally used by every per-provider setup helper.
/// Replaces the previous typed `_<X>FtueModelResult` classes — none of the
/// per-role fields were ever read outside the loop.
typedef _FtueModelTally = ({
  List<AiConfigModel> created,
  List<AiConfigModel> verified,
});
