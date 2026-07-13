import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/inference_profile_form.dart';
import 'package:lotti/features/ai/ui/widgets/inference_provider_model_picker_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/settings/settings_picker_field.dart';

/// One skill-slot row in the profile form: shows the model currently assigned
/// to the slot ([modelId]) and opens the shared provider/model picker on tap.
///
/// The picker is restricted to models matching [filter] (e.g. "audio in / text
/// out" for the transcription slot). When [required] is true an empty slot is
/// flagged. Selecting a model — or clearing it — reports back via
/// [onModelSelected] (null clears the slot).
class ModelSlotField extends ConsumerWidget {
  const ModelSlotField({
    required this.label,
    required this.modelId,
    required this.onModelSelected,
    required this.filter,
    this.required = false,
    super.key,
  });

  final String label;
  final String? modelId;
  final ValueChanged<String?> onModelSelected;
  final bool Function(AiConfigModel) filter;
  final bool required;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelsAsync = ref.watch(
      aiConfigByTypeControllerProvider(AiConfigType.model),
    );
    final providersAsync = ref.watch(
      aiConfigByTypeControllerProvider(AiConfigType.inferenceProvider),
    );

    final allModels = (modelsAsync.value ?? const <AiConfig>[])
        .whereType<AiConfigModel>()
        .toList();
    final providers = (providersAsync.value ?? const <AiConfig>[])
        .whereType<AiConfigInferenceProvider>()
        .toList();

    final filteredModels = allModels.where(filter).toList();

    final selectedModel = resolveModelSlot(modelId, allModels);

    return SettingsPickerField(
      label: '$label${required ? ' *' : ''}',
      valueText:
          selectedModel?.name ??
          (modelId != null
              ? context.messages.inferenceProfileModelUnavailable
              : null),
      hintText: context.messages.inferenceProfileSelectModel,
      enabled: filteredModels.isNotEmpty,
      onClear: modelId != null ? () => onModelSelected(null) : null,
      onTap: () => unawaited(
        _showModelPicker(
          context,
          filteredModels,
          providers,
          selectedModel?.id,
        ),
      ),
    );
  }

  Future<void> _showModelPicker(
    BuildContext context,
    List<AiConfigModel> models,
    List<AiConfigInferenceProvider> providers,
    String? selectedModelId,
  ) async {
    final selectedId = await InferenceProviderModelPickerModal.show(
      context: context,
      defaultModelId: null,
      selectedModelId: selectedModelId,
      models: models,
      providers: providers,
      title: context.messages.inferenceProfileChooseModelTitle,
      defaultBadgeLabel: context.messages.designSystemSelectedLabel,
    );
    if (selectedId != null && context.mounted) {
      onModelSelected(selectedId);
    }
  }
}
