import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:lotti/theme.dart';

class TitleAppBar extends StatelessWidget with PreferredSizeWidget {
  const TitleAppBar({
    Key? key,
    required this.title,
    this.actions,
  }) : super(key: key);

  final String title;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      actions: actions,
      backgroundColor: AppColors.headerBgColor,
      title: Text(title, style: appBarTextStyle),
      centerTitle: true,
      leading: AutoLeadingButton(
        color: AppColors.entryTextColor,
      ),
    );
  }
}
