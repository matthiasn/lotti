part of 'journal_card.dart';

/// A modern journal list card with a single, consistent anatomy shared across
/// every entry type:
///
/// ```text
/// ┌──────────────────────────────────────────────┐
/// │ ▣  Primary content (title / text preview)   ★ │  ← glyph rail · title · status
/// │    relative date · metric chips                │  ← de-emphasized meta row
/// │    optional note preview                        │  ← secondary
/// │    label chips                                  │
/// └──────────────────────────────────────────────┘
/// ```
///
/// The leading glyph identifies the type at a glance, the brightest element is
/// the entry's own content, and structured data (health, workout, measurement,
/// survey) is humanised into compact chips instead of raw `key: value` dumps.
class ModernJournalCard extends StatelessWidget {
  const ModernJournalCard({
    required this.item,
    this.showLinkedDuration = false,
    this.removeHorizontalMargin = false,
    this.selected = false,
    super.key,
  });

  final JournalEntity item;
  final bool showLinkedDuration;
  final bool removeHorizontalMargin;

  /// Whether this entry is the one open in the desktop detail pane.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (item.meta.deletedAt != null) {
      return const SizedBox.shrink();
    }

    void onTap() {
      if (item is Task) {
        beamToNamed('/tasks/${item.meta.id}');
      } else if (item is JournalEvent) {
        beamToNamed('/events/${item.meta.id}');
      } else if (item case CheckInEntry(:final data)) {
        // A check-in's page is its person's, on the People tab.
        beamToNamed('/people/${data.relationshipId}/check-ins/${item.meta.id}');
      } else {
        beamToNamed('/journal/${item.meta.id}');
      }
    }

    final tokens = context.designTokens;

    return ModernBaseCard(
      onTap: onTap,
      selected: selected,
      backgroundColor: dsCardSurface(context),
      // Same flat material as DesignSystemSectionCard: hairline decorative
      // border, no drop shadow — list rows and the detail card are one
      // surface recipe, not two coincidentally similar ones.
      borderColor: tokens.colors.decorative.level01,
      customShadows: const [],
      // step2 vertical: an 8px seam between neighbours, so the canvas
      // actually separates cards instead of leaving a hairline stripe.
      margin: EdgeInsets.symmetric(
        horizontal: removeHorizontalMargin ? 0 : tokens.spacing.step5,
        vertical: tokens.spacing.step2,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step4,
        vertical: tokens.spacing.step4,
      ),
      child: _EntryCardContent(
        item: item,
        showLinkedDuration: showLinkedDuration,
      ),
    );
  }
}

/// The shared visual anatomy every journal card is laid out with.
class _EntryCardScaffold extends StatelessWidget {
  const _EntryCardScaffold({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.dateLabel,
    this.metaChips = const [],
    this.secondary,
    this.trailing,
    this.labelIds,
  });

  final IconData icon;
  final Color iconColor;
  final Widget title;
  final String dateLabel;
  final List<Widget> metaChips;
  final Widget? secondary;
  final Widget? trailing;
  final List<String>? labelIds;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final showLabels = labelIds != null && labelIds!.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TintedTypeGlyph(icon: icon, color: iconColor),
        SizedBox(width: tokens.spacing.step3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: title),
                  if (trailing != null) ...[
                    SizedBox(width: tokens.spacing.step2),
                    trailing!,
                  ],
                ],
              ),
              SizedBox(height: tokens.spacing.step1),
              // A lone metric on an otherwise bare card (Weight, a
              // measurement) shares the meta row with the date: one fact does
              // not need its own band, and the feed skims two rows tighter.
              if (metaChips.length == 1 && secondary == null && !showLabels)
                Row(
                  children: [
                    Flexible(child: _MetaRow(dateLabel: dateLabel)),
                    SizedBox(width: tokens.spacing.step3),
                    metaChips.single,
                  ],
                )
              else ...[
                _MetaRow(dateLabel: dateLabel),
                if (metaChips.isNotEmpty) ...[
                  SizedBox(height: tokens.spacing.step2),
                  Wrap(
                    spacing: tokens.spacing.step2,
                    runSpacing: tokens.spacing.step1,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: metaChips,
                  ),
                ],
              ],
              if (secondary != null) ...[
                SizedBox(height: tokens.spacing.step2),
                secondary!,
              ],
              if (showLabels) ...[
                SizedBox(height: tokens.spacing.step2),
                _JournalCardLabelsRow(labelIds: labelIds!),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// De-emphasized metadata line: just the relative date. The entry's category is
/// now conveyed by the colour of the glyph tile, so no category badge is shown
/// here (a meta-row badge previously collided with the date).
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.dateLabel});

  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Text(
      dateLabel,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      // mediumEmphasis, not outline: timestamps are wayfinding in a
      // chronological feed and were flagged as too faint to skim by.
      style: tokens.typography.styles.others.caption.copyWith(
        color: tokens.colors.text.mediumEmphasis,
      ),
    );
  }
}

/// Habit completions resolve the habit definition via a notification-driven
/// stream so the card live-updates when the habit (or privacy) changes.
class _HabitCompletionContent extends StatefulWidget {
  const _HabitCompletionContent({
    required this.habitCompletion,
    required this.dateLabel,
    this.trailing,
    this.labelIds,
  });

  final HabitCompletionEntry habitCompletion;
  final String dateLabel;
  final Widget? trailing;
  final List<String>? labelIds;

  @override
  State<_HabitCompletionContent> createState() =>
      _HabitCompletionContentState();
}

class _HabitCompletionContentState extends State<_HabitCompletionContent> {
  late Stream<HabitDefinition?> _habitStream;

  @override
  void initState() {
    super.initState();
    _habitStream = _createStream();
  }

  @override
  void didUpdateWidget(covariant _HabitCompletionContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only re-subscribe when the habit actually changes; a plain parent
    // rebuild must not recreate the stream (which would refetch every frame).
    if (oldWidget.habitCompletion.data.habitId !=
        widget.habitCompletion.data.habitId) {
      _habitStream = _createStream();
    }
  }

  Stream<HabitDefinition?> _createStream() => notificationDrivenItemStream(
    notifications: getIt<UpdateNotifications>(),
    notificationKeys: {habitsNotification, privateToggleNotification},
    fetcher: () =>
        getIt<JournalDb>().getHabitById(widget.habitCompletion.data.habitId),
  );

  @override
  Widget build(BuildContext context) {
    final completion =
        widget.habitCompletion.data.completionType ??
        HabitCompletionType.success;

    return StreamBuilder<HabitDefinition?>(
      stream: _habitStream,
      builder: (context, snapshot) {
        final habit = snapshot.data;
        final name =
            habit?.name ?? context.messages.entryTypeLabelHabitCompletionEntry;
        final categoryColor = _habitColor(context, habit);
        final note = widget.habitCompletion.entryText?.plainText.trim() ?? '';

        return _EntryCardScaffold(
          icon: _completionIcon(completion),
          iconColor: categoryColor,
          title: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.designTokens.typography.styles.subtitle.subtitle2
                .copyWith(color: context.designTokens.colors.text.highEmphasis),
          ),
          dateLabel: widget.dateLabel,
          metaChips: [_statusChip(context, completion)],
          secondary: note.isEmpty
              ? null
              : Text(
                  note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.designTokens.typography.styles.body.bodySmall
                      .copyWith(
                        color: context.designTokens.colors.text.mediumEmphasis,
                      ),
                ),
          trailing: widget.trailing,
          labelIds: widget.labelIds,
        );
      },
    );
  }

  Widget _statusChip(BuildContext context, HabitCompletionType type) {
    final cs = context.colorScheme;
    final (label, color) = switch (type) {
      HabitCompletionType.success => (
        context.messages.habitCompletionStatusCompleted,
        context.designTokens.colors.alert.success.ink,
      ),
      HabitCompletionType.skip => (
        context.messages.habitCompletionStatusSkipped,
        cs.onSurfaceVariant,
      ),
      HabitCompletionType.fail => (
        context.messages.habitCompletionStatusFailed,
        cs.error,
      ),
      HabitCompletionType.open => (
        context.messages.habitCompletionStatusOpen,
        cs.onSurfaceVariant,
      ),
    };
    return ModernStatusChip(
      label: label,
      color: color,
      icon: _completionIcon(type),
    );
  }

  IconData _completionIcon(HabitCompletionType type) {
    return switch (type) {
      HabitCompletionType.success => LottiIcons.confirmCircled,
      HabitCompletionType.skip => LottiIcons.removeCircled,
      HabitCompletionType.fail => LottiIcons.closeCircled,
      HabitCompletionType.open => LottiIcons.radioUnselected,
    };
  }

  Color _habitColor(BuildContext context, HabitDefinition? habit) {
    final accent = context.designTokens.colors.interactive.enabled;
    if (habit == null) {
      return accent;
    }
    final category = getIt<EntitiesCacheService>().getCategoryById(
      habit.categoryId,
    );
    return category != null ? colorFromCssHex(category.color) : accent;
  }
}

/// Checklists resolve their completion (`done/total`) via the shared
/// completion controller so the card surfaces progress at a glance.
class _ChecklistContent extends ConsumerWidget {
  const _ChecklistContent({
    required this.checklist,
    required this.dateLabel,
    required this.iconColor,
    this.trailing,
    this.labelIds,
  });

  final Checklist checklist;
  final String dateLabel;
  final Color iconColor;
  final Widget? trailing;
  final List<String>? labelIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref
        .watch(
          checklistCompletionControllerProvider((
            id: checklist.meta.id,
            taskId: null,
          )),
        )
        .value;

    // Reserve the status chip + progress bar from the first paint using the
    // checklist's synchronous linked-item count, so the row keeps a stable
    // height while the async completion counts resolve — otherwise the card
    // grows after load and shoves the feed below it as you scroll. The
    // completed count fills in (0 until resolved) without changing the layout.
    final total =
        counts?.totalCount ?? checklist.data.linkedChecklistItems.length;
    final completed = counts?.completedCount ?? 0;

    final metaChips = <Widget>[];
    Widget? secondary;
    if (total > 0) {
      metaChips.add(
        ModernStatusChip(
          label: '$completed/$total',
          color: context.designTokens.colors.interactive.enabled,
          // The double tick, not the list: this chip counts what is *done*,
          // while the card's leading glyph names the entry type. Material drew
          // them `checklist_rounded` and `mdi:checkAll` — two pictures that
          // Lucide expresses as one, so without this the card showed the same
          // mark twice.
          icon: LottiIcons.confirmAll,
        ),
      );
      secondary = _TypeProgressBar(value: completed / total);
    }

    return _EntryCardScaffold(
      icon: LottiIcons.checkAll,
      iconColor: iconColor,
      title: Text(
        checklist.data.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.designTokens.typography.styles.subtitle.subtitle2
            .copyWith(color: context.designTokens.colors.text.highEmphasis),
      ),
      dateLabel: dateLabel,
      metaChips: metaChips,
      secondary: secondary,
      trailing: trailing,
      labelIds: labelIds,
    );
  }
}

/// A thin, rounded completion bar used by the checklist card.
class _TypeProgressBar extends StatelessWidget {
  const _TypeProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(context.designTokens.radii.xs),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 4,
        backgroundColor: cs.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation<Color>(
          context.designTokens.colors.interactive.enabled,
        ),
      ),
    );
  }
}

/// Internal widget that listens to label updates to rebuild when labels change.
class _JournalCardLabelsRow extends ConsumerWidget {
  const _JournalCardLabelsRow({required this.labelIds});

  final List<String> labelIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch label stream to rebuild when labels change globally
    ref.watch(labelsStreamProvider);

    final cache = getIt<EntitiesCacheService>();
    final showPrivate = cache.showPrivateEntries;

    // Use cache for fast label lookups
    final labels =
        labelIds
            .map(cache.getLabelById)
            .whereType<LabelDefinition>()
            .where((label) => showPrivate || !(label.private ?? false))
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    if (labels.isEmpty) {
      return const SizedBox.shrink();
    }

    final tokens = context.designTokens;
    return Wrap(
      spacing: tokens.spacing.step2,
      runSpacing: tokens.spacing.step2,
      children: labels.map((label) => LabelChip(label: label)).toList(),
    );
  }
}
