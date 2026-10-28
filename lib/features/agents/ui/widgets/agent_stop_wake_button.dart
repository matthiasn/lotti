import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/design_system/components/buttons/ds_ai_disc_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Shows that [agentId] is running and stops it — the control for an
/// inference that hangs.
///
/// It wears the read-aloud control's disc: the accent disc inside a spinning
/// ring is the app's one grammar for "AI work under way, tap to stop", so the
/// running indicator and the stop are one control rather than a spinner with
/// a button beside it.
///
/// Renders nothing while the agent is idle, so a host can place it
/// unconditionally. A press signals the orchestrator's abort: the runner
/// marks the wake run `aborted` and releases the agent at once, and the
/// conversation loop leaves its current model turn at the next streamed
/// chunk instead of waiting for the model to finish.
///
/// Between the press and the runner letting go, the glyph turns to the
/// pending one, the label to "Stopping…", and further taps do nothing. It
/// returns to the stop glyph once the agent is idle, so the same control
/// serves the agent's next wake.
class AgentStopWakeButton extends ConsumerStatefulWidget {
  const AgentStopWakeButton({required this.agentId, super.key});

  final String agentId;

  @override
  ConsumerState<AgentStopWakeButton> createState() =>
      _AgentStopWakeButtonState();
}

class _AgentStopWakeButtonState extends ConsumerState<AgentStopWakeButton> {
  bool _stopping = false;

  void _stop() {
    if (_stopping) return;
    final signalled = ref
        .read(agentServiceProvider)
        .abortRunningWake(widget.agentId);
    // A wake that ended on its own between the frame and the tap has
    // nothing to stop; the control goes with the running state.
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

    final ai = context.designTokens.colors.aiCard;
    final messages = context.messages;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return DsAiDiscButton(
      icon: _stopping ? LottiIcons.pending : LottiIcons.stop,
      label: _stopping
          ? messages.agentStopWakeStopping
          : messages.agentStopWakeTooltip,
      onPressed: _stop,
      active: true,
      ring: CircularProgressIndicator(
        strokeWidth: 2,
        value: reduceMotion ? 1.0 : null,
        color: ai.accent,
        backgroundColor: ai.borderSoft,
      ),
    );
  }
}
