import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/auto_leading_button.dart';

class DashboardAppBar extends StatelessWidget with PreferredSizeWidget {
  const DashboardAppBar(
    this.dashboard, {
    required this.showBackIcon,
    super.key,
  });

  final DashboardDefinition dashboard;
  final bool showBackIcon;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: colorConfig().headerBgColor,
      title: Text(
        dashboard.name,
        style: appBarTextStyle(),
      ),
      centerTitle: true,
      leading: showBackIcon ? const TestDetectingAutoLeadingButton() : null,
    );
  }
}
