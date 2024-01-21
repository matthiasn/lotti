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
      expandedHeight: 120,
      leadingWidth: 100,
      leading: showBackButton ? const BackWidget() : null,
      pinned: pinned,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        titlePadding: const EdgeInsetsDirectional.only(
          bottom: 12,
        ),
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
