import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';
import 'package:lotti/features/events/ui/widgets/event_card.dart';
import 'package:lotti/features/events/ui/widgets/event_cover_image.dart';
import 'package:lotti/features/events/ui/widgets/event_overlay_pill.dart';

/// A wide, full-bleed "featured" event card — a photographic hero banner with
/// the event's identity overlaid bottom-left over a scrim. Used to give the
/// Upcoming section a magazine-cover lead and to fill the width on desktop.
/// Below a breakpoint it degrades to the standard vertical [EventCard] so
/// phones still get a clean single-column card.
class EventFeatureCard extends StatelessWidget {
  const EventFeatureCard({required this.data, this.onTap, super.key});

  final EventCardData data;
  final VoidCallback? onTap;

  static const double _wideBreakpoint = 560;
  static const double _height = 248;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _wideBreakpoint) {
          // Shorter cover on phones so the featured hero doesn't crowd the
          // dated grid that follows it.
          return EventCard(data: data, onTap: onTap, coverAspect: 16 / 9);
        }
        return _wide(context);
      },
    );
  }

  Widget _wide(BuildContext context) {
    final tokens = context.designTokens;
    final styles = tokens.typography.styles;
    final meta = data.location != null
        ? '${data.dateLabel}  ·  ${data.location}'
        : data.dateLabel;

    return Material(
      color: dsCardSurface(context),
      borderRadius: BorderRadius.circular(tokens.radii.l),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: _height,
          child: EventCoverImage(
            image: data.coverImage,
            fallbackColor: data.categoryColor,
            cropX: data.coverCropX,
            scrim: EventCoverScrim.hero,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: EdgeInsets.all(tokens.spacing.step5),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (data.categoryName != null)
                        EventOverlayPill(
                          dotColor: data.categoryColor,
                          label: data.categoryName!,
                        ),
                      SizedBox(height: tokens.spacing.step3),
                      Text(
                        data.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: styles.heading.heading2.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: tokens.spacing.step2),
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
                              meta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: styles.body.bodyMedium.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (data.summary != null) ...[
                        SizedBox(height: tokens.spacing.step2),
                        Text(
                          data.summary!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: styles.body.bodyMedium.copyWith(
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
