import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:siri_wave/siri_wave.dart';

class AIRunningAnimation extends ConsumerStatefulWidget {
  const AIRunningAnimation({
    required this.entryId,
    required this.height,
    required this.backgroundColor,
    super.key,
  });

  final String entryId;
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

    final taskInferenceStatus = ref.watch(
      inferenceStatusControllerProvider(
        id: widget.entryId,
        aiResponseType: taskSummary,
      ),
    );
    final actionItemInferenceStatus = ref.watch(
      inferenceStatusControllerProvider(
        id: widget.entryId,
        aiResponseType: actionItemSuggestions,
      ),
    );

    final isRunning = taskInferenceStatus == InferenceStatus.running ||
        actionItemInferenceStatus == InferenceStatus.running;

    if (!isRunning) {
      return const SizedBox.shrink();
    }

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
