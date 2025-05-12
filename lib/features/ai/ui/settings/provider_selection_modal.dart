import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/inference_model_form_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class ProviderSelectionModal extends ConsumerWidget {
  const ProviderSelectionModal({
    required this.configId,
    super.key,
  });

  final String? configId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(
      aiConfigByTypeControllerProvider(
        configType: AiConfigType.inferenceProvider,
      ),
    );

    final formState = ref
        .watch(
          inferenceModelFormControllerProvider(
            configId: configId,
          ),
        )
        .valueOrNull;
    final formController = ref.read(
      inferenceModelFormControllerProvider(configId: configId).notifier,
    );

    return data.when(
      data: (providers) {
        if (providers.isEmpty) {
          return Center(
            child: Text(context.messages.aiConfigNoProvidersAvailable),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          itemCount: providers.length,
          itemBuilder: (context, index) {
            final provider = providers[index];
            return provider.maybeMap(
              inferenceProvider: (providerConfig) {
                return ListTile(
                  title: Text(providerConfig.name),
                  subtitle: Text(
                    providerConfig.description ?? providerConfig.baseUrl,
                  ),
                  trailing: formState?.inferenceProviderId == providerConfig.id
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    formController
                        .inferenceProviderIdChanged(providerConfig.id);
                    Navigator.of(context).pop();
                  },
                );
              },
              orElse: () => const SizedBox.shrink(),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text(
          '${context.messages.aiConfigListErrorLoading}: $error',
        ),
      ),
    );
  }
}
