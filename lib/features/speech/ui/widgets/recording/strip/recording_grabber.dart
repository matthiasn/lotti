import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The short bar that says "this opens and folds": on the recording strip's
/// top edge, where the strip opens into its tray, and on the tray's, where
/// it folds back. The tap is the host's; this only draws.
class RecordingGrabber extends StatelessWidget {
  const RecordingGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.step2),
      child: Container(
        width: tokens.spacing.step7,
        height: tokens.spacing.step2,
        decoration: BoxDecoration(
          color: tokens.colors.decorative.level02,
          borderRadius: BorderRadius.circular(tokens.radii.xs),
        ),
      ),
    );
  }
}
