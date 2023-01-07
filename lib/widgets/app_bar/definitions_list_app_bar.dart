import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/misc/search_widget.dart';

class DefinitionsListAppBar extends StatelessWidget with PreferredSizeWidget {
  const DefinitionsListAppBar({
    super.key,
    required this.title,
    required this.match,
    this.showBackButton = true,
    this.actions,
    required this.onQueryChanged,
  });

  final String title;
  final String match;
  final bool showBackButton;
  final List<Widget>? actions;
  final void Function(String) onQueryChanged;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight * 2.5);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      actions: actions,
      automaticallyImplyLeading: false,
      backgroundColor: styleConfig().negspace,
      elevation: 0,
      scrolledUnderElevation: 10,
      titleSpacing: 0,
      leadingWidth: 100,
      title: Text(
        title,
        style: appBarTextStyleNew(),
      ),
      leading: showBackButton ? const BackWidget() : Container(),
      centerTitle: true,
      bottom: SearchWidget(
        text: match,
        onChanged: onQueryChanged,
        hintText: 'Search $title...',
      ),
    );
  }
}
