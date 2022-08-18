import 'package:flutter/material.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/consts.dart';
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
    return StreamBuilder<bool>(
      stream: getIt<JournalDb>().watchConfigFlag(enableBeamerNavFlag),
      builder: (context, snapshot) {
        return AppBar(
          actions: actions,
          backgroundColor: colorConfig().headerBgColor,
          title: Text(
            title,
            style: appBarTextStyle().copyWith(
              color: colorConfig().entryTextColor,
            ),
          ),
          centerTitle: true,
          leading: snapshot.data != true
              ? const TestDetectingAutoLeadingButton()
              : null,
        );
      },
    );
  }
}
