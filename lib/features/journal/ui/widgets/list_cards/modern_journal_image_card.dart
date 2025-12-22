import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/card_image_widget.dart';
import 'package:lotti/features/journal/ui/widgets/tags/tags_view_widget.dart';
import 'package:lotti/features/journal/ui/widgets/text_viewer_widget_non_scrollable.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// A modern journal image card with gradient styling matching the task and settings design
class ModernJournalImageCard extends StatelessWidget {
  const ModernJournalImageCard({
    required this.item,
    super.key,
  });

  // Layout constants
  static const double minImageSectionWidth = 300;
  static const double cardHorizontalPadding = 40;

  // Header and content spacing constants
  static const double headerHeight = 24; // Approximate height of date/icons row
  static const double spacingAfterHeader = 8;
  static const double tagsHeight = 32; // Approximate height of tags widget
  static const double spacingAfterTags = 8;

  final JournalImage item;

  @override
  Widget build(BuildContext context) {
    if (item.meta.deletedAt != null) {
      return const SizedBox.shrink();
    }

    void onTap() => beamToNamed('/journal/${item.meta.id}');

    return ModernBaseCard(
      onTap: onTap,
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: AppTheme.cardSpacing / 2,
      ),
      padding: EdgeInsets.zero,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    // Image dimensions
    const imageHeight = 160;

    final maxWidth =
        max(MediaQuery.of(context).size.width / 2, minImageSectionWidth) -
            cardHorizontalPadding;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image section
        ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppTheme.cardBorderRadius),
            bottomLeft: Radius.circular(AppTheme.cardBorderRadius),
          ),
          child: LimitedBox(
            maxWidth: maxWidth,
            maxHeight: imageHeight.toDouble(),
            child: CardImageWidget(
              journalImage: item,
              height: imageHeight,
              fit: BoxFit.cover,
            ),
          ),
        ),

        // Content section
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(AppTheme.cardPadding),
            height: imageHeight.toDouble(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with date and icons
                _buildHeader(context),

                const SizedBox(height: 8),
                // Tags
                TagsViewWidget(item: item),
                const SizedBox(height: 8),
                // Text content
                Expanded(
                  child: _buildTextContent(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Date and category
        Expanded(
          child: Row(
            children: [
              Text(
                dfShorter.format(item.meta.dateFrom),
                style: context.textTheme.bodySmall?.copyWith(
                  fontFeatures: [const FontFeature.tabularFigures()],
                  color: context.colorScheme.onSurfaceVariant
                      .withValues(alpha: AppTheme.alphaSurfaceVariant),
                  fontSize: AppTheme.subtitleFontSize,
                ),
              ),
              const SizedBox(width: 8),
              CategoryIconCompact(
                item.meta.categoryId,
                size: CategoryIconConstants.iconSizeMedium,
              ),
            ],
          ),
        ),

        // Status indicators
        _buildStatusIndicators(context),
      ],
    );
  }

  Widget _buildStatusIndicators(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (fromNullableBool(item.meta.private))
          Icon(
            MdiIcons.security,
            color: context.colorScheme.error,
            size: 16,
          ),
        if (fromNullableBool(item.meta.starred))
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(
              MdiIcons.star,
              color: starredGold,
              size: 16,
            ),
          ),
        if (item.meta.flag == EntryFlag.import)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(
              MdiIcons.flag,
              color: context.colorScheme.error,
              size: 16,
            ),
          ),
      ],
    );
  }

  Widget _buildTextContent(BuildContext context) {
    if (item.entryText == null || item.entryText!.plainText.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculate available height based on image height and padding
    const imageHeight = 160;
    const padding = AppTheme.cardPadding;
    // Calculate reserved height for header and spacing
    const reservedHeight =
        headerHeight + spacingAfterHeader + tagsHeight + spacingAfterTags;

    const availableHeight = imageHeight -
        (padding * 2) -
        reservedHeight; // Account for header and tags

    return TextViewerWidgetNonScrollable(
      entryText: item.entryText,
      maxHeight: availableHeight,
    );
  }
}
