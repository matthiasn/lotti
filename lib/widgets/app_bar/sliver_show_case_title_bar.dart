import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';

class SliverShowCaseTitleBar extends StatelessWidget {
  const SliverShowCaseTitleBar({
    required this.title,
    this.showcaseIcon,
    this.pinned = false,
    this.showBackButton = true,
    this.actions,
    this.bottom,
    super.key,
  });

  final String title;
  final Widget? showcaseIcon;
  final bool pinned;
  final bool showBackButton;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      leadingWidth: 100,
      leading: showBackButton ? const BackWidget() : null,
      pinned: pinned,
      actions: [
        if (actions != null) ...actions!,
        if (showcaseIcon != null) showcaseIcon!,
      ],
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        titlePadding: const EdgeInsetsDirectional.only(bottom: 12, start: 16),
        title: Text(
          title,
          style: appBarTextStyleNewLarge.copyWith(
            color: Theme.of(context).primaryColor,
          ),
        ),
      ),
      bottom: bottom,
    );
  }
}
