import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/ui/chat/agent_chat_view.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/model/goal_measurable_record_offer.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_chat_controller.dart';
import 'package:lotti/features/goals/state/goal_measurable_capture_state.dart';
import 'package:lotti/features/goals/ui/goal_record_offer_card.dart';
import 'package:lotti/features/goals/ui/unified/unified_goal_status.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurables_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

class GoalAgentChatPane extends ConsumerWidget {
  const GoalAgentChatPane({
    required this.agentId,
    this.showHeader = true,
    super.key,
  });

  final String agentId;
  final bool showHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(agentIdentityProvider(agentId)).value;
    final healthAsync = ref.watch(goalAgentHealthProvider(agentId));
    final health = healthAsync.value;
    final composer = ref.watch(goalChatControllerProvider(agentId));
    final controller = ref.read(goalChatControllerProvider(agentId).notifier);
    final measurables = ref.watch(measurableDataTypesStreamProvider).value;
    final captureDecisions = ref
        .watch(goalMeasurableCaptureDecisionsProvider(agentId))
        .value;
    final name = identity is AgentIdentityEntity
        ? identity.displayName
        : context.messages.agentsPageTitle;
    // The subtitle is current STATE, not the aspiration: next to a Behind
    // chip elsewhere, the goal statement here read as the agent claiming
    // all is well. Only a RESOLVED health record carries a verdict — while
    // the first load is in flight (or has failed with no prior value) the
    // header shows no label rather than a false "Not enough data".
    // Same suppression the detail header and the list rows apply: beside a
    // published assessment, "Not enough data" is the app disagreeing with
    // itself in one viewport. On desktop this pane sits directly next to that
    // header, which is where the contradiction was most visible.
    final status = healthAsync.hasValue
        ? unifiedGoalStatusChip(
            health?.trackStatus,
            hasStandingAssessment:
                health?.reportOneLiner?.trim().isNotEmpty ?? false,
          )
        : null;
    final tokens = context.designTokens;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final now = clock.now();
    final shortDay = DateFormat.E(locale);
    final longDay = DateFormat.EEEE(locale);
    final recentDayLabels = <DateTime, List<String>>{
      for (var offset = 0; offset < 7; offset++)
        now.subtract(Duration(days: offset)): [
          shortDay.format(now.subtract(Duration(days: offset))),
          longDay.format(now.subtract(Duration(days: offset))),
          if (offset == 0) context.messages.calendarTodayLabel,
          if (offset == 1) context.messages.knowledgeGraphAgeYesterday,
        ],
    };

    Widget? attachmentBuilder(
      BuildContext _,
      AgentChatMessage message,
    ) {
      final spec = health?.spec;
      if (message.role != AgentChatRole.user ||
          measurables == null ||
          captureDecisions == null ||
          spec == null) {
        return null;
      }
      final decision = captureDecisions[message.id];
      if (decision != null) {
        return decision.recorded
            ? GoalRecordReceipt(
                entryCount: decision.entryCount,
                agentName: decision.agentName ?? name,
              )
            : null;
      }
      final offer = parseGoalMeasurableRecordOffer(
        message: message,
        criteria: spec.criteria,
        measurables: measurables,
        reference: now,
        recentDayLabels: recentDayLabels,
      );
      if (offer == null) return null;
      final measurable = measurables
          .where(
            (item) => item.id == offer.dataTypeId,
          )
          .firstOrNull;
      if (measurable == null) return null;
      return GoalRecordOfferCard(
        key: ValueKey('goal-record-offer-${message.id}'),
        agentId: agentId,
        agentName: name,
        offer: offer,
        measurable: measurable,
      );
    }

    return Column(
      children: [
        if (showHeader)
          DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.colors.background.level01,
              border: Border(
                bottom: BorderSide(color: tokens.colors.decorative.level01),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(tokens.spacing.step4),
              child: Row(
                children: [
                  Icon(
                    LottiIcons.aiSpark,
                    color: tokens.colors.interactive.enabled,
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: tokens.typography.styles.subtitle.subtitle2
                              .copyWith(
                                color: tokens.colors.text.highEmphasis,
                              ),
                        ),
                        // The same pill the list rows and the detail header
                        // wear — word AND hue — so this header can never
                        // disagree with the surfaces beside it.
                        if (status != null)
                          Padding(
                            padding: EdgeInsets.only(
                              top: tokens.spacing.step1,
                            ),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: UnifiedGoalStatusPill(status: status),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: AgentChatView(
            agentId: agentId,
            agentName: name,
            draft: composer.draft,
            isSending: composer.isSending,
            hasFailedTurn: composer.failedMessage != null,
            onDraftChanged: controller.updateDraft,
            onSend: controller.send,
            onRetry: controller.retry,
            attachmentBuilder: attachmentBuilder,
          ),
        ),
      ],
    );
  }
}
