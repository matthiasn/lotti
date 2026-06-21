import 'package:flutter/material.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';
import 'package:lotti/features/events/ui/widgets/event_cover_image.dart';
import 'package:lotti/features/events/ui/widgets/event_status_picker.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';

/// A dense, info-rich summary of an event for *list* contexts — the logbook and
/// a task's linked-entries timeline — where the full photo-led `EventCard` is
/// too tall. A cover thumbnail leads; the body packs the title with a gold
/// rating right beside it (the one quality signal), a
/// `● category · date · status-pill` meta line, an optional snippet, and a quiet
/// `📷 N photos · ☑ N tasks` contents line. Tapping opens the event.
class EventSummaryCard extends StatelessWidget {
  const EventSummaryCard({required this.data, this.onTap, super.key});

  final EventCardData data;
  final VoidCallback? onTap;

  /// Cover-thumbnail width clamps. The cover holds a compact floor on phones so
  /// the title keeps its room, and grows toward the ceiling on wider layouts —
  /// where there is spare width — so the photo reads as a real image rather
  /// than a stamp.
  static const double _minCoverWidth = 112;
  static const double _maxCoverWidth = 168;

  /// Caps the card on wide layouts so it reads as a compact list tile rather
  /// than a stretched band — and keeps the title and its rating close together
  /// instead of letting the rating drift to a far edge.
  static const double _maxWidth = 560;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    final styles = tokens.typography.styles;

    // Surface the rating once as a gold anchor, but only when the event has
    // actually been rated — a completed-but-unrated event should not read as
    // "rated 0".
    final showRating = data.stars > 0;

    final card = Material(
      color: dsCardSurface(context),
      borderRadius: BorderRadius.circular(tokens.radii.m),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // A leading thumbnail that reads as a real photo: a compact floor
            // on phones (so the title keeps its room) that grows into the
            // spare width on wider layouts instead of leaving a side gutter.
            final coverWidth = (constraints.maxWidth * 0.27).clamp(
              _minCoverWidth,
              _maxCoverWidth,
            );
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: coverWidth,
                    child: EventCoverImage(
                      image: data.coverImage,
                      fallbackColor: data.categoryColor,
                      cropX: data.coverCropX,
                      scrim: EventCoverScrim.none,
                      decodeWidth: coverWidth,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(tokens.spacing.step4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              // Loose (not Expanded) so the rating sits right
                              // beside the title rather than drifting to the far
                              // edge on wide cards; the title still ellipsizes
                              // when it would otherwise crowd the rating.
                              Flexible(
                                child: Text(
                                  data.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: styles.subtitle.subtitle1.copyWith(
                                    color: cs.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (showRating) ...[
                                SizedBox(width: tokens.spacing.step4),
                                _Rating(stars: data.stars),
                              ],
                            ],
                          ),
                          SizedBox(height: tokens.spacing.step2),
                          _MetaLine(data: data),
                          if (data.summary != null) ...[
                            SizedBox(height: tokens.spacing.step2),
                            Text(
                              data.summary!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: styles.body.bodyMedium.copyWith(
                                color: cs.onSurface,
                              ),
                            ),
                          ],
                          _ContentsLine(data: data),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: card,
      ),
    );
  }
}

/// The gold rating anchor (`★ 4.5`) shown right beside the title. Gold + bold so
/// it reads as the event's one quality signal at a glance.
class _Rating extends StatelessWidget {
  const _Rating({required this.stars});

  final double stars;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 16, color: starredGold),
        SizedBox(width: tokens.spacing.step1),
        Text(
          _label(stars),
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: starredGold,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Always one decimal (`5.0`, `4.5`) so the 5-point scale reads at a glance
  /// and the gold anchor keeps a stable width down the list.
  static String _label(double stars) => stars.toStringAsFixed(1);
}

/// `● Category · 12 May  [Status]` — the glanceable facts line. The category and
/// date ellipsize together; a non-completed status rides at the end as a small
/// tinted pill so the state reads as a flag rather than blending into the line.
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.data});

  final EventCardData data;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    final style = tokens.typography.styles.body.bodyMedium.copyWith(
      color: cs.onSurfaceVariant,
    );

    // Most logbook events are completed, so the status is only worth surfacing
    // when it's *not* — an upcoming/tentative/cancelled event.
    final showStatus = data.status != EventStatus.completed;

    final facts = <String>[
      if (data.categoryName != null) data.categoryName!,
      data.dateLabel,
    ].join(' · ');

    return Row(
      children: [
        if (data.categoryName != null) ...[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: data.categoryColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: tokens.spacing.step1),
        ],
        Flexible(
          child: Text(
            facts,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        if (showStatus) ...[
          SizedBox(width: tokens.spacing.step3),
          _StatusPill(status: data.status),
        ],
      ],
    );
  }
}

/// A small tinted pill for a non-completed event status (e.g. `Planned`).
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final EventStatus status;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = status.color;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1 / 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
      ),
      child: Text(
        eventStatusLabel(context, status),
        style: tokens.typography.styles.body.bodySmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// `📷 24 photos · ☑ 2 tasks` — a quiet contents line, one tier below the meta
/// line (smaller + muted). Each count pairs a small icon (warmth + fast
/// scanning) with a localized, pluralized word (unambiguous for everyone). Laid
/// out as a [Wrap] so a long count never overflows the row — it drops onto a
/// second line instead. Renders nothing when the event has no photos or tasks.
class _ContentsLine extends StatelessWidget {
  const _ContentsLine({required this.data});

  final EventCardData data;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    final style = tokens.typography.styles.body.bodySmall.copyWith(
      color: cs.onSurfaceVariant,
    );

    final parts = <Widget>[
      if (data.photoCount > 0)
        _Count(
          icon: Icons.photo_library_rounded,
          label: context.messages.eventsMetricPhotos(data.photoCount),
          style: style,
        ),
      if (data.taskCount > 0)
        _Count(
          icon: Icons.task_alt_rounded,
          label: context.messages.eventsMetricTasks(data.taskCount),
          style: style,
        ),
    ];

    if (parts.isEmpty) return const SizedBox.shrink();

    // A hairline + generous gap sets the counts apart as a deliberate footer:
    // the snippet ("what happened") reads as the story, the counts ("what's
    // inside") as quiet metadata, so the divider reads as a section break
    // rather than an underline and the two zones never blur together.
    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.step4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: cs.outlineVariant,
            child: const SizedBox(height: 1, width: double.infinity),
          ),
          SizedBox(height: tokens.spacing.step3),
          Wrap(
            spacing: tokens.spacing.step4,
            runSpacing: tokens.spacing.step1,
            children: parts,
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.icon, required this.label, required this.style});

  final IconData icon;
  final String label;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: style.color),
        SizedBox(width: tokens.spacing.step1),
        Text(label, style: style),
      ],
    );
  }
}
