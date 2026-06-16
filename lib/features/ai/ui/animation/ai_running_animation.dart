import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glass_kit/glass_kit.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/active_inference_controller.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/animation/ai_state_shader_animation.dart';
import 'package:lotti/features/ai/ui/unified_ai_progress_view.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:siri_wave/siri_wave.dart';

/// Bare iOS-9-style Siri waveform sized to [height].
///
/// The visual primitive only — it carries no inference state. Wrap it in
/// [AiRunningAnimationWrapper] to gate it on a running entry, or use
/// [AiRunningDecoderBars] for the shader-based variant.
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

/// [AiRunningAnimation] gated on whether inference is running for an entry.
///
/// Watches the inference-running signal for [entryId] / [responseTypes] and
/// renders nothing when idle. When [isInteractive] is true, tapping the
/// waveform opens the AI progress view for that entry.
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
    await _handleAiActivityTap(
      context: context,
      ref: ref,
      entryId: entryId,
      responseTypes: responseTypes,
    );
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

/// The shader-based "AI is thinking" decoder bars, gated per entry.
///
/// Watches the inference-running signal for [entryId] / [responseTypes] and
/// drives [AiThinkingShaderPresence] (which owns the fade/scale-in, exit, and
/// collapse-to-zero envelope). When [isInteractive] is true the bars become a
/// labelled button that opens the AI progress view. The `default*` statics
/// expose the shared shader defaults so other surfaces can match this look.
class AiRunningDecoderBars extends ConsumerWidget {
  const AiRunningDecoderBars({
    required this.entryId,
    required this.responseTypes,
    this.height = defaultHeight,
    this.isInteractive = false,
    super.key,
  });

  static const defaultHeight = 34.0;
  static const defaultSpeed = 3.6;
  static const defaultRandomness = 1.0;
  static const defaultAmplitude = 0.7;
  static const defaultPulse = 0.6;
  static const defaultLineCount = 5;
  static const transitionDuration = Duration(milliseconds: 340);

  @visibleForTesting
  static const Key indicatorKey = ValueKey('ai-running-decoder-bars');

  @visibleForTesting
  static double resolveShaderWidth(BoxConstraints constraints, Size mediaSize) {
    if (constraints.hasBoundedWidth) {
      return constraints.maxWidth;
    }

    return mediaSize.width;
  }

  final String entryId;
  final Set<AiResponseType> responseTypes;
  final double height;
  final bool isInteractive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The presence envelope (fade/scale in & out, collapse to zero) lives in
    // [AiThinkingShaderPresence]; here we only feed it the entry's
    // inference-running signal and, when interactive, the tap-to-progress
    // affordance.
    final isRunning = ref.watch(
      inferenceRunningControllerProvider(
        id: entryId,
        responseTypes: responseTypes,
      ),
    );

    final bars = AiThinkingShaderPresence(
      isRunning: isRunning,
      height: height,
      indicatorKey: indicatorKey,
    );

    if (!isInteractive) {
      return bars;
    }

    return Semantics(
      button: true,
      label: context.messages.aiRunningActivityOpenProgress,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _handleAiActivityTap(
          context: context,
          ref: ref,
          entryId: entryId,
          responseTypes: responseTypes,
        ),
        child: bars,
      ),
    );
  }
}

/// Reusable presence/fade envelope around [AiThinkingLineShader].
///
/// Renders nothing while [isRunning] is false and the exit animation has
/// finished; on `isRunning` → true it fades and scales the shader in over
/// [transitionDuration], and reverses on the way out before collapsing to
/// zero reserved height. The shader amplitude, pulse, and opacity are
/// scaled by the eased presence progress so entry/exit read as a single
/// motion.
///
/// Extracted from [AiRunningDecoderBars] so surfaces that aren't tied to
/// the per-entry inference provider — e.g. the day-planning modal action
/// bar — can show the same "AI is thinking" shader driven by their own
/// busy signal.
class AiThinkingShaderPresence extends StatefulWidget {
  const AiThinkingShaderPresence({
    required this.isRunning,
    this.height = AiRunningDecoderBars.defaultHeight,
    this.speed = AiRunningDecoderBars.defaultSpeed,
    this.amplitude = AiRunningDecoderBars.defaultAmplitude,
    this.randomness = AiRunningDecoderBars.defaultRandomness,
    this.pulse = AiRunningDecoderBars.defaultPulse,
    this.lineCount = AiRunningDecoderBars.defaultLineCount,
    this.transitionDuration = AiRunningDecoderBars.transitionDuration,
    this.primaryColor,
    this.secondaryColor,
    this.indicatorKey,
    super.key,
  });

  final bool isRunning;
  final double height;
  final double speed;
  final double amplitude;
  final double randomness;
  final double pulse;
  final int lineCount;
  final Duration transitionDuration;

  /// Defaults to `tokens.colors.interactive.enabled` when null.
  final Color? primaryColor;

  /// Defaults to `tokens.colors.text.highEmphasis` when null.
  final Color? secondaryColor;

  /// Optional key placed on the animated reserved-height box so hosts can
  /// assert presence/absence in tests.
  final Key? indicatorKey;

  @override
  State<AiThinkingShaderPresence> createState() =>
      _AiThinkingShaderPresenceState();
}

class _AiThinkingShaderPresenceState extends State<AiThinkingShaderPresence>
    with SingleTickerProviderStateMixin {
  late final AnimationController _presenceController;

  bool _buildBars = false;

  @override
  void initState() {
    super.initState();
    _presenceController = AnimationController(
      vsync: this,
      duration: widget.transitionDuration,
    );
    _presenceController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && mounted) {
        setState(() => _buildBars = false);
      }
    });

    // Seed the presence for a busy signal that is already true when this
    // widget first mounts — fully shown, without an entry animation.
    if (widget.isRunning) {
      _buildBars = true;
      _presenceController.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant AiThinkingShaderPresence oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.transitionDuration != oldWidget.transitionDuration) {
      _presenceController.duration = widget.transitionDuration;
    }
    if (widget.isRunning != oldWidget.isRunning) {
      _syncPresence(widget.isRunning);
    }
  }

  @override
  void dispose() {
    _presenceController.dispose();
    super.dispose();
  }

  void _syncPresence(bool isRunning) {
    if (isRunning) {
      if (!_buildBars) {
        setState(() => _buildBars = true);
      }
      if (_presenceController.value < 1 &&
          _presenceController.status != AnimationStatus.forward) {
        _presenceController.forward();
      }
      return;
    }

    if (_presenceController.value > 0 &&
        _presenceController.status != AnimationStatus.reverse) {
      _presenceController.reverse();
    }
  }

  double get _presenceProgress {
    final value = _presenceController.value.clamp(0.0, 1.0);
    return Curves.easeInOutCubic.transform(value);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final bottomGap = spacing.step2;
    final primary = widget.primaryColor ?? tokens.colors.interactive.enabled;
    final secondary = widget.secondaryColor ?? tokens.colors.text.highEmphasis;

    return AnimatedBuilder(
      animation: _presenceController,
      builder: (context, _) {
        final progress = _presenceProgress;
        final shaderHeight = widget.height * progress;
        if (!_buildBars || shaderHeight < 1) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          key: widget.indicatorKey,
          height: (widget.height + bottomGap) * progress,
          width: double.infinity,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: shaderHeight,
              width: double.infinity,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = AiRunningDecoderBars.resolveShaderWidth(
                    constraints,
                    MediaQuery.sizeOf(context),
                  );
                  return AiThinkingLineShader(
                    width: width,
                    height: shaderHeight,
                    speed: widget.speed,
                    amplitude: widget.amplitude * progress,
                    randomness: widget.randomness,
                    lineCount: widget.lineCount,
                    pulse: widget.pulse * progress,
                    opacity: progress,
                    primaryColor: primary,
                    secondaryColor: secondary,
                    backgroundColor: Colors.transparent,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> _handleAiActivityTap({
  required BuildContext context,
  required WidgetRef ref,
  required String entryId,
  required Set<AiResponseType> responseTypes,
}) async {
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

  if (activeInference == null) return;

  final prompt = await ref.read(
    aiConfigByIdProvider(activeInference.promptId).future,
  );

  if (prompt == null || prompt is! AiConfigPrompt) return;

  final entityId = activeInference.entityId;
  if (!context.mounted) return;

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

/// [AiRunningAnimationWrapper] wrapped in a glass card.
///
/// Same per-entry gating as [AiRunningAnimationWrapper] (renders nothing when
/// idle), but presents the waveform inside a frosted-glass container for
/// surfaces that need a self-contained card rather than an inline indicator.
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
