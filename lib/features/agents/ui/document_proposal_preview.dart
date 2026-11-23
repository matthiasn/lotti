import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/markdown/agent_markdown_view.dart';
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

/// "Read draft" under a document proposal (ADR 0166): the row says only
/// which document it writes, so the text itself is one tap away, before the
/// user decides. Renders nothing for any other change, or for a proposal
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
    this.confirmLabel,
    this.rejectLabel,
    super.key,
  });

  final String toolName;
  final Map<String, dynamic> args;
  final Future<void> Function()? onConfirm;
  final Future<void> Function()? onReject;

  /// The host's words for its verdicts; the AI card's by default.
  final String? confirmLabel;
  final String? rejectLabel;

  @override
  Widget build(BuildContext context) {
    final markdown = args['markdown'];
    if (toolName != TaskAgentToolNames.proposeDocumentVersion ||
        markdown is! String ||
        markdown.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.only(top: context.designTokens.spacing.step2),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: DesignSystemButton(
          key: DocumentProposalPreviewKeys.read,
          label: context.messages.documentProposalRead,
          leadingIcon: LottiIcons.description,
          variant: DesignSystemButtonVariant.tertiary,
          size: DesignSystemButtonSize.dense,
          onPressed: () => showDocumentProposalPreview(
            context,
            args: args,
            onConfirm: onConfirm,
            onReject: onReject,
            confirmLabel: confirmLabel,
            rejectLabel: rejectLabel,
          ),
        ),
      ),
    );
  }
}

/// Opens the proposed text of a document proposal in a sheet, with the
/// host's Confirm and Reject at its foot when it passes them. A verdict
/// closes the sheet first, so the row it came from shows the outcome.
Future<void> showDocumentProposalPreview(
  BuildContext context, {
  required Map<String, dynamic> args,
  Future<void> Function()? onConfirm,
  Future<void> Function()? onReject,
  String? confirmLabel,
  String? rejectLabel,
}) {
  final messages = context.messages;
  final tokens = context.designTokens;
  return ModalUtils.showSinglePageModal<void>(
    context: context,
    title: documentProposalTitle(args) ?? messages.documentProposalRead,
    padding: EdgeInsets.all(tokens.spacing.step5),
    builder: (_) => DocumentProposalPreview(args: args),
    stickyActionBarBuilder: onConfirm == null && onReject == null
        ? null
        : (sheetContext) {
            Future<void> decide(Future<void> Function() verdict) async {
              Navigator.of(sheetContext).pop();
              await verdict();
            }

            return Padding(
              padding: EdgeInsets.all(tokens.spacing.step4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onReject != null)
                    DesignSystemButton(
                      key: DocumentProposalPreviewKeys.reject,
                      label: rejectLabel ?? messages.changeSetSwipeReject,
                      variant: DesignSystemButtonVariant.quiet,
                      onPressed: () => decide(onReject),
                    ),
                  if (onConfirm != null) ...[
                    SizedBox(width: tokens.spacing.step3),
                    DesignSystemButton(
                      key: DocumentProposalPreviewKeys.confirm,
                      label: confirmLabel ?? messages.changeSetSwipeConfirm,
                      onPressed: () => decide(onConfirm),
                    ),
                  ],
                ],
              ),
            );
          },
  );
}

/// The proposed version: whether it starts a document or replaces the text
/// one shows, the agent's one line on what it changes, then the markdown as
/// it would read once confirmed.
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
    final meta = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isNew
              ? messages.documentProposalKindNew
              : messages.documentProposalKindVersion,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        if (summary is String && summary.trim().isNotEmpty) ...[
          SizedBox(height: tokens.spacing.step2),
          Text(summary.trim(), style: meta),
        ],
        SizedBox(height: tokens.spacing.step4),
        const DesignSystemDivider(),
        SizedBox(height: tokens.spacing.step4),
        AgentMarkdownView(
          markdown is String ? markdown : '',
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
        ),
      ],
    );
  }
}
