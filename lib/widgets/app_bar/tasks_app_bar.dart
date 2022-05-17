import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme.dart';

class TasksAppBar extends StatelessWidget with PreferredSizeWidget {
  TasksAppBar({
    Key? key,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return AppBar(
      backgroundColor: AppColors.headerBgColor,
      title: Column(
        children: [
          Text(
            'Tasks',
            style: appBarTextStyle.copyWith(fontWeight: FontWeight.w300),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TasksCountWidget(
                status: 'OPEN',
                label: localizations.taskStatusOpen,
              ),
              TasksCountWidget(
                status: 'IN PROGRESS',
                label: localizations.taskStatusInProgress,
              ),
              TasksCountWidget(
                status: 'ON HOLD',
                label: localizations.taskStatusOnHold,
              ),
              TasksCountWidget(
                status: 'BLOCKED',
                label: localizations.taskStatusBlocked,
              ),
              TasksCountWidget(
                status: 'DONE',
                label: localizations.taskStatusDone,
              ),
            ],
          ),
        ],
      ),
      centerTitle: true,
      leading: AutoBackButton(
        color: AppColors.entryTextColor,
      ),
    );
  }
}

class TasksCountWidget extends StatelessWidget {
  TasksCountWidget({
    required this.status,
    required this.label,
    Key? key,
  }) : super(key: key);

  final String status;
  final String label;
  final JournalDb _db = getIt<JournalDb>();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
        stream: _db.watchTaskCount(status),
        builder: (
          BuildContext context,
          AsyncSnapshot<int> snapshot,
        ) {
          if (snapshot.data == null) {
            return const SizedBox.shrink();
          } else {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                '$label: ${snapshot.data}',
                style: TextStyle(
                  color: AppColors.headerFontColor2,
                  fontFamily: 'Oswald',
                  fontSize: 12.0,
                  fontWeight: FontWeight.w100,
                ),
              ),
            );
          }
        });
  }
}
