import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:keyboard_dismisser/keyboard_dismisser.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/pages/add/add_page.dart';
import 'package:lotti/widgets/pages/audio.dart';
import 'package:lotti/widgets/pages/journal_page.dart';
import 'package:lotti/widgets/pages/settings/settings_page.dart';

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
              debugPrint(
                  'On Will called ${navigatorKeys[_pageIndex]!.currentState!.context.widget}');
              // return !await navigatorKeys[_pageIndex].currentState.context;
              return !await Navigator.maybePop(
                  navigatorKeys[_pageIndex]!.currentState!.context);
              // Navigator.pop(navigatorKeys[_pageIndex].currentState.context);
            },
            child: IndexedStack(
              index: _pageIndex,
              children: <Widget>[
                JournalPage(),
                const AddPage(),
                const AudioPage(),
                const SettingsPage(),
              ],
            ),
          ),
        ),
        backgroundColor: AppColors.headerBgColor,
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Journal',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_box),
              label: 'Add',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.mic),
              label: 'Audio',
            ),
            BottomNavigationBarItem(
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
