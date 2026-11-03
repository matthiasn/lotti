part of 'goal_agent_detail_page.dart';

/// The §4b "About this agent" expander: the plumbing — lifetime cost pills
/// and the automatic-updates controls — folded behind one quiet row at the
/// foot of the dashboard, so what the agent SAYS outranks how it is kept
/// fresh everywhere above the fold.
class _GoalReportCard extends StatefulWidget {
  const _GoalReportCard({
    required this.report,
    required this.fallback,
    required this.fallbackMuted,
    required this.expanded,
    required this.onToggle,
  });

  final AgentReportEntity? report;
  final String fallback;
  final bool fallbackMuted;

  /// Whether "Show more" is open. Held by the read card, whose read-aloud
  /// control speaks what this body shows ([goalReportSpokenText]).
  final bool expanded;
  final VoidCallback onToggle;

  @override
  State<_GoalReportCard> createState() => _GoalReportCardState();
}

class _GoalReportCardState extends State<_GoalReportCard>
    with SingleTickerProviderStateMixin {
  /// Matches the task-details agent section: the body eases open rather than
  /// appearing, so the card reads as one surface revealing more of itself.
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: MotionDurations.medium2,
    value: widget.expanded ? 1 : 0,
  );
  late final Animation<double> _revealCurve = CurvedAnimation(
    parent: _reveal,
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _GoalReportCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded == oldWidget.expanded) return;
    if (widget.expanded) {
      _reveal.forward();
    } else {
      _reveal.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final report = widget.report;
    final tldr = report?.tldr?.trim();
    final content = report?.content.trim();
    final hasTldr = tldr != null && tldr.isNotEmpty;
    final hasContent = content != null && content.isNotEmpty;
    final sections = goalReportSections(report);
    final expandable = goalReportExpandable(report);
    final primary = hasTldr
        ? tldr
        : hasContent
        ? content
        : widget.fallback;

    // No card wrapper of its own: this body renders INSIDE the
    // Agent's-read hero card, which owns the surface, title and freshness
    // caption.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selectable, like the task-details agent section: a standing
        // report carries exact readings a user may well want to copy.
        SelectionArea(
          child: AgentMarkdownView(
            primary,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: report == null && widget.fallbackMuted
                  ? tokens.colors.text.lowEmphasis
                  : tokens.colors.text.highEmphasis,
            ),
          ),
        ),
        // What the user said, answered: with the summary rather than behind
        // Show more, and above what comes next. It is the one part of the
        // report written about the person's own words instead of the
        // numbers — on a journal goal, the part they came for.
        if (goalReportReflection(sections) case final reflection?) ...[
          SizedBox(height: tokens.spacing.step3),
          Text(
            context.messages.goalReportSectionReflection,
            key: const ValueKey('goal-report-reflection-heading'),
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          // Which of their words it answers, so "From your check-ins"
          // is checkable rather than taken on trust.
          if (_answeredOf(report) case final answered?) ...[
            Text(
              context.messages.goalReportReflectionAnswers(
                answered
                    .map(
                      DateFormat.MMMd(context.messages.localeName).format,
                    )
                    .join(', '),
              ),
              key: const ValueKey('goal-report-reflection-answers'),
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ],
          SizedBox(height: tokens.spacing.step1),
          SelectionArea(
            child: AgentMarkdownView(
              reflection,
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
          ),
        ],
        // The actions sit with the summary, not behind Show more. Inside
        // the expanded body they were reachable only by a tap most readers
        // never make — the one part of a standing report that asks
        // something of you, gated behind the part that only informs.
        if (goalReportActions(sections) case final actions?) ...[
          SizedBox(height: tokens.spacing.step3),
          // Named, so the briefing's weight reads at a glance: what stands
          // is a sentence above; what comes next is this list.
          Text(
            context.messages.goalReportSectionNext,
            key: const ValueKey('goal-report-next-heading'),
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step1),
          SelectionArea(
            child: AgentMarkdownView(
              [for (final action in actions) '- $action'].join('\n'),
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
          ),
        ],
        if (expandable)
          AnimatedBuilder(
            animation: _revealCurve,
            builder: (context, child) => _revealCurve.value == 0
                ? const SizedBox.shrink()
                : ClipRect(
                    child: Align(
                      alignment: Alignment.topLeft,
                      heightFactor: _revealCurve.value,
                      child: child,
                    ),
                  ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: tokens.spacing.step3),
                // Sections when the report carries them, the flat text when
                // it does not. The sentences are model-authored in the
                // user's own language, so the composer cannot wrap them in
                // headings without injecting English — the headings are
                // added here instead, which also means they follow the app
                // language rather than whichever one the report was
                // written in.
                SelectionArea(
                  child: sections != null
                      ? _GoalReportSections(sections: sections)
                      // Non-null by construction: with no sections,
                      // `expandable` is only true when there IS content.
                      : AgentMarkdownView(
                          content!,
                          style: tokens.typography.styles.body.bodySmall
                              .copyWith(
                                color: tokens.colors.text.highEmphasis,
                              ),
                        ),
                ),
              ],
            ),
          ),
        // The one action the summary offers. "Ask why" used to ride this
        // row too, but the header already carries a mic for a check-in and a
        // chat doorway — a third way into the same conversation, set in the
        // middle of a paragraph, was the least discoverable of the three and
        // the easiest to lose.
        if (expandable) ...[
          SizedBox(height: tokens.spacing.step1),
          DesignSystemButton(
            label: widget.expanded
                ? context.messages.aiResponseShowLess
                : context.messages.aiResponseShowMore,
            onPressed: widget.onToggle,
            variant: DesignSystemButtonVariant.tertiary,
            size: DesignSystemButtonSize.dense,
            trailingIcon: widget.expanded
                ? LottiIcons.collapse
                : LottiIcons.expand,
            alignsLabelToLeadingEdge: true,
            suppressHoverFill: true,
          ),
        ],
      ],
    );
  }
}

enum _GoalDetailMenuAction {
  edit,
  updateRead,
  automaticUpdates,
  internals,
  delete,
}

class _GoalActionsMenuButton extends ConsumerWidget {
  const _GoalActionsMenuButton({
    required this.agentId,
    required this.agentName,
    required this.canEdit,
    required this.onUpdateRead,
    required this.automaticUpdatesEnabled,
  });

  final String agentId;
  final String agentName;
  final bool canEdit;

  /// Requests a report refresh (§4b overflow: "Update read"); null while
  /// the goal is not active.
  final VoidCallback? onUpdateRead;

  /// Current automatic-updates preference, or null while the goal is not
  /// active (the item is then omitted). The AI card's footer deliberately
  /// carries only freshness + the manual trigger; this menu is where the
  /// standing preference lives.
  final bool? automaticUpdatesEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = context.messages;

    Future<void> run(_GoalDetailMenuAction action) async {
      switch (action) {
        case _GoalDetailMenuAction.edit:
          beamToNamed(goalEditPath(agentId));
        case _GoalDetailMenuAction.updateRead:
          onUpdateRead?.call();
        case _GoalDetailMenuAction.automaticUpdates:
          final enabled = automaticUpdatesEnabled;
          if (enabled != null) {
            try {
              await ref
                  .read(goalAgentServiceProvider)
                  .updateAutomaticUpdates(
                    agentId: agentId,
                    enabled: !enabled,
                  );
            } catch (_) {
              if (!context.mounted) return;
              ScaffoldMessenger.maybeOf(context)
                ?..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(content: Text(messages.saveFailedRetry)),
                );
            }
          }
        case _GoalDetailMenuAction.internals:
          await AgentInternalsPanel.show(
            context: context,
            agentId: agentId,
            agentName: agentName,
            subjectEntityId: ref.read(goalEntryIdProvider(agentId)),
          );
        case _GoalDetailMenuAction.delete:
          await _confirmAndDelete(context, ref);
      }
    }

    VoidCallback runs(_GoalDetailMenuAction action) =>
        // run answers its own failures (the automatic-updates write shows
        // a snackbar); the menu row only starts it.
        () => run(action);

    // The shared agent-surface menu: the goal's own action, then the
    // agent's, internals last among them, delete at the bottom — the same
    // surface, order and rows as the person page's menu.
    return AgentSurfaceMenuButton(
      key: const ValueKey('goal-menu'),
      semanticsLabel: MaterialLocalizations.of(context).showMenuTooltip,
      items: [
        if (canEdit)
          DesignSystemContextMenuItem(
            key: const ValueKey('goal-menu-edit'),
            icon: LottiIcons.edit,
            label: messages.goalFormEditTitle,
            onTap: runs(_GoalDetailMenuAction.edit),
          ),
        if (onUpdateRead != null)
          DesignSystemContextMenuItem(
            key: const ValueKey('goal-menu-update'),
            icon: LottiIcons.refresh,
            label: messages.taskAgentUpdateNow,
            onTap: runs(_GoalDetailMenuAction.updateRead),
            startsGroup: true,
          ),
        if (automaticUpdatesEnabled case final enabled?)
          DesignSystemContextMenuItem(
            key: const ValueKey('goal-menu-automatic-updates'),
            label: messages.taskAgentAutomaticUpdatesLabel,
            checked: enabled,
            onTap: runs(_GoalDetailMenuAction.automaticUpdates),
            startsGroup: onUpdateRead == null,
          ),
        agentInternalsMenuItem(
          context: context,
          key: const ValueKey('goal-menu-internals'),
          onTap: runs(_GoalDetailMenuAction.internals),
          startsGroup: onUpdateRead == null && automaticUpdatesEnabled == null,
        ),
        DesignSystemContextMenuItem(
          key: const ValueKey('goal-menu-delete'),
          icon: LottiIcons.delete,
          label: messages.goalDeleteMenuItem,
          isDestructive: true,
          onTap: runs(_GoalDetailMenuAction.delete),
          startsGroup: true,
        ),
      ],
      triggerBuilder: (context, open) => IconButton(
        key: const ValueKey('goal-menu-trigger'),
        tooltip: MaterialLocalizations.of(context).showMenuTooltip,
        icon: const Icon(LottiIcons.moreVertical),
        onPressed: open,
      ),
    );
  }

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final messages = context.messages;
    final confirmed = await showConfirmationModal(
      context: context,
      title: messages.goalDeleteDialogTitle,
      message: messages.goalDeleteDialogContent,
      cancelLabel: messages.cancelButton,
      confirmLabel: messages.goalDeleteConfirmButton,
    );
    if (confirmed) {
      try {
        final deleted = await ref
            .read(goalAgentServiceProvider)
            .deleteGoalAgent(agentId);
        if (!deleted || !context.mounted) return;
        beamToNamed(goalsRootPath);
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(context.messages.saveFailedRetry)),
          );
      }
    }
  }
}

/// The local dates of the check-ins the report's reflection says it answers,
/// oldest first and one per day, or null when it names none — a report from
/// before the record existed, or one whose reflection answered no check-in.
List<DateTime>? _answeredOf(AgentReportEntity? report) {
  final raw = report?.provenance[GoalReportProvenanceKeys.checkInsAnswered];
  if (raw is! List) return null;
  final days = <DateTime>{
    for (final value in raw)
      if (value is String)
        if (DateTime.tryParse(value)?.toLocal() case final at?)
          DateTime(at.year, at.month, at.day),
  };
  return days.isEmpty ? null : (days.toList()..sort());
}

/// The expanded report, rendered as titled sections.
///
/// Headings come from the app's catalogs rather than the model, so they read
/// in the user's language whatever language the report was written in, and a
/// section the model left empty is simply absent rather than a heading with
/// nothing beneath it.
class _GoalReportSections extends StatelessWidget {
  const _GoalReportSections({required this.sections});

  final Map<String, Object?> sections;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ordered = goalReportExpandedSections(sections, context.messages);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, (heading, body)) in ordered.indexed) ...[
          if (index > 0) SizedBox(height: tokens.spacing.step4),
          Text(
            heading,
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step1),
          // One step below the TLDR above them. Set at bodyMedium the section
          // bodies were LARGER than the subtitle2 headings labelling them —
          // an inverted ramp — and identical to the summary they expand on,
          // which made the summary read as a duplicated first paragraph.
          AgentMarkdownView(
            body,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
        ],
      ],
    );
  }
}
