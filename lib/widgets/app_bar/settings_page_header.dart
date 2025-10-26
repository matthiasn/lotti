import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';

// Compact spacing constants for SettingsPageHeader.
const double kSettingsHeaderTop = 0;
const double kSettingsHeaderSubtitleGap = 6; // title → subtitle gap
const double kSettingsHeaderSubtitleBottomGapWithBottom =
    4; // subtitle → bottom gap when bottom is present
const double kSettingsHeaderBottomShim =
    2; // tiny spacer above the bottom widget
const double kSettingsHeaderFooterWithSubtitle =
    8; // footer padding when no bottom
const double kSettingsHeaderFooterNoSubtitle =
    6; // footer padding when no bottom and no subtitle
// Reduce collapsed minimums so there’s less blank space above the title
// when the sliver is pinned.
const double kSettingsHeaderCollapsedMinWithSubtitle = 24;
const double kSettingsHeaderCollapsedMinNoSubtitle = 24;

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

    final baseTitleSize = _titleFontSize(width: width, wide: wide);
    final collapsedTitleSize = math.max(20, baseTitleSize - (wide ? 4 : 3));
    final subtitleFontSize = settingsHeaderSubtitleTextStyle.fontSize ?? 16.0;
    final titleLineHeight = settingsHeaderTitleTextStyle.height ?? 1.05;
    final subtitleLineHeight = settingsHeaderSubtitleTextStyle.height ?? 1.3;
    // Fixed paddings: simple and predictable.
    const topSpacing = kSettingsHeaderTop;
    final bottomSpacing = bottom != null
        ? (showSubtitle ? kSettingsHeaderSubtitleBottomGapWithBottom : 0.0)
        : (showSubtitle
            ? kSettingsHeaderFooterWithSubtitle
            : kSettingsHeaderFooterNoSubtitle);
    final subtitleGap = showSubtitle ? kSettingsHeaderSubtitleGap : 0.0;
    final footerSpacing = showSubtitle
        ? kSettingsHeaderFooterWithSubtitle
        : kSettingsHeaderFooterNoSubtitle;

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
              ? kSettingsHeaderCollapsedMinWithSubtitle
              : kSettingsHeaderCollapsedMinNoSubtitle,
          collapsedBodyHeight,
        );

    final colorScheme = Theme.of(context).colorScheme;

    final bottomHeight = bottom?.preferredSize.height ?? 0;
    final accessorySpacing = bottom != null ? kSettingsHeaderBottomShim : 0.0;
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
          final progress = _collapseProgress(
            effectiveExpandedHeight,
            effectiveCollapsedHeight,
            currentHeight,
          );
          final easedProgress = Curves.easeOutCubic.transform(progress);

          final horizontalPadding =
              (_horizontalPadding(width) - 8).clamp(16.0, double.infinity);
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
            child: Column(
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
                          Expanded(
                            child: _HeaderText(
                              title: title,
                              subtitle: subtitle,
                              titleStyle: settingsHeaderTitleTextStyle.copyWith(
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
                ] else
                  SizedBox(height: footerSpacing),
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
          const SizedBox(height: kSettingsHeaderSubtitleGap),
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

double _horizontalPadding(double width) {
  if (width >= 1600) return 160;
  if (width >= 1200) return 120;
  if (width >= 992) return 88;
  if (width >= 720) return 56;
  if (width >= 540) return 36;
  if (width >= 420) return 28;
  return 20;
}

double _titleFontSize({required double width, required bool wide}) {
  if (width >= 1600) return 46;
  if (width >= 1200) return 42;
  if (width >= 992) return 38;
  if (wide) return 34;
  if (width >= 600) return 32;
  if (width >= 420) return 30;
  return 28;
}

double _collapseProgress(
  double expandedHeight,
  double collapsedHeight,
  double currentHeight,
) {
  final available = expandedHeight - collapsedHeight;
  if (available <= 0) {
    return 1;
  }
  final delta = expandedHeight - currentHeight;
  return (delta / available).clamp(0.0, 1.0);
}
