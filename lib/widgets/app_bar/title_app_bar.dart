import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
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
    return AppBar(
      actions: actions,
      automaticallyImplyLeading: false,
      backgroundColor: styleConfig().negspace,
      scrolledUnderElevation: 10,
      titleSpacing: 0,
      leadingWidth: 100,
      title: Text(
        title,
        style: appBarTextStyleNew(),
      ),
      leading: showBackButton ? const BackWidget() : Container(),
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
    final localizations = AppLocalizations.of(context)!;

    void onPressed() {
      final beamedBack = dashboardsBeamerDelegate.beamBack();

      if (!beamedBack) {
        Navigator.pop(context);
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Row(
              children: [
                const SizedBox(width: 10),
                const Icon(
                  Icons.chevron_left,
                  size: 30,
                ),
                Text(
                  localizations.appBarBack,
                  style: appBarTextStyleNew().copyWith(
                    fontWeight: FontWeight.w300,
                  ),
                  semanticsLabel: 'Navigate back',
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}
