import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:siri_wave/siri_wave.dart';

class AIRunningAnimation extends ConsumerStatefulWidget {
  const AIRunningAnimation({
    required this.height,
    required this.backgroundColor,
    super.key,
  });

  final Color backgroundColor;
  final double height;

  @override
  ConsumerState<AIRunningAnimation> createState() => _AIRunningAnimationState();
}

class _AIRunningAnimationState extends ConsumerState<AIRunningAnimation> {
  SiriWaveformController controller = IOS9SiriWaveformController();

  @override
  Widget build(BuildContext context) {
    controller.speed = 0.05;
    controller.amplitude = 3.6;

    return Container(
      width: double.infinity,
      color: widget.backgroundColor,
      child: SiriWaveform.ios9(
        controller: controller as IOS9SiriWaveformController,
        options: IOS9SiriWaveformOptions(height: widget.height),
      ),
    );
  }
}

class AiRunningAnimationWrapper extends ConsumerWidget {
  const AiRunningAnimationWrapper({
    required this.entryId,
    required this.height,
    required this.backgroundColor,
    required this.responseTypes,
    super.key,
  });

  final String entryId;
  final Color backgroundColor;
  final double height;
  final Set<String> responseTypes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runningStatuses = responseTypes.map((responseType) {
      final inferenceStatus = ref.watch(
        inferenceStatusControllerProvider(
          id: entryId,
          aiResponseType: responseType,
        ),
      );

      return inferenceStatus == InferenceStatus.running;
    });

    final isRunning = runningStatuses.contains(true);

    if (!isRunning) {
      return const SizedBox.shrink();
    }

    return AIRunningAnimation(
      height: height,
      backgroundColor: backgroundColor,
    );
  }
}
