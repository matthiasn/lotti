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
    this.margin = const EdgeInsets.symmetric(horizontal: 70),
  });

  final Widget title;
  final bool showBackButton;
  final List<Widget>? actions;
  final EdgeInsets margin;

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
      title: Container(
        margin: margin,
        child: title,
      ),
      leading: showBackButton
          ? const BackWidget().animate().fadeIn(
                duration: const Duration(
                  seconds: 1,
                ),
              )
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
        const SizedBox(width: 2),
        IconButton(
          onPressed: onPressed,
          icon: Icon(
            Icons.chevron_left,
            size: 30,
            weight: 500,
            color: Theme.of(context).colorScheme.outline,
            semanticLabel: 'Navigate back',
          ),
        ),
      ],
    ).animate().fadeIn(duration: const Duration(seconds: 1));
  }
}
