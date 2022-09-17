import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/themes/theme.dart';

class TitleAppBar extends StatelessWidget with PreferredSizeWidget {
  const TitleAppBar({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.actions,
  });

  final String title;
  final bool showBackButton;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    void onPressed() {
      final beamedBack = dashboardsBeamerDelegate.beamBack();

      if (!beamedBack) {
        Navigator.pop(context);
      }
    }

    return AppBar(
      actions: actions,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 10,
      titleSpacing: 0,
      leadingWidth: 40,
      title: Text(
        title,
        style: appBarTextStyleNew(),
      ),
      leading: showBackButton
          ? IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              onPressed: onPressed,
              icon: SvgPicture.asset('assets/icons/back.svg'),
            )
          : Container(),
      centerTitle: false,
    );
  }
}
