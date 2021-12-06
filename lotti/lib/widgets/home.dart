import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:keyboard_dismisser/keyboard_dismisser.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/pages/audio.dart';
import 'package:lotti/widgets/pages/editor.dart';
import 'package:lotti/widgets/pages/health_page.dart';
import 'package:lotti/widgets/pages/journal_page.dart';
import 'package:lotti/widgets/pages/journal_page2.dart';
import 'package:lotti/widgets/pages/photo_import.dart';
import 'package:lotti/widgets/pages/settings.dart';
import 'package:lotti/widgets/pages/survey_page.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

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
                JournalPage2(
                  child: Text(
                    'Journal',
                    style: TextStyle(
                      fontFamily: 'Oswald',
                      color: AppColors.entryBgColor,
                    ),
                  ),
                ),
                const JournalPage(),
                const EditorPage(),
                const PhotoImportPage(),
                const AudioPage(),
                const HealthPage(),
                const SurveyPage(),
                const SettingsPage(),
              ],
            ),
          ),
        ),
        backgroundColor: AppColors.bodyBgColor,
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Journal',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Journal2',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_box),
              label: 'Add',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.camera_roll),
              label: 'Photos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.mic),
              label: 'Audio',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.directions_run),
              label: 'Health',
            ),
            BottomNavigationBarItem(
              icon: Icon(MdiIcons.clipboardOutline),
              label: 'Surveys',
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
