import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_audio_controller.dart';
import 'package:lotti/features/agents/query/query_chat_controller.dart';
import 'package:lotti/features/agents/query/query_chat_projection.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/agents/query/query_transcription_provider.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/ui/chat/agent_chat_view.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_controller.dart';
import 'package:lotti/features/agents/ui/query/query_audio_controls.dart';
import 'package:lotti/features/agents/ui/query/query_evidence_card.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
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
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/ui/pages/entry_details_page.dart';
import 'package:lotti/features/lockdown/state/lockdown_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart' as nav_service;
import 'package:lotti/utils/markdown_link_utils.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Turns bare answer citations into local links without changing Markdown's
/// code spans/blocks, existing links, or numeric reference definitions.
String _linkEvidenceCitations(String text, int evidenceCount) {
  final referenceLabels = RegExp(
    r'^ {0,3}\[([^\]\n]+)\]:',
    multiLine: true,
  ).allMatches(text).map((match) => match[1]).toSet();
  final referencePattern = referenceLabels
      .whereType<String>()
      .map(RegExp.escape)
      .join('|');
  // The first alternatives consume protected Markdown before the final
  // numeric-citation alternative can see anything inside it. An unclosed
  // fence protects the remainder of the answer as code, too.
  final tokens = RegExp(
    [
      [
        r'(^[ \t]{0,3}(`{3,}|~{3,})[^\n]*(?:\n|$)[\s\S]*?',
        r'(?:^[ \t]{0,3}\2[`~]*[ \t]*(?=\n|$)|(?![\s\S])))',
      ].join(),
      r'(`+)[\s\S]*?\3',
      r'^(?: {4}|\t)[^\n]*',
      r'\\.',
      r'!?\[[^\]\n]*\]\([^\)\n]*\)',
      // Adjacent citations are links individually unless the second bracket
      // actually names a reference definition (Markdown labels ignore case).
      if (referencePattern.isNotEmpty) ...[
        [
          r'!?\[[^\]\n]*\][ \t]*(?:\n[ \t]*)?\[(?:',
          referencePattern,
          r')\]',
        ].join(),
        [r'!?\[(?:', referencePattern, r')\][ \t]*\[\]'].join(),
      ],
      r'\[(\d+)\](?!:)',
    ].join('|'),
    multiLine: true,
    caseSensitive: false,
  );
  return text.replaceAllMapped(tokens, (match) {
    final label = match[4];
    if (label == null || referenceLabels.contains(label)) return match[0]!;
    final number = int.tryParse(label);
    return number != null && number > 0 && number <= evidenceCount
        ? '[$label](#query-evidence-$label)'
        : '($label)';
  });
}

/// A scoped conversation hosted in a companion or a standalone detail view.
/// Opening evidence stays inside it, preserving the chat's draft and scroll.
class QueryChatPane extends ConsumerStatefulWidget {
  const QueryChatPane({
    required this.scope,
    required this.onClose,
    this.companion = false,
    this.storageBucket,
    this.onToggleExpanded,
    this.expanded = false,
    super.key,
  });
  final QueryScope scope;
  final VoidCallback onClose;
  final bool companion;
  final PageStorageBucket? storageBucket;
  final VoidCallback? onToggleExpanded;
  final bool expanded;
  @override
  ConsumerState<QueryChatPane> createState() => _QueryChatPaneState();
}

class _QueryChatPaneState extends ConsumerState<QueryChatPane> {
  final _storage = PageStorageBucket();
  (String, int)? _sourceReturnEvidence;
  FocusNode? _sourceReturnFocus;
  final _ownerFocus = <(String, String), FocusNode>{};

  @override
  void dispose() {
    for (final node in _ownerFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  final _evidenceKeys = <(String, int), GlobalKey<QueryEvidenceCardState>>{};

  Future<void> _openCitation(
    AgentChatMessage message,
    String url,
    String title,
    QueryChatHistory? chat,
  ) async {
    final match = RegExp(r'^#query-evidence-(\d+)$').firstMatch(url);
    if (match == null) {
      await handleMarkdownLinkTap(url, title);
      return;
    }
    final number = int.tryParse(match[1]!);
    if (number == null) return;
    final index = number - 1;
    final answer = chat?.events
        .where((e) => e.id == message.id)
        .firstOrNull
        ?.data;
    if (answer is! QueryChatAnswer ||
        index < 0 ||
        index >= answer.evidence.length) {
      return;
    }
    final source = answer.evidence[index].source;
    final fresh = await ref.read(querySourceAccessProvider).load([source.id]);
    if (!mounted) return;
    final current = QueryAccessSnapshot(
      showPrivate: ref.read(configFlagProvider('private')).value == true,
      categories: fresh.categories,
      entries: fresh.entries,
      lockdown: ref.read(lockdownControllerProvider),
    );
    if (current.allowsReference(source)) {
      _evidenceKeys[(message.id, index)]?.currentState?.reveal();
    }
  }

  String? _sourceId;
  String? _readThrough;
  String? _dictatedChat;
  bool _creating = false;
  bool _showArchived = false;
  bool _menuOpen = false;
  bool _showScope = false;
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

  Future<void> _openSource(String id, {FocusNode? returnFocus}) async {
    final fresh = await ref.read(querySourceAccessProvider).load([id]);
    if (!mounted) return;
    final current = QueryAccessSnapshot(
      showPrivate: ref.read(configFlagProvider('private')).value == true,
      categories: fresh.categories,
      entries: fresh.entries,
      lockdown: ref.read(lockdownControllerProvider),
    );
    final entry = current.entries[id];
    if (entry == null || !current.allowsEntry(entry)) return;
    _sourceReturnEvidence = null;
    _sourceReturnFocus = returnFocus ?? FocusManager.instance.primaryFocus;
    setState(() => _sourceId = id);
  }

  Future<void> _leave() async {
    await ref.read(chatRecorderControllerProvider.notifier).cancel();
    if (!mounted) return;
    if (_sourceId != null) {
      setState(() => _sourceId = null);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final evidence = _evidenceKeys[_sourceReturnEvidence]?.currentState;
        if (evidence != null) {
          evidence.reveal();
        } else if (_sourceReturnFocus?.context != null &&
            _sourceReturnFocus!.canRequestFocus) {
          _sourceReturnFocus!.requestFocus();
        }
      });
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

  Future<void> _archive(
    QueryChatController controller,
    String id, {
    required bool archived,
  }) async {
    await controller.archive(id, archived: archived);
    if (mounted && archived) {
      context.showToast(
        tone: DesignSystemToastTone.success,
        title: context.messages.queryArchiveConfirmation,
      );
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
                  label: forget
                      ? messages.queryDeleteForget
                      : messages.queryDeleteKeep,
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
    ref.listen(queryChatEnabledProvider, (_, enabled) {
      if (!enabled) {
        unawaited(ref.read(chatRecorderControllerProvider.notifier).cancel());
      }
    });
    if (!ref.watch(queryChatEnabledProvider)) return const SizedBox.shrink();
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
    final audioKey = (home: key, chatId: id);
    if (chat != null && _sourceId == null) {
      ref.watch(queryAudioControllerProvider(audioKey));
    }
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
    final originalsOnly =
        widget.scope.kind == QueryScopeKind.task && local.kind != null;
    final reach = originalsOnly
        ? messages.queryOriginalsHome
        : widget.scope.kind == QueryScopeKind.category
        ? messages.queryReachCategoryOnly(categoryName ?? label)
        : categoryName == null
        ? messages.queryReachUncategorized
        : local.homeOnly
        ? messages.queryReachHome
        : messages.queryReachCategory(categoryName);
    final tokens = context.designTokens;
    final lastQuestion = chat?.questions.lastOrNull;
    final running = local.status == QueryTurnStatus.running;
    final provisional = local.provisional;
    final showProvisional =
        provisional != null &&
        provisional.text.isNotEmpty &&
        (!provisional.private || showPrivate) &&
        chat != null &&
        chat.answerFor(provisional.questionId) == null;
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
        else if (event.data case QueryChatAnswer(
          :final text,
          :final evidence,
          :final summaryBased,
        ))
          AgentChatMessage(
            id: event.id,
            role: AgentChatRole.agent,
            // Route answer-local citations to their saved evidence cards.
            // Existing Markdown links retain their original destination.
            text: summaryBased
                ? '**${messages.querySummaryBased}**\n\n$text'
                : _linkEvidenceCitations(text, evidence.length),
            createdAt: event.createdAt,
          ),
    ];
    final visibleEvidenceKeys = {
      for (final event in chat?.events ?? const <AgentQueryChatEventEntity>[])
        if (event.data case QueryChatAnswer(:final evidence))
          for (final (index, _) in evidence.indexed) (event.id, index),
    };
    _evidenceKeys.removeWhere((key, _) => !visibleEvidenceKeys.contains(key));
    final memories = data.projection.memories
        .where((e) => access.allowsEvent(e.data))
        .length;
    final source = access.entries[_sourceId];
    if (_sourceId != null && (source == null || !access.allowsEntry(source))) {
      // A source hidden while open must not leave a visibility placeholder.
      _sourceId = null;
      _sourceReturnEvidence = null;
      _sourceReturnFocus = null;
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _header(
                context,
                label: label,
                agentName: agent.displayName,
                reach: reach,
                switcher: _switcher(
                  context,
                  controller,
                  visible,
                  session,
                  chat,
                ),
                filters: [
                  if (categoryId != null &&
                      widget.scope.kind != QueryScopeKind.category)
                    DesignSystemChip(
                      label: messages.queryHomeOnly,
                      size: DesignSystemChipSize.compactPillTouch,
                      outlined: true,
                      selected: local.homeOnly || originalsOnly,
                      onPressed: running || originalsOnly
                          ? null
                          : () => controller.narrow(
                              id,
                              homeOnly: !local.homeOnly,
                            ),
                    ),
                  if (widget.scope.kind == QueryScopeKind.task)
                    DesignSystemChip(
                      label: messages.querySummaries,
                      size: DesignSystemChipSize.compactPillTouch,
                      outlined: true,
                      selected: local.kind == null,
                      onPressed: running
                          ? null
                          : () => controller.narrow(id, clearKind: true),
                    ),
                  if (widget.scope.kind == QueryScopeKind.task)
                    for (final kind in [
                      QuerySourceKind.text,
                      QuerySourceKind.recording,
                    ])
                      DesignSystemChip(
                        label: kind == QuerySourceKind.text
                            ? messages.queryNotes
                            : messages.queryRecordings,
                        size: DesignSystemChipSize.compactPillTouch,
                        outlined: true,
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
              if (_sourceId == null) ...[
                const Divider(height: 0),
                Expanded(
                  child: PageStorage(
                    bucket: widget.storageBucket ?? _storage,
                    child: AgentChatView(
                      key: ValueKey(id),
                      agentId: agent.id,
                      agentName: agent.displayName,
                      conversationId: id,
                      history: AsyncData(history),
                      draft: draft,
                      isSending: running || showProvisional,
                      sendingLabel: _activityLabel(context, local),
                      onDraftChanged: (text) =>
                          controller.updateDraft(id, text),
                      onSend: () => unawaited(
                        _guard(() => _send(controller, chat, local)),
                      ),
                      onRetry: () {},
                      onLinkTap: (message, url, title) => unawaited(
                        _guard(() => _openCitation(message, url, title, chat)),
                      ),
                      scrollOnReplies: false,
                      groupAttachmentsWithReply: true,
                      allowDraftWhileSending: true,
                      showVoiceDetails: true,
                      replyTextStyle: tokens.typography.styles.body.bodySmall,
                      resolveTranscriptionTarget: ref.watch(
                        queryTranscriptionTargetResolverProvider(widget.scope),
                      ),
                      composerShape: DesignSystemTextInputShape.pill,
                      composerEnabled: chat?.archived != true && !_creating,
                      emptyState: _empty(
                        context,
                        controller,
                        id,
                        memories,
                        agent.displayName,
                      ),
                      activity: showProvisional
                          ? Padding(
                              padding: EdgeInsets.all(tokens.spacing.step4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    messages.queryDraftProvisional,
                                    style:
                                        tokens.typography.styles.others.caption,
                                  ),
                                  SizedBox(height: tokens.spacing.step2),
                                  SelectableText(
                                    provisional.text,
                                    key: ValueKey(
                                      'query-provisional-${provisional.questionId}',
                                    ),
                                    style:
                                        tokens.typography.styles.body.bodySmall,
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                      pinnedActivity: _progress(
                        context,
                        local,
                        () => controller.cancel(id),
                      ),
                      footer: _footer(
                        context,
                        controller,
                        chat,
                        local,
                      ),
                      attachmentBuilder: (context, message) {
                        final row = chat?.events
                            .where((e) => e.id == message.id)
                            .firstOrNull;
                        if (row?.data is QueryChatQuestion &&
                            chat != null &&
                            chat.answerFor(row!.id) == null &&
                            (chat.failed(row.id) ||
                                (!running && row.id == lastQuestion?.id))) {
                          return _questionRecovery(
                            context,
                            controller,
                            chat,
                            row.id,
                            local: local,
                            running: running,
                          );
                        }
                        if (row?.data case final QueryChatAnswer answer) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              QueryAnswerSpeechButton(
                                chatKey: audioKey,
                                answerId: message.id,
                              ),
                              if (answer.recalledMemoryIds.isNotEmpty)
                                _recalledConclusions(
                                  context,
                                  answer,
                                  data.projection,
                                  visible,
                                  access,
                                  controller,
                                ),
                              if (answer.coverage.incomplete)
                                Text(
                                  answer.summaryBased
                                      ? messages.querySummaryIncomplete
                                      : messages.queryIncompleteShort,
                                  style:
                                      tokens.typography.styles.others.caption,
                                ),
                              for (final (index, evidence)
                                  in answer.evidence.indexed)
                                QueryEvidenceCard(
                                  key: _evidenceKeys.putIfAbsent(
                                    (message.id, index),
                                    GlobalKey<QueryEvidenceCardState>.new,
                                  ),
                                  storageId: '${message.id}:$index',
                                  evidence: evidence,
                                  number: index + 1,
                                  access: access,
                                  onOpen: (sourceId) => setState(() {
                                    _sourceReturnEvidence = (message.id, index);
                                    _sourceId = sourceId;
                                  }),
                                  audioControls:
                                      access.entries[evidence.source.id]
                                          is JournalAudio
                                      ? QueryEvidenceAudioControls(
                                          chatKey: audioKey,
                                          actionId: '${message.id}:$index',
                                          onOpenEntry: () => unawaited(
                                            _guard(
                                              () => _openSource(
                                                evidence.source.id,
                                              ),
                                            ),
                                          ),
                                          onOpenSettings: () => nav_service
                                              .beamToNamed('/settings/ai'),
                                          evidence: evidence,
                                          audio:
                                              access.entries[evidence
                                                      .source
                                                      .id]!
                                                  as JournalAudio,
                                        )
                                      : null,
                                ),
                              if (answer.summaryBased)
                                _summaryBasis(context, answer, access)
                              else
                                ExpansionTile(
                                  key: PageStorageKey('${message.id}:coverage'),
                                  expandedCrossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  title: Text(
                                    messages.queryCoverage,
                                    style:
                                        tokens.typography.styles.others.caption,
                                  ),
                                  childrenPadding: EdgeInsets.all(
                                    tokens.spacing.step3,
                                  ),
                                  children: [
                                    if (answer.coverage.incomplete)
                                      Text(
                                        messages.queryIncomplete,
                                        style: tokens
                                            .typography
                                            .styles
                                            .others
                                            .caption,
                                      ),
                                    Text(
                                      messages.queryChecked(
                                        answer.coverage.checked,
                                      ),
                                      style: tokens
                                          .typography
                                          .styles
                                          .body
                                          .bodySmall,
                                    ),
                                    if (answer.coverage.homeChecked
                                        case final count?)
                                      Text(
                                        '${widget.scope.kind == QueryScopeKind.category ? messages.queryCoverageCategory : messages.queryHomeScope} · ${messages.queryChecked(count)}',
                                        style: tokens
                                            .typography
                                            .styles
                                            .body
                                            .bodySmall,
                                      ),
                                    if (widget.scope.kind !=
                                            QueryScopeKind.category &&
                                        answer.coverage.categoryChecked != null)
                                      Text(
                                        '${messages.queryCoverageWider} · ${messages.queryChecked(answer.coverage.categoryChecked!)}',
                                        style: tokens
                                            .typography
                                            .styles
                                            .body
                                            .bodySmall,
                                      ),
                                    Text(
                                      messages.queryCoverageExcluded,
                                      style: tokens
                                          .typography
                                          .styles
                                          .body
                                          .bodySmall,
                                    ),
                                    for (final reference
                                        in answer.coverage.unreadableSources)
                                      if (access.entries[reference.id]
                                          case final JournalAudio audio)
                                        if (access.allowsEntry(audio))
                                          DesignSystemListItem(
                                            titleMaxLines: 2,
                                            subtitleMaxLines: null,
                                            title:
                                                '${messages.queryRecordings} · ${DateFormat.yMMMd(Localizations.localeOf(context).toString()).add_Hm().format(audio.meta.dateFrom)}',
                                            subtitle:
                                                audio.meta.categoryId ==
                                                    reference.categoryId
                                                ? messages
                                                      .queryCoverageUnreadable
                                                : '${messages.queryCoverageUnreadable}\n${messages.querySourceMoved}',
                                            trailing: const Icon(
                                              LottiIcons.openExternal,
                                            ),
                                            onTap: () => unawaited(
                                              _guard(
                                                () => _openSource(reference.id),
                                              ),
                                            ),
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
                  child: EntryDetailsPage(
                    itemId: source!.meta.id,
                    showBackButton: false,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Gives the owning task and conversation separate readable rows in a
  /// narrow panel. Scope remains explicit while optional filters disclose.
  Widget _header(
    BuildContext context, {
    required String label,
    required String agentName,
    required String reach,
    required Widget switcher,
    required List<Widget> filters,
  }) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth <
            kPageHeaderFoldWidth * MediaQuery.textScalerOf(context).scale(1);
        final close = DesignSystemIconAction(
          icon: widget.companion ? LottiIcons.close : LottiIcons.back,
          tooltip: widget.companion
              ? messages.queryCloseChat
              : MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: widget.companion ? widget.onClose : _leave,
        );
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step4,
            vertical: tokens.spacing.step3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (widget.companion && _sourceId != null)
                    DesignSystemIconAction(
                      icon: LottiIcons.back,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      onPressed: _leave,
                    ),
                  Expanded(
                    child: Tooltip(
                      message: '${_scopeKind(context)} · $label',
                      child: Semantics(
                        tooltip: reach,
                        child: Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: compact
                              ? tokens.typography.styles.body.bodySmall
                              : tokens.typography.styles.subtitle.subtitle1,
                        ),
                      ),
                    ),
                  ),
                  close,
                ],
              ),
              if (!compact)
                Text(
                  '$agentName · ${_agentKind(context)}',
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              if (_sourceId == null) ...[
                Row(
                  children: [
                    Expanded(child: switcher),
                    if (compact)
                      MergeSemantics(
                        child: Semantics(
                          expanded: _showScope,
                          child: DesignSystemIconAction(
                            icon: LottiIcons.filter,
                            tooltip: messages.querySearchScope,
                            onPressed: () =>
                                setState(() => _showScope = !_showScope),
                          ),
                        ),
                      ),
                    if (widget.onToggleExpanded != null)
                      DesignSystemIconAction(
                        icon: widget.expanded
                            ? LottiIcons.collapseBoth
                            : LottiIcons.expandFull,
                        tooltip: widget.expanded
                            ? messages.queryCollapseChat
                            : messages.queryExpandChat,
                        onPressed: widget.onToggleExpanded,
                      ),
                  ],
                ),
                if (!compact || _showScope)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: tokens.spacing.step2,
                    ),
                    child: Text(
                      reach,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ),
                if (!compact || _showScope)
                  Wrap(
                    spacing: tokens.spacing.step3,
                    runSpacing: tokens.spacing.step2,
                    children: filters,
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _shell(BuildContext context, String? message) => Scaffold(
    appBar: AppBar(
      leading: DesignSystemIconAction(
        icon: widget.companion ? LottiIcons.close : LottiIcons.back,
        tooltip: widget.companion
            ? context.messages.queryCloseChat
            : MaterialLocalizations.of(context).backButtonTooltip,
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

  String _scopeKind(BuildContext context) => switch (widget.scope.kind) {
    QueryScopeKind.task => context.messages.entryTypeLabelTask,
    QueryScopeKind.project => context.messages.projectFilterLabel,
    QueryScopeKind.category => context.messages.dashboardCategoryLabel,
  };

  String _agentKind(BuildContext context) => switch (widget.scope.kind) {
    QueryScopeKind.task => context.messages.agentTemplateKindTaskAgent,
    QueryScopeKind.project => context.messages.agentTemplateKindProjectAgent,
    QueryScopeKind.category => context.messages.queryCategoryAgent,
  };

  Widget _empty(
    BuildContext context,
    QueryChatController controller,
    String id,
    int memories,
    String agentName,
  ) {
    final messages = context.messages;
    final tokens = context.designTokens;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        primary: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.step4),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: kActionListContentMaxWidth,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (constraints.maxHeight >
                        constraints.maxWidth.clamp(
                          0,
                          kActionListContentMaxWidth,
                        ))
                      Text(
                        switch (widget.scope.kind) {
                          QueryScopeKind.task => messages.queryWelcomeTask(
                            agentName,
                          ),
                          QueryScopeKind.project =>
                            messages.queryWelcomeProject(
                              agentName,
                            ),
                          QueryScopeKind.category =>
                            messages.queryWelcomeCategory(agentName),
                        },
                        textAlign: TextAlign.center,
                        style: tokens.typography.styles.heading.heading3,
                      ),
                    SizedBox(height: tokens.spacing.step3),
                    Text(
                      messages.queryEmptyBody,
                      textAlign: TextAlign.center,
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                    SizedBox(height: tokens.spacing.step3),
                    for (final example in [
                      messages.queryExampleDecision,
                      messages.queryExampleMeeting,
                      messages.queryExampleSuggestion,
                    ])
                      Padding(
                        padding: EdgeInsets.only(bottom: tokens.spacing.step3),
                        child: Material(
                          color: tokens.colors.background.level02,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(tokens.radii.m),
                            side: BorderSide(
                              color: tokens.colors.decorative.level01,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => controller.updateDraft(id, example),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: tokens.spacing.step5,
                                vertical: tokens.spacing.step4,
                              ),
                              child: Text(
                                example,
                                style: tokens.typography.styles.body.bodySmall,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (memories > 0)
                      Padding(
                        padding: EdgeInsets.only(top: tokens.spacing.step3),
                        child: Text(
                          messages.queryMemoryCount(memories),
                          style: tokens.typography.styles.others.caption,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _questionRecovery(
    BuildContext context,
    QueryChatController controller,
    QueryChatHistory chat,
    String questionId, {
    required QueryChatLocal local,
    required bool running,
  }) {
    final terminal = chat.events
        .where(
          (event) => switch (event.data) {
            QueryChatFailed(questionId: final id) ||
            QueryChatCancelled(questionId: final id) => id == questionId,
            _ => false,
          },
        )
        .lastOrNull;
    final messages = context.messages;
    final needsSetup =
        local.status == QueryTurnStatus.unavailable &&
        local.requestQuestionId == questionId;
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            needsSetup
                ? messages.queryInferenceUnavailable
                : local.draftRetracted && local.requestQuestionId == questionId
                ? messages.queryDraftRetracted
                : terminal?.data is QueryChatCancelled
                ? messages.aiAttributionStatusCancelled
                : messages.queryFailed,
            style: context.designTokens.typography.styles.others.caption,
          ),
          if (!chat.archived)
            Wrap(
              spacing: context.designTokens.spacing.step2,
              children: [
                if (needsSetup)
                  DesignSystemButton(
                    tapTargetSize: MaterialTapTargetSize.padded,
                    label: messages.settingsAiTitle,
                    onPressed: () => nav_service.beamToNamed('/settings/ai'),
                    variant: DesignSystemButtonVariant.tertiary,
                    size: DesignSystemButtonSize.dense,
                  ),
                DesignSystemButton(
                  tapTargetSize: MaterialTapTargetSize.padded,
                  label: messages.aiInferenceErrorRetryButton,
                  onPressed: running
                      ? null
                      : () => unawaited(
                          controller.send(chat.id, retryQuestionId: questionId),
                        ),
                  variant: DesignSystemButtonVariant.tertiary,
                  size: DesignSystemButtonSize.dense,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _recalledConclusions(
    BuildContext context,
    QueryChatAnswer answer,
    QueryChatProjection projection,
    List<QueryChatHistory> visible,
    QueryAccessSnapshot access,
    QueryChatController controller,
  ) {
    final recalled = projection.memories.where(
      (event) =>
          answer.recalledMemoryIds.contains(event.id) &&
          access.allowsEvent(event.data),
    );
    if (recalled.isEmpty) {
      return const SizedBox.shrink();
    }
    return ExpansionTile(
      key: PageStorageKey('recall:${answer.questionId}'),
      title: Text(
        context.messages.queryRecall,
        style: context.designTokens.typography.styles.others.caption,
      ),
      children: [
        for (final event in recalled)
          if (event.data case QueryChatMemory(:final text))
            Padding(
              padding: EdgeInsets.all(context.designTokens.spacing.step3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.messages.querySavedConclusion(
                      DateFormat.yMMMd(
                        Localizations.localeOf(context).toString(),
                      ).add_Hm().format(event.createdAt),
                    ),
                    style:
                        context.designTokens.typography.styles.others.caption,
                  ),
                  SelectableText(
                    key: PageStorageKey('memory-text:${event.id}'),
                    text,
                    style:
                        context.designTokens.typography.styles.body.bodySmall,
                  ),
                  if (visible
                          .where((chat) => chat.id == event.chatId)
                          .firstOrNull
                      case final origin?)
                    DesignSystemButton(
                      label: origin.title,
                      onPressed: () =>
                          unawaited(_select(controller, origin.id)),
                      variant: DesignSystemButtonVariant.tertiary,
                      size: DesignSystemButtonSize.dense,
                    ),
                ],
              ),
            ),
      ],
    );
  }

  Widget? _footer(
    BuildContext context,
    QueryChatController controller,
    QueryChatHistory? chat,
    QueryChatLocal local,
  ) {
    final messages = context.messages;
    final recorderStatus = ref.watch(
      chatRecorderControllerProvider.select((s) => s.status),
    );
    final hasRecovery =
        local.requestQuestionId != null &&
        chat?.questions.any(
              (question) =>
                  question.id == local.requestQuestionId &&
                  chat.answerFor(question.id) == null,
            ) ==
            true;
    final text = chat?.archived == true
        ? messages.queryArchivedReadOnly
        : switch (local.status) {
            QueryTurnStatus.unavailable =>
              hasRecovery ? null : messages.queryInferenceUnavailable,
            QueryTurnStatus.hidden => messages.queryUnavailable,
            QueryTurnStatus.failed => hasRecovery ? null : messages.queryFailed,
            QueryTurnStatus.cancelled =>
              hasRecovery ? null : messages.aiAttributionStatusCancelled,
            _ =>
              recorderStatus == ChatRecorderStatus.processing
                  ? messages.queryTranscribing
                  : _dictatedChat == (chat?.id ?? 'new') &&
                        local.draft.isNotEmpty
                  ? messages.queryDictated
                  : null,
          };
    if (text == null) return null;
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step5,
        vertical: tokens.spacing.step2,
      ),
      child: Column(
        children: [
          Text(text, style: tokens.typography.styles.others.caption),
          if (local.status == QueryTurnStatus.unavailable)
            DesignSystemButton(
              label: messages.settingsAiTitle,
              onPressed: () => nav_service.beamToNamed('/settings/ai'),
              variant: DesignSystemButtonVariant.tertiary,
            ),
          if (chat != null && chat.archived)
            DesignSystemButton(
              label: messages.queryRestoreChat,
              onPressed: () => unawaited(
                _guard(() => controller.archive(chat.id, archived: false)),
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
      width:
          (MediaQuery.sizeOf(context).width -
                  context.designTokens.spacing.step7)
              .clamp(0, kGoalChatDrawerWidth),
      semanticsLabel: messages.queryChats,
      builder: (context, {required toggle, required isOpen}) {
        _toggleMenu = toggle;
        _menuOpen = isOpen;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (anyRunning || anyUnread) ...[
              DesignSystemBadge.dot(
                tone: anyRunning
                    ? DesignSystemBadgeTone.primary
                    : DesignSystemBadgeTone.warning,
                semanticLabel: anyRunning
                    ? messages.querySearching
                    : messages.queryUnread,
              ),
              SizedBox(width: context.designTokens.spacing.step2),
            ],
            Flexible(
              child: MergeSemantics(
                child: Semantics(
                  expanded: isOpen,
                  child: DesignSystemButton(
                    label: selected?.title ?? messages.queryNewChat,
                    semanticsLabel: messages.querySourceAction(
                      messages.queryChats,
                      selected?.title ?? messages.queryNewChat,
                    ),
                    trailingIcon: LottiIcons.chevronDown,
                    onPressed: toggle,
                    variant: DesignSystemButtonVariant.outlined,
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: Container(
        color: context.designTokens.colors.background.level02,
        padding: EdgeInsets.all(context.designTokens.spacing.step3),
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
              MergeSemantics(
                child: Semantics(
                  expanded: _showArchived,
                  child: DesignSystemListItem(
                    title:
                        '${messages.queryArchivedChats} · ${chats.where((c) => c.archived).length}',
                    leading: const Icon(LottiIcons.archive, size: IconSizes.s),
                    trailing: Icon(
                      _showArchived ? LottiIcons.collapse : LottiIcons.expand,
                      size: IconSizes.s,
                    ),
                    onTap: () => setState(() => _showArchived = !_showArchived),
                  ),
                ),
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

  Widget _summaryBasis(
    BuildContext context,
    QueryChatAnswer answer,
    QueryAccessSnapshot access,
  ) {
    final messages = context.messages;
    final tokens = context.designTokens;
    final dependencies = answer.dependencies.map((ref) => ref.id).toSet();
    final owners = <({String id, String title})>[
      for (final id in answer.summaryOwnerIds.toSet())
        if (dependencies.contains(id) &&
            access.entries[id] != null &&
            access.allowsEntry(access.entries[id]!))
          if (switch (access.entries[id]) {
                Task(:final data) => data.title,
                ProjectEntry(:final data) => data.title,
                _ => null,
              }
              case final String title)
            (id: id, title: title),
    ];
    return ExpansionTile(
      key: PageStorageKey(('summary-basis', answer.questionId)),
      title: Text(
        messages.querySummaryOwners,
        style: tokens.typography.styles.others.caption,
      ),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      childrenPadding: EdgeInsets.all(tokens.spacing.step3),
      children: [
        Text(
          messages.querySummaryCoverage,
          style: tokens.typography.styles.body.bodySmall,
        ),
        for (final owner in owners)
          Focus(
            focusNode: _ownerFocus.putIfAbsent((
              answer.questionId,
              owner.id,
            ), FocusNode.new),
            child: DesignSystemButton(
              label: owner.title,
              leadingIcon: LottiIcons.openExternal,
              semanticsLabel: messages.querySourceAction(
                messages.queryOpenCurrentEntry,
                owner.title,
              ),
              variant: DesignSystemButtonVariant.tertiary,
              size: DesignSystemButtonSize.dense,
              tapTargetSize: MaterialTapTargetSize.padded,
              onPressed: () => unawaited(
                _guard(
                  () => _openSource(
                    owner.id,
                    returnFocus: _ownerFocus[(answer.questionId, owner.id)],
                  ),
                ),
              ),
            ),
          ),
        if (owners.isNotEmpty)
          Text(
            messages.querySummaryCurrent,
            style: tokens.typography.styles.others.caption,
          ),
      ],
    );
  }

  Widget _progress(
    BuildContext context,
    QueryChatLocal local,
    VoidCallback cancel,
  ) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step4,
        vertical: tokens.spacing.step2,
      ),
      child: Row(
        children: [
          const SizedBox.square(
            dimension: IconSizes.s,
            child: CircularProgressIndicator(
              strokeWidth: BorderWidths.emphasis,
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _activityLabel(context, local),
                    style: tokens.typography.styles.others.caption,
                  ),
                  if (local.checked > 0)
                    Text(
                      context.messages.queryChecked(local.checked),
                      style: tokens.typography.styles.others.caption,
                    ),
                ],
              ),
            ),
          ),
          DesignSystemButton(
            label: context.messages.cancelButton,
            onPressed: cancel,
            variant: DesignSystemButtonVariant.tertiary,
            size: DesignSystemButtonSize.dense,
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
        ],
      ),
    );
  }

  String _activityLabel(BuildContext context, QueryChatLocal local) =>
      local.answering
      ? context.messages.queryPreparingAnswer
      : local.expanded
      ? context.messages.queryExpanding
      : context.messages.querySearching;

  Widget _chatRow(
    BuildContext context,
    QueryChatController controller,
    QueryChatHistory chat,
    QueryChatLocal local,
    String? selectedId,
  ) {
    final messages = context.messages;
    final status = local.status == QueryTurnStatus.running
        ? _activityLabel(context, local)
        : chat.unread
        ? messages.queryUnread
        : local.status == QueryTurnStatus.failed
        ? messages.queryFailed
        : chat.events.reversed
                  .map(
                    (event) => switch (event.data) {
                      QueryChatAnswer(:final text) ||
                      QueryChatQuestion(:final text) => text,
                      _ => '',
                    },
                  )
                  .where((text) => text.isNotEmpty)
                  .firstOrNull ??
              DateFormat.yMMMd(
                Localizations.localeOf(context).toString(),
              ).format(chat.lastActivity);
    return DesignSystemListItem(
      title: chat.title,
      subtitle: status,
      selected: chat.id == selectedId,
      activated: chat.id == selectedId,
      onTap: () => unawaited(_select(controller, chat.id)),
      leading: local.status == QueryTurnStatus.running || chat.unread
          ? DesignSystemBadge.dot(
              tone: local.status == QueryTurnStatus.running
                  ? DesignSystemBadgeTone.primary
                  : DesignSystemBadgeTone.warning,
              excludeFromSemantics: true,
            )
          : null,
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
                  () => _archive(
                    controller,
                    chat.id,
                    archived: !chat.archived,
                  ),
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
