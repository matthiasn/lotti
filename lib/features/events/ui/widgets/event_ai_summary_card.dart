import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_report_provenance.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/event_agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/ui/agent_automation_row.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/tldr_section_part.dart';
import 'package:lotti/features/agents/ui/task_agent_model_identity.dart';
import 'package:lotti/features/agents/ui/widgets/ai_card_chrome.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/events/ui/widgets/event_passive_summary_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The event agent's living recap, on the same card the task and project
/// agents use.
///
/// [AgentSummaryCardSurface] gives it the shared AI surface — the accent wash,
/// hairline and radius, and no shadow — and the reading order is the task
/// card's: the identity header (the agent's name opens its internals), the
/// recap's TLDR with *Read more* for the full recap, then the freshness strip
/// with *Update now*, which re-wakes the agent. Before the first recap the
/// body is the awaiting hint; a report that fails to load says so instead.
///
/// With no event agent attached it falls back to [fallbackSummary] on the
/// plain [EventPassiveSummaryCard], and renders nothing when there is neither.
///
/// The event's **rating and cover are never shown or touched here** — the agent
/// has no authority over them, so this card never surfaces or edits them.
class EventAiSummaryCard extends ConsumerWidget {
  const EventAiSummaryCard({
    required this.eventId,
    this.fallbackSummary,
    super.key,
  });

  final String eventId;

  /// The passive summary, shown only when no event agent is attached.
  final String? fallbackSummary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agent = ref
        .watch(eventAgentProvider(eventId))
        .value
        ?.mapOrNull(agent: (a) => a);

    if (agent == null) {
      final fallback = fallbackSummary?.trim();
      if (fallback == null || fallback.isEmpty) {
        return const SizedBox.shrink();
      }
      return EventPassiveSummaryCard(summary: fallback);
    }
    return _EventAgentRecapCard(identity: agent);
  }
}

class _EventAgentRecapCard extends ConsumerStatefulWidget {
  const _EventAgentRecapCard({required this.identity});

  final AgentIdentityEntity identity;

  @override
  ConsumerState<_EventAgentRecapCard> createState() =>
      _EventAgentRecapCardState();
}

class _EventAgentRecapCardState extends ConsumerState<_EventAgentRecapCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final agentId = widget.identity.agentId;

    // `.value` keeps the last recap through a background reload (a wake, a
    // sync), so the card never drops back to its empty state while the
    // report refreshes.
    final reportAsync = ref.watch(agentReportProvider(agentId));
    final report = reportAsync.value?.mapOrNull(agentReport: (r) => r);
    final isRunning = ref.watch(agentIsRunningProvider(agentId)).value ?? false;
    final state = ref
        .watch(agentStateProvider(agentId))
        .value
        ?.mapOrNull(agentState: (s) => s);
    final setup = ref.watch(taskAgentResolvedSetupProvider(agentId)).value;
    final identityData = TaskAgentModelIdentityViewData.fromResolution(
      setup: setup,
      reportProvenance: report == null
          ? null
          : ReportInferenceProvenance.tryRead(report.provenance),
      hasReport: report != null,
    );
    final inferenceAvailable =
        identityData.presentation != TaskAgentIdentityPresentation.disabled &&
        identityData.presentation != TaskAgentIdentityPresentation.broken;
    final template = ref.watch(templateForAgentProvider(agentId)).value;
    final templateName = template is AgentTemplateEntity
        ? template.displayName.trim()
        : null;
    final agentName = templateName == null || templateName.isEmpty
        ? widget.identity.displayName
        : templateName;

    final tldr = resolveReportTldr(report);
    final hasReportContent = tldr.isNotEmpty;

    void openInternals() => AgentInternalsPanel.show(
      context: context,
      agentId: agentId,
      agentName: agentName,
    );

    final Widget body;
    if (hasReportContent) {
      body = TldrBody(
        disclosureKey: const ValueKey('eventAgentReportDisclosure'),
        tldr: tldr,
        expanded: _expanded,
        additionalReport: resolveReportAdditional(report),
        onToggle: () => setState(() => _expanded = !_expanded),
        onOpenInternals: openInternals,
      );
    } else {
      // A load that failed says so; otherwise the agent simply has nothing
      // to narrate yet. A first load in flight shows neither — the header
      // and strip stand alone for that moment, as on a task's card.
      final hint = reportAsync.hasError
          ? context.messages.eventsRecapUnavailable
          : reportAsync.hasValue
          ? context.messages.eventsRecapAwaitingContent
          : null;
      body = hint == null
          ? const SizedBox.shrink()
          : Padding(
              padding: EdgeInsets.only(bottom: tokens.spacing.step3),
              child: Text(
                hint,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.aiCard.metaText,
                ),
              ),
            );
    }

    return AgentSummaryCardSurface(
      children: [
        TldrHeader(agentName: agentName, onAgentTap: openInternals),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.cardPadding),
          child: body,
        ),
        // The freshness word and the manual trigger, on the summary's leading
        // edge; the card pays the bottom inset, as the task card does.
        Padding(
          padding: EdgeInsets.only(
            left: tokens.spacing.cardPadding,
            right: tokens.spacing.cardPadding,
            bottom: tokens.spacing.step4,
          ),
          child: AgentAutomationRow.compact(
            inferenceAvailable: inferenceAvailable,
            isRunning: isRunning,
            hasReportContent: hasReportContent,
            // A photo or note added since the recap queues a wake behind
            // the coalescing window: that deadline is the only trace of
            // the change until it fires, and the recap is just as behind
            // meanwhile — so it counts, and its countdown rides Update now,
            // as on a task's card.
            isStale: state?.isReportBehindAt(clock.now()) ?? false,
            nextWakeAt: state?.nextWakeAt,
            reportUpdatedAt: report?.createdAt,
            onRunNow: inferenceAvailable
                ? () => ref
                      .read(eventAgentServiceProvider)
                      .triggerReanalysis(agentId)
                : null,
          ),
        ),
      ],
    );
  }
}
