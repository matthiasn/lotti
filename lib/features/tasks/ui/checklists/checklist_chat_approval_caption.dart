import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_chat_controller.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Credits a checklist item's current state to the user when a chat approval
/// still backs it, so a change applied by the agent on the user's say-so no
/// longer reads as the agent's own edit.
///
/// While task chat is enabled, tapping it opens the task's chat on the
/// conversation the approval came from.
class ChecklistChatApprovalCaption extends ConsumerWidget {
  const ChecklistChatApprovalCaption({
    required this.approval,
    required this.taskId,
    super.key,
  });

  final ChecklistItemProvenance approval;
  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final color = tokens.colors.text.lowEmphasis;
    final date = DateFormat.yMMMd(
      messages.localeName,
    ).format(approval.approvedAt.toLocal());
    // Inline icon, so a narrow row wraps the date onto a second line rather
    // than cutting it off.
    final caption = Padding(
      padding: EdgeInsets.only(top: tokens.spacing.step1),
      child: Text.rich(
        TextSpan(
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsets.only(right: tokens.spacing.step2),
                child: Icon(LottiIcons.chat, size: IconSizes.xs, color: color),
              ),
            ),
            TextSpan(text: messages.checklistItemApprovedInChat(date)),
          ],
        ),
        style: tokens.typography.styles.others.caption.copyWith(color: color),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
    if (!ref.watch(queryChatEnabledProvider)) return caption;

    void openChat() {
      final scope = QueryScope(kind: QueryScopeKind.task, id: taskId);
      ref
          .read(
            queryChatControllerProvider((
              agentId: approval.agentId,
              scope: scope,
            )).notifier,
          )
          .select(approval.conversationId);
      ref.read(queryPaneOpenProvider(scope).notifier).open = true;
    }

    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: openChat,
          child: caption,
        ),
      ),
    );
  }
}
