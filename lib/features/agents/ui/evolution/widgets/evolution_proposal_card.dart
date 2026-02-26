import 'package:flutter/material.dart';
import 'package:lotti/features/agents/workflow/evolution_strategy.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/gamey/colors.dart';
import 'package:lotti/themes/gamey/glows.dart';
import 'package:lotti/themes/gamey/gradients.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';

/// Inline proposal card showing the proposed directive changes.
///
/// Displays current vs. proposed directives, the agent's rationale, and
/// approve/reject action buttons. Uses enhanced card styling with a
/// purple→blue gradient border glow.
class EvolutionProposalCard extends StatelessWidget {
  const EvolutionProposalCard({
    required this.proposal,
    required this.onApprove,
    required this.onReject,
    this.currentDirectives,
    this.isWaiting = false,
    super.key,
  });

  final PendingProposal proposal;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final String? currentDirectives;
  final bool isWaiting;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ModernBaseCard(
        isEnhanced: true,
        customShadows: [GameyGlows.strongGlow(GameyColors.primaryPurple)],
        gradient: GameyGradients.cardDark(GameyColors.primaryPurple),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 20,
                  color: GameyColors.primaryPurple,
                ),
                const SizedBox(width: 8),
                Text(
                  context.messages.agentEvolutionProposalTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Current directives
            if (currentDirectives != null && currentDirectives!.isNotEmpty) ...[
              _SectionLabel(
                text: context.messages.agentEvolutionCurrentDirectives,
              ),
              const SizedBox(height: 6),
              _DirectiveBox(
                text: currentDirectives!,
                backgroundColor: GameyColors.surfaceDark.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 14),
            ],

            // Proposed directives
            _SectionLabel(
              text: context.messages.agentEvolutionProposedDirectives,
            ),
            const SizedBox(height: 6),
            _DirectiveBox(
              text: proposal.directives,
              backgroundColor: GameyColors.primaryPurple.withValues(alpha: 0.1),
              borderColor: GameyColors.primaryPurple.withValues(alpha: 0.3),
            ),

            // Rationale
            if (proposal.rationale.isNotEmpty) ...[
              const SizedBox(height: 14),
              _SectionLabel(
                text: context.messages.agentEvolutionProposalRationale,
              ),
              const SizedBox(height: 6),
              Text(
                proposal.rationale,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Reject button
                OutlinedButton(
                  onPressed: isWaiting ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: GameyColors.primaryRed),
                    foregroundColor: GameyColors.primaryRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: Text(context.messages.agentTemplateEvolveReject),
                ),
                const SizedBox(width: 12),
                // Approve button
                _ApproveButton(
                  onPressed: isWaiting ? null : onApprove,
                  label: context.messages.agentTemplateEvolveApprove,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.6),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _DirectiveBox extends StatelessWidget {
  const _DirectiveBox({
    required this.text,
    this.backgroundColor,
    this.borderColor,
  });

  final String text;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
      ),
      child: SelectableText(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 13,
          height: 1.5,
        ),
      ),
    );
  }
}

class _ApproveButton extends StatelessWidget {
  const _ApproveButton({
    required this.onPressed,
    required this.label,
  });

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: onPressed != null ? GameyGradients.success : null,
        color: onPressed == null ? Colors.grey : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
