import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/day_agent_identity.dart';
import 'package:lotti/features/agents/knowledge/agent_knowledge_providers.dart';
import 'package:lotti/features/agents/ui/knowledge/agent_knowledge_panel.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Opens the planner-knowledge panel ("What I've learned") in the standard
/// modal container — bottom sheet on phones, dialog on wide screens — so
/// proposed learnings can be confirmed from anywhere on the Day surface.
Future<void> showKnowledgePanelModal(BuildContext context) {
  return ModalUtils.showSinglePageModal<void>(
    context: context,
    builder: (_) => const AgentKnowledgePanel(agentId: dailyOsPlannerAgentId),
  );
}

/// Quiet one-line affordance on the Day page that surfaces *proposed*
/// planner knowledge — learnings the agent wants the human to confirm.
///
/// Renders nothing while there is nothing awaiting confirmation, so the
/// page stays calm by default; when proposals exist it shows a single
/// sparkle caption line ("2 things I noticed — review"), with no surface of
/// its own, that opens the
/// [AgentKnowledgePanel] modal. Confirmed-only knowledge stays reachable via
/// the header menu instead of occupying the page.
class KnowledgeNudge extends ConsumerWidget {
  const KnowledgeNudge({super.key});

  /// Stable key for presence asserts in tests.
  @visibleForTesting
  static const Key nudgeKey = ValueKey('daily-os-knowledge-nudge');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final proposedCount =
        ref
            .watch(agentKnowledgeProvider(dailyOsPlannerAgentId))
            .value
            ?.proposed
            .length ??
        0;
    if (proposedCount == 0) return const SizedBox.shrink();

    final accent = tokens.colors.aiCard.accent;
    final glyphSize = tokens.typography.size.caption;
    // A caption row, not a pill: the briefing above it is the page's one
    // violet surface, so the nudge carries only the sparkle. The InkWell
    // still spans the line at the recommended touch target, so it reads — and
    // hits — as one tappable line.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: nudgeKey,
        onTap: () => showKnowledgePanelModal(context),
        borderRadius: BorderRadius.circular(tokens.radii.s),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: TapTargets.minimum),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LottiIcons.aiSpark, size: glyphSize, color: accent),
              SizedBox(width: tokens.spacing.step2),
              Flexible(
                child: Text(
                  context.messages.dailyOsNextKnowledgeNudge(proposedCount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ),
              SizedBox(width: tokens.spacing.step1),
              Icon(
                LottiIcons.chevronRight,
                size: glyphSize,
                color: tokens.colors.text.lowEmphasis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
