import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
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
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 10,
      titleSpacing: 0,
      title: Text(
        dashboard.name,
        style: appBarTextStyleNew(),
      ),
      leading: IconButton(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        onPressed: dashboardsBeamerDelegate.beamBack,
        icon: SvgPicture.asset('assets/icons/back.svg'),
      ),
      centerTitle: false,
    );
  }
}
