import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/app_bar/settings_header_bar.dart';

/// Fixed settings header for scrollable settings pages.
///
/// A pinned, **non-collapsing** sliver: the title stays put and at one
/// size while the body scrolls underneath it — replacing the former
/// scroll-driven shrinking large-title behaviour. The visible chrome
/// (back button, title typography, leading inset, trailing actions) is the
/// shared [SettingsHeaderBar], so every settings surface — leaf utility
/// pages, definition lists and editors, sync, AI, and the mobile
/// drill-down menu — wears an identical header.
///
/// An optional [bottom] accessory (e.g. a sync filter-chip row) renders
/// beneath the title; the bottom hairline sits below it.
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
  /// `NavService.beamBack()` (see `BackWidget`). Detail pages that mount
  /// inline in the desktop split pane pass an explicit beam target here.
  final VoidCallback? onBack;

  final PreferredSizeWidget? bottom;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final bottomHeight = bottom?.preferredSize.height ?? 0.0;
    final barHeight = settingsHeaderContentHeight(
      context,
      hasSubtitle: subtitle?.trim().isNotEmpty ?? false,
    );
    final extent = topInset + barHeight + bottomHeight;
    return SliverPersistentHeader(
      pinned: pinned,
      delegate: _SettingsHeaderDelegate(
        extent: extent,
        topInset: topInset,
        barHeight: barHeight,
        title: title,
        subtitle: subtitle,
        showBackButton: showBackButton,
        onBack: onBack,
        bottom: bottom,
        actions: actions,
      ),
    );
  }
}

class _SettingsHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SettingsHeaderDelegate({
    required this.extent,
    required this.topInset,
    required this.barHeight,
    required this.title,
    required this.subtitle,
    required this.showBackButton,
    required this.onBack,
    required this.bottom,
    required this.actions,
  });

  final double extent;
  final double topInset;
  final double barHeight;
  final String title;
  final String? subtitle;
  final bool showBackButton;
  final VoidCallback? onBack;
  final PreferredSizeWidget? bottom;
  final List<Widget>? actions;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final tokens = context.designTokens;
    final accessory = bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        border: Border(
          bottom: BorderSide(color: tokens.colors.decorative.level01),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: topInset),
          SizedBox(
            height: barHeight,
            child: SettingsHeaderBar(
              title: title,
              subtitle: subtitle,
              showBackButton: showBackButton,
              onBack: onBack,
              actions: actions,
            ),
          ),
          if (accessory != null)
            SizedBox(height: accessory.preferredSize.height, child: accessory),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SettingsHeaderDelegate old) =>
      old.extent != extent ||
      old.topInset != topInset ||
      old.title != title ||
      old.subtitle != subtitle ||
      old.showBackButton != showBackButton ||
      old.onBack != onBack ||
      old.bottom != bottom ||
      old.actions != actions;
}
