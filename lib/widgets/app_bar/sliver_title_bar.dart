import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';

class SliverTitleBar extends StatelessWidget {
  const SliverTitleBar(
    this.title, {
    this.pinned = false,
    this.showBackButton = false,
    this.bottom,
    super.key,
  });

  final String title;
  final bool pinned;
  final bool showBackButton;
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      backgroundColor: styleConfig().negspace,
      expandedHeight: 120,
      leadingWidth: 100,
      leading: showBackButton ? const BackWidget() : Container(),
      pinned: pinned,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          title,
          style: appBarTextStyleNewLarge(),
        ),
      ),
      bottom: bottom,
    );
  }
}
