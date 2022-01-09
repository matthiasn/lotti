import 'package:flutter/material.dart';
import 'package:keyboard_dismisser/keyboard_dismisser.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/pages/add/add_page.dart';
import 'package:lotti/widgets/pages/audio.dart';
import 'package:lotti/widgets/pages/flagged_entries_page.dart';
import 'package:lotti/widgets/pages/journal_page.dart';
import 'package:lotti/widgets/pages/settings/settings_page.dart';

import 'bottom_nav/flagged_badge_icon.dart';

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
            child: IndexedStack(
              index: _pageIndex,
              children: const <Widget>[
                JournalPage(),
                FlaggedEntriesPage(),
                AddPage(),
                AudioPage(),
                SettingsPage(),
              ],
            ),
          ),
        ),
        backgroundColor: AppColors.headerBgColor,
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: <BottomNavigationBarItem>[
            const BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Journal',
            ),
            BottomNavigationBarItem(
              icon: FlaggedBadgeIcon(),
              label: 'Flagged',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.add_box),
              label: 'Add',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.mic),
              label: 'Audio',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
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
