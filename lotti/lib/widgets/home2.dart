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

class HomePage2 extends StatefulWidget {
  @override
  _HomePage2State createState() => _HomePage2State();
}

class _HomePage2State extends State<HomePage2> {
  int _pageIndex = 0;

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
                  child: const Text('Journal2'),
                  navigatorKey: navigatorKeys[0],
                ),
                NavigatorPage(
                  child: const Text('Journal'),
                  navigatorKey: navigatorKeys[1],
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

class NavigatorPage extends StatefulWidget {
  const NavigatorPage({this.navigatorKey, required this.child});

  final Widget child;
  final GlobalKey? navigatorKey;

  @override
  _NavigatorPageState createState() => _NavigatorPageState();
}

class _NavigatorPageState extends State<NavigatorPage> {
  late TextEditingController _textEditingController;

  int _currentRoute = 0;

  @override
  void initState() {
    _textEditingController = TextEditingController();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: widget.navigatorKey,
      onGenerateRoute: (RouteSettings settings) {
        return MaterialPageRoute(
          settings: settings,
          builder: (BuildContext context) {
            return Scaffold(
              appBar: AppBar(
                backgroundColor: AppColors.headerBgColor,
                title: widget.child,
                centerTitle: true,
              ),
              backgroundColor: AppColors.bodyBgColor,
              body: Container(
                margin: const EdgeInsets.symmetric(
                  vertical: 10.0,
                  horizontal: 20.0,
                ),
                child: ListView(
                  children: List.generate(
                    50,
                    (int index) {
                      return Card(
                        child: ListTile(
                          leading: const FlutterLogo(),
                          title: Text('Item ${index + 1}'),
                          enabled: true,
                          onTap: () {
                            if (_currentRoute != index) {
                              _textEditingController = TextEditingController();
                            }
                            _currentRoute = index;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (BuildContext context) {
                                  return DetailRoute(
                                    textEditingController:
                                        _textEditingController,
                                    index: index,
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class DetailRoute extends StatelessWidget {
  const DetailRoute({required this.textEditingController, required this.index});

  final TextEditingController textEditingController;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Route for $index Item'),
      ),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        alignment: Alignment.center,
        child: TextField(controller: textEditingController),
      ),
    );
  }
}
