part of 'query_chat_pane.dart';

/// Section builders for the query chat pane: the shell, empty state, recovery and recall blocks, footer, summary basis, progress and chat rows. Builders that write state stay in the State (the repo's extension-split rule).
extension _QueryChatPaneSections on _QueryChatPaneState {
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
                      deviceTimestampLabel(context, event.createdAt),
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
            skipTraversal: true,
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
                    inspectSummary: true,
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

/// Labels naming the chat's scope and the agent kind behind it.
extension _QueryChatPaneLabels on _QueryChatPaneState {
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
}
