import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/ui/chat/agent_chat_view.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_controller.dart';
import 'package:lotti/features/daily_os_next/state/selected_date_provider.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/state/front_chat_controller.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
import 'package:lotti/features/front_agent/state/front_journal_access_provider.dart';
import 'package:lotti/features/front_agent/ui/front_ask_options_row.dart';
import 'package:lotti/features/front_agent/ui/front_category_chips.dart';
import 'package:lotti/features/front_agent/ui/front_chat_header.dart';
import 'package:lotti/features/front_agent/ui/front_chat_hero.dart';
import 'package:lotti/features/front_agent/ui/front_chat_voice.dart';
import 'package:lotti/features/front_agent/ui/front_conversation_list.dart';
import 'package:lotti/features/front_agent/ui/front_door_card.dart';
import 'package:lotti/features/front_agent/ui/front_door_wizards.dart';
import 'package:lotti/features/front_agent/ui/front_turn_cost_line.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/goal_routes.dart';
import 'package:material_ui/material_ui.dart';

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
    final beside = listWidth != null;
    // Beside the conversation the list is always there: it never opens
    // over it.
    final listOpen = !beside && ref.watch(frontConversationListOpenProvider);
    // Her reply to a spoken turn is spoken back, list open or not.
    FrontVoice.listenForSpokenReply(ref, context);
    final inboxOnly = ref.watch(frontInboxFilterProvider);
    // A thread opens at its top, her bust in view, so the header lets her
    // go: on another conversation, and on the thread coming back from the
    // list (it is rebuilt at its top). Listened here, where it is always
    // mounted, not in the thread, which the list replaces.
    void letHerGo(Object? previous, Object? next) {
      if (previous == next) return;
      ref.read(frontHeroScrolledProvider.notifier).reset();
      // What was being said belongs to the conversation it was said in:
      // leaving it — for another, or for the list — lets it go, rather than
      // sending it into wherever the user went.
      // (Only on leaving one: a conversation resolving as the surface opens
      // is where the user already is.)
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
                SizedBox(
                  width: listWidth,
                  child: const FrontConversationList(beside: true),
                ),
                const DesignSystemDivider(
                  orientation: DesignSystemDividerOrientation.vertical,
                ),
                Expanded(
                  child: Column(
                    children: [
                      FrontChatHeader(onClose: onClose, listBeside: true),
                      Expanded(child: _Body()),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                FrontChatHeader(onClose: onClose),
                Expanded(
                  child: listOpen ? const FrontConversationList() : _Body(),
                ),
              ],
            ),
    );
  }
}

class _Body extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = context.messages;
    final threadAsync = ref.watch(frontChatThreadProvider);
    // Read through `.value`: a reload keeps the shown thread on screen
    // (stay while reload); only a first load with nothing yet shows a shell.
    final thread = threadAsync.value;
    final history = switch (thread) {
      null when threadAsync.hasError => AsyncError<List<AgentChatMessage>>(
        threadAsync.error!,
        threadAsync.stackTrace ?? StackTrace.empty,
      ),
      null => const AsyncLoading<List<AgentChatMessage>>(),
      final t => AsyncData(t.messages),
    };
    final composer = ref.watch(frontChatControllerProvider);
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
    final actions = FrontDoorActions(
      onFile: controller.fileUnderOwner,
      onDecline: controller.decline,
      onUndoDecline: controller.undoDecline,
      onTakeBack: controller.takeBack,
      onMakeTask: controller.makeTask,
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
        Navigator.of(context).maybePop();
        beamToNamed(path);
      },
      // The goal wizard opens with the words as its intention; nothing is
      // written by opening it, and the item keeps waiting.
      onStartGoal: (door) {
        // Leave the sheet, then go: the wizard is a page, not a modal.
        Navigator.of(context).maybePop();
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
        Navigator.of(context).maybePop();
        beamToNamed(switch (evidence.kind) {
          QuerySourceKind.task => '/tasks/$id',
          QuerySourceKind.project => '/projects/$id',
          _ => '/journal/$id',
        });
      },
    );

    return AgentChatView(
      // The thread's scroll moves her: once her bust has gone by, the
      // header carries her and the title in a line.
      onThreadScrolled: (metrics) =>
          ref.read(frontHeroScrolledProvider.notifier).follow(metrics.pixels),
      agentId: frontAgentId,
      agentName: messages.frontChatTitle,
      // Where the question is asked, its scope: the conversation's chips,
      // in the composer — not in the inbox, which spans every conversation.
      composerHeader: inboxOnly ? null : const FrontCategoryChips(),
      // Each conversation keeps its own scroll position.
      conversationId: inboxOnly
          ? 'front-chat-inbox'
          : 'front-chat:${conversationId ?? ''}',
      history: shown,
      // A conversation with her, not a log: her words as prose, the user's
      // in a soft bubble, and a talk control that leads.
      conversational: true,
      voiceFirst: true,
      // She leads the thread, and scrolls away with it.
      leading: inboxOnly ? null : const FrontChatHero(),
      // A conversation not begun opens on her, and what she can do.
      emptyState: inboxOnly
          ? null
          : ListView(
              padding: EdgeInsets.all(context.designTokens.spacing.step5),
              children: [
                const FrontChatHero(),
                Text(
                  messages.frontChatEmpty,
                  textAlign: TextAlign.center,
                  style: context.designTokens.typography.styles.body.bodyMedium
                      .copyWith(
                        color: context.designTokens.colors.text.mediumEmphasis,
                      ),
                ),
              ],
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
