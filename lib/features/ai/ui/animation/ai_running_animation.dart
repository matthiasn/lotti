import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glass_kit/glass_kit.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/active_inference_controller.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/unified_ai_progress_view.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:siri_wave/siri_wave.dart';

class AiRunningAnimation extends ConsumerStatefulWidget {
  const AiRunningAnimation({
    required this.height,
    super.key,
  });

  final double height;

  @override
  ConsumerState<AiRunningAnimation> createState() => _AIRunningAnimationState();
}

class _AIRunningAnimationState extends ConsumerState<AiRunningAnimation> {
  SiriWaveformController controller = IOS9SiriWaveformController();

  @override
  Widget build(BuildContext context) {
    controller.speed = 0.02;
    controller.amplitude = 1;

    return SiriWaveform.ios9(
      controller: controller as IOS9SiriWaveformController,
      options: IOS9SiriWaveformOptions(height: widget.height),
    );
  }
}

class AiRunningAnimationWrapper extends ConsumerWidget {
  const AiRunningAnimationWrapper({
    required this.entryId,
    required this.height,
    required this.responseTypes,
    this.isInteractive = false,
    super.key,
  });

  final String entryId;
  final double height;
  final Set<AiResponseType> responseTypes;
  final bool isInteractive;

  Future<void> _handleTap(BuildContext context, WidgetRef ref) async {
    // Find the active inference for this entity
    ActiveInferenceData? activeInference;

    for (final responseType in responseTypes) {
      final inference = ref.read(
        activeInferenceControllerProvider(
          entityId: entryId,
          aiResponseType: responseType,
        ),
      );
      if (inference != null) {
        activeInference = inference;
        break;
      }
    }

    if (activeInference != null) {
      // Get the prompt configuration
      final prompt = await ref.read(
        aiConfigByIdProvider(activeInference.promptId).future,
      );

      if (prompt != null && prompt is AiConfigPrompt) {
        final entityId = activeInference.entityId;
        if (context.mounted) {
          await ModalUtils.showSingleSliverPageModal<void>(
            context: context,
            builder: (ctx) => UnifiedAiProgressUtils.progressPage(
              context: ctx,
              prompt: prompt,
              entityId: entityId,
              onTapBack: () => Navigator.of(ctx).pop(),
              showExisting: true,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = inferenceRunningControllerProvider(
      id: entryId,
      responseTypes: responseTypes,
    );
    final isRunning = ref.watch(provider);

    if (!isRunning) {
      return const SizedBox.shrink();
    }

    final animation = AiRunningAnimation(height: height);

    if (isInteractive) {
      return GestureDetector(
        onTap: () => _handleTap(context, ref),
        child: animation,
      );
    }

    return animation;
  }
}

class AiRunningAnimationWrapperCard extends ConsumerWidget {
  const AiRunningAnimationWrapperCard({
    required this.entryId,
    required this.height,
    required this.responseTypes,
    this.isInteractive = false,
    super.key,
  });

  final String entryId;
  final double height;
  final Set<AiResponseType> responseTypes;
  final bool isInteractive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = inferenceRunningControllerProvider(
      id: entryId,
      responseTypes: responseTypes,
    );
    final isRunning = ref.watch(provider);

    if (!isRunning) {
      return const SizedBox.shrink();
    }

    return GlassContainer.clearGlass(
      elevation: 0,
      height: height,
      width: double.infinity,
      blur: 12,
      color: context.colorScheme.surface.withAlpha(128),
      borderWidth: 0,
      child: Center(
        child: AiRunningAnimationWrapper(
          entryId: entryId,
          height: height,
          responseTypes: responseTypes,
          isInteractive: isInteractive,
        ),
      ),
    );
  }
}
