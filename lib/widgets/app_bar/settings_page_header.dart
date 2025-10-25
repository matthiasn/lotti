import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';

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

    final compact = width < 360;
    final wide = width >= 840;
    final showSubtitle = subtitle?.trim().isNotEmpty ?? false;

    final baseTitleSize = _titleFontSize(width: width, wide: wide);
    final collapsedTitleSize = math.max(20, baseTitleSize - (wide ? 4 : 3));
    final subtitleFontSize = settingsHeaderSubtitleTextStyle.fontSize ?? 16.0;
    final titleLineHeight = settingsHeaderTitleTextStyle.height ?? 1.05;
    final subtitleLineHeight = settingsHeaderSubtitleTextStyle.height ?? 1.3;
    final topSpacing = wide
        ? 18.0
        : compact
            ? 12.0
            : 16.0;
    final bottomSpacing = showSubtitle ? 16.0 : 12.0;
    final gapBetween = showSubtitle ? 4.0 : 0.0;
    final footerSpacing = showSubtitle ? 10.0 : 8.0;

    final titleBlockHeight = baseTitleSize * titleLineHeight * textScale;
    final subtitleBlockHeight =
        showSubtitle ? subtitleFontSize * subtitleLineHeight * textScale : 0;
    final accessibilityAllowance = textScale <= 1
        ? 0.0
        : (textScale - 1).clamp(0.0, 1.5) * (showSubtitle ? 64.0 : 48.0);

    final expandedBodyHeight = topSpacing +
        titleBlockHeight +
        gapBetween +
        subtitleBlockHeight +
        bottomSpacing +
        footerSpacing +
        accessibilityAllowance;

    final collapsedBodyHeight = titleBlockHeight * 0.85 +
        subtitleBlockHeight * 0.6 +
        topSpacing * 0.5 +
        bottomSpacing +
        footerSpacing +
        accessibilityAllowance * 0.8;

    final expandedHeight = topInset + expandedBodyHeight;
    final collapsedHeight =
        topInset + math.max(showSubtitle ? 68.0 : 56.0, collapsedBodyHeight);

    final colorScheme = Theme.of(context).colorScheme;

    return SliverAppBar(
      automaticallyImplyLeading: false,
      pinned: pinned,
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      expandedHeight: expandedHeight + (bottom?.preferredSize.height ?? 0),
      collapsedHeight: collapsedHeight + (bottom?.preferredSize.height ?? 0),
      toolbarHeight: collapsedHeight,
      bottom: bottom,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final currentHeight = constraints.biggest.height;
          final progress = _collapseProgress(
            expandedHeight,
            collapsedHeight,
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
                math.max(10.0, bottomSpacing - 4),
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
                bottom: Radius.circular(36),
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

    return Column(
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
          const SizedBox(height: 8),
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
  }
}

double _horizontalPadding(double width) {
  if (width >= 1600) return 200;
  if (width >= 1400) return 168;
  if (width >= 1200) return 140;
  if (width >= 992) return 108;
  if (width >= 840) return 72;
  if (width >= 720) return 52;
  if (width >= 600) return 36;
  if (width >= 420) return 26;
  return 20;
}

double _titleFontSize({required double width, required bool wide}) {
  if (width >= 1600) return 52;
  if (width >= 1200) return 46;
  if (width >= 992) return 42;
  if (wide) return 38;
  if (width >= 600) return 34;
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
