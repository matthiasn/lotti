import 'package:flutter/material.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';
import 'package:lotti/features/events/ui/widgets/event_cover_image.dart';
import 'package:lotti/features/events/ui/widgets/event_status_picker.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';

/// A dense, info-rich summary of an event for *list* contexts — the logbook and
/// a task's linked-entries timeline — where the full photo-led `EventCard` is
/// too tall. A cover thumbnail leads; the body packs title + rating, a
/// category · date · status meta line, an optional snippet, and glanceable
/// photo/task counts. Tapping opens the event.
class EventSummaryCard extends StatelessWidget {
  const EventSummaryCard({required this.data, this.onTap, super.key});

  final EventCardData data;
  final VoidCallback? onTap;

  static const double _coverWidth = 92;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    final styles = tokens.typography.styles;
    // Rating belongs to events that have happened; surface it as a metric, not
    // a loud row of gold stars.
    final showRating = data.status == EventStatus.completed || data.stars > 0;

    final metrics = <Widget>[
      if (showRating)
        _Metric(
          icon: Icons.star_rounded,
          label: _ratingLabel(data.stars),
          color: starredGold,
        ),
      if (data.photoCount > 0)
        _Metric(
          icon: Icons.photo_library_outlined,
          label: '${data.photoCount}',
        ),
      if (data.taskCount > 0)
        _Metric(icon: Icons.check_circle_outline, label: '${data.taskCount}'),
    ];

    return Material(
      color: dsCardSurface(context),
      borderRadius: BorderRadius.circular(tokens.radii.m),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: _coverWidth,
                child: EventCoverImage(
                  image: data.coverImage,
                  fallbackColor: data.categoryColor,
                  cropX: data.coverCropX,
                  scrim: EventCoverScrim.none,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(tokens.spacing.step3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        data.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: styles.subtitle.subtitle1.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: tokens.spacing.step1),
                      _MetaLine(data: data),
                      if (data.summary != null) ...[
                        SizedBox(height: tokens.spacing.step1),
                        Text(
                          data.summary!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: styles.body.bodySmall.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (metrics.isNotEmpty) ...[
                        SizedBox(height: tokens.spacing.step2),
                        Wrap(
                          spacing: tokens.spacing.step4,
                          children: metrics,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// `5` for a whole rating, else `4.5`.
  static String _ratingLabel(double stars) =>
      stars == stars.roundToDouble() ? '${stars.toInt()}' : '$stars';
}

/// `● Category · 12 May · Status` — the glanceable facts line.
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.data});

  final EventCardData data;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    final style = tokens.typography.styles.body.bodySmall.copyWith(
      color: cs.onSurfaceVariant,
    );

    // Most logbook events are completed, so the status is only worth surfacing
    // when it's *not* — an upcoming/tentative/cancelled event.
    final showStatus = data.status != EventStatus.completed;

    // Built as a single rich line so it ellipsizes cleanly rather than
    // overflowing when the category/date/status run long.
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          if (data.categoryName != null) ...[
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsets.only(right: tokens.spacing.step1),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: data.categoryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            TextSpan(text: '${data.categoryName} · '),
          ],
          TextSpan(text: data.dateLabel),
          if (showStatus)
            TextSpan(
              text: ' · ${eventStatusLabel(data.status)}',
              style: style.copyWith(
                color: data.status.color,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color ?? cs.onSurfaceVariant),
        SizedBox(width: tokens.spacing.step1),
        Text(
          label,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
