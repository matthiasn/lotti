import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:quill_markdown/quill_markdown.dart';
import 'package:wisely/data/entry.dart';
import 'package:wisely/data/persistence.dart';
import 'package:wisely/location.dart';
import 'package:wisely/sync/imap.dart';
import 'package:wisely/sync/qr_display_widget.dart';
import 'package:wisely/sync/qr_scanner_widget.dart';
import 'package:wisely/sync/secure_storage.dart';
import 'package:wisely/theme.dart';

import 'data/health_service.dart';
import 'map/cached_tile_provider.dart';

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
    _importPhoto();
    setState(() {
      String json = jsonEncode(_controller.document.toDelta().toJson());
      String md = quillToMarkdown(json);
      print(md);
      _counter++;
    });

    var loc = await location.getCurrentLocation();
    var latitude = loc.latitude;
    var longitude = loc.longitude;

    if (latitude != null && longitude != null) {
      _currentLocation = LatLng(latitude, longitude);
      mapController.move(_currentLocation, 17);
    }

    db.insertEntry(Entry(
        id: DateTime.now().millisecondsSinceEpoch,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        plainText: 'foo',
        latitude: latitude ?? 0,
        longitude: longitude ?? 0));

    print(await db.entries());
  }

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
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                height: 300,
                child: Listener(
                  onPointerSignal: (pointerSignal) {
                    if (pointerSignal is PointerScrollEvent) {
                      if (pointerSignal.scrollDelta.dy < 0) {
                        mapController.move(
                            mapController.center, mapController.zoom + 1);
                      } else {
                        mapController.move(
                            mapController.center, mapController.zoom - 1);
                      }
                    }
                  },
                  child: FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      center: berlin,
                      zoom: 13.0,
                    ),
                    layers: [
                      TileLayerOptions(
                        urlTemplate:
                            "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                        subdomains: ['a', 'b', 'c'],
                        tileProvider: CachedTileProvider(),
                      ),
                      MarkerLayerOptions(
                        markers: [
                          Marker(
                            width: 64.0,
                            height: 64.0,
                            point: _currentLocation,
                            builder: (ctx) => Container(
                              child: Image(
                                image: AssetImage(
                                    'assets/images/map/728975_location_map_marker_pin_place_icon.png'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Container(
                  //width: 400,
                  padding: EdgeInsets.all(8.0),
                  height: 400,
                  color: AppColors.editorBgColor,
                  child: Column(
                    children: [
                      QuillToolbar.basic(controller: _controller),
                      Expanded(
                        child: Container(
                          child: QuillEditor.basic(
                            controller: _controller,
                            readOnly: false, // true for view only mode
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const Text(
                'You have pushed the button this many times:',
              ),
              Text(
                '$_counter',
                style: Theme.of(context).textTheme.headline4,
              ),
              QrDisplayWidget(),
              if (Platform.isIOS) QrScannerWidget(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
