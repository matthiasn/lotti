import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/proposal_row_widgets_part.dart';
import 'package:lotti/features/agents/ui/localized_change_summary.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_inline_action.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// One proposed mutation from the project agent — a status change or a task
/// it wants to create — inside the AI card's "Proposed changes" band.
///
/// A pending row carries the task agent's reject/confirm disc rail, so the
/// same gesture applies the same kind of change on a task page and a project
/// page. A decided row keeps its place with the shared resolved tag instead of
/// leaving the band, so what was just done stays legible.
class ProjectProposalRow extends StatelessWidget {
  const ProjectProposalRow({
    required this.changeSet,
    required this.itemIndex,
    required this.busy,
    required this.onConfirm,
    required this.onReject,
    this.enabled = true,
    this.canUndo = false,
    this.onUndo,
    super.key,
  });

  final ChangeSetEntity changeSet;
  final int itemIndex;

  /// The rail shows a spinner instead of its buttons while the decision is
  /// being applied.
  final bool busy;
  final Future<void> Function() onConfirm;
  final Future<void> Function() onReject;

  /// `false` keeps the rail visible but inert.
  final bool enabled;

  /// Whether a decided row still offers Undo; [onUndo] puts it back.
  final bool canUndo;
  final VoidCallback? onUndo;

  ChangeItem get item => changeSet.items[itemIndex];

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final decided = item.status != ChangeItemStatus.pending;
    final summary =
        localizedChangeSummary(context.messages, item.toolName, item.args) ??
        item.humanSummary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: decided ? ai.subtleWash : ai.row,
        borderRadius: BorderRadius.circular(tokens.radii.s),
        border: Border.all(color: ai.rowBorder),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step4,
          vertical: tokens.spacing.step2,
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
                child: Text(
                  summary,
                  style: tokens.typography.styles.body.bodyMedium.copyWith(
                    color: decided ? ai.metaText : ai.titleText,
                  ),
                ),
              ),
            ),
            SizedBox(width: tokens.spacing.step3),
            if (decided) ...[
              ResolvedTag(status: item.status),
              if (canUndo) ...[
                SizedBox(width: tokens.spacing.step3),
                IntrinsicWidth(
                  child: DesignSystemInlineAction(
                    onTap: enabled ? onUndo : null,
                    semanticsLabel: context.messages.designSystemUndoLabel,
                    label: context.messages.designSystemUndoLabel,
                    leadingIcon: LottiIcons.undo,
                  ),
                ),
              ],
            ] else
              RowActions(
                busy: busy,
                enabled: enabled,
                onReject: onReject,
                onConfirm: onConfirm,
              ),
          ],
        ),
      ),
    );
  }
}
