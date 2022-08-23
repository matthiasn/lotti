import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/themes/theme.dart';

class DashboardAppBar extends StatelessWidget with PreferredSizeWidget {
  const DashboardAppBar(
    this.dashboard, {
    super.key,
    required this.showBackButton,
  });

  final DashboardDefinition dashboard;
  final bool showBackButton;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    void maybePop() => Navigator.of(context).maybePop();

    return AppBar(
      backgroundColor: colorConfig().headerBgColor,
      title: Text(
        dashboard.name,
        style: appBarTextStyle(),
      ),
      centerTitle: true,
      leading: showBackButton
          ? IconButton(
              icon: Icon(
                Icons.arrow_back_ios_rounded,
                size: 24,
                color: colorConfig().entryTextColor,
              ),
              onPressed: maybePop,
            )
          : null,
    );
  }
}
