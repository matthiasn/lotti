import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/agents/time_entry_datetime.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/ui/localized_change_summary.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// A chat-owned proposal stays inert until the user accepts the displayed set.
/// Completed items remain visible and are never repeated when retrying a set.
class QueryActionReview extends ConsumerStatefulWidget {
  const QueryActionReview({
    required this.chatKey,
    required this.chatId,
    required this.answer,
    this.approved,
    this.access,
    this.canApply = true,
    super.key,
  });

  final QueryChatKey chatKey;
  final String chatId;
  final QueryChatAnswer answer;
  final bool? approved;
  final QueryAccessSnapshot? access;
  final bool canApply;

  @override
  ConsumerState<QueryActionReview> createState() => _QueryActionReviewState();
}

class _QueryActionReviewState extends ConsumerState<QueryActionReview> {
  bool _busy = false;
  bool _failed = false;
  bool? _decision;

  Future<void> _resolve(bool approved) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final results = await ref
          .read(queryChatActionServiceProvider)
          .resolve(
            agentId: widget.chatKey.agentId,
            chatId: widget.chatId,
            questionId: widget.answer.questionId,
            approved: approved,
          );
      if (!mounted) return;
      setState(() {
        _decision = approved;
        _failed = results.any((r) => !r.success);
      });
      ref.invalidate(
        queryActionChangeSetProvider((
          agentId: widget.chatKey.agentId,
          questionId: widget.answer.questionId,
        )),
      );
    } catch (_) {
      // Provider/handler errors may contain source text: show only app copy.
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Rebuild from executable values and live target names, never a model's
  /// description of an ID-only change. Dates are explicit, including overnight
  /// sessions; follow-up task options and simultaneous checklist edits stay visible.
  List<String> _descriptions(BuildContext context, ChangeItem item) {
    final messages = context.messages;
    final args = item.args;
    final target = widget.access?.entries[args['targetTaskId']];
    final checklist = widget.access?.entries[args['id']];
    final display = <String, dynamic>{
      ...args,
      if (target is Task) 'targetTitle': target.data.title,
      if (checklist is ChecklistItem && !args.containsKey('title'))
        'title': checklist.data.title,
    };
    final lines = <String>[
      localizedChangeSummary(messages, item.toolName, display) ??
          item.humanSummary,
    ];
    if (item.toolName == TaskAgentToolNames.updateChecklistItem) {
      final title = display['title'];
      if (title is String) {
        lines.clear();
        if (args.containsKey('title')) {
          lines.add(messages.agentSummaryUpdateItem(title));
        }
        if (args['isChecked'] case final bool checked) {
          lines.add(
            checked
                ? messages.agentSummaryCheckItem(title)
                : messages.agentSummaryUncheckItem(title),
          );
        }
        if (args['isArchived'] case final bool archived) {
          lines.add(
            archived
                ? messages.agentSummaryArchiveItem(title)
                : messages.agentSummaryRestoreItem(title),
          );
        }
      }
    }
    final timeTarget = widget.access?.entries[args['entryId']];
    if (item.toolName == TaskAgentToolNames.updateTimeEntry &&
        timeTarget is JournalEntry) {
      final format = DateFormat.yMMMd(messages.localeName).add_Hm();
      lines.insert(
        0,
        messages.queryActionsTarget(
          messages.agentSummaryTimeRangeBetween(
            format.format(timeTarget.meta.dateFrom),
            format.format(timeTarget.meta.dateTo),
          ),
        ),
      );
    }
    final dates = <String>[];
    for (final key in ['startTime', 'endTime']) {
      if (args[key] case final String raw) {
        final date = parseTimeEntryLocalDateTime(raw);
        if (date != null) {
          dates.add(DateFormat.yMMMd(messages.localeName).format(date));
        }
      }
    }
    if (dates.isNotEmpty) lines.add(dates.toSet().join(' – '));
    if (item.toolName == TaskAgentToolNames.createFollowUpTask) {
      if (args['description'] case final String description) {
        lines.add(description);
      }
      for (final (key, tool) in [
        ('dueDate', TaskAgentToolNames.updateTaskDueDate),
        ('priority', TaskAgentToolNames.updateTaskPriority),
      ]) {
        if (args.containsKey(key)) {
          lines.add(localizedChangeSummary(messages, tool, args)!);
        }
      }
    }
    if (item.toolName == TaskAgentToolNames.migrateChecklistItem &&
        target is Task) {
      lines.add(messages.queryActionsTarget(target.data.title));
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final decision = widget.approved ?? _decision;
    final saved = decision == true
        ? ref.watch(
            queryActionChangeSetProvider((
              agentId: widget.chatKey.agentId,
              questionId: widget.answer.questionId,
            )),
          )
        : null;
    final items = saved?.value?.items ?? widget.answer.proposedActions;
    final completed =
        decision == true &&
        saved?.value != null &&
        items.every((item) => item.status != ChangeItemStatus.pending);
    final loading =
        decision == true && saved?.value == null && saved?.hasError != true;
    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.step3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Padding(
              padding: EdgeInsets.only(top: tokens.spacing.step3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    _descriptions(context, item).join('\n'),
                    style: tokens.typography.styles.body.bodySmall,
                  ),
                  if (!_busy && item.status != ChangeItemStatus.pending)
                    Text(
                      item.status == ChangeItemStatus.confirmed
                          ? messages.changeSetItemConfirmed
                          : messages.changeSetItemRejected,
                      style: tokens.typography.styles.others.caption,
                    ),
                ],
              ),
            ),
          SizedBox(height: tokens.spacing.step3),
          if (decision == false)
            Text(
              messages.aiCardProposalDismissed,
              style: tokens.typography.styles.others.caption,
            )
          else if (!completed) ...[
            if (_failed || saved?.hasError == true)
              Padding(
                padding: EdgeInsets.only(bottom: tokens.spacing.step2),
                child: Text(
                  messages.queryActionsIncomplete,
                  style: tokens.typography.styles.others.caption,
                ),
              ),
            Wrap(
              spacing: tokens.spacing.step2,
              runSpacing: tokens.spacing.step2,
              children: [
                DesignSystemButton(
                  label: decision == true
                      ? messages.projectNextStepRetry
                      : messages.queryActionsAccept,
                  isLoading: _busy || loading,
                  onPressed: widget.canApply ? () => _resolve(true) : null,
                ),
                if (decision == null)
                  DesignSystemButton(
                    label: messages.queryActionsDismiss,
                    variant: DesignSystemButtonVariant.tertiary,
                    onPressed: _busy || !widget.canApply
                        ? null
                        : () => _resolve(false),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
