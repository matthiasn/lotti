import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_icon.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/events/ui/widgets/linked_event_card.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:lotti/features/front_agent/state/front_entity_preview_provider.dart';
import 'package:lotti/features/tasks/ui/cover_art_thumbnail.dart';
import 'package:lotti/features/tasks/ui/due_date_text.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_task_row.dart'
    show StatusGlyph;
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/utils/entry_tools.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for her preview cards.
@visibleForTesting
abstract final class FrontEntityPreviewKeys {
  static const Key list = Key('front-entity-preview-list');
  static Key card(String id) => Key('front-entity-preview-$id');
  static Key cover(String id) => Key('front-entity-preview-cover-$id');
  static Key estimate(String id) => Key('front-entity-preview-estimate-$id');
}

/// The entities a reply made, as a stack of preview cards under her words —
/// a task as a compact card, an event as the app's event card. [onOpen] is
/// given the reference of the card tapped.
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
    key: FrontEntityPreviewKeys.list,
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
      FrontEventPreview() || null => _TitleOnly(
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
      FrontTaskPreview() || null => _TitleOnly(
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

/// The title an entity was made with, alone on a card, still opening it:
/// what a card shows before its preview has loaded and after the entity is
/// gone.
class _TitleOnly extends StatelessWidget {
  const _TitleOnly({required this.reference, required this.onTap});

  final FrontEntityReference reference;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _PreviewSurface(
    child: DesignSystemListItem(
      title: reference.title,
      titleMaxLines: 2,
      size: DesignSystemListItemSize.small,
      onTap: onTap,
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
      trailingExtra: const _Chevron(),
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
