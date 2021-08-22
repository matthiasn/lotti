import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:latlong2/latlong.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:quill_markdown/quill_markdown.dart';
import 'package:wisely/location.dart';
import 'package:wisely/theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WISELY',
      theme: ThemeData(
        primarySwatch: Colors.grey,
      ),
      home: const MyHomePage(title: 'WISELY'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  QuillController _controller = QuillController.basic();

  int _counter = 0;
  DeviceLocation location = DeviceLocation();
  LatLng? _currentLocation = null;
  static LatLng berlin = LatLng(52.5, 13.4);

  late final MapController mapController;

  @override
  void initState() {
    super.initState();
    mapController = MapController();
  }

  void _incrementCounter() async {
    setState(() {
      String json = jsonEncode(_controller.document.toDelta().toJson());
      String md = quillToMarkdown(json);
      print(md);
      _counter++;
    });

    var loc = await location.getCurrentLocation();

    if (loc.latitude != null && loc.longitude != null) {
      mapController.move(LatLng(loc.latitude!, loc.longitude!), 17);
    }
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
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
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
                          subdomains: ['a', 'b', 'c']),
                      MarkerLayerOptions(
                        markers: [
                          Marker(
                            width: 64.0,
                            height: 64.0,
                            point: berlin,
                            builder: (ctx) => Container(
                              child: Image(
                                image: AssetImage(
                                    'images/map/728975_location_map_marker_pin_place_icon.png'),
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
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(
                    Radius.circular(8.0),
                  ),
                ),
                child: QrImage(
                  data:
                      '1234567890123456789012345678901234567890123456789012345678901234567890',
                  version: QrVersions.auto,
                  size: 200.0,
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
