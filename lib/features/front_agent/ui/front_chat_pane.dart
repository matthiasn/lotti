import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/ui/chat/agent_chat_view.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_controller.dart';
import 'package:lotti/features/ai/state/subject_dictation_providers.dart';
import 'package:lotti/features/daily_os_next/state/selected_date_provider.dart';
import 'package:lotti/features/design_system/components/chat_input/design_system_chat_input.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/model/front_reference_links.dart';
import 'package:lotti/features/front_agent/model/front_reply_parts.dart';
import 'package:lotti/features/front_agent/state/front_chat_controller.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
import 'package:lotti/features/front_agent/state/front_journal_access_provider.dart';
import 'package:lotti/features/front_agent/state/front_mention_categories.dart';
import 'package:lotti/features/front_agent/ui/front_ask_options_row.dart';
import 'package:lotti/features/front_agent/ui/front_chat_header.dart';
import 'package:lotti/features/front_agent/ui/front_chat_hero.dart';
import 'package:lotti/features/front_agent/ui/front_chat_voice.dart';
import 'package:lotti/features/front_agent/ui/front_conversation_list.dart';
import 'package:lotti/features/front_agent/ui/front_door_card.dart';
import 'package:lotti/features/front_agent/ui/front_door_wizards.dart';
import 'package:lotti/features/front_agent/ui/front_logged_time_chart_card.dart';
import 'package:lotti/features/front_agent/ui/front_pull_request_chart_card.dart';
import 'package:lotti/features/front_agent/ui/front_task_list.dart';
import 'package:lotti/features/front_agent/ui/front_turn_cost_line.dart';
import 'package:lotti/features/tasks/util/task_navigation.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/utils/device_datetime.dart';
import 'package:lotti/utils/goal_routes.dart';
import 'package:lotti/widgets/markdown_link_utils.dart';
import 'package:material_ui/material_ui.dart';

/// A task's page, as [internalRouteFromMarkdownUrl] gives it: `/tasks/<id>`.
final RegExp _taskRoute = RegExp(r'^/tasks/([^/?]+)$');

/// The companion's chat: one of the user's conversations with her, under
/// her header, in the shared [AgentChatView] — or, while the header's list
/// is open, the list of them all ([FrontConversationList]).
///
/// What differs from a goal's or a person's chat is what hangs off a
/// message: under a routed turn, the doors it was taken through and what
/// came back, attributed to each owner; under her latest clarifying
/// question, the choices as chips. A day divider sits between messages of
/// different days.
class FrontChatPane extends ConsumerWidget {
  const FrontChatPane({required this.onClose, this.listWidth, super.key});

  final VoidCallback onClose;

  /// The width of the list kept beside the conversation, on a window wide
  /// enough for both; null where the list is a page over the conversation.
  final double? listWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final beside = listWidth != null;
    // Beside the conversation the list is always there: it never opens
    // over it.
    final listOpen = !beside && ref.watch(frontConversationListOpenProvider);
    // Her reply to a spoken turn is spoken back, list open or not.
    FrontVoice.listenForSpokenReply(ref, context);
    final inboxOnly = ref.watch(frontInboxFilterProvider);
    // What was being said belongs to the conversation it was said in:
    // leaving it — for another, or for the list — lets it go, rather than
    // sending it into wherever the user went. Listened here, where it is
    // always mounted, not in the thread, which the list replaces.
    void letHerGo(Object? previous, Object? next) {
      if (previous == next) return;
      // Only on leaving one: a conversation resolving as the surface opens
      // is where the user already is.
      final recorder = ref.read(chatRecorderControllerProvider);
      if (previous != null &&
          (recorder.status == ChatRecorderStatus.recording ||
              recorder.status == ChatRecorderStatus.processing)) {
        ref.read(chatRecorderControllerProvider.notifier).cancel().ignore();
      }
    }

    ref
      ..listen<String?>(
        frontActiveConversationProvider.select((active) => active.value),
        letHerGo,
      )
      ..listen<bool>(frontConversationListOpenProvider, letHerGo);
    // The list is a page over the conversation, and the inbox a view of
    // it: back — the system gesture, the Escape key — leaves the list, then
    // the inbox, before it closes the sheet.
    return PopScope(
      canPop: !listOpen && !inboxOnly,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (listOpen) {
          ref.read(frontConversationListOpenProvider.notifier).close();
        } else {
          ref.read(frontInboxFilterProvider.notifier).clear();
        }
      },
      child: beside
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // A step off the conversation's ground: the list is the
                // sheet's sidebar, not more of the thread.
                ColoredBox(
                  color: tokens.colors.background.level02,
                  child: SizedBox(
                    width: listWidth,
                    child: const FrontConversationList(beside: true),
                  ),
                ),
                const DesignSystemDivider(
                  orientation: DesignSystemDividerOrientation.vertical,
                ),
                Expanded(
                  child: Column(
                    children: [
                      FrontChatHeader(onClose: onClose, listBeside: true),
                      Expanded(child: FrontChatThreadView(onClose: onClose)),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                FrontChatHeader(onClose: onClose),
                Expanded(
                  child: listOpen
                      ? const FrontConversationList()
                      : FrontChatThreadView(onClose: onClose),
                ),
              ],
            ),
    );
  }
}

/// One conversation's thread and the field under it — or, while the inbox is
/// on, every turn still waiting on the user. In the pane under her header,
/// and beside her on her full-screen stage on a desktop window.
///
/// Without [composerEnabled] the thread is read only, and leaves what is said
/// aloud to the view that has the field: two views acting on one finished
/// recording would send it twice.
class FrontChatThreadView extends ConsumerWidget {
  const FrontChatThreadView({
    required this.onClose,
    this.composerEnabled = true,
    super.key,
  });

  /// Whether the field sits under the thread; off beside her on her stage,
  /// whose own control at her feet is the way to answer her there.
  final bool composerEnabled;

  /// Closes her surface. Everything that leaves her for a page goes through
  /// this, never `maybePop`: while the list or the inbox is open, back is
  /// theirs ([PopScope] clears them), and the page would open behind her.
  /// A task is the exception: it opens on top of her, and back returns here.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = context.messages;
    final threadAsync = ref.watch(frontChatThreadProvider);
    // Read through `.value`: a reload keeps the shown thread on screen
    // (stay while reload); only a first load with nothing yet shows a shell.
    final thread = threadAsync.value;
    // She copies dates as her tools give them (ISO); on screen each is in
    // the device's own format, as a due date is everywhere else.
    String deviceDays(String text) =>
        replaceIsoDays(text, (day) => deviceDateLabel(context, day));
    final history = switch (thread) {
      null when threadAsync.hasError => AsyncError<List<AgentChatMessage>>(
        threadAsync.error!,
        threadAsync.stackTrace ?? StackTrace.empty,
      ),
      null => const AsyncLoading<List<AgentChatMessage>>(),
      final t => AsyncData([
        for (final m in t.messages)
          if (m.role == AgentChatRole.agent)
            AgentChatMessage(
              id: m.id,
              role: m.role,
              text: deviceDays(m.text),
              createdAt: m.createdAt,
              runKey: m.runKey,
            )
          else
            m,
      ]),
    };
    final composer = ref.watch(frontChatControllerProvider);
    final mentions = ref.watch(frontMentionCategoriesProvider);
    // Kept across a reread (`.value`): an answer is not taken off the screen
    // while its sources' visibility is checked again.
    final journalAccess = ref.watch(frontJournalAccessProvider).value;
    final controller = ref.read(frontChatControllerProvider.notifier);
    final latestId = thread?.messages.lastOrNull?.id;
    final locale = Localizations.localeOf(context).toLanguageTag();
    // The inbox is the same thread, filtered to the turns with a door still
    // waiting on the user (decision 7).
    final inboxOnly = ref.watch(frontInboxFilterProvider);
    final conversationId = ref.watch(frontActiveConversationProvider).value;
    final inboxIds = thread?.inboxMessageIds ?? const <String>{};
    final shown = inboxOnly
        ? history.whenData(
            (messages) => [
              for (final message in messages)
                if (inboxIds.contains(message.id)) message,
            ],
          )
        : history;
    // A link in her words or in an answer: a task she names opens on top of
    // her, so back comes back to this conversation; another page in the app
    // closes her and goes there; anything else is opened the way every
    // agent's links are.
    void openLink(String url, String title) {
      final route = internalRouteFromMarkdownUrl(url);
      if (route == null) {
        handleMarkdownLinkTap(url, title).ignore();
        return;
      }
      if (_taskRoute.firstMatch(route)?.group(1) case final taskId?) {
        pushTaskDetailPage(context, taskId, rootNavigator: true);
        return;
      }
      onClose();
      beamToNamed(route);
    }

    final actions = FrontDoorActions(
      onOpenLink: (url) => openLink(url, ''),
      onFile: controller.fileUnderOwner,
      onDecline: controller.decline,
      onUndoDecline: controller.undoDecline,
      onTakeBack: controller.takeBack,
      onMakeTask: (doorId) =>
          FrontVoice.makeTask(ref, context, conversationId, doorId),
      onSaveNote: controller.saveAsNote,
      // What a door wrote lives on its own page: leave the sheet, then go.
      onOpen: (door) {
        final path = switch (door.record.outcome) {
          FrontDoorFiled(:final entryId) => '/journal/$entryId',
          FrontDoorTaskCreated(:final taskId) => '/tasks/$taskId',
          FrontDoorProjectCreated(:final projectId) => '/projects/$projectId',
          FrontDoorDayPlanned() => '/calendar',
          _ => null,
        };
        if (path == null) return;
        // The day surface shows the selected day: the planned one, not
        // whichever was picked there last.
        if (door.record.outcome case FrontDoorDayPlanned(:final day)) {
          ref.read(dailyOsNextSelectedDateProvider.notifier).select(day);
        }
        onClose();
        beamToNamed(path);
      },
      // The goal wizard opens with the words as its intention; nothing is
      // written by opening it, and the item keeps waiting.
      onStartGoal: (door) {
        // Leave the sheet, then go: the wizard is a page, not a modal.
        onClose();
        beamToNamed(goalCreatePathWith(intention: door.record.text));
      },
      // The project form opens with the words as its title; a project it
      // creates settles the item.
      onNewProject: (door) => controller.newProject(
        door.doorId,
        () => ref.read(frontNewProjectProvider)(context, door.record.text),
      ),
      // A change to today opens the Daily OS planning with the words given:
      // refining today's plan, or planning the day when there is none. The
      // plan changes only when the user accepts there; then the door
      // settles.
      onPlanDay: (door) => controller.planDay(
        door.doorId,
        () => ref.read(frontDayPlannerProvider)(context, door.record.text),
      ),
      // A source a journal answer cites opens on its own page.
      onOpenEvidence: (evidence) {
        final id = evidence.source.id;
        openLink(switch (evidence.kind) {
          QuerySourceKind.task => '/tasks/$id',
          QuerySourceKind.project => '/projects/$id',
          _ => '/journal/$id',
        }, '');
      },
    );

    return AgentChatView(
      agentId: frontAgentId,
      agentName: messages.frontChatTitle,
      // Each conversation keeps its own scroll position.
      conversationId: inboxOnly
          ? 'front-chat-inbox'
          : 'front-chat:${conversationId ?? ''}',
      history: shown,
      // A conversation with her, not a log: her words as prose, the user's
      // in a soft bubble; what was said goes out as it stops.
      conversational: true,
      // One reading column for the thread and the field under it, so the
      // field's edges line up with the messages on a wide window.
      contentMaxWidth: kProseMeasureWidth,
      composerEnabled: composerEnabled,
      voiceFirst: true,
      // `@` names a category she may see; naming one narrows her answer.
      composerHelper: mentions.isEmpty ? null : messages.frontChatMentionHint,
      mentionOptions: [
        for (final category in mentions)
          DesignSystemChatInputMention(
            label: category.name,
            color: colorFromCssHex(category.color),
          ),
      ],
      // A conversation not begun opens on her, and what she can do, in the
      // middle of where the thread will be.
      emptyState: inboxOnly
          ? null
          : Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(context.designTokens.spacing.step5),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: kProseMeasureWidth,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FrontChatHero(),
                      Text(
                        messages.frontChatEmpty,
                        textAlign: TextAlign.center,
                        style: context
                            .designTokens
                            .typography
                            .styles
                            .body
                            .bodyMedium
                            .copyWith(
                              color: context
                                  .designTokens
                                  .colors
                                  .text
                                  .mediumEmphasis,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      emptyMessage: inboxOnly
          ? messages.frontChatInboxEmpty
          : messages.frontChatEmpty,
      composerHint: messages.frontChatPlaceholder,
      sendingLabel: messages.frontChatResponding,
      draft: composer.draft,
      isSending: composer.isSending,
      hasFailedTurn: composer.failedMessage != null,
      onDraftChanged: controller.updateDraft,
      onSend: controller.send,
      // A spoken question gets a spoken answer.
      onSendSpoken: controller.sendSpoken,
      // Her ears are the Settings default's transcription slot, the words
      // as heard: never a discovered on-device engine, never a correction
      // pass that keeps the question waiting.
      resolveTranscriptionTarget: ref.watch(
        settingsDefaultDictationTargetProvider,
      ),
      onLinkTap: (_, url, title) => openLink(url, title),
      // A list of tasks in her words is drawn as task rows, her words
      // around it as she wrote them; an answer about what was completed
      // gets every task it found as cards, and one about logged time or
      // pull requests its chart, under her words. Any other reply is drawn
      // as usual.
      replyBodyBuilder: (context, message, prose) {
        // Cut from her words as written, before their dates became the
        // device's: a list line may end in when it was due, in ISO.
        final written = thread?.messages
            .where((m) => m.id == message.id)
            .firstOrNull
            ?.text;
        final closedTasks = thread?.closedTasksByMessageId[message.id];
        final carded = {...?closedTasks?.map((task) => task.id)};
        // A task the cards show is not drawn twice from her words.
        final parts = [
          for (final part in frontReplyParts(written ?? message.text))
            switch (part) {
              FrontReplyTasks(:final tasks) when carded.isNotEmpty =>
                FrontReplyTasks([
                  for (final task in tasks)
                    if (!carded.contains(task.id)) task,
                ]),
              _ => part,
            },
        ]..removeWhere((part) => part is FrontReplyTasks && part.tasks.isEmpty);
        final chart = thread?.loggedTimeByMessageId[message.id];
        final pullRequests = thread?.pullRequestsByMessageId[message.id];
        if (chart == null &&
            pullRequests == null &&
            closedTasks == null &&
            !parts.any((part) => part is FrontReplyTasks)) {
          return null;
        }
        final tokens = context.designTokens;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: tokens.spacing.step4,
          children: [
            for (final part in parts)
              switch (part) {
                FrontReplyText(:final markdown) => prose(deviceDays(markdown)),
                FrontReplyTasks(:final tasks) => FrontTaskList(
                  tasks: tasks,
                  onOpen: (mention) => openLink(
                    frontReferenceUrl(mention.kind, mention.id),
                    '',
                  ),
                ),
              },
            if (closedTasks != null)
              FrontClosedTaskList(
                key: ValueKey('front-closed-tasks-${message.id}'),
                tasks: closedTasks,
                onOpen: (id) => openLink(
                  frontReferenceUrl(FrontDestinationKind.task, id),
                  '',
                ),
              ),
            if (chart != null)
              FrontLoggedTimeChartCard(
                key: ValueKey('front-logged-time-${message.id}'),
                chart: chart,
              ),
            if (pullRequests != null)
              FrontPullRequestChartCard(
                key: ValueKey('front-pull-requests-${message.id}'),
                chart: pullRequests,
              ),
          ],
        );
      },
      onRetry: controller.retry,
      attachmentBuilder: (context, message) {
        if (thread == null) return null;
        final isHers = message.role == AgentChatRole.agent;
        // The doors ride her reply, as the stack of cards under her bubble;
        // until she has replied they sit under the user's.
        final doors = thread.doorsCarriedBy(message.id);
        final card = doors == null || doors.isEmpty
            ? null
            : FrontDoorCard(
                key: ValueKey('front-doors-${message.id}'),
                doors: doors,
                actions: actions,
                busyDoorIds: composer.busyDoorIds,
                failedDoorIds: composer.failedDoorIds,
                journalAccess: journalAccess,
              );
        // Chips only under her latest question: an older one has been
        // answered, or walked away from, and its options would send a reply
        // to a question nobody is asking any more.
        final options = isHers && message.id == latestId
            ? thread.optionsByMessageId[message.id]
            : null;
        final chips = options == null || options.isEmpty
            ? null
            : FrontAskOptionsRow(
                key: ValueKey('front-options-${message.id}'),
                options: options,
                enabled: !composer.isSending,
                onChosen: (option) => controller.sendText(option.label),
              );
        if (card != null && chips != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              card,
              SizedBox(height: context.designTokens.spacing.step2),
              chips,
            ],
          );
        }
        return card ?? chips;
      },
      // What her turn cost — the routing calls of the wake that wrote the
      // row — quietly under her words.
      footerTrailingBuilder: (context, message) {
        final runKey = message.runKey;
        if (message.role != AgentChatRole.agent || runKey == null) {
          return null;
        }
        return FrontTurnCostLine(runKey: runKey);
      },
      dividerBuilder: (context, message, previous) {
        if (previous != null &&
            _sameDay(previous.createdAt, message.createdAt)) {
          return null;
        }
        return DesignSystemDivider(
          label: _dayLabel(context, message.createdAt, locale),
        );
      },
    );
  }

  static bool _sameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  /// Today and yesterday by name, every other day by date.
  static String _dayLabel(BuildContext context, DateTime at, String locale) {
    final day = at.toLocal();
    final today = clock.now();
    if (_sameDay(day, today)) return context.messages.calendarTodayLabel;
    if (_sameDay(day, today.subtract(const Duration(days: 1)))) {
      return context.messages.frontChatYesterday;
    }
    return DateFormat.yMMMMEEEEd(locale).format(day);
  }
}
