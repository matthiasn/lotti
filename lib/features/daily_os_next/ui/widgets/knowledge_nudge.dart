import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/state/planner_knowledge_provider.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/knowledge_panel.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Opens the planner-knowledge panel ("What I've learned") in the standard
/// modal container — bottom sheet on phones, dialog on wide screens — so
/// proposed learnings can be confirmed from anywhere on the Day surface.
Future<void> showKnowledgePanelModal(BuildContext context) {
  return ModalUtils.showSinglePageModal<void>(
    context: context,
    builder: (_) => const KnowledgePanel(),
  );
}

/// Quiet one-line affordance on the Day page that surfaces *proposed*
/// planner knowledge — learnings the agent wants the human to confirm.
///
/// Renders nothing while there is nothing awaiting confirmation, so the
/// page stays calm by default; when proposals exist it shows a single
/// sparkle line ("2 things I noticed — review") that opens the
/// [KnowledgePanel] modal. Confirmed-only knowledge stays reachable via
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
        ref.watch(plannerKnowledgeProvider).value?.proposed.length ?? 0;
    if (proposedCount == 0) return const SizedBox.shrink();

    final accent = tokens.colors.aiCard.accent;
    // A quiet chip (not a bare text line) so it reads as tappable, with
    // padding that keeps the hit target at ≥44px.
    return Material(
      color: tokens.colors.surface.enabled,
      borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
      child: InkWell(
        key: nudgeKey,
        onTap: () => showKnowledgePanelModal(context),
        borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step4,
            vertical: tokens.spacing.step4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 14, color: accent),
              SizedBox(width: tokens.spacing.step2),
              Flexible(
                child: Text(
                  context.messages.dailyOsNextKnowledgeNudge(proposedCount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ),
              SizedBox(width: tokens.spacing.step1),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: tokens.colors.text.lowEmphasis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
