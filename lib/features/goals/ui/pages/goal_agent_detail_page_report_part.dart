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
  });

  final AgentReportEntity? report;
  final String fallback;
  final bool fallbackMuted;

  @override
  State<_GoalReportCard> createState() => _GoalReportCardState();
}

class _GoalReportCardState extends State<_GoalReportCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  /// Matches the task-details agent section: the body eases open rather than
  /// appearing, so the card reads as one surface revealing more of itself.
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: MotionDurations.medium2,
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

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
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
    // A full text identical to the TLDR would make Show more a no-op that
    // merely repeats the same paragraph — hide the toggle instead.
    final sections = _sectionsOf(report);
    // A renderable sections payload is expandable even when the flat text
    // happens to equal the TLDR: without this the toggle vanished and the
    // sections became unreachable.
    final expandable =
        hasTldr && (sections != null || (hasContent && content != tldr));
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
        // The actions sit with the summary, not behind Show more. Inside
        // the expanded body they were reachable only by a tap most readers
        // never make — the one part of a standing report that asks
        // something of you, gated behind the part that only informs.
        if (_actionsOf(sections) case final actions?) ...[
          SizedBox(height: tokens.spacing.step3),
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
            label: _expanded
                ? context.messages.aiResponseShowLess
                : context.messages.aiResponseShowMore,
            onPressed: _toggle,
            variant: DesignSystemButtonVariant.tertiary,
            size: DesignSystemButtonSize.dense,
            trailingIcon: _expanded ? LottiIcons.collapse : LottiIcons.expand,
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
    final tokens = context.designTokens;
    final danger = tokens.colors.alert.error.ink;
    return PopupMenuButton<_GoalDetailMenuAction>(
      icon: const Icon(LottiIcons.moreVertical),
      onSelected: (action) async {
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
                    SnackBar(content: Text(context.messages.saveFailedRetry)),
                  );
              }
            }
          case _GoalDetailMenuAction.internals:
            Navigator.of(context).push(
              AgentInternalsPanel.route(
                context: context,
                agentId: agentId,
                agentName: agentName,
              ),
            );
          case _GoalDetailMenuAction.delete:
            await _confirmAndDelete(context, ref);
        }
      },
      itemBuilder: (context) => [
        if (canEdit)
          PopupMenuItem<_GoalDetailMenuAction>(
            value: _GoalDetailMenuAction.edit,
            child: Row(
              children: [
                const Icon(LottiIcons.edit),
                SizedBox(width: tokens.spacing.step3),
                Expanded(
                  child: Text(
                    context.messages.goalFormEditTitle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        if (onUpdateRead != null)
          PopupMenuItem<_GoalDetailMenuAction>(
            value: _GoalDetailMenuAction.updateRead,
            child: Row(
              children: [
                const Icon(LottiIcons.refresh),
                SizedBox(width: tokens.spacing.step3),
                Expanded(
                  child: Text(
                    context.messages.taskAgentUpdateNow,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        if (automaticUpdatesEnabled != null)
          CheckedPopupMenuItem<_GoalDetailMenuAction>(
            value: _GoalDetailMenuAction.automaticUpdates,
            checked: automaticUpdatesEnabled!,
            child: Text(
              context.messages.taskAgentAutomaticUpdatesLabel,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        PopupMenuItem<_GoalDetailMenuAction>(
          value: _GoalDetailMenuAction.internals,
          child: Row(
            children: [
              const Icon(LottiIcons.tune),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Text(
                  context.messages.aiCardOpenAgentInternals,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<_GoalDetailMenuAction>(
          value: _GoalDetailMenuAction.delete,
          child: Row(
            children: [
              Icon(LottiIcons.delete, color: danger),
              SizedBox(width: tokens.spacing.step3),
              Text(
                context.messages.goalDeleteMenuItem,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: danger,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final messages = dialogContext.messages;
        return AlertDialog(
          title: Text(messages.goalDeleteDialogTitle),
          content: Text(messages.goalDeleteDialogContent),
          actions: [
            DesignSystemButton(
              label: messages.cancelButton,
              variant: DesignSystemButtonVariant.tertiary,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            DesignSystemButton(
              label: messages.goalDeleteConfirmButton,
              variant: DesignSystemButtonVariant.danger,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );
    if (confirmed ?? false) {
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

/// The report's current actions, or null when it has none.
///
/// Read by the card directly so they can sit with the summary rather than
/// inside the expandable body: an action reachable only behind "Show more"
/// is an action most readers never see.
List<String>? _actionsOf(Map<String, Object?>? sections) {
  if (sections == null) return null;
  final actions = <String>[
    if (sections[GoalReportSectionKeys.nextActions] case final List<Object?> a)
      for (final item in a)
        if (item case final String text when text.trim().isNotEmpty)
          text.trim(),
  ];
  return actions.isEmpty ? null : actions;
}

/// The structured sections a report carries, or null when it has none —
/// a free-form report, or one written before sections were persisted.
Map<String, Object?>? _sectionsOf(AgentReportEntity? report) {
  final raw = report?.provenance[GoalReportProvenanceKeys.sections];
  if (raw is! Map) return null;
  final sections = <String, Object?>{};
  for (final entry in raw.entries) {
    if (entry.key is String) sections[entry.key as String] = entry.value;
  }
  // A payload has to RENDER something to count as a sectioned report. A map
  // of blanks — or one carrying only keys this build does not know — passed
  // the old non-empty check and won the branch, so the card opened on zero
  // headings and zero actions while `content` still held the real text.
  //
  // Only recognized keys count, for the same reason.
  var renderable = false;
  for (final key in const [
    GoalReportSectionKeys.currentPeriod,
    GoalReportSectionKeys.rollingWindow,
    GoalReportSectionKeys.latestChange,
    GoalReportSectionKeys.coverage,
  ]) {
    if (sections[key] case final String text when text.trim().isNotEmpty) {
      renderable = true;
    }
  }
  if (sections[GoalReportSectionKeys.nextActions] case final List<Object?> a) {
    if (a.any((item) => item is String && item.trim().isNotEmpty)) {
      renderable = true;
    }
  }
  return renderable ? sections : null;
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
    final messages = context.messages;
    final ordered = <(String, String)>[
      for (final (key, heading) in <(String, String)>[
        (
          GoalReportSectionKeys.currentPeriod,
          messages.goalReportSectionStanding,
        ),
        (GoalReportSectionKeys.rollingWindow, messages.goalReportSectionWindow),
        (GoalReportSectionKeys.latestChange, messages.goalReportSectionChange),
        (GoalReportSectionKeys.coverage, messages.goalReportSectionCoverage),
      ])
        if (sections[key] case final String body when body.trim().isNotEmpty)
          (heading, body.trim()),
    ];

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
