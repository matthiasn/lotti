import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:lotti/theme.dart';

class TitleAppBar extends StatelessWidget with PreferredSizeWidget {
  const TitleAppBar({
    Key? key,
    required this.title,
  }) : super(key: key);

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.headerBgColor,
      title: Text(title, style: appBarTextStyle),
      centerTitle: true,
      leading: AutoLeadingButton(
        color: AppColors.entryTextColor,
      ),
    );
  }
}
