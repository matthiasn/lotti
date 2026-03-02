import 'package:flutter/material.dart';
import 'package:lotti/themes/gamey/colors.dart';

/// Styled container for transcript text in the evolution dark/cyan theme.
///
/// Shared by the realtime view and transcription progress widgets.
class EvolutionTranscriptContainer extends StatelessWidget {
  const EvolutionTranscriptContainer({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 120),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: GameyColors.surfaceDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: GameyColors.aiCyan.withValues(alpha: 0.3),
        ),
      ),
      child: child,
    );
  }
}
