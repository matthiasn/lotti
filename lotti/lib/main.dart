import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyboard_dismisser/keyboard_dismisser.dart';
import 'package:lotti/blocs/audio/player_cubit.dart';
import 'package:lotti/blocs/audio/recorder_cubit.dart';
import 'package:lotti/blocs/journal/health_cubit.dart';
import 'package:lotti/blocs/journal/journal_image_cubit.dart';
import 'package:lotti/blocs/journal/persistence_cubit.dart';
import 'package:lotti/blocs/sync/encryption_cubit.dart';
import 'package:lotti/blocs/sync/imap/inbox_cubit.dart';
import 'package:lotti/blocs/sync/imap/outbox_cubit.dart';
import 'package:lotti/blocs/sync/outbox_cubit.dart';
import 'package:lotti/blocs/sync/vector_clock_cubit.dart';
import 'package:lotti/pages/audio.dart';
import 'package:lotti/pages/editor.dart';
import 'package:lotti/pages/health_page.dart';
import 'package:lotti/pages/journal_page.dart';
import 'package:lotti/pages/photo_import.dart';
import 'package:lotti/pages/settings.dart';
import 'package:lotti/pages/survey_page.dart';
import 'package:lotti/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const enableSentry = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  if (enableSentry) {
    await SentryFlutter.init(
      (options) {
        options.dsn = dotenv.env['SENTRY_DSN'];
        // Set tracesSampleRate to 1.0 to capture 100% of transactions for performance monitoring.
        // We recommend adjusting this value in production.
        options.tracesSampleRate = 1.0;
      },
      appRunner: () => runApp(const LottiApp()),
    );
  } else {
    runApp(const LottiApp());
  }
}

class LottiApp extends StatelessWidget {
  const LottiApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<EncryptionCubit>(
          lazy: false,
          create: (BuildContext context) => EncryptionCubit(),
        ),
        BlocProvider<VectorClockCubit>(
          lazy: false,
          create: (BuildContext context) => VectorClockCubit(),
        ),
        BlocProvider<OutboxImapCubit>(
          lazy: false,
          create: (BuildContext context) => OutboxImapCubit(
            encryptionCubit: BlocProvider.of<EncryptionCubit>(context),
          ),
        ),
        BlocProvider<OutboxCubit>(
          lazy: false,
          create: (BuildContext context) => OutboxCubit(
            encryptionCubit: BlocProvider.of<EncryptionCubit>(context),
            outboxImapCubit: BlocProvider.of<OutboxImapCubit>(context),
            vectorClockCubit: BlocProvider.of<VectorClockCubit>(context),
          ),
        ),
        BlocProvider<PersistenceCubit>(
          lazy: false,
          create: (BuildContext context) => PersistenceCubit(
            outboundQueueCubit: BlocProvider.of<OutboxCubit>(context),
            vectorClockCubit: BlocProvider.of<VectorClockCubit>(context),
          ),
        ),
        BlocProvider<InboxImapCubit>(
          lazy: false,
          create: (BuildContext context) => InboxImapCubit(
            encryptionCubit: BlocProvider.of<EncryptionCubit>(context),
            persistenceCubit: BlocProvider.of<PersistenceCubit>(context),
            vectorClockCubit: BlocProvider.of<VectorClockCubit>(context),
          ),
        ),
        BlocProvider<HealthCubit>(
          lazy: true,
          create: (BuildContext context) => HealthCubit(
            persistenceCubit: BlocProvider.of<PersistenceCubit>(context),
          ),
        ),
        BlocProvider<JournalImageCubit>(
          lazy: false,
          create: (BuildContext context) => JournalImageCubit(
            persistenceCubit: BlocProvider.of<PersistenceCubit>(context),
          ),
        ),
        BlocProvider<AudioRecorderCubit>(
          create: (BuildContext context) => AudioRecorderCubit(
            persistenceCubit: BlocProvider.of<PersistenceCubit>(context),
          ),
        ),
        BlocProvider<AudioPlayerCubit>(
          create: (BuildContext context) => AudioPlayerCubit(),
        ),
      ],
      child: MaterialApp(
        title: 'Lotti',
        theme: ThemeData(
          primarySwatch: Colors.grey,
        ),
        home: const LottiHomePage(title: 'Lotti'),
      ),
    );
  }
}

class LottiHomePage extends StatefulWidget {
  const LottiHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

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
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
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
                    fontWeight: FontWeight.w400),
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
