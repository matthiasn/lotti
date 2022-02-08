import 'package:flutter/material.dart';
import 'package:keyboard_dismisser/keyboard_dismisser.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/bottom_nav/flagged_badge_icon.dart';
import 'package:lotti/widgets/bottom_nav/tasks_badge_icon.dart';
import 'package:lotti/widgets/pages/flagged_entries_page.dart';
import 'package:lotti/widgets/pages/journal_page.dart';
import 'package:lotti/widgets/pages/my_day.dart';
import 'package:lotti/widgets/pages/settings/outbox_badge.dart';
import 'package:lotti/widgets/pages/settings/settings_page.dart';
import 'package:lotti/widgets/pages/tasks_page.dart';

import 'misc/time_recording_indicator.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _pageIndex = 0;

  // TODO: cleanup unused
  Map<int, GlobalKey> navigatorKeys = {
    0: GlobalKey(),
    1: GlobalKey(),
    2: GlobalKey(),
    3: GlobalKey(),
  };

  @override
  Widget build(BuildContext context) {
    return KeyboardDismisser(
      child: Scaffold(
        body: SafeArea(
          child: WillPopScope(
            onWillPop: () async {
              return !await Navigator.maybePop(
                  navigatorKeys[_pageIndex]!.currentState!.context);
            },
            child: Stack(
              children: [
                IndexedStack(
                  index: _pageIndex,
                  children: <Widget>[
                    const JournalPage(),
                    const FlaggedEntriesPage(),
                    const TasksPage(),
                    MyDayPage(),
                    const SettingsPage(),
                  ],
                ),
                TimeRecordingIndicator(),
              ],
            ),
          ),
        ),
        backgroundColor: AppColors.headerBgColor,
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: <BottomNavigationBarItem>[
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              label: 'Journal',
              tooltip: '',
            ),
            BottomNavigationBarItem(
              icon: FlaggedBadgeIcon(),
              label: 'Flagged',
              tooltip: '',
            ),
            BottomNavigationBarItem(
              icon: TasksBadgeIcon(),
              label: 'Tasks',
              tooltip: '',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today),
              label: 'My Day',
              tooltip: '',
            ),
            BottomNavigationBarItem(
              icon: OutboxBadgeIcon(
                icon: const Icon(Icons.settings_outlined),
              ),
              label: 'Settings',
              tooltip: '',
            ),
          ],
          selectedItemColor: Colors.amber[800],
          unselectedItemColor: AppColors.headerFontColor,
          backgroundColor: AppColors.headerBgColor,
          currentIndex: _pageIndex,
          onTap: (int index) {
            setState(
              () {
                _pageIndex = index;
              },
            );
          },
        ),
      ),
    );
  }
}
