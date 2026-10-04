import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/query/query_audio_controller.dart';
import 'package:lotti/features/agents/query/query_chat_controller.dart';
import 'package:lotti/features/agents/query/query_chat_projection.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/agents/query/query_transcription_provider.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/ui/chat/agent_chat_view.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_controller.dart';
import 'package:lotti/features/agents/ui/query/query_action_review.dart';
import 'package:lotti/features/agents/ui/query/query_audio_controls.dart';
import 'package:lotti/features/agents/ui/query/query_evidence_card.dart';
import 'package:lotti/features/agents/ui/query/query_summary_preview.dart';
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
import 'package:lotti/features/lockdown/state/lockdown_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/agent_repository_providers.dart';
import 'package:lotti/services/nav_service.dart' as nav_service;
import 'package:lotti/utils/device_datetime.dart';
import 'package:lotti/widgets/markdown_link_utils.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

part 'query_chat_pane_actions_part.dart';
part 'query_chat_pane_rename_part.dart';
part 'query_chat_pane_sections_part.dart';

/// A scoped conversation hosted in a companion or a standalone detail view.
/// Opening evidence stays inside it, preserving the chat's draft and scroll.
class QueryChatPane extends ConsumerStatefulWidget {
  const QueryChatPane({
    required this.scope,
    required this.onClose,
    required this.entryViewBuilder,
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

  /// Builds the view of a source entry that is neither a task nor a project
  /// with a summary — the journal's entry details, which the hosting page
  /// supplies so this pane does not import the journal feature above it.
  final Widget Function(String entryId) entryViewBuilder;
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

  String? _sourceId;
  bool _inspectSummary = false;
  AgentReportEntity? _sourceSummary;
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

  Future<void> _openSource(
    String id, {
    FocusNode? returnFocus,
    bool inspectSummary = false,
  }) async {
    final entry = await _visibleSource(id);
    if (entry == null) return;
    AgentReportEntity? report;
    if (inspectSummary) {
      final repository = ref.read(agentRepositoryProvider);
      if (entry is Task) {
        report = (await repository.getLatestTaskReportsForTaskIds([id]))[id];
      } else if (entry is ProjectEntry) {
        report = await repository.getLatestProjectReportForProjectId(id);
      } else {
        return;
      }
      final latest = await _visibleSource(id);
      if (latest == null || latest.runtimeType != entry.runtimeType) return;
    }
    _sourceReturnEvidence = null;
    _sourceReturnFocus = returnFocus ?? FocusManager.instance.primaryFocus;
    setState(() {
      _sourceId = id;
      _inspectSummary = inspectSummary;
      _sourceSummary = report;
    });
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
          final opener = _sourceReturnFocus!;
          final action = opener.descendants
              .where((node) => node.canRequestFocus && !node.skipTraversal)
              .firstOrNull;
          (action ?? opener).requestFocus();
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
          :final proposedActions,
        ))
          AgentChatMessage(
            id: event.id,
            role: AgentChatRole.agent,
            // Route answer-local citations to their saved evidence cards.
            // Existing Markdown links retain their original destination.
            // A model cannot announce execution before human approval.
            text: proposedActions.isNotEmpty
                ? messages.queryActionsReview
                : summaryBased
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
    if (_sourceId != null &&
        (source == null ||
            !access.allowsEntry(source) ||
            (_inspectSummary && source is! Task && source is! ProjectEntry))) {
      // A source hidden while open must not leave a visibility placeholder.
      _sourceId = null;
      _sourceSummary = null;
      _inspectSummary = false;
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
                      label: messages.queryAllSources,
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
                          if (answer.proposedActions.isNotEmpty &&
                              chat != null) {
                            final decision = chat.events
                                .map((e) => e.data)
                                .whereType<QueryChatActionDecision>()
                                .where((d) => d.questionId == answer.questionId)
                                .firstOrNull;
                            return QueryActionReview(
                              key: ValueKey('actions-${answer.questionId}'),
                              chatKey: audioKey.home,
                              chatId: chat.id,
                              answer: answer,
                              approved: decision?.approved,
                              access: access,
                              canApply: !chat.archived,
                            );
                          }
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
                                    _inspectSummary = false;
                                    _sourceSummary = null;
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
                                                '${messages.queryRecordings} · ${deviceTimestampLabel(context, audio.meta.dateFrom)}',
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
                  child: _inspectSummary
                      ? QuerySummaryPreview(
                          title: source is Task
                              ? source.data.title
                              : (source! as ProjectEntry).data.title,
                          report: _sourceSummary,
                        )
                      : widget.entryViewBuilder(source!.meta.id),
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
}
