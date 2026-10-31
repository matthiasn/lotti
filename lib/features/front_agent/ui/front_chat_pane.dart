import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/ui/chat/agent_chat_view.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/state/front_chat_controller.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
import 'package:lotti/features/front_agent/state/front_journal_access_provider.dart';
import 'package:lotti/features/front_agent/ui/front_ask_options_row.dart';
import 'package:lotti/features/front_agent/ui/front_chat_header.dart';
import 'package:lotti/features/front_agent/ui/front_door_card.dart';
import 'package:lotti/features/front_agent/ui/front_turn_cost_line.dart';
import 'package:lotti/features/projects/ui/widgets/project_create_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/goal_routes.dart';
import 'package:material_ui/material_ui.dart';

/// The companion's chat: one continuous thread across days (decision 7),
/// under her header, in the shared [AgentChatView].
///
/// What differs from a goal's or a person's chat is what hangs off a
/// message: under a routed turn, the doors it was taken through and what
/// came back, attributed to each owner; under her latest clarifying
/// question, the choices as chips. A day divider sits between messages of
/// different days.
class FrontChatPane extends ConsumerWidget {
  const FrontChatPane({required this.onClose, super.key});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        FrontChatHeader(onClose: onClose),
        Expanded(child: _Body()),
      ],
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
      onFile: controller.fileUnderTask,
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
          _ => null,
        };
        if (path == null) return;
        Navigator.of(context).maybePop();
        beamToNamed(path);
      },
      // The wizards are not pre-filled: they open plain, the words stay in
      // the thread, and the door keeps waiting until a chip that writes
      // takes it (nothing is written by opening a wizard).
      onStartGoal: (_) {
        // Leave the sheet, then go: the wizard is a page, not a modal.
        Navigator.of(context).maybePop();
        beamToNamed(goalCreatePath);
      },
      onNewProject: (_) => showProjectCreateModal(context: context),
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
      agentId: frontAgentId,
      agentName: messages.frontChatTitle,
      conversationId: inboxOnly ? 'front-chat-inbox' : 'front-chat',
      history: shown,
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
      // row — tails the bubble's footer line.
      footerTrailingBuilder: (context, message) {
        final runKey = message.runKey;
        if (message.role != AgentChatRole.agent || runKey == null) return null;
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
