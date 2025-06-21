import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:lotti/features/ai/ui/widgets/ai_error_display.dart';
import 'package:lotti/features/ai/util/ai_error_utils.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/modals.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

/// Progress view for unified AI inference
class UnifiedAiProgressContent extends ConsumerWidget {
  const UnifiedAiProgressContent({
    required this.entityId,
    required this.promptId,
    super.key,
  });

  final String entityId;
  final String promptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // First get the prompt config
    final promptConfigAsync = ref.watch(
      aiConfigByIdProvider(promptId),
    );

    return promptConfigAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Error loading prompt: $error',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
      data: (config) {
        if (config == null || config is! AiConfigPrompt) {
          return const Center(child: Text('Invalid prompt configuration'));
        }

        final promptConfig = config;
        final state = ref.watch(
          unifiedAiControllerProvider(
            entityId: entityId,
            promptId: promptId,
          ),
        );

        final inferenceStatus = ref.watch(
          inferenceStatusControllerProvider(
            id: entityId,
            aiResponseType: promptConfig.aiResponseType,
          ),
        );

        final isError = inferenceStatus == InferenceStatus.error;

        // If there's an error, try to parse it as an InferenceError
        if (isError) {
          try {
            // Try to create an InferenceError from the state string
            final inferenceError = AiErrorUtils.categorizeError(state);

            return AiErrorDisplay(
              error: inferenceError,
              onRetry: () {
                // Retry the inference
                ref.invalidate(
                  unifiedAiControllerProvider(
                    entityId: entityId,
                    promptId: promptId,
                  ),
                );
              },
            );
          } catch (_) {
            // If we can't parse it as InferenceError, fall back to text display
          }
        }

        final textStyle = monospaceTextStyleSmall.copyWith(
          fontWeight: FontWeight.w300,
        );

        return Padding(
          padding: const EdgeInsets.only(
            top: 10,
            bottom: 55,
            left: 20,
            right: 20,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 600),
            child: Text(
              state,
              style: textStyle,
            ),
          ),
        );
      },
    );
  }
}

class UnifiedAiProgressUtils {
  static SliverWoltModalSheetPage progressPage({
    required BuildContext context,
    required AiConfigPrompt prompt,
    required String entityId,
    VoidCallback? onTapBack,
    ScrollController? scrollController,
  }) {
    return ModalUtils.sliverModalSheetPage(
      context: context,
      title: prompt.name,
      onTapBack: onTapBack,
      scrollController: scrollController,
      stickyActionBar: Column(
        children: [
          Align(
            alignment: Alignment.bottomCenter,
            child: AiRunningAnimationWrapper(
              entryId: entityId,
              height: 50,
              responseTypes: {prompt.aiResponseType},
            ),
          ),
          TextButton(
            onPressed: () {
              final currentPosition = scrollController?.position.pixels ?? 0;

              scrollController?.animateTo(
                currentPosition + 50,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            },
            child: Text('Scroll'),
          ),
        ],
      ),
      slivers: [
        SliverToBoxAdapter(
            child: UnifiedAiProgressContent(
          entityId: entityId,
          promptId: prompt.id,
        )),
      ],
    );
  }
}
