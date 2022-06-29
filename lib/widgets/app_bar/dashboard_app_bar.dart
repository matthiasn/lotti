import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/app_bar/auto_leading_button.dart';

class DashboardAppBar extends StatelessWidget with PreferredSizeWidget {
  const DashboardAppBar(
    this.dashboard, {
    super.key,
  });

  final DashboardDefinition dashboard;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return AppBar(
      backgroundColor: AppColors.headerBgColor,
      title: Text(
        dashboard.name,
        style: appBarTextStyle,
      ),
      centerTitle: true,
      leading: const TestDetectingAutoLeadingButton(),
    );
  }
}
