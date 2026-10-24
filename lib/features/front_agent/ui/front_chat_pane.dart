import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/ui/chat/agent_chat_view.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/state/front_chat_controller.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/ui/front_ask_options_row.dart';
import 'package:lotti/features/front_agent/ui/front_chat_header.dart';
import 'package:lotti/features/front_agent/ui/front_door_card.dart';
import 'package:lotti/features/front_agent/ui/front_turn_cost_line.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
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
    final controller = ref.read(frontChatControllerProvider.notifier);
    final latestId = thread?.messages.lastOrNull?.id;
    final locale = Localizations.localeOf(context).toLanguageTag();

    return AgentChatView(
      agentId: frontAgentId,
      agentName: messages.frontChatTitle,
      conversationId: 'front-chat',
      history: history,
      emptyMessage: messages.frontChatEmpty,
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
        final doors = thread.doorsByMessageId[message.id];
        if (doors != null && doors.isNotEmpty) {
          return FrontDoorCard(
            key: ValueKey('front-doors-${message.id}'),
            doors: doors,
          );
        }
        if (message.role != AgentChatRole.agent) return null;
        // Chips only under her latest question: an older one has been
        // answered, or walked away from, and its options would send a reply
        // to a question nobody is asking any more.
        final options = thread.optionsByMessageId[message.id];
        final runKey = message.runKey;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (options != null &&
                options.isNotEmpty &&
                message.id == latestId) ...[
              FrontAskOptionsRow(
                key: ValueKey('front-options-${message.id}'),
                options: options,
                enabled: !composer.isSending,
                onChosen: (option) => controller.sendText(option.label),
              ),
              SizedBox(height: context.designTokens.spacing.step1),
            ],
            // What her turn cost: the routing calls of the wake that wrote
            // this row.
            if (runKey != null) FrontTurnCostLine(runKey: runKey),
          ],
        );
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
