import 'package:flutter/material.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/app_bar/auto_leading_button.dart';

class TitleAppBar extends StatelessWidget with PreferredSizeWidget {
  const TitleAppBar({
    super.key,
    required this.title,
    this.actions,
  });

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
      leading: const TestDetectingAutoLeadingButton(),
    );
  }
}
