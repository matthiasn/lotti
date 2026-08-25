import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/card_image_widget.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';

/// A modern journal image card: a square photo thumbnail leads (it is the
/// type's identity), followed by the same content-first title and de-emphasized
/// relative-date meta row used by every other list card. When the underlying
/// file is missing, a framed image glyph stands in so the row never collapses
/// to an empty box.
class ModernJournalImageCard extends StatelessWidget {
  const ModernJournalImageCard({
    required this.item,
    this.selected = false,
    super.key,
  });

  /// Square thumbnail size; also drives the card's height.
  static const double _thumbnailSize = 104;

  final JournalImage item;

  /// Whether this entry is the one open in the desktop detail pane.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (item.meta.deletedAt != null) {
      return const SizedBox.shrink();
    }

    void onTap() => beamToNamed('/journal/${item.meta.id}');
    final tokens = context.designTokens;
    final caption = item.entryText?.plainText.trim() ?? '';

    return ModernBaseCard(
      onTap: onTap,
      selected: selected,
      backgroundColor: dsCardSurface(context),
      // Same flat material and seam as ModernJournalCard so image rows sit on
      // one surface recipe with the rest of the feed: hairline decorative
      // border, no drop shadow, and the step2 (8px) vertical gap between
      // neighbours rather than a hairline stripe.
      borderColor: tokens.colors.decorative.level01,
      customShadows: const [],
      margin: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step5,
        vertical: tokens.spacing.step2,
      ),
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          _ImageThumbnail(item: item, size: _thumbnailSize),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step4,
                vertical: tokens.spacing.step3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          caption.isEmpty
                              ? context.messages.entryTypeLabelJournalImage
                              : caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          // subtitle2 (14/w600), the same title tier every
                          // other list card uses. An image caption is the
                          // row's title, not a body paragraph, so it must not
                          // outrank a text or task title sitting next to it in
                          // the same feed.
                          style: tokens.typography.styles.subtitle.subtitle2
                              .copyWith(
                                color: tokens.colors.text.highEmphasis,
                              ),
                        ),
                      ),
                      _StatusIndicators(item: item),
                    ],
                  ),
                  SizedBox(height: tokens.spacing.step1),
                  Text(
                    entryDateLabel(context, item.meta.dateFrom),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // mediumEmphasis, not outline, matching the meta row of
                    // every other card: timestamps are wayfinding in a
                    // chronological feed and outline was flagged as too faint
                    // to skim by.
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded-left thumbnail with a framed-image placeholder behind it, so a
/// missing file degrades to an intentional glyph instead of an empty gap.
class _ImageThumbnail extends StatelessWidget {
  const _ImageThumbnail({required this.item, required this.size});

  final JournalImage item;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(AppTheme.cardBorderRadius),
        bottomLeft: Radius.circular(AppTheme.cardBorderRadius),
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // A neutral, gradient media-well reads as an intentional
            // "no preview yet" affordance rather than an empty colored block,
            // and blends into the card instead of leaving a tinted seam.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    context.colorScheme.surfaceContainerHigh,
                    context.colorScheme.surfaceContainerLow,
                  ],
                ),
              ),
              child: Icon(
                LottiIcons.image,
                color: context.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
                size: size * 0.3,
              ),
            ),
            CardImageWidget(
              journalImage: item,
              height: size.toInt(),
              fit: BoxFit.cover,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusIndicators extends StatelessWidget {
  const _StatusIndicators({required this.item});

  final JournalImage item;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final indicators = <Widget>[
      if (fromNullableBool(item.meta.private))
        Icon(LottiIcons.shield, color: cs.error, size: 16),
      if (fromNullableBool(item.meta.starred))
        const Icon(LottiIcons.star, color: starredGold, size: 16),
      if (item.meta.isFlagged) Icon(LottiIcons.flag, color: cs.error, size: 16),
    ];

    if (indicators.isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final indicator in indicators)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: indicator,
          ),
      ],
    );
  }
}
