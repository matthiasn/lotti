import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_icon.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_timeline_models.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/events/ui/widgets/linked_event_card.dart';
import 'package:lotti/features/front_agent/model/front_due_section.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';
import 'package:lotti/features/front_agent/state/front_entity_preview_provider.dart';
import 'package:lotti/features/tasks/ui/cover_art_thumbnail.dart';
import 'package:lotti/features/tasks/ui/due_date_text.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_task_row.dart'
    show StatusGlyph;
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_chips.dart'
    show TaskShowcasePriorityGlyph;
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/utils/entry_tools.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for her preview cards.
@visibleForTesting
abstract final class FrontEntityPreviewKeys {
  static Key card(String id) => Key('front-entity-preview-$id');
  static Key cover(String id) => Key('front-entity-preview-cover-$id');
  static Key estimate(String id) => Key('front-entity-preview-estimate-$id');
  static Key priority(String id) => Key('front-entity-preview-priority-$id');
  static Key block(String id, int index) =>
      Key('front-entity-preview-block-$id-$index');
  static Key more(String id) => Key('front-entity-preview-more-$id');
}

/// Entities as a stack of preview cards under her words — what a turn made,
/// or what her words list: a task as a compact card, an event as the app's
/// event card, a day's plan as its blocks, a project as its title. [onOpen]
/// is given the reference of the card tapped.
class FrontEntityPreviewList extends StatelessWidget {
  const FrontEntityPreviewList({
    required this.references,
    required this.onOpen,
    super.key,
  });

  final List<FrontEntityReference> references;
  final ValueChanged<FrontEntityReference> onOpen;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: context.designTokens.spacing.step2,
    children: [
      for (final reference in references)
        switch (reference.kind) {
          FrontEntityKind.task => FrontEntityPreviewCompactCard(
            key: FrontEntityPreviewKeys.card(reference.id),
            reference: reference,
            onTap: () => onOpen(reference),
          ),
          FrontEntityKind.event => FrontEntityPreviewRichCard(
            key: FrontEntityPreviewKeys.card(reference.id),
            reference: reference,
            onTap: () => onOpen(reference),
          ),
          FrontEntityKind.dayPlan => FrontEntityPreviewDayCard(
            key: FrontEntityPreviewKeys.card(reference.id),
            reference: reference,
            onTap: () => onOpen(reference),
          ),
          // No preview of its own yet: its title, under the folder glyph.
          FrontEntityKind.project => _TitleOnly(
            key: FrontEntityPreviewKeys.card(reference.id),
            reference: reference,
            onTap: () => onOpen(reference),
          ),
        },
    ],
  );
}

/// One entity as a compact card: its cover or status, title, its agent's
/// one-liner, then status, category, when it is due and how long it is
/// estimated to take — kept current as it changes. A tap opens it. Until it
/// has loaded, or if it is gone, the title it was made with stands alone,
/// and still opens it.
class FrontEntityPreviewCompactCard extends ConsumerWidget {
  const FrontEntityPreviewCompactCard({
    required this.reference,
    required this.onTap,
    super.key,
  });

  final FrontEntityReference reference;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.value`: a reload keeps the card as it was until the new one lands.
    final preview = ref
        .watch(frontEntityPreviewProvider((reference.kind, reference.id)))
        .value;
    return switch (preview) {
      final FrontTaskPreview task => _PreviewSurface(
        child: _TaskPreviewContent(task: task, onTap: onTap),
      ),
      FrontEventPreview() || FrontDayPlanPreview() || null => _TitleOnly(
        reference: reference,
        onTap: onTap,
      ),
    };
  }
}

/// One event as the app draws it wherever an event is linked — its cover,
/// title and rating, category, date and status, and its summary — kept
/// current as it changes. A tap opens it. Until it has loaded, or if it is
/// gone, the title it was made with stands alone, and still opens it.
class FrontEntityPreviewRichCard extends ConsumerWidget {
  const FrontEntityPreviewRichCard({
    required this.reference,
    required this.onTap,
    super.key,
  });

  final FrontEntityReference reference;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.value`: a reload keeps the card as it was until the new one lands.
    final preview = ref
        .watch(frontEntityPreviewProvider((reference.kind, reference.id)))
        .value;
    return switch (preview) {
      FrontEventPreview(:final event) => LinkedEventCard(
        event: event,
        onTap: onTap,
      ),
      FrontTaskPreview() || FrontDayPlanPreview() || null => _TitleOnly(
        reference: reference,
        onTap: onTap,
      ),
    };
  }
}

/// A preview card's surface: the card colour, the medium radius and a
/// hairline border.
class _PreviewSurface extends StatelessWidget {
  const _PreviewSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dsCardSurface(context),
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(
          color: tokens.colors.decorative.level01,
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.radii.m),
        child: child,
      ),
    );
  }
}

/// The title an entity was made or named with, alone on a card under its
/// kind's glyph, still opening it: what a card shows before its preview has
/// loaded and after the entity is gone — and all a project shows yet.
class _TitleOnly extends StatelessWidget {
  const _TitleOnly({required this.reference, required this.onTap, super.key});

  final FrontEntityReference reference;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _PreviewSurface(
    child: DesignSystemListItem(
      title: reference.title,
      titleMaxLines: 2,
      size: DesignSystemListItemSize.small,
      onTap: onTap,
      leading: Icon(
        switch (reference.kind) {
          FrontEntityKind.task => LottiIcons.checkboxChecked,
          FrontEntityKind.project => LottiIcons.folder,
          FrontEntityKind.event ||
          FrontEntityKind.dayPlan => LottiIcons.calendar,
        },
        size: IconSizes.s,
        color: context.designTokens.colors.text.mediumEmphasis,
      ),
      trailingExtra: const _Chevron(),
    ),
  );
}

/// A task's card content, from its live [task] preview.
class _TaskPreviewContent extends ConsumerWidget {
  const _TaskPreviewContent({required this.task, required this.onTap});

  final FrontTaskPreview task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final statusLabel = taskLabelFromStatusString(
      task.status.toDbString,
      context,
    );
    final category = ref
        .watch(entitiesCacheServiceProvider)
        ?.getCategoryById(task.categoryId);
    final oneLiner = task.oneLiner;
    final due = task.settled ? null : task.due;
    final estimate = task.settled ? null : task.estimate;
    final estimateText = estimate == null
        ? null
        : formatRangeDuration(estimate);
    final coverArtId = task.coverArtId;
    final meta = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );
    return DesignSystemListItem(
      title: task.title,
      titleMaxLines: 2,
      size: DesignSystemListItemSize.small,
      onTap: onTap,
      semanticsLabel: [
        task.title,
        ?oneLiner,
        statusLabel,
        ?category?.name,
        if (!task.settled) task.priority.short,
        if (estimateText != null)
          '${context.messages.taskEstimateLabel} $estimateText',
      ].join(', '),
      // The cover, when it has one; else how it stands.
      leading: coverArtId == null
          ? StatusGlyph(status: task.status, tooltip: statusLabel)
          : ClipRRect(
              key: FrontEntityPreviewKeys.cover(task.entityId),
              borderRadius: BorderRadius.circular(tokens.radii.s),
              child: CoverArtThumbnail(
                imageId: coverArtId,
                size: ControlSizes.iconChip,
                cropX: task.coverArtCropX,
              ),
            ),
      subtitleSpans: [
        // In the AI ink the tasks list gives a one-liner.
        if (oneLiner != null)
          TextSpan(
            text: '$oneLiner\n',
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.aiCard.accent,
            ),
          ),
        TextSpan(text: statusLabel),
        if (category != null) ...[
          const TextSpan(text: ' · '),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: ColorIcon(
              colorFromCssHex(category.color),
              size: IconSizes.xs,
            ),
          ),
          TextSpan(text: ' ${category.name}'),
        ],
        if (due != null) ...[
          const TextSpan(text: '   '),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: DueDateText(dueDate: due),
          ),
        ],
        if (estimateText != null) ...[
          const TextSpan(text: '   '),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Row(
              key: FrontEntityPreviewKeys.estimate(task.entityId),
              mainAxisSize: MainAxisSize.min,
              spacing: tokens.spacing.step1,
              children: [
                Icon(
                  LottiIcons.timer,
                  size: IconSizes.xs,
                  color: tokens.colors.text.lowEmphasis,
                ),
                Text(estimateText, style: meta),
              ],
            ),
          ),
        ],
      ],
      // Room for a one-liner that wraps on a phone without taking the
      // estimate off the end of the line under it.
      subtitleMaxLines: oneLiner == null ? 2 : 4,
      subtitleEmphasis: tokens.colors.text.lowEmphasis,
      // Its priority while it is still to do, beside the chevron: out of
      // the subtitle, so however long the one-liner, truncation never takes
      // it.
      trailingExtra: task.settled
          ? const _Chevron()
          : Row(
              key: FrontEntityPreviewKeys.priority(task.entityId),
              mainAxisSize: MainAxisSize.min,
              children: [
                TaskShowcasePriorityGlyph(
                  priority: task.priority,
                  size: IconSizes.xs,
                ),
                SizedBox(width: tokens.spacing.step1),
                Text(task.priority.short, style: meta),
                SizedBox(width: tokens.spacing.step2),
                const _Chevron(),
              ],
            ),
    );
  }
}

/// A day's plan as a card: the day, then its blocks in the order they run —
/// when each starts and ends, and what it is for, a done block ticked —
/// at most [maxBlocks] of them, with how many more there are. Kept current
/// as the plan changes. A tap opens the day. Until it has loaded, or once
/// the day has no plan, the words that changed it stand alone.
class FrontEntityPreviewDayCard extends ConsumerWidget {
  const FrontEntityPreviewDayCard({
    required this.reference,
    required this.onTap,
    super.key,
  });

  final FrontEntityReference reference;
  final VoidCallback onTap;

  /// How many blocks the card lists before it says how many more there are.
  static const int maxBlocks = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.value`: a reload keeps the card as it was until the new one lands.
    final preview = ref
        .watch(frontEntityPreviewProvider((reference.kind, reference.id)))
        .value;
    if (preview is! FrontDayPlanPreview) {
      return _TitleOnly(reference: reference, onTap: onTap);
    }
    final tokens = context.designTokens;
    final styles = tokens.typography.styles;
    final low = tokens.colors.text.lowEmphasis;
    final dayLabel = DateFormat.MMMEd(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(preview.day);
    String time(DateTime at) => TimeOfDay.fromDateTime(at).format(context);
    final shown = preview.blocks.take(maxBlocks).toList();
    final more = preview.blocks.length - shown.length;
    return _PreviewSurface(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.step3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: tokens.spacing.step2,
              children: [
                Row(
                  spacing: tokens.spacing.step2,
                  children: [
                    Icon(
                      LottiIcons.calendar,
                      size: IconSizes.s,
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                    Expanded(
                      child: Text(
                        dayLabel,
                        style: styles.body.bodyMedium.copyWith(
                          color: tokens.colors.text.highEmphasis,
                        ),
                      ),
                    ),
                    const _Chevron(),
                  ],
                ),
                for (final (index, block) in shown.indexed)
                  Row(
                    key: FrontEntityPreviewKeys.block(reference.id, index),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: tokens.spacing.step3,
                    children: [
                      Text(
                        '${time(block.start)}–${time(block.end)}',
                        style: styles.others.caption.copyWith(
                          color: low,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Expanded(
                        child: Text(
                          block.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: styles.others.caption.copyWith(
                            color: tokens.colors.text.highEmphasis,
                          ),
                        ),
                      ),
                      if (block.state == TimeBlockState.completed)
                        Icon(
                          LottiIcons.confirmCircled,
                          size: IconSizes.xs,
                          color: tokens.colors.alert.success.ink,
                        ),
                    ],
                  ),
                if (more > 0)
                  Text(
                    context.messages.frontDayPlanMore(more),
                    key: FrontEntityPreviewKeys.more(reference.id),
                    style: styles.others.caption.copyWith(color: low),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The quiet label over a list of due tasks: the window her answer read —
/// due today, overdue, or due through a later day.
class FrontDueSectionLabel extends StatelessWidget {
  const FrontDueSectionLabel({required this.section, super.key});

  final FrontDueSection section;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final tokens = context.designTokens;
    final through = DateFormat.MMMEd(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(section.through);
    final label = switch (section.window) {
      FrontDueWindow.today => messages.tasksDueViewDueToday,
      FrontDueWindow.overdue => messages.tasksDueViewOverdue,
      FrontDueWindow.upcoming when section.endsToday =>
        messages.tasksDueViewDueToday,
      FrontDueWindow.upcoming => messages.frontDueSectionThrough(through),
      FrontDueWindow.all when section.endsToday =>
        messages.frontDueSectionOverdueAndToday,
      FrontDueWindow.all => messages.frontDueSectionOverdueAndThrough(through),
    };
    return Text(
      label,
      style: tokens.typography.styles.others.caption.copyWith(
        color: tokens.colors.text.lowEmphasis,
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) => Icon(
    LottiIcons.chevronRight,
    size: IconSizes.s,
    color: context.designTokens.colors.text.lowEmphasis,
  );
}
