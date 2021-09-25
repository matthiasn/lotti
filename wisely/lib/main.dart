import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:quill_markdown/quill_markdown.dart';
import 'package:uuid/uuid.dart';
import 'package:wisely/db/entry.dart';
import 'package:wisely/db/persistence.dart';
import 'package:wisely/health/health_service.dart';
import 'package:wisely/location.dart';
import 'package:wisely/pages/editor.dart';
import 'package:wisely/pages/settings.dart';
import 'package:wisely/sync/imap.dart';
import 'package:wisely/sync/secure_storage.dart';
import 'package:wisely/theme.dart';

void main() {
  runApp(const WiselyApp());
}

class WiselyApp extends StatelessWidget {
  const WiselyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WISELY',
      theme: ThemeData(
        primarySwatch: Colors.grey,
      ),
      home: const WiselyHomePage(title: 'WISELY'),
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
  late ImapSyncClient imapSyncClient;
  QuillController _controller = QuillController.basic();

  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  int _counter = 0;
  DeviceLocation location = DeviceLocation();
  static LatLng berlin = LatLng(52.5, 13.4);
  LatLng _currentLocation = berlin;

  late final MapController mapController;

  late Persistence db;
  late HealthService healthService;

  @override
  void initState() {
    super.initState();
    mapController = MapController();

    imapSyncClient = ImapSyncClient();

    SecureStorage.writeValue('foo', 'some secret for testing');
    db = Persistence();
    healthService = HealthService();
  }

  void _importPhoto() async {
    final ImagePicker _picker = ImagePicker();
    // final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    // final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    final List<XFile>? images = await _picker.pickMultiImage();
    print(images);
  }

  void _incrementCounter() async {
    // _importPhoto();
    // healthService.fetchData();
    setState(() {
      String json = jsonEncode(_controller.document.toDelta().toJson());
      String md = quillToMarkdown(json);
      print(md);
      _counter++;
    });

    var uuid = Uuid();

    db.insertEntry(Entry(
        entryId: uuid.v1(),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        plainText: 'foo',
        markdown: 'foo',
        quill: '',
        vectorClock: '',
        commentFor: '',
        latitude: 0,
        longitude: 0));

    var loc = await location.getCurrentLocation();
    var latitude = loc.latitude;
    var longitude = loc.longitude;

    if (latitude != null && longitude != null) {
      _currentLocation = LatLng(latitude, longitude);
      mapController.move(_currentLocation, 17);
    }

    db.insertEntry(Entry(
        entryId: uuid.v1(),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        plainText: 'foo',
        markdown: 'foo',
        quill: '',
        vectorClock: '',
        commentFor: '',
        latitude: latitude ?? 0,
        longitude: longitude ?? 0));

    print(await db.entries());
  }

  static const List<Widget> _widgetOptions = <Widget>[
    Text(
      'Index 0: Home',
    ),
    EditorPage(),
    Text(
      'Index 2: Photos',
    ),
    Text(
      'Index 3: Health',
    ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
