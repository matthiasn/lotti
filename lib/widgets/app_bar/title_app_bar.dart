import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';

class TitleAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TitleAppBar({
    required this.title,
    super.key,
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
    return TitleWidgetAppBar(
      showBackButton: showBackButton,
      actions: actions,
      title: Text(
        title,
        style: appBarTextStyleNew,
      ),
    );
  }
}

class TitleWidgetAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TitleWidgetAppBar({
    required this.title,
    super.key,
    this.showBackButton = true,
    this.actions,
  });

  final Widget title;
  final bool showBackButton;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      actions: actions,
      automaticallyImplyLeading: false,
      scrolledUnderElevation: 10,
      titleSpacing: 0,
      leadingWidth: 100,
      title: title,
      leading: showBackButton
          ? const BackWidget()
              .animate()
              .fadeIn(duration: const Duration(seconds: 1))
          : Container(),
      centerTitle: true,
    );
  }
}

class BackWidget extends StatelessWidget {
  const BackWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    void onPressed() {
      getIt<NavService>().beamBack();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: const MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Row(
              children: [
                SizedBox(width: 9),
                Icon(
                  Icons.chevron_left,
                  size: 30,
                  weight: 500,
                  semanticLabel: 'Navigate back',
                ),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: const Duration(seconds: 1));
  }
}
