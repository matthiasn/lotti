import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Stops [agentId]'s running wake — the control for an inference that hangs.
///
/// Renders nothing while the agent is idle, so a host can place it
/// unconditionally. A press signals the orchestrator's abort: the runner
/// marks the wake run `aborted` and releases the agent at once, and the
/// conversation loop leaves its current model turn at the next streamed
/// chunk instead of waiting for the model to finish.
///
/// Between the press and the runner letting go, the button reads
/// "Stopping…" and ignores further taps. It returns to "Stop" once the agent
/// is idle, so the same button serves the agent's next wake.
class AgentStopWakeButton extends ConsumerStatefulWidget {
  const AgentStopWakeButton({
    required this.agentId,
    this.size = DesignSystemButtonSize.small,
    super.key,
  });

  final String agentId;
  final DesignSystemButtonSize size;

  @override
  ConsumerState<AgentStopWakeButton> createState() =>
      _AgentStopWakeButtonState();
}

class _AgentStopWakeButtonState extends ConsumerState<AgentStopWakeButton> {
  bool _stopping = false;

  void _stop() {
    final signalled = ref
        .read(agentServiceProvider)
        .abortRunningWake(widget.agentId);
    // A wake that ended on its own between the frame and the tap has
    // nothing to stop; the button goes with the running state.
    if (signalled) setState(() => _stopping = true);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(agentIsRunningProvider(widget.agentId), (_, next) {
      if (next.value == false && _stopping) {
        setState(() => _stopping = false);
      }
    });
    final isRunning =
        ref.watch(agentIsRunningProvider(widget.agentId)).value ?? false;
    if (!isRunning) return const SizedBox.shrink();

    final messages = context.messages;
    return DesignSystemButton(
      label: _stopping
          ? messages.agentStopWakeStopping
          : messages.agentStopWake,
      semanticsLabel: messages.agentStopWakeTooltip,
      onPressed: _stop,
      isLoading: _stopping,
      variant: DesignSystemButtonVariant.outlined,
      size: widget.size,
      leadingIcon: LottiIcons.stop,
    );
  }
}

/// The running indicator and its [AgentStopWakeButton], side by side, for a
/// page or panel header. Renders nothing while [agentId] is idle.
class AgentRunningControls extends ConsumerWidget {
  const AgentRunningControls({required this.agentId, super.key});

  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRunning = ref.watch(agentIsRunningProvider(agentId)).value ?? false;
    if (!isRunning) return const SizedBox.shrink();

    final tokens = context.designTokens;
    final label = context.messages.agentRunningIndicator;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: label,
          child: DesignSystemSpinner(
            style: DesignSystemSpinnerStyle.plain,
            size: IconSizes.m,
            semanticsLabel: label,
          ),
        ),
        SizedBox(width: tokens.spacing.step3),
        AgentStopWakeButton(agentId: agentId),
      ],
    );
  }
}
