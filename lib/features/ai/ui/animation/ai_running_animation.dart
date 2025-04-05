import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glass_kit/glass_kit.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/themes/theme.dart';
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
    super.key,
  });

  final String entryId;
  final double height;
  final Set<String> responseTypes;

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

    return AiRunningAnimation(height: height);
  }
}

class AiRunningAnimationWrapperCard extends ConsumerWidget {
  const AiRunningAnimationWrapperCard({
    required this.entryId,
    required this.height,
    required this.responseTypes,
    super.key,
  });

  final String entryId;
  final double height;
  final Set<String> responseTypes;

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
      child: Center(child: AiRunningAnimation(height: height)),
    );
  }
}
