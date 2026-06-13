import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/settings_header_dimensions.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/settings/settings_page_layout.dart';

// Dimensions have been extracted to SettingsHeaderDimensions to centralize
// spacing and layout breakpoints.

/// Premium settings header that adapts to phone, tablet, and desktop layouts
/// without overlapping the back button or status bar.
///
/// On desktop the header may be rendered inside a content pane that is narrower
/// than the full window. All dimension calculations use the actual available
/// width from a [LayoutBuilder] so that padding, font size, and heights adapt
/// correctly regardless of the host container's width.
class SettingsPageHeader extends StatelessWidget {
  const SettingsPageHeader({
    required this.title,
    this.subtitle,
    this.pinned = true,
    this.showBackButton = false,
    this.onBack,
    this.bottom,
    this.actions,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool pinned;
  final bool showBackButton;

  /// Optional override for the back action; defaults to
  /// `NavService.beamBack()` (see [BackWidget]). Detail pages that mount
  /// inline in the desktop split pane pass an explicit beam target here.
  final VoidCallback? onBack;

  final PreferredSizeWidget? bottom;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    // Use a SliverLayoutBuilder so we measure the actual pane width, not the
    // full screen width (which would be wrong on desktop split-pane layouts).
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        return _buildSliverAppBar(context, width);
      },
    );
  }

  Widget _buildSliverAppBar(BuildContext context, double width) {
    final mediaQuery = MediaQuery.of(context);
    final topInset = mediaQuery.padding.top;
    final textScale = mediaQuery.textScaler.scale(1);

    final wide = width >= 840;
    final showSubtitle = subtitle?.trim().isNotEmpty ?? false;

    final baseTitleSize = SettingsHeaderDimensions.titleFontSize(
      width: width,
      wide: wide,
    );
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
    final subtitleGap = showSubtitle
        ? SettingsHeaderDimensions.subtitleGap
        : 0.0;
    final footerSpacing = showSubtitle
        ? SettingsHeaderDimensions.footerWithSubtitle
        : SettingsHeaderDimensions.footerNoSubtitle;

    final titleBlockHeight = baseTitleSize * titleLineHeight * textScale;
    final subtitleBlockHeight = showSubtitle
        ? subtitleFontSize * subtitleLineHeight * textScale
        : 0;

    // Simple, content-based heights with fixed paddings.
    final scaleAllowance = textScale > 1
        ? (textScale - 1) * (showSubtitle ? 72.0 : 48.0)
        : 0.0;

    final expandedBodyHeight =
        topSpacing +
        titleBlockHeight +
        subtitleGap +
        subtitleBlockHeight +
        bottomSpacing +
        footerSpacing +
        scaleAllowance;

    final collapsedBodyHeight =
        titleBlockHeight * 0.9 +
        (showSubtitle ? subtitleBlockHeight * 0.35 : 0) +
        topSpacing;

    final expandedHeight = topInset + expandedBodyHeight;
    final collapsedHeight =
        topInset +
        math.max(
          showSubtitle
              ? SettingsHeaderDimensions.collapsedMinWithSubtitle
              : SettingsHeaderDimensions.collapsedMinNoSubtitle,
          collapsedBodyHeight,
        );

    final colorScheme = Theme.of(context).colorScheme;

    final bottomHeight = bottom?.preferredSize.height ?? 0;
    final accessorySpacing = bottom != null
        ? SettingsHeaderDimensions.bottomShim
        : 0.0;
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

          // Shares the settings content grid's start inset so the title
          // sits on the same axis as search fields, cards, and the
          // action bar below it.
          final horizontalPadding = SettingsPageLayout.contentInsets(
            width,
          ).start;
          final titleSize =
              lerpDouble(
                baseTitleSize,
                collapsedTitleSize,
                easedProgress,
              ) ??
              baseTitleSize;
          final bottomPadding =
              lerpDouble(
                bottomSpacing,
                math.max(0.0, bottomSpacing - 4),
                easedProgress,
              ) ??
              bottomSpacing;

          // Flat header: plain surface with a hairline that fades in as
          // the header collapses over scrolling content. No gradient,
          // shadow, or rounded card edge — chrome that earned attention
          // without carrying information.
          final borderColor =
              Color.lerp(
                colorScheme.outlineVariant.withValues(alpha: 0),
                colorScheme.outlineVariant.withValues(alpha: 0.24),
                easedProgress,
              ) ??
              colorScheme.outlineVariant;

          return Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                bottom: BorderSide(color: borderColor),
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: bottom != null
                      ? bottom!.preferredSize.height + 2
                      : footerSpacing,
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: horizontalPadding,
                      end: horizontalPadding,
                      bottom: bottomPadding,
                    ),
                    child: Row(
                      children: [
                        if (showBackButton)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 4),
                            child: BackWidget(onPressed: onBack),
                          ),
                        Expanded(
                          child: _HeaderText(
                            title: title,
                            subtitle: subtitle,
                            // Neutral title: the accent is reserved for
                            // things you can act on (FAB, Save, toggles),
                            // so the largest static element doesn't
                            // compete with the actual call to action.
                            titleStyle: settingsHeaderTitleTextStyle.copyWith(
                              fontSize: titleSize,
                              color: colorScheme.onSurface,
                            ),
                            subtitleStyle: settingsHeaderSubtitleTextStyle
                                .copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                            collapseProgress: progress,
                          ),
                        ),
                        if (actions != null) ...[
                          const SizedBox(width: 16),
                          ...actions!,
                        ],
                      ],
                    ),
                  ),
                ),
                if (bottom != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: bottom!.preferredSize.height,
                    child: bottom!,
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
