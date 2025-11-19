import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/settings_header_dimensions.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';

// Dimensions have been extracted to SettingsHeaderDimensions to centralize
// spacing and layout breakpoints.

/// Premium settings header that adapts to phone, tablet, and desktop layouts
/// without overlapping the back button or status bar.
class SettingsPageHeader extends StatelessWidget {
  const SettingsPageHeader({
    required this.title,
    this.subtitle,
    this.pinned = true,
    this.showBackButton = false,
    this.bottom,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool pinned;
  final bool showBackButton;
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final topInset = mediaQuery.padding.top;
    final textScale = mediaQuery.textScaler.scale(1);

    final wide = width >= 840;
    final showSubtitle = subtitle?.trim().isNotEmpty ?? false;

    final baseTitleSize =
        SettingsHeaderDimensions.titleFontSize(width: width, wide: wide);
    final collapsedTitleSize = math.max(20, baseTitleSize - (wide ? 4 : 3));
    final subtitleFontSize = settingsHeaderSubtitleTextStyle.fontSize ?? 16.0;
    final titleLineHeight = settingsHeaderTitleTextStyle.height ?? 1.05;
    final subtitleLineHeight = settingsHeaderSubtitleTextStyle.height ?? 1.3;
    // Fixed paddings: simple and predictable.
    const topSpacing = SettingsHeaderDimensions.topSpacing;
    final bottomSpacing = bottom != null
        ? (showSubtitle
            ? SettingsHeaderDimensions.subtitleBottomGapWithBottom
            : 0.0)
        : (showSubtitle
            ? SettingsHeaderDimensions.footerWithSubtitle
            : SettingsHeaderDimensions.footerNoSubtitle);
    final subtitleGap =
        showSubtitle ? SettingsHeaderDimensions.subtitleGap : 0.0;
    final footerSpacing = showSubtitle
        ? SettingsHeaderDimensions.footerWithSubtitle
        : SettingsHeaderDimensions.footerNoSubtitle;

    final titleBlockHeight = baseTitleSize * titleLineHeight * textScale;
    final subtitleBlockHeight =
        showSubtitle ? subtitleFontSize * subtitleLineHeight * textScale : 0;

    // Simple, content-based heights with fixed paddings.
    final scaleAllowance =
        textScale > 1 ? (textScale - 1) * (showSubtitle ? 72.0 : 48.0) : 0.0;

    final expandedBodyHeight = topSpacing +
        titleBlockHeight +
        subtitleGap +
        subtitleBlockHeight +
        bottomSpacing +
        footerSpacing +
        scaleAllowance;

    final collapsedBodyHeight = titleBlockHeight * 0.9 +
        (showSubtitle ? subtitleBlockHeight * 0.35 : 0) +
        topSpacing * 0.5;

    final expandedHeight = topInset + expandedBodyHeight;
    final collapsedHeight = topInset +
        math.max(
          showSubtitle
              ? SettingsHeaderDimensions.collapsedMinWithSubtitle
              : SettingsHeaderDimensions.collapsedMinNoSubtitle,
          collapsedBodyHeight,
        );

    final colorScheme = Theme.of(context).colorScheme;

    final bottomHeight = bottom?.preferredSize.height ?? 0;
    final accessorySpacing =
        bottom != null ? SettingsHeaderDimensions.bottomShim : 0.0;
    final effectiveExpandedHeight =
        expandedHeight + bottomHeight + accessorySpacing;
    final effectiveCollapsedHeight =
        collapsedHeight + bottomHeight + accessorySpacing;

    return SliverAppBar(
      automaticallyImplyLeading: false,
      pinned: pinned,
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      expandedHeight: effectiveExpandedHeight,
      collapsedHeight: effectiveCollapsedHeight,
      toolbarHeight: effectiveCollapsedHeight,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final currentHeight = constraints.biggest.height;
          final progress = SettingsHeaderDimensions.collapseProgress(
            effectiveExpandedHeight,
            effectiveCollapsedHeight,
            currentHeight,
          );
          final easedProgress = Curves.easeOutCubic.transform(progress);

          final horizontalPadding =
              (SettingsHeaderDimensions.horizontalPadding(width) - 8)
                  .clamp(16.0, double.infinity);
          final titleSize = lerpDouble(
                baseTitleSize,
                collapsedTitleSize,
                easedProgress,
              ) ??
              baseTitleSize;
          final topPadding = lerpDouble(
                topSpacing,
                topSpacing * 0.6,
                easedProgress,
              ) ??
              topSpacing;
          final bottomPadding = lerpDouble(
                bottomSpacing,
                math.max(0.0, bottomSpacing - 4),
                easedProgress,
              ) ??
              bottomSpacing;

          final borderColor = Color.lerp(
                colorScheme.primary.withValues(alpha: 0.18),
                colorScheme.outlineVariant.withValues(alpha: 0.24),
                easedProgress,
              ) ??
              colorScheme.outlineVariant;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.topCenter,
                end: AlignmentDirectional.bottomCenter,
                colors: [
                  colorScheme.surface.withValues(alpha: wide ? 0.98 : 0.96),
                  colorScheme.surface.withValues(alpha: 0.93),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow
                      .withValues(alpha: 0.16 * (1 - easedProgress)),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
              border: Border(
                bottom: BorderSide(color: borderColor),
              ),
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsetsDirectional.only(
                          start: horizontalPadding,
                          end: horizontalPadding,
                          top: topPadding,
                          bottom: bottomPadding,
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.bottomStart,
                          child: Row(
                            children: [
                              if (showBackButton)
                                const Padding(
                                  padding: EdgeInsetsDirectional.only(end: 4),
                                  child: BackWidget(),
                                ),
                              Flexible(
                                child: _HeaderText(
                                  title: title,
                                  subtitle: subtitle,
                                  titleStyle:
                                      settingsHeaderTitleTextStyle.copyWith(
                                    fontSize: titleSize,
                                    color: colorScheme.primary,
                                  ),
                                  subtitleStyle:
                                      settingsHeaderSubtitleTextStyle.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  collapseProgress: progress,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (bottom != null) ...[
                      const SizedBox(height: 2),
                      SizedBox(
                        height: bottom!.preferredSize.height,
                        child: bottom,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText({
    required this.title,
    required this.titleStyle,
    required this.subtitleStyle,
    required this.collapseProgress,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final TextStyle titleStyle;
  final TextStyle subtitleStyle;
  final double collapseProgress;

  @override
  Widget build(BuildContext context) {
    final subtitleOpacity = subtitle == null || subtitle!.trim().isEmpty
        ? 0.0
        : (1 - collapseProgress.clamp(0.0, 1.0));
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          style: titleStyle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          child: Text(title),
        ),
        if (subtitleOpacity > 0) ...[
          const SizedBox(height: SettingsHeaderDimensions.subtitleGap),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            opacity: subtitleOpacity,
            child: Text(
              subtitle!,
              style: subtitleStyle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );

    final textScale = MediaQuery.maybeOf(context)?.textScaler.scale(1) ?? 1.0;
    if (textScale >= 1.5) {
      return FittedBox(
        alignment: AlignmentDirectional.bottomStart,
        fit: BoxFit.scaleDown,
        child: content,
      );
    }
    return content;
  }
}
