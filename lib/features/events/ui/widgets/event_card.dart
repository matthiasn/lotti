import 'package:flutter/material.dart';
import 'package:flutter_rating/flutter_rating.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';
import 'package:lotti/features/events/ui/widgets/event_cover_image.dart';
import 'package:lotti/features/events/ui/widgets/event_overlay_pill.dart';
import 'package:lotti/features/events/ui/widgets/event_status_picker.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';

/// A large, photo-led card representing one event in the overview.
///
/// The cover photo is the hero; a thin scrim carries only the most glanceable
/// signals (category, star rating, or — for upcoming events — the date). The
/// textual identity (title, summary, counts) lives in a clean content block
/// beneath the image so the layout stays legible at a glance.
class EventCard extends StatelessWidget {
  const EventCard({
    required this.data,
    this.onTap,
    this.coverAspect = 3 / 2,
    super.key,
  });

  final EventCardData data;
  final VoidCallback? onTap;

  /// Cover aspect ratio (width / height). The featured card uses a shorter
  /// (wider) ratio on phones so the hero doesn't crowd the grid below it.
  final double coverAspect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    final styles = tokens.typography.styles;

    return Material(
      color: dsCardSurface(context),
      borderRadius: BorderRadius.circular(tokens.radii.l),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: coverAspect,
              child: EventCoverImage(
                image: data.coverImage,
                fallbackColor: data.categoryColor,
                cropX: data.coverCropX,
                child: EventCoverOverlay(data: data),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(tokens.spacing.step3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    data.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: styles.heading.heading3.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                  SizedBox(height: tokens.spacing.step1),
                  EventCardMetaLine(
                    dateLabel: data.dateLabel,
                    location: data.location,
                  ),
                  if (data.summary != null) ...[
                    SizedBox(height: tokens.spacing.step2),
                    Text(
                      data.summary!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: styles.body.bodyMedium.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                  EventCardFooter(data: data),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The category pill overlaid top-left on a cover photo (over the scrim).
class EventCoverOverlay extends StatelessWidget {
  const EventCoverOverlay({required this.data, super.key});

  final EventCardData data;

  @override
  Widget build(BuildContext context) {
    if (data.categoryName == null) return const SizedBox.shrink();
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.step3),
      child: Align(
        alignment: Alignment.topLeft,
        child: EventOverlayPill(
          dotColor: data.categoryColor,
          label: data.categoryName!,
        ),
      ),
    );
  }
}

/// Date (+ optional location) line shown beneath a card's title.
class EventCardMetaLine extends StatelessWidget {
  const EventCardMetaLine({required this.dateLabel, this.location, super.key});

  final String dateLabel;
  final String? location;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    final style = tokens.typography.styles.body.bodySmall.copyWith(
      color: cs.onSurfaceVariant,
    );
    return Row(
      children: [
        Flexible(
          child: Text(
            dateLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        if (location != null) ...[
          Text('  ·  ', style: style),
          Icon(Icons.place_outlined, size: 13, color: cs.onSurfaceVariant),
          SizedBox(width: tokens.spacing.step1),
          Flexible(
            child: Text(
              location!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
      ],
    );
  }
}

/// Footer row with photo/task counts and (for non-completed, non-upcoming
/// events) a small status label.
class EventCardFooter extends StatelessWidget {
  const EventCardFooter({required this.data, super.key});

  final EventCardData data;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final showStatus = !data.isUpcoming && data.status != EventStatus.completed;
    final showRating = !data.isUpcoming && data.stars > 0;

    final counts = <Widget>[
      if (data.photoCount > 0)
        _MetaCount(icon: Icons.photo_library_outlined, value: data.photoCount),
      if (data.taskCount > 0)
        _MetaCount(icon: Icons.check_circle_outline, value: data.taskCount),
    ];

    if (counts.isEmpty && !showStatus && !showRating) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.step2),
      child: Row(
        children: [
          if (showRating) ...[
            StarRating(
              rating: data.stars,
              size: 13,
              allowHalfRating: true,
              color: starredGold,
              borderColor: starredGold,
            ),
            SizedBox(width: tokens.spacing.step3),
          ],
          for (final c in counts) ...[
            c,
            SizedBox(width: tokens.spacing.step3),
          ],
          const Spacer(),
          if (showStatus)
            Text(
              eventStatusLabel(data.status),
              style: tokens.typography.styles.others.caption.copyWith(
                color: data.status.color,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _MetaCount extends StatelessWidget {
  const _MetaCount({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: cs.onSurfaceVariant),
        SizedBox(width: tokens.spacing.step1),
        Text(
          '$value',
          style: tokens.typography.styles.others.caption.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
