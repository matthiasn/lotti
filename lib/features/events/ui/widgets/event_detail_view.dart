import 'package:flutter/material.dart';
import 'package:flutter_rating/flutter_rating.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';
import 'package:lotti/features/events/ui/widgets/event_cover_image.dart';
import 'package:lotti/features/events/ui/widgets/event_overlay_pill.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';

/// The redesigned event detail surface: a photographic hero header carrying the
/// event's identity (cover, title, when/where, rating), followed by an AI
/// summary, a vertical timeline of linked entries, and the associated
/// prep/follow-up tasks. On wide screens the body splits into a main column
/// (summary + timeline) and a tasks rail so the canvas is used; on phones it
/// stacks into one column.
///
/// Pure/presentational — driven entirely by [EventDetailData].
class EventDetailView extends StatelessWidget {
  const EventDetailView({
    required this.data,
    this.onBack,
    this.onEdit,
    this.onRegenerateSummary,
    this.onAddToTimeline,
    this.onAddTask,
    super.key,
  });

  final EventDetailData data;
  final VoidCallback? onBack;
  final VoidCallback? onEdit;
  final VoidCallback? onRegenerateSummary;
  final VoidCallback? onAddToTimeline;
  final VoidCallback? onAddTask;

  /// Content cap so the body doesn't sprawl on very wide screens.
  static const double _contentMaxWidth = 1080;

  /// At/above this body width the layout splits into two columns.
  static const double _twoColumnBreakpoint = 900;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Scaffold(
      backgroundColor: dsPageSurface(context),
      body: CustomScrollView(
        slivers: [
          _HeroSliver(card: data.card, onBack: onBack, onEdit: onEdit),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    tokens.spacing.step4,
                    tokens.spacing.step4,
                    tokens.spacing.step4,
                    tokens.spacing.step10,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final twoColumn =
                          constraints.maxWidth >= _twoColumnBreakpoint &&
                          data.tasks.isNotEmpty;
                      return twoColumn
                          ? _twoColumnBody(context)
                          : _oneColumnBody(context);
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _oneColumnBody(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._mainColumn(context),
        if (data.tasks.isNotEmpty) ...[
          _SectionHeader(
            title: context.messages.eventsTasksSection,
            count: data.tasks.length,
            onAdd: onAddTask,
          ),
          for (final task in data.tasks) _TaskRow(task: task),
        ],
        SizedBox(height: tokens.spacing.step2),
      ],
    );
  }

  Widget _twoColumnBody(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _mainColumn(context),
          ),
        ),
        SizedBox(width: tokens.spacing.step6),
        SizedBox(
          width: 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                title: context.messages.eventsTasksSection,
                count: data.tasks.length,
                onAdd: onAddTask,
              ),
              for (final task in data.tasks) _TaskRow(task: task),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _mainColumn(BuildContext context) {
    final tokens = context.designTokens;
    return [
      if (data.whenLabel != null) ...[
        Text(
          data.whenLabel!,
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: tokens.spacing.step4),
      ],
      if (data.summary != null) ...[
        _SummaryCard(summary: data.summary!, onRegenerate: onRegenerateSummary),
      ],
      if (data.timeline.isNotEmpty) ...[
        _SectionHeader(
          title: context.messages.eventsTimelineSection,
          count: data.timeline.length,
          onAdd: onAddToTimeline,
        ),
        _Timeline(entries: data.timeline),
      ],
    ];
  }
}

class _HeroSliver extends StatelessWidget {
  const _HeroSliver({required this.card, this.onBack, this.onEdit});

  final EventCardData card;
  final VoidCallback? onBack;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final size = MediaQuery.sizeOf(context);
    // Cap the hero on wide screens so the summary + first timeline beat stay
    // above the fold; phones get a taller, more immersive hero.
    final heroHeight = size.width >= 900
        ? 320.0
        : (size.height * 0.46).clamp(280.0, 420.0);

    return SliverAppBar(
      expandedHeight: heroHeight,
      pinned: true,
      backgroundColor: dsPageSurface(context),
      leading: _ScrimIconButton(icon: Icons.arrow_back, onPressed: onBack),
      // A single overflow action (Edit / Share / Change cover / Delete) rather
      // than competing pencil + overflow icons.
      actions: [
        _ScrimIconButton(icon: Icons.more_horiz, onPressed: onEdit),
        SizedBox(width: tokens.spacing.step2),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: EventCoverImage(
          image: card.coverImage,
          fallbackColor: card.categoryColor,
          cropX: card.coverCropX,
          scrim: EventCoverScrim.hero,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: EdgeInsets.all(tokens.spacing.step5),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: _HeroContent(card: card),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroContent extends StatelessWidget {
  const _HeroContent({required this.card});

  final EventCardData card;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final styles = tokens.typography.styles;
    final showStatus = card.status != EventStatus.completed;
    // display2 is too large for a phone width and truncates long titles; step
    // down to heading1 on narrow screens so the full title always fits.
    final titleStyle = MediaQuery.sizeOf(context).width < 600
        ? styles.heading.heading1
        : styles.display.display2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (card.categoryName != null)
              EventOverlayPill(
                dotColor: card.categoryColor,
                label: card.categoryName!,
              ),
            if (showStatus) ...[
              SizedBox(width: tokens.spacing.step2),
              EventOverlayPill(
                dotColor: card.status.color,
                label: _statusLabel(card.status),
              ),
            ],
          ],
        ),
        SizedBox(height: tokens.spacing.step3),
        Text(
          card.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: titleStyle.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: tokens.spacing.step3),
        Row(
          children: [
            Icon(
              Icons.event_outlined,
              size: 15,
              color: Colors.white.withValues(alpha: 0.85),
            ),
            SizedBox(width: tokens.spacing.step1),
            Flexible(
              child: Text(
                card.location != null
                    ? '${card.dateLabel}  ·  ${card.location}'
                    : card.dateLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: styles.body.bodyMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
            if (card.stars > 0) ...[
              SizedBox(width: tokens.spacing.step3),
              StarRating(
                rating: card.stars,
                size: 16,
                allowHalfRating: true,
                color: starredGold,
                borderColor: starredGold,
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _statusLabel(EventStatus status) {
    final lower = status.label.toLowerCase();
    return lower.isEmpty
        ? lower
        : '${lower[0].toUpperCase()}${lower.substring(1)}';
  }
}

class _ScrimIconButton extends StatelessWidget {
  const _ScrimIconButton({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(context.designTokens.spacing.step2),
      child: Material(
        color: Colors.black.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          icon: Icon(icon, color: Colors.white),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, this.onRegenerate});

  final String summary;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    final styles = tokens.typography.styles;

    return ModernBaseCard(
      isEnhanced: true,
      padding: EdgeInsets.all(tokens.spacing.step4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: cs.primary),
              SizedBox(width: tokens.spacing.step2),
              Text(
                context.messages.eventsSummaryTitle,
                style: styles.subtitle.subtitle2.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onRegenerate,
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                color: cs.onSurfaceVariant,
                tooltip: 'Regenerate summary',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step2),
          Text(
            summary,
            style: styles.body.bodyLarge.copyWith(color: cs.onSurface),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count, this.onAdd});

  final String title;
  final int count;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        top: tokens.spacing.step6,
        bottom: tokens.spacing.step3,
      ),
      child: Row(
        children: [
          Text(
            title,
            style: tokens.typography.styles.heading.heading3.copyWith(
              color: cs.onSurface,
            ),
          ),
          SizedBox(width: tokens.spacing.step2),
          Text(
            '$count',
            style: tokens.typography.styles.subtitle.subtitle1.copyWith(
              color: cs.outline,
            ),
          ),
          const Spacer(),
          _AddButton(onTap: onAdd),
        ],
      ),
    );
  }
}

/// Explicit, always-legible "Add" affordance (a generic [TextButton.icon]
/// rendered as a near-invisible pill against the dark card surface).
class _AddButton extends StatelessWidget {
  const _AddButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step2,
            vertical: tokens.spacing.step1,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 18, color: cs.primary),
              SizedBox(width: tokens.spacing.step1),
              Text(
                context.messages.eventsAddLabel,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.entries});

  final List<EventTimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          _TimelineTile(entry: entries[i], isLast: i == entries.length - 1),
      ],
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.entry, required this.isLast});

  final EventTimelineEntry entry;
  final bool isLast;

  static const double _railWidth = 28;
  static const double _dotSize = 12;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _railWidth,
            child: Column(
              children: [
                SizedBox(height: tokens.spacing.step1),
                Container(
                  width: _dotSize,
                  height: _dotSize,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(width: 2, color: cs.outline),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: tokens.spacing.step5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.timeLabel,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: tokens.spacing.step2),
                  _TimelineContent(entry: entry),
                ],
              ),
            ),
          ),
          // Trailing chevron signals each entry opens its source entry. Pinned
          // to the top (timestamp line) so it reads as a row-level "open"
          // affordance, not horizontal paging of the photo cluster below.
          Padding(
            padding: EdgeInsets.only(left: tokens.spacing.step2),
            child: Align(
              alignment: Alignment.topCenter,
              child: Icon(Icons.chevron_right, size: 20, color: cs.outline),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineContent extends StatelessWidget {
  const _TimelineContent({required this.entry});

  final EventTimelineEntry entry;

  static const double _leadHeight = 196;
  static const double _thumbSize = 72;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    final styles = tokens.typography.styles;

    switch (entry.kind) {
      case EventTimelineKind.photo:
        // A hero "lead" frame plus a small supporting cluster, with the caption
        // anchored beneath — a curated moment, not a flat contact strip.
        final photos = entry.photos;
        final lead = photos.first;
        final rest = photos.length > 1
            ? photos.sublist(1)
            : const <EventPhoto>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radii.m),
              child: SizedBox(
                height: _leadHeight,
                width: double.infinity,
                child: EventCoverImage(
                  image: lead.image,
                  fallbackColor: cs.surfaceContainerHighest,
                  cropX: lead.cropX,
                  scrim: EventCoverScrim.none,
                ),
              ),
            ),
            if (rest.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.step2),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final photo in rest) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(tokens.radii.s),
                        child: SizedBox(
                          width: _thumbSize,
                          height: _thumbSize,
                          child: EventCoverImage(
                            image: photo.image,
                            fallbackColor: cs.surfaceContainerHighest,
                            cropX: photo.cropX,
                            scrim: EventCoverScrim.none,
                          ),
                        ),
                      ),
                      SizedBox(width: tokens.spacing.step2),
                    ],
                  ],
                ),
              ),
            ],
            if (entry.text != null) ...[
              SizedBox(height: tokens.spacing.step2),
              Text(
                entry.text!,
                style: styles.body.bodyMedium.copyWith(
                  color: cs.onSurface,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        );
      case EventTimelineKind.note:
        return Text(
          entry.text ?? '',
          style: styles.body.bodyLarge.copyWith(color: cs.onSurface),
        );
      case EventTimelineKind.audio:
        return Row(
          children: [
            Icon(Icons.play_circle_outline, size: 22, color: cs.primary),
            SizedBox(width: tokens.spacing.step2),
            Text(
              entry.durationLabel ?? 'Voice note',
              style: styles.body.bodyMedium.copyWith(color: cs.onSurface),
            ),
            if (entry.text != null) ...[
              SizedBox(width: tokens.spacing.step2),
              Flexible(
                child: Text(
                  entry.text!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: styles.body.bodyMedium.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        );
    }
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});

  final EventTaskRef task;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    final styles = tokens.typography.styles;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
      child: Row(
        children: [
          Icon(
            task.done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 20,
            color: task.done ? cs.primary : cs.outline,
          ),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Text(
              task.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: styles.body.bodyLarge.copyWith(
                color: task.done ? cs.onSurfaceVariant : cs.onSurface,
              ),
            ),
          ),
          if (task.dueLabel != null) ...[
            SizedBox(width: tokens.spacing.step2),
            Text(
              task.dueLabel!,
              style: styles.body.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
          if (task.statusLabel != null) ...[
            SizedBox(width: tokens.spacing.step2),
            Text(
              task.statusLabel!,
              style: styles.others.caption.copyWith(
                color: task.statusColor ?? cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
