import 'package:flutter/material.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_typing_indicator.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/cards/modern_icon_container.dart';

/// The first frame of a 1-on-1, shown while the session is being opened.
///
/// This is the moment the whole feature is judged on, and it used to be a
/// 16px spinner beside a literal `'...'` in the corner of an empty black
/// page. It now says what is happening, centred in the column the
/// conversation will occupy.
class EvolutionSessionOpening extends StatelessWidget {
  const EvolutionSessionOpening({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ModernIconContainer(icon: Icons.forum_rounded),
            SizedBox(height: tokens.spacing.step5),
            // The agent is named in the app bar directly above; repeating it
            // here is the duplication this redesign set out to remove.
            Text(
              context.messages.agentRitualOpeningHint,
              textAlign: TextAlign.center,
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
            SizedBox(height: tokens.spacing.step6),
            const EvolutionTypingIndicator(),
          ],
        ),
      ),
    );
  }
}
