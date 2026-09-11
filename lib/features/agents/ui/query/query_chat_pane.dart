import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_chat_controller.dart';
import 'package:lotti/features/agents/query/query_chat_projection.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/ui/chat/agent_chat_view.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_controller.dart';
import 'package:lotti/features/agents/ui/query/query_evidence_card.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_button.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/popovers/design_system_popover_anchor.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/ui/pages/entry_details_page.dart';
import 'package:lotti/features/lockdown/state/lockdown_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// The same pane is a desktop detail replacement and a mobile full page.
/// Opening evidence stays inside it, preserving the chat's draft and scroll.
class QueryChatPane extends ConsumerStatefulWidget {
  const QueryChatPane({required this.scope, required this.onClose, super.key});
  final QueryScope scope;
  final VoidCallback onClose;
  @override
  ConsumerState<QueryChatPane> createState() => _QueryChatPaneState();
}

class _QueryChatPaneState extends ConsumerState<QueryChatPane> {
  final _storage = PageStorageBucket();
  String? _sourceId;
  String? _readThrough;
  String? _dictatedChat;
  bool _creating = false;
  bool _showArchived = false;
  bool _menuOpen = false;
  VoidCallback? _toggleMenu;

  void _closeMenu() {
    if (_menuOpen) _toggleMenu?.call();
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.commonError,
        );
      }
    }
  }

  Future<void> _leave() async {
    await ref.read(chatRecorderControllerProvider.notifier).cancel();
    if (!mounted) return;
    if (_sourceId != null) {
      setState(() => _sourceId = null);
    } else {
      widget.onClose();
    }
  }

  Future<void> _select(QueryChatController controller, String id) async {
    _closeMenu();
    await ref.read(chatRecorderControllerProvider.notifier).cancel();
    if (mounted) {
      controller.select(id);
      setState(() => _sourceId = null);
    }
  }

  Future<void> _newChat(QueryChatController controller) async {
    if (_creating) return;
    _closeMenu();
    final title = context.messages.queryNewChat;
    setState(() => _creating = true);
    try {
      await ref.read(chatRecorderControllerProvider.notifier).cancel();
      await controller.create(title);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _send(
    QueryChatController controller,
    QueryChatHistory? chat,
    QueryChatLocal local,
  ) async {
    if (_creating) return;
    setState(() => _dictatedChat = null);
    var id = chat?.id;
    if (id == null) {
      setState(() => _creating = true);
      try {
        final text = local.draft.trim();
        if (text.isEmpty) return;
        id = await controller.create(
          text.length > 80 ? text.substring(0, 80) : text,
          private: local.draftPrivate,
        );
        controller
          ..updateDraft(id, local.draft, private: local.draftPrivate)
          ..narrow(id, homeOnly: local.homeOnly, kind: local.kind)
          ..updateDraft('new', '');
      } finally {
        if (mounted) setState(() => _creating = false);
      }
    }
    await controller.send(id);
  }

  Future<void> _rename(
    QueryChatController controller,
    QueryChatHistory chat,
  ) async {
    _closeMenu();
    final authoredPrivate =
        chat.private || ref.read(configFlagProvider('private')).value == true;
    final result = await ModalUtils.showSinglePageModal<String>(
      context: context,
      builder: (context) => _QueryRenameDialog(
        controller: controller,
        chat: chat,
        private: authoredPrivate,
      ),
    );
    if (result != null) {
      await controller.rename(chat.id, result, private: authoredPrivate);
    }
  }

  Future<void> _delete(
    QueryChatController controller,
    QueryChatHistory chat,
  ) async {
    _closeMenu();
    var forget = false;
    final result = await ModalUtils.showSinglePageModal<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final messages = context.messages;
          final tokens = context.designTokens;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                messages.queryDeleteChat,
                style: tokens.typography.styles.heading.heading3,
              ),
              SizedBox(height: tokens.spacing.step3),
              Text(
                messages.queryDeleteExplanation,
                style: tokens.typography.styles.body.bodyMedium,
              ),
              SizedBox(height: tokens.spacing.step4),
              for (final value in [false, true])
                DesignSystemSelectionRow(
                  title: value
                      ? messages.queryForgetConclusions
                      : messages.queryKeepConclusions,
                  type: DesignSystemSelectionRowType.singleSelect,
                  selected: forget == value,
                  onTap: () => setModalState(() => forget = value),
                ),
              SizedBox(height: tokens.spacing.step5),
              DesignSystemModalActionBar(
                primary: DesignSystemButton(
                  label: messages.queryDeleteChat,
                  fullWidth: true,
                  variant: DesignSystemButtonVariant.danger,
                  onPressed: () => Navigator.of(context).pop(forget),
                ),
                secondary: [
                  DesignSystemButton(
                    label: messages.cancelButton,
                    variant: DesignSystemButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    if (result != null) await controller.delete(chat.id, forget: result);
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen(configFlagProvider('private'), (previous, next) {
        if (previous?.hasValue == true && previous?.value != next.value) {
          ref.invalidate(queryChatTargetProvider(widget.scope));
        }
        if (previous?.value == true && next.value != true) {
          unawaited(ref.read(chatRecorderControllerProvider.notifier).cancel());
        }
      })
      ..listen(lockdownControllerProvider, (_, _) {
        unawaited(ref.read(chatRecorderControllerProvider.notifier).cancel());
      });
    final targetAsync = ref.watch(queryChatTargetProvider(widget.scope));
    final target = targetAsync.value;
    final messages = context.messages;
    if (target == null) {
      return _shell(
        context,
        targetAsync.hasError ? messages.queryUnavailable : null,
      );
    }
    final agent = target.agent;
    if (agent == null) return _shell(context, messages.queryNoAgent);
    final key = (agentId: agent.id, scope: widget.scope);
    final dataAsync = ref.watch(queryChatDataProvider(key));
    final data = dataAsync.value;
    final session = ref.watch(queryChatControllerProvider(key));
    final controller = ref.read(queryChatControllerProvider(key).notifier);
    final showPrivate = ref.watch(configFlagProvider('private')).value ?? false;
    final lockdown = ref.watch(lockdownControllerProvider);
    if (data == null) {
      return _shell(
        context,
        dataAsync.hasError ? messages.goalChatHistoryError : null,
      );
    }
    // The synchronous privacy/lockdown settings dominate a snapshot fetched
    // before a visibility toggle. No saved title, preview or quote bypasses it.
    final access = QueryAccessSnapshot(
      showPrivate: showPrivate,
      categories: data.access.categories,
      entries: data.access.entries,
      lockdown: lockdown,
    );
    final home = access.entries[widget.scope.id];
    if (widget.scope.kind == QueryScopeKind.category
        ? !access.allowsCategory(widget.scope.id)
        : home == null || !access.allowsEntry(home)) {
      return _shell(context, messages.queryUnavailable);
    }
    final visible = data.projection.chats
        .where(
          (c) =>
              c.scope == widget.scope &&
              (!c.private || showPrivate) &&
              c.events.every((e) => access.allowsEvent(e.data)),
        )
        .toList();
    final chat =
        visible.where((c) => c.id == session.selectedId).firstOrNull ??
        visible.where((c) => !c.archived).firstOrNull;
    final id = chat?.id ?? 'new';
    ref.listen(chatRecorderControllerProvider.select((s) => s.transcript), (
      _,
      transcript,
    ) {
      if (transcript?.trim().isNotEmpty == true) {
        setState(() => _dictatedChat = id);
      }
    });
    final local = session.local(id);
    final draft = !local.draftPrivate || showPrivate ? local.draft : '';
    final categoryId = widget.scope.kind == QueryScopeKind.category
        ? widget.scope.id
        : home!.meta.categoryId;
    final categoryName = access.categories[categoryId]?.name;
    final label = switch (home) {
      Task(:final data) => data.title,
      ProjectEntry(:final data) => data.title,
      _ => access.categories[widget.scope.id]?.name ?? target.label,
    };
    final reach = widget.scope.kind == QueryScopeKind.category
        ? messages.queryReachCategoryOnly(categoryName ?? label)
        : categoryName == null
        ? messages.queryReachUncategorized
        : messages.queryReachCategory(categoryName);
    final tokens = context.designTokens;
    final lastQuestion = chat?.questions.lastOrNull;
    final running = local.status == QueryTurnStatus.running;
    final pending =
        lastQuestion != null &&
        chat!.answerFor(lastQuestion.id) == null &&
        !running;
    final lastAnswer = chat?.events
        .where((e) => e.data is QueryChatAnswer)
        .lastOrNull;
    if (chat != null &&
        chat.unread &&
        lastAnswer != null &&
        _readThrough != lastAnswer.id &&
        _sourceId == null) {
      _readThrough = lastAnswer.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_guard(() => controller.markRead(chat.id, lastAnswer.id)));
        }
      });
    }
    final history = <AgentChatMessage>[
      for (final event in chat?.events ?? const <AgentQueryChatEventEntity>[])
        if (event.data case QueryChatQuestion(:final text))
          AgentChatMessage(
            id: event.id,
            role: AgentChatRole.user,
            text: text,
            createdAt: event.createdAt,
          )
        else if (event.data case QueryChatAnswer(:final text))
          AgentChatMessage(
            id: event.id,
            role: AgentChatRole.agent,
            // GPT Markdown treats bare [n] as a web citation. These numbers
            // refer to our evidence cards, so keep them as ordinary text.
            text: text.replaceAllMapped(
              RegExp(r'\[(\d+)\]'),
              (match) => '(${match[1]})',
            ),
            createdAt: event.createdAt,
          ),
    ];
    final memories = data.projection.memories
        .where((e) => access.allowsEvent(e.data))
        .length;
    final source = access.entries[_sourceId];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step3,
                  vertical: tokens.spacing.step2,
                ),
                child: Row(
                  children: [
                    DesignSystemIconAction(
                      icon: LottiIcons.back,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      onPressed: _leave,
                    ),
                    SizedBox(width: tokens.spacing.step2),
                    Icon(
                      LottiIcons.aiSpark,
                      color: tokens.colors.aiCard.accent,
                      size: IconSizes.m,
                    ),
                    SizedBox(width: tokens.spacing.step3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            agent.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tokens.typography.styles.subtitle.subtitle2,
                          ),
                          Text(
                            switch (widget.scope.kind) {
                              QueryScopeKind.task =>
                                messages.agentTemplateKindTaskAgent,
                              QueryScopeKind.project =>
                                messages.agentTemplateKindProjectAgent,
                              QueryScopeKind.category =>
                                messages.queryCategoryAgent,
                            },
                            style: tokens.typography.styles.others.caption,
                          ),
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tokens.typography.styles.others.caption
                                .copyWith(color: tokens.colors.aiCard.accent),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: _switcher(
                        context,
                        controller,
                        visible,
                        session,
                        chat,
                      ),
                    ),
                  ],
                ),
              ),
              if (_sourceId == null) ...[
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacing.step5,
                    vertical: tokens.spacing.step2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reach,
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: tokens.colors.text.mediumEmphasis,
                        ),
                      ),
                      SizedBox(height: tokens.spacing.step2),
                      Wrap(
                        spacing: tokens.spacing.step2,
                        runSpacing: tokens.spacing.step2,
                        children: [
                          if (categoryId != null &&
                              widget.scope.kind != QueryScopeKind.category)
                            DesignSystemChip(
                              label: messages.queryHomeOnly,
                              selected: local.homeOnly,
                              onPressed: running
                                  ? null
                                  : () => controller.narrow(
                                      id,
                                      homeOnly: !local.homeOnly,
                                    ),
                            ),
                          for (final kind in [
                            QuerySourceKind.text,
                            QuerySourceKind.recording,
                          ])
                            DesignSystemChip(
                              label: kind == QuerySourceKind.text
                                  ? messages.queryNotes
                                  : messages.queryRecordings,
                              selected: local.kind == kind,
                              onPressed: running
                                  ? null
                                  : () => controller.narrow(
                                      id,
                                      kind: kind,
                                      clearKind: local.kind == kind,
                                    ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 0),
                Expanded(
                  child: PageStorage(
                    bucket: _storage,
                    child: AgentChatView(
                      key: ValueKey(id),
                      agentId: agent.id,
                      agentName: agent.displayName,
                      conversationId: id,
                      history: AsyncData(history),
                      draft: draft,
                      isSending: running,
                      onDraftChanged: (text) =>
                          controller.updateDraft(id, text),
                      onSend: () => unawaited(
                        _guard(() => _send(controller, chat, local)),
                      ),
                      onRetry: () {},
                      scrollOnReplies: false,
                      composerEnabled: chat?.archived != true && !_creating,
                      emptyState: _empty(context, controller, id, memories),
                      activity: Padding(
                        padding: EdgeInsets.all(tokens.spacing.step3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              local.expanded
                                  ? messages.queryExpanding
                                  : messages.querySearching,
                              style: tokens.typography.styles.body.bodySmall,
                            ),
                            Text(
                              messages.queryChecked(local.checked),
                              style: tokens.typography.styles.others.caption,
                            ),
                            DesignSystemButton(
                              label: messages.cancelButton,
                              onPressed: () => controller.cancel(id),
                              variant: DesignSystemButtonVariant.tertiary,
                            ),
                          ],
                        ),
                      ),
                      footer: _footer(
                        context,
                        controller,
                        chat,
                        local,
                        pending ? lastQuestion.id : null,
                      ),
                      attachmentBuilder: (context, message) {
                        final row = chat?.events
                            .where((e) => e.id == message.id)
                            .firstOrNull;
                        if (row?.data case final QueryChatAnswer answer) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (answer.recalledMemoryIds.isNotEmpty)
                                Text(
                                  messages.queryRecall,
                                  style:
                                      tokens.typography.styles.others.caption,
                                ),
                              for (final (index, evidence)
                                  in answer.evidence.indexed)
                                QueryEvidenceCard(
                                  key: PageStorageKey('${message.id}:$index'),
                                  evidence: evidence,
                                  number: index + 1,
                                  access: access,
                                  onOpen: (sourceId) =>
                                      setState(() => _sourceId = sourceId),
                                ),
                              ExpansionTile(
                                key: PageStorageKey('${message.id}:coverage'),
                                title: Text(
                                  messages.queryCoverage,
                                  style:
                                      tokens.typography.styles.others.caption,
                                ),
                                childrenPadding: EdgeInsets.all(
                                  tokens.spacing.step3,
                                ),
                                children: [
                                  Text(
                                    messages.queryChecked(
                                      answer.coverage.checked,
                                    ),
                                    style:
                                        tokens.typography.styles.body.bodySmall,
                                  ),
                                  if (answer.coverage.incomplete)
                                    Text(
                                      messages.queryIncomplete,
                                      style: tokens
                                          .typography
                                          .styles
                                          .body
                                          .bodySmall,
                                    ),
                                  if (answer.coverage.missingTranscripts > 0)
                                    Text(
                                      messages.queryMissingTranscripts(
                                        answer.coverage.missingTranscripts,
                                      ),
                                      style: tokens
                                          .typography
                                          .styles
                                          .body
                                          .bodySmall,
                                    ),
                                ],
                              ),
                            ],
                          );
                        }
                        return null;
                      },
                    ),
                  ),
                ),
              ] else
                Expanded(
                  child: source != null && access.allowsEntry(source)
                      ? EntryDetailsPage(
                          itemId: source.meta.id,
                          showBackButton: false,
                        )
                      : Center(
                          child: Text(
                            messages.queryUnavailable,
                            style: tokens.typography.styles.body.bodyMedium,
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shell(BuildContext context, String? message) => Scaffold(
    appBar: AppBar(
      leading: DesignSystemIconAction(
        icon: LottiIcons.back,
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: widget.onClose,
      ),
    ),
    body: Center(
      child: message == null
          ? const CircularProgressIndicator()
          : Padding(
              padding: EdgeInsets.all(context.designTokens.spacing.step5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    style:
                        context.designTokens.typography.styles.body.bodyMedium,
                  ),
                  DesignSystemButton(
                    label: context.messages.aiInferenceErrorRetryButton,
                    variant: DesignSystemButtonVariant.tertiary,
                    onPressed: () {
                      final agentId = ref
                          .read(queryChatTargetProvider(widget.scope))
                          .value
                          ?.agent
                          ?.id;
                      ref.invalidate(queryChatTargetProvider(widget.scope));
                      if (agentId != null) {
                        ref.invalidate(
                          queryChatDataProvider((
                            agentId: agentId,
                            scope: widget.scope,
                          )),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
    ),
  );

  Widget _empty(
    BuildContext context,
    QueryChatController controller,
    String id,
    int memories,
  ) {
    final messages = context.messages;
    final tokens = context.designTokens;
    return SingleChildScrollView(
      primary: false,
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              messages.queryEmptyTitle,
              style: tokens.typography.styles.heading.heading3,
            ),
            SizedBox(height: tokens.spacing.step3),
            Text(
              messages.queryEmptyBody,
              style: tokens.typography.styles.body.bodyMedium,
            ),
            if (memories > 0)
              Padding(
                padding: EdgeInsets.only(top: tokens.spacing.step3),
                child: Text(
                  messages.queryMemoryCount(memories),
                  style: tokens.typography.styles.others.caption,
                ),
              ),
            SizedBox(height: tokens.spacing.step5),
            for (final example in [
              messages.queryExampleMeeting,
              messages.queryExampleDecision,
            ])
              DesignSystemListItem(
                title: example,
                titleMaxLines: null,
                leading: const Icon(LottiIcons.search, size: IconSizes.s),
                onTap: () => controller.updateDraft(id, example),
              ),
          ],
        ),
      ),
    );
  }

  Widget? _footer(
    BuildContext context,
    QueryChatController controller,
    QueryChatHistory? chat,
    QueryChatLocal local,
    String? retryId,
  ) {
    final messages = context.messages;
    final recorderStatus = ref.watch(
      chatRecorderControllerProvider.select((s) => s.status),
    );
    final text = chat?.archived == true
        ? messages.queryArchivedReadOnly
        : switch (local.status) {
            QueryTurnStatus.unavailable => messages.queryInferenceUnavailable,
            QueryTurnStatus.hidden => messages.queryUnavailable,
            QueryTurnStatus.failed => messages.queryFailed,
            QueryTurnStatus.cancelled => messages.aiAttributionStatusCancelled,
            _ =>
              recorderStatus == ChatRecorderStatus.processing
                  ? messages.queryTranscribing
                  : _dictatedChat == (chat?.id ?? 'new') &&
                        local.draft.isNotEmpty
                  ? messages.queryDictated
                  : null,
          };
    if (text == null && retryId == null) return null;
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step5,
        vertical: tokens.spacing.step2,
      ),
      child: Column(
        children: [
          if (text != null)
            Text(text, style: tokens.typography.styles.others.caption),
          if (chat != null && chat.archived)
            DesignSystemButton(
              label: messages.queryRestoreChat,
              onPressed: () => unawaited(
                _guard(() => controller.archive(chat.id, archived: false)),
              ),
              variant: DesignSystemButtonVariant.tertiary,
            )
          else if (retryId != null)
            DesignSystemButton(
              label: messages.aiInferenceErrorRetryButton,
              onPressed: () => unawaited(
                controller.send(chat!.id, retryQuestionId: retryId),
              ),
              variant: DesignSystemButtonVariant.tertiary,
            ),
        ],
      ),
    );
  }

  Widget _switcher(
    BuildContext context,
    QueryChatController controller,
    List<QueryChatHistory> chats,
    QueryChatSession session,
    QueryChatHistory? selected,
  ) {
    final messages = context.messages;
    final anyRunning = chats.any(
      (c) =>
          c.id != selected?.id &&
          session.local(c.id).status == QueryTurnStatus.running,
    );
    final anyUnread = chats.any((c) => c.id != selected?.id && c.unread);
    return DesignSystemPopoverAnchor(
      semanticsLabel: messages.queryChats,
      builder: (context, {required toggle, required isOpen}) {
        _toggleMenu = toggle;
        _menuOpen = isOpen;
        return DesignSystemButton(
          label: selected?.title ?? messages.queryChats,
          semanticsLabel: messages.queryChats,
          leadingIcon: anyRunning
              ? LottiIcons.sync
              : anyUnread
              ? LottiIcons.chat
              : null,
          trailingIcon: LottiIcons.chevronDown,
          onPressed: toggle,
          variant: DesignSystemButtonVariant.outlined,
        );
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height / 2,
        ),
        child: SingleChildScrollView(
          primary: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DesignSystemListItem(
                title: messages.queryNewChat,
                leading: const Icon(LottiIcons.add, size: IconSizes.s),
                onTap: _creating
                    ? null
                    : () => unawaited(_guard(() => _newChat(controller))),
              ),
              for (final chat in chats.where((c) => !c.archived))
                _chatRow(
                  context,
                  controller,
                  chat,
                  session.local(chat.id),
                  selected?.id,
                ),
              DesignSystemListItem(
                title: messages.queryArchivedChats,
                leading: const Icon(LottiIcons.archive, size: IconSizes.s),
                trailing: Icon(
                  _showArchived ? LottiIcons.collapse : LottiIcons.expand,
                  size: IconSizes.s,
                ),
                onTap: () => setState(() => _showArchived = !_showArchived),
              ),
              if (_showArchived)
                for (final chat in chats.where((c) => c.archived))
                  _chatRow(
                    context,
                    controller,
                    chat,
                    session.local(chat.id),
                    selected?.id,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chatRow(
    BuildContext context,
    QueryChatController controller,
    QueryChatHistory chat,
    QueryChatLocal local,
    String? selectedId,
  ) {
    final messages = context.messages;
    final status = local.status == QueryTurnStatus.running
        ? messages.querySearching
        : chat.unread
        ? messages.queryUnread
        : local.status == QueryTurnStatus.failed
        ? messages.queryFailed
        : DateFormat.yMMMd(
            Localizations.localeOf(context).toString(),
          ).format(chat.lastActivity);
    return DesignSystemListItem(
      title: chat.title,
      subtitle: status,
      selected: chat.id == selectedId,
      onTap: () => unawaited(_select(controller, chat.id)),
      trailing: DesignSystemContextMenuButton(
        items: [
          DesignSystemContextMenuItem(
            label: messages.queryRenameChat,
            icon: LottiIcons.edit,
            onTap: () => unawaited(_guard(() => _rename(controller, chat))),
          ),
          DesignSystemContextMenuItem(
            label: chat.archived
                ? messages.queryRestoreChat
                : messages.queryArchiveChat,
            icon: chat.archived ? LottiIcons.unarchive : LottiIcons.archive,
            onTap: () {
              _closeMenu();
              unawaited(
                _guard(
                  () => controller.archive(chat.id, archived: !chat.archived),
                ),
              );
            },
          ),
          DesignSystemContextMenuItem(
            label: messages.queryDeleteChat,
            icon: LottiIcons.delete,
            isDestructive: true,
            onTap: () => unawaited(_guard(() => _delete(controller, chat))),
          ),
        ],
      ),
    );
  }
}

/// Owns the input until the modal route finishes its dismissal animation.
class _QueryRenameDialog extends ConsumerStatefulWidget {
  const _QueryRenameDialog({
    required this.controller,
    required this.chat,
    required this.private,
  });
  final QueryChatController controller;
  final QueryChatHistory chat;
  final bool private;

  @override
  ConsumerState<_QueryRenameDialog> createState() => _QueryRenameDialogState();
}

class _QueryRenameDialogState extends ConsumerState<_QueryRenameDialog> {
  late final _text = TextEditingController(text: widget.chat.title);
  late bool _authoredPrivate = widget.private;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(queryChatDataProvider(widget.controller.key)).value;
    final showPrivate = ref.watch(configFlagProvider('private')).value ?? false;
    final lockdown = ref.watch(lockdownControllerProvider);
    final access = data == null
        ? null
        : QueryAccessSnapshot(
            showPrivate: showPrivate,
            categories: data.access.categories,
            entries: data.access.entries,
            lockdown: lockdown,
          );
    final current = data?.projection.chats
        .where((candidate) => candidate.id == widget.chat.id)
        .firstOrNull;
    final home = access?.entries[widget.controller.key.scope.id];
    final homeVisible =
        access != null &&
        (widget.controller.key.scope.kind == QueryScopeKind.category
            ? access.allowsCategory(widget.controller.key.scope.id)
            : home != null && access.allowsEntry(home));
    final visible =
        homeVisible &&
        current != null &&
        (!(_authoredPrivate || current.private) || showPrivate) &&
        current.events.every(
          (event) => access.allowsEvent(event.data),
        );
    _authoredPrivate = _authoredPrivate || showPrivate;
    if (!visible) {
      // Remove the field before the modal's dismissal animation so
      // neither the saved title nor newly typed text flashes on lock.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
          _text.clear();
          Navigator.of(context).pop();
        }
      });
      return const SizedBox.shrink();
    }
    final tokens = context.designTokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DesignSystemTextInput(
          controller: _text,
          label: context.messages.queryRenameChat,
          autofocus: true,
        ),
        SizedBox(height: tokens.spacing.step5),
        DesignSystemModalActionBar(
          primary: DesignSystemButton(
            label: context.messages.saveButton,
            fullWidth: true,
            onPressed: () {
              if (_text.text.trim().isNotEmpty &&
                  _text.text.trim().length <= 120) {
                Navigator.of(context).pop(_text.text.trim());
              }
            },
          ),
          secondary: [
            DesignSystemButton(
              label: context.messages.cancelButton,
              onPressed: () => Navigator.of(context).pop(),
              variant: DesignSystemButtonVariant.secondary,
            ),
          ],
        ),
      ],
    );
  }
}
