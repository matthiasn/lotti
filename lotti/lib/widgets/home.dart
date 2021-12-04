import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyboard_dismisser/keyboard_dismisser.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/pages/audio.dart';
import 'package:lotti/widgets/pages/editor.dart';
import 'package:lotti/widgets/pages/health_page.dart';
import 'package:lotti/widgets/pages/journal_page.dart';
import 'package:lotti/widgets/pages/photo_import.dart';
import 'package:lotti/widgets/pages/settings.dart';
import 'package:lotti/widgets/pages/survey_page.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

class LottiHomePage extends StatefulWidget {
  const LottiHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<LottiHomePage> createState() => _LottiHomePageState();
}

class _LottiHomePageState extends State<LottiHomePage> {
  int _selectedIndex = 0;
  String version = '';
  String buildNumber = '';

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> getVersions() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      version = packageInfo.version;
      buildNumber = packageInfo.buildNumber;
    });
  }

  @override
  void initState() {
    super.initState();
    getVersions();
  }

  static const List<Widget> _widgetOptions = <Widget>[
    JournalPage(),
    EditorPage(),
    PhotoImportPage(),
    AudioPage(),
    HealthPage(),
    SurveyPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return KeyboardDismisser(
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  color: AppColors.headerFontColor,
                  fontFamily: 'Oswald',
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                ' v$version Build $buildNumber',
                style: TextStyle(
                  color: AppColors.headerFontColor2,
                  fontFamily: 'Oswald',
                  fontSize: 12.0,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.headerBgColor,
        ),
        backgroundColor: AppColors.bodyBgColor,
        body: Center(
          child: _widgetOptions.elementAt(_selectedIndex),
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
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
          currentIndex: _selectedIndex,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.amber[800],
          unselectedItemColor: AppColors.headerFontColor,
          backgroundColor: AppColors.headerBgColor,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}
