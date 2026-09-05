import 'package:lotti/features/agents/ui/evolution/widgets/evolution_circle_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Cancel and stop button pair used during recording states.
///
/// Shared by the voice-recording control widgets.
class EvolutionCancelStopButtons extends StatelessWidget {
  const EvolutionCancelStopButtons({
    required this.onCancel,
    required this.onStop,
    required this.cancelTooltip,
    required this.stopTooltip,
    super.key,
  });

  final VoidCallback onCancel;
  final VoidCallback onStop;
  final String cancelTooltip;
  final String stopTooltip;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 8),
        EvolutionCircleButton(
          icon: LottiIcons.close,
          onPressed: onCancel,
          tooltip: cancelTooltip,
        ),
        const SizedBox(width: 4),
        EvolutionCircleButton(
          icon: LottiIcons.stop,
          onPressed: onStop,
          tooltip: stopTooltip,
        ),
      ],
    );
  }
}
