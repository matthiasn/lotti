import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/search/search_widget.dart';

class DefinitionsListAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const DefinitionsListAppBar({
    required this.title,
    required this.match,
    required this.onQueryChanged,
    super.key,
    this.showBackButton = true,
    this.actions,
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
      ),
    );
  }
}
