import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme/theme.dart';
import 'package:lotti/widgets/app_bar/auto_leading_button.dart';

class DashboardAppBar extends StatefulWidget with PreferredSizeWidget {
  const DashboardAppBar({
    super.key,
    required this.dashboardId,
  });

  final String dashboardId;

  @override
  State<DashboardAppBar> createState() => _DashboardAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _DashboardAppBarState extends State<DashboardAppBar> {
  final JournalDb _db = getIt<JournalDb>();
  late Stream<List<DashboardDefinition>> stream;

  @override
  void initState() {
    super.initState();
    stream = _db.watchDashboardById(widget.dashboardId);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return StreamBuilder<List<DashboardDefinition>>(
      stream: stream,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<DashboardDefinition>> snapshot,
      ) {
        DashboardDefinition? dashboard;
        final data = snapshot.data ?? [];
        if (data.isNotEmpty) {
          dashboard = data.first;
        }

        return AppBar(
          backgroundColor: getIt<ThemeService>().colors.headerBgColor,
          title: Text(
            dashboard == null
                ? localizations.dashboardNotFound
                : dashboard.name,
            style: appBarTextStyle,
          ),
          centerTitle: true,
          leading: const TestDetectingAutoLeadingButton(),
        );
      },
    );
  }
}
