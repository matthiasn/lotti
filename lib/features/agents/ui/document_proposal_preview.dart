import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/proposal_row_widgets_part.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_inline_action.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/markdown/agent_markdown_view.dart';
import 'package:lotti/widgets/markdown/markdown_title.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for the document proposal preview.
abstract final class DocumentProposalPreviewKeys {
  static const read = Key('document-proposal-read');
  static const confirm = Key('document-proposal-confirm');
  static const reject = Key('document-proposal-reject');
}

/// The title a `propose_document_version` names: a new document's title, or
/// the title of the document it revises. Null when it carries neither.
String? documentProposalTitle(Map<String, dynamic> args) {
  for (final key in const ['newTitle', 'title']) {
    if (args[key] case final String title when title.trim().isNotEmpty) {
      return title.trim();
    }
  }
  return null;
}

/// "Read draft" under a document proposal (ADR 0167): the row says only
/// which document it writes, and a draft is confirmed only after reading
/// it, in the sheet this opens — the row itself offers no confirm. Renders nothing for any other change, or for a proposal
/// without text.
///
/// [onConfirm] and [onReject] are the host's own verdicts for the row; with
/// them the sheet decides in place, without them it only reads — a decided
/// proposal, or one the host cannot act on.
class DocumentProposalReadButton extends StatelessWidget {
  const DocumentProposalReadButton({
    required this.toolName,
    required this.args,
    this.onConfirm,
    this.onReject,
    this.onRead,
    this.inRow = false,
    super.key,
  });

  /// Set inside a row of buttons: no gap above, and it hugs its label.
  final bool inRow;

  /// Opens the draft somewhere other than the reading sheet — the
  /// side-by-side review, where the host can reach it. Null opens the sheet.
  final VoidCallback? onRead;

  final String toolName;
  final Map<String, dynamic> args;
  final Future<void> Function()? onConfirm;
  final Future<void> Function()? onReject;

  @override
  Widget build(BuildContext context) {
    final markdown = args['markdown'];
    if (toolName != TaskAgentToolNames.proposeDocumentVersion ||
        markdown is! String ||
        markdown.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final label = context.messages.documentProposalRead;
    final onRead = this.onRead;
    void open() {
      if (onRead != null) {
        onRead();
        return;
      }
      showDocumentProposalPreview(
        context,
        args: args,
        onConfirm: onConfirm,
        onReject: onReject,
      );
    }

    final tokens = context.designTokens;
    // While the draft can be decided, reading it is the way to confirm it,
    // so it is the row's button. Once decided, it is only a way to look.
    if (onConfirm != null) {
      final button = DesignSystemButton(
        key: DocumentProposalPreviewKeys.read,
        label: label,
        leadingIcon: LottiIcons.description,
        variant: DesignSystemButtonVariant.constructiveOutlined,
        onPressed: open,
      );
      if (inRow) return button;
      return Padding(
        padding: EdgeInsets.only(top: tokens.spacing.step2),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: button,
        ),
      );
    }
    // An inline action, so its glyph sits on the row's text edge.
    if (inRow) {
      return IntrinsicWidth(
        child: DesignSystemInlineAction(
          key: DocumentProposalPreviewKeys.read,
          label: label,
          semanticsLabel: label,
          leadingIcon: LottiIcons.description,
          ink: tokens.colors.interactive.enabled,
          onTap: open,
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.step1),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: DesignSystemInlineAction(
          key: DocumentProposalPreviewKeys.read,
          label: label,
          semanticsLabel: label,
          leadingIcon: LottiIcons.description,
          ink: tokens.colors.interactive.enabled,
          onTap: open,
        ),
      ),
    );
  }
}

/// Opens the proposed text of a document proposal in a sheet, with the
/// verdicts on its glass footer when the host passes them: Dismiss, and a
/// primary that names what confirming does — create the document, or make
/// this its new version. A verdict closes the sheet first, so the row it
/// came from shows the outcome.
Future<void> showDocumentProposalPreview(
  BuildContext context, {
  required Map<String, dynamic> args,
  Future<void> Function()? onConfirm,
  Future<void> Function()? onReject,
}) {
  final messages = context.messages;
  final tokens = context.designTokens;
  final decides = onConfirm != null || onReject != null;
  final isNew = args['newTitle'] is String;
  return ModalUtils.showSinglePageModal<void>(
    context: context,
    title: documentProposalTitle(args) ?? messages.documentProposalRead,
    // The text scrolls behind the glass footer, so its last line keeps
    // clear of the footer's height.
    padding: EdgeInsets.fromLTRB(
      tokens.spacing.step5,
      tokens.spacing.step5,
      tokens.spacing.step5,
      tokens.spacing.step5 +
          (decides ? WoltModalConfig.stickyActionBarClearance : 0),
    ),
    builder: (_) => DocumentProposalPreview(args: args),
    stickyActionBarBuilder: !decides
        ? null
        : (sheetContext) {
            Future<void> decide(Future<void> Function() verdict) async {
              Navigator.of(sheetContext).pop();
              await verdict();
            }

            return DesignSystemModalActionBar(
              glass: true,
              layout: DesignSystemModalActionBarLayout.compactPrimary,
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step5,
                vertical: tokens.spacing.step4,
              ),
              secondary: [
                if (onReject != null)
                  DesignSystemButton(
                    key: DocumentProposalPreviewKeys.reject,
                    // Not "Dismiss": closing the sheet keeps the draft; this
                    // throws it away.
                    label: messages.documentProposalDiscard,
                    variant: DesignSystemButtonVariant.quiet,
                    size: DesignSystemButtonSize.large,
                    onPressed: () => decide(onReject),
                  ),
              ],
              primary: DesignSystemButton(
                key: DocumentProposalPreviewKeys.confirm,
                label: isNew
                    ? messages.documentProposalConfirmNew
                    : messages.documentProposalConfirmVersion,
                size: DesignSystemButtonSize.large,
                onPressed: onConfirm == null ? null : () => decide(onConfirm),
              ),
            );
          },
  );
}

/// The proposed version: whether it starts a document or replaces the text
/// one shows — in the agent's voice, since the agent wrote it — the agent's
/// line on what it changes, then the markdown as it would read once
/// confirmed, without a leading heading that only repeats the sheet's title.
class DocumentProposalPreview extends StatelessWidget {
  const DocumentProposalPreview({required this.args, super.key});

  final Map<String, dynamic> args;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final isNew = args['newTitle'] is String;
    final summary = args['changeSummary'];
    final markdown = args['markdown'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isNew
              ? messages.documentProposalKindNew
              : messages.documentProposalKindVersion,
          // Caption tier: the sheet's title leads, this says whose it is.
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.aiCard.accent,
            fontWeight: tokens.typography.weight.semiBold,
          ),
        ),
        if (summary is String && summary.trim().isNotEmpty) ...[
          SizedBox(height: tokens.spacing.step1),
          Text(
            summary.trim(),
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
        // Space, not a rule: a draft opening with its own heading would sit
        // between two hairlines.
        SizedBox(height: tokens.spacing.step5),
        AgentMarkdownView(
          withoutRepeatedTitle(
            markdown is String ? markdown : '',
            documentProposalTitle(args),
          ),
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
        ),
      ],
    );
  }
}

/// The second line of a pending document draft's row in the AI card: the
/// agent's line on what the draft changes, then Read draft with the ✕
/// across from it, in the reject column every other row's ✕ uses. The
/// title above takes the row's full width; a draft has no ✓ of its own.
class DocumentDraftRowActions extends StatelessWidget {
  const DocumentDraftRowActions({
    required this.args,
    required this.busy,
    required this.resolving,
    required this.onConfirm,
    required this.onReject,
    this.onRead,
    super.key,
  });

  final Map<String, dynamic> args;

  /// Where Read draft goes instead of the sheet; see
  /// [DocumentProposalReadButton.onRead].
  final VoidCallback? onRead;

  /// A verdict is being written: the rail shows its spinner.
  final bool busy;

  /// The row's resolve beat is playing: the rail keeps its width, empty, so
  /// the badge over it is the only indicator.
  final bool resolving;
  final Future<void> Function() onConfirm;
  final Future<void> Function() onReject;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final summary = args['changeSummary'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summary is String && summary.trim().isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: tokens.spacing.step1),
            child: Text(
              summary.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.aiCard.metaText,
              ),
            ),
          ),
        SizedBox(height: tokens.spacing.step2),
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: DocumentProposalReadButton(
                  toolName: TaskAgentToolNames.proposeDocumentVersion,
                  args: args,
                  inRow: true,
                  onConfirm: onConfirm,
                  onReject: onReject,
                  onRead: onRead,
                ),
              ),
            ),
            SizedBox(width: tokens.spacing.step2),
            if (resolving)
              SizedBox(
                width: RowActions.footprintWidth(context),
                height: RowActions.buttonSize,
              )
            else
              RowActions(
                busy: busy,
                onReject: onReject,
                rejectLabel: context.messages.documentProposalDiscard,
              ),
          ],
        ),
      ],
    );
  }
}
