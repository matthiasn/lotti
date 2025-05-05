import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/prompt_form_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// A modal for selecting an inference model to use with a prompt.
class ModelSelectionModal extends ConsumerWidget {
  const ModelSelectionModal({
    required this.promptId,
    super.key,
  });

  final String? promptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelsAsync = ref.watch(
      aiConfigByTypeControllerProvider(configType: AiConfigType.model),
    );

    return modelsAsync.when(
      data: (models) {
        if (models.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.messages.aiConfigNoModelsAvailable,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: models.length,
          itemBuilder: (context, index) {
            final model = models[index] as AiConfigModel;
            return ListTile(
              title: Text(model.name),
              subtitle: Text(model.description ?? ''),
              trailing: model.isReasoningModel
                  ? Tooltip(
                      message: context.messages.aiConfigModelSupportsReasoning,
                      child: const Icon(Icons.psychology),
                    )
                  : null,
              onTap: () {
                // Select this model for the prompt
                ref
                    .read(
                      promptFormControllerProvider(configId: promptId).notifier,
                    )
                    .modelIdChanged(model.id);
                Navigator.of(context).pop();
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            context.messages.aiConfigFailedToLoadModels(error.toString()),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
