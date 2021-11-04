import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wisely/blocs/audio/player_cubit.dart';
import 'package:wisely/blocs/audio/recorder_cubit.dart';
import 'package:wisely/blocs/journal/health_cubit.dart';
import 'package:wisely/blocs/journal_entities_cubit.dart';
import 'package:wisely/blocs/sync/encryption_cubit.dart';
import 'package:wisely/blocs/sync/imap_cubit.dart';
import 'package:wisely/pages/audio.dart';
import 'package:wisely/pages/editor.dart';
import 'package:wisely/pages/health_page.dart';
import 'package:wisely/pages/journal_page.dart';
import 'package:wisely/pages/photo_import.dart';
import 'package:wisely/pages/settings.dart';
import 'package:wisely/sync/secure_storage.dart';
import 'package:wisely/theme.dart';

import 'blocs/journal/journal_image_cubit.dart';
import 'blocs/journal/persistence_cubit.dart';
import 'blocs/sync/outbound_queue_cubit.dart';
import 'blocs/sync/vector_clock_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: await getApplicationDocumentsDirectory(),
  );
  runApp(const WiselyApp());
  // Bloc.observer = MyBlocObserver();
}

class WiselyApp extends StatelessWidget {
  const WiselyApp({Key? key}) : super(key: key);

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
        BlocProvider<PersistenceCubit>(
          lazy: false,
          create: (BuildContext context) => PersistenceCubit(
            vectorClockCubit: BlocProvider.of<VectorClockCubit>(context),
          ),
        ),
        BlocProvider<HealthCubit>(
          lazy: true,
          create: (BuildContext context) => HealthCubit(
            persistenceCubit: BlocProvider.of<PersistenceCubit>(context),
          ),
        ),
        BlocProvider<JournalEntitiesCubit>(
          lazy: false,
          create: (BuildContext context) => JournalEntitiesCubit(),
        ),
        BlocProvider<ImapCubit>(
          lazy: false,
          create: (BuildContext context) => ImapCubit(
            encryptionCubit: BlocProvider.of<EncryptionCubit>(context),
            journalEntitiesCubit:
                BlocProvider.of<JournalEntitiesCubit>(context),
          ),
        ),
        BlocProvider<OutboundQueueCubit>(
          lazy: false,
          create: (BuildContext context) => OutboundQueueCubit(
            encryptionCubit: BlocProvider.of<EncryptionCubit>(context),
            imapCubit: BlocProvider.of<ImapCubit>(context),
          ),
        ),
        BlocProvider<JournalImageCubit>(
          lazy: false,
          create: (BuildContext context) => JournalImageCubit(
            outboundQueueCubit: BlocProvider.of<OutboundQueueCubit>(context),
            vectorClockCubit: BlocProvider.of<VectorClockCubit>(context),
            journalEntitiesCubit:
                BlocProvider.of<JournalEntitiesCubit>(context),
            persistenceCubit: BlocProvider.of<PersistenceCubit>(context),
          ),
        ),
        BlocProvider<AudioRecorderCubit>(
          create: (BuildContext context) => AudioRecorderCubit(
            outboundQueueCubit: BlocProvider.of<OutboundQueueCubit>(context),
            journalEntitiesCubit:
                BlocProvider.of<JournalEntitiesCubit>(context),
            vectorClockCubit: BlocProvider.of<VectorClockCubit>(context),
            persistenceCubit: BlocProvider.of<PersistenceCubit>(context),
          ),
        ),
        BlocProvider<AudioPlayerCubit>(
          create: (BuildContext context) => AudioPlayerCubit(),
        ),
      ],
      child: MaterialApp(
        title: 'WISELY',
        theme: ThemeData(
          primarySwatch: Colors.grey,
        ),
        home: const WiselyHomePage(title: 'WISELY'),
      ),
    );
  }
}

class WiselyHomePage extends StatefulWidget {
  const WiselyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<WiselyHomePage> createState() => _WiselyHomePageState();
}

class _WiselyHomePageState extends State<WiselyHomePage> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();

    SecureStorage.writeValue('foo', 'some secret for testing');
  }

  static const List<Widget> _widgetOptions = <Widget>[
    JournalPage(),
    EditorPage(),
    PhotoImportPage(),
    AudioPage(),
    HealthPage(),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: TextStyle(
            color: AppColors.headerFontColor,
            fontFamily: 'Oswald',
            fontWeight: FontWeight.w500,
          ),
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
    );
  }
}
