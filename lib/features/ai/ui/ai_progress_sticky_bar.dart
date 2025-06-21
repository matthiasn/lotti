import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:lotti/themes/theme.dart';

class AiProgressStickyBar extends ConsumerWidget {
  const AiProgressStickyBar({
    required this.entityId,
    required this.promptId,
    this.onTap,
    super.key,
  });

  final String entityId;
  final String promptId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promptConfigAsync = ref.watch(
      aiConfigByIdProvider(promptId),
    );

    return promptConfigAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (config) {
        if (config == null || config is! AiConfigPrompt) {
          return const SizedBox.shrink();
        }

        final promptConfig = config;
        final inferenceStatus = ref.watch(
          inferenceStatusControllerProvider(
            id: entityId,
            aiResponseType: promptConfig.aiResponseType,
          ),
        );

        final isRunning = inferenceStatus == InferenceStatus.running;

        if (!isRunning) {
          // Show subtle status when not running
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.light
                  ? context.colorScheme.surface
                  : context.colorScheme.surfaceContainer,
              border: Border(
                top: BorderSide(
                  color: context.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Center(
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  decoration: BoxDecoration(
                    color: inferenceStatus == InferenceStatus.idle
                        ? context.colorScheme.primaryContainer
                            .withValues(alpha: 0.2)
                        : context.colorScheme.errorContainer
                            .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: inferenceStatus == InferenceStatus.idle
                          ? context.colorScheme.primary.withValues(alpha: 0.3)
                          : context.colorScheme.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        inferenceStatus == InferenceStatus.idle
                            ? Icons.check_circle
                            : Icons.error_outline,
                        size: 16,
                        color: inferenceStatus == InferenceStatus.idle
                            ? context.colorScheme.primary
                            : context.colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        inferenceStatus == InferenceStatus.idle
                            ? 'Complete'
                            : 'Error',
                        style: context.textTheme.labelMedium?.copyWith(
                          color: inferenceStatus == InferenceStatus.idle
                              ? context.colorScheme.primary
                              : context.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        // Running state with animation
        return GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.light
                  ? context.colorScheme.surface
                  : context.colorScheme.surfaceContainer,
              border: Border(
                top: BorderSide(
                  color: context.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Processing indicator at top
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            context.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Processing',
                        style: context.textTheme.labelLarge?.copyWith(
                          color: context.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Animation below
                SizedBox(
                  height: 60,
                  child: AiRunningAnimationWrapper(
                    entryId: entityId,
                    height: 50,
                    responseTypes: {promptConfig.aiResponseType},
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
