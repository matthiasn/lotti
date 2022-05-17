import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme.dart';

class TasksAppBar extends StatelessWidget with PreferredSizeWidget {
  TasksAppBar({
    Key? key,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  final JournalDb _db = getIt<JournalDb>();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.headerBgColor,
      title: Column(
        children: [
          Text(
            'Tasks',
            style: appBarTextStyle,
          ),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TasksCountWidget('OPEN'),
              TasksCountWidget('IN PROGRESS'),
              TasksCountWidget('ON HOLD'),
              TasksCountWidget('BLOCKED'),
              TasksCountWidget('DONE'),
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
  TasksCountWidget(
    this.status, {
    Key? key,
  }) : super(key: key);

  final String status;
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
                '$status: ${snapshot.data}',
                style: TextStyle(
                  color: AppColors.headerFontColor2,
                  fontFamily: 'Oswald',
                  fontSize: 10.0,
                  fontWeight: FontWeight.w300,
                ),
              ),
            );
          }
        });
  }
}
