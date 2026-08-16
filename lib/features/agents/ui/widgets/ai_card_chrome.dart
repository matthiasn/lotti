import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// The shared chrome of the app's "intelligence" panels — the task agent
/// section on Task Details and the goal agent's read on Goal Details wear
/// the SAME surface, so a change to the wash, border or radius lands on
/// both in unison.
///
/// A directional accent wash anchored at the top-left (where the sparkle
/// badge sits) leads the eye to the AI identity, then falls off to the flat
/// background — a crafted panel that stays within the aiCard palette and
/// the design system's flat aesthetic.
BoxDecoration aiCardDecoration(BuildContext context) {
  final tokens = context.designTokens;
  final ai = tokens.colors.aiCard;
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: const [0, 0.55, 1],
      colors: [
        // A gentle top-left accent wash that falls off to the flat
        // background — a touch more present than the original (which read
        // as muted) but without carrying the accent across the whole card
        // (which read as too loud). Landed between the two.
        Color.alphaBlend(ai.accent.withValues(alpha: 0.12), ai.background),
        ai.background,
        ai.background,
      ],
    ),
    borderRadius: aiCardRadius(context),
    border: Border.all(color: ai.border),
  );
}

/// The corner radius both AI panels share (clip children with it too).
BorderRadius aiCardRadius(BuildContext context) =>
    BorderRadius.circular(context.designTokens.radii.l);

/// Shared outer structure for agent summaries across task and project detail.
///
/// Feature-specific cards supply their report, proposal, and footer regions,
/// while this widget keeps the AI surface, clipping, and vertical composition
/// identical. This prevents each domain from inventing its own agent card.
class AgentSummaryCardSurface extends StatelessWidget {
  const AgentSummaryCardSurface({
    required this.children,
    super.key,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: aiCardDecoration(context),
      child: ClipRRect(
        borderRadius: aiCardRadius(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}
