import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
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
    super.key,
  });

  /// Square thumbnail size; also drives the card's height.
  static const double _thumbnailSize = 104;

  final JournalImage item;

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
      backgroundColor: dsCardSurface(context),
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingLarge,
        vertical: AppTheme.cardSpacing / 2,
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
                          style: caption.isEmpty
                              ? tokens.typography.styles.subtitle.subtitle1
                                    .copyWith(
                                      color: context.colorScheme.onSurface,
                                    )
                              : tokens.typography.styles.body.bodyLarge
                                    .copyWith(
                                      color: context.colorScheme.onSurface,
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
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: context.colorScheme.outline,
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
                MdiIcons.imageOutline,
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
        Icon(MdiIcons.security, color: cs.error, size: 16),
      if (fromNullableBool(item.meta.starred))
        const Icon(MdiIcons.star, color: starredGold, size: 16),
      if (item.meta.flag == EntryFlag.import)
        Icon(MdiIcons.flag, color: cs.error, size: 16),
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
