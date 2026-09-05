import 'package:lotti/features/agents/ui/agent_palette.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';
import 'package:material_ui/material_ui.dart';

/// Expandable card showing a recorded evolution note.
///
/// Starts collapsed (2 lines max) and expands to show the full content on tap.
class EvolutionNoteConfirmationCard extends StatefulWidget {
  const EvolutionNoteConfirmationCard({
    required this.kind,
    required this.content,
    super.key,
  });

  final String kind;
  final String content;

  @override
  State<EvolutionNoteConfirmationCard> createState() =>
      _EvolutionNoteConfirmationCardState();
}

class _EvolutionNoteConfirmationCardState
    extends State<EvolutionNoteConfirmationCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: ModernBaseCard(
          gradient: agentCardDarkGradient(AgentPalette.cyan),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _noteKindIcon(widget.kind),
                size: 18,
                color: AgentPalette.cyan,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.messages.agentEvolutionNoteRecorded,
                            style: const TextStyle(
                              color: AgentPalette.cyan,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          _expanded
                              ? LottiIcons.chevronDown
                              : LottiIcons.chevronRight,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 200),
                      crossFadeState: _expanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: Text(
                        widget.content,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      secondChild: Text(
                        widget.content,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _noteKindIcon(String kind) {
  return switch (kind) {
    'reflection' => LottiIcons.reasoning,
    'hypothesis' => LottiIcons.tip,
    'decision' => LottiIcons.legal,
    'pattern' => LottiIcons.pattern,
    _ => LottiIcons.note,
  };
}
