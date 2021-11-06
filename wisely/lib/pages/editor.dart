import 'dart:convert';

import 'package:delta_markdown/delta_markdown.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import 'package:wisely/db/entry.dart';
import 'package:wisely/db/persistence.dart';
import 'package:wisely/location.dart';
import 'package:wisely/map/cached_tile_provider.dart';
import 'package:wisely/theme.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({Key? key}) : super(key: key);

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final QuillController _controller = QuillController.basic();

  DeviceLocation location = DeviceLocation();
  static LatLng berlin = LatLng(52.5, 13.4);
  LatLng _currentLocation = berlin;

  late final MapController mapController;
  late Persistence db;

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    db = Persistence();
  }

  void _save() async {
    setState(() {
      Delta _delta = _controller.document.toDelta();
      String _json = jsonEncode(_delta.toJson());
      String _md = deltaToMarkdown(_json);
    });

    const uuid = Uuid();
    DateTime created = DateTime.now();
    String timezone = await FlutterNativeTimezone.getLocalTimezone();

    db.insertEntry(Entry(
        entryId: uuid.v1(),
        createdAt: created.millisecondsSinceEpoch,
        updatedAt: created.millisecondsSinceEpoch,
        utcOffset: created.timeZoneOffset.inMinutes,
        timezone: timezone,
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

    DateTime updated = DateTime.now();

    db.insertEntry(Entry(
        entryId: uuid.v1(),
        createdAt: created.millisecondsSinceEpoch,
        updatedAt: updated.millisecondsSinceEpoch,
        utcOffset: created.timeZoneOffset.inMinutes,
        timezone: created.timeZoneName,
        plainText: 'foo',
        markdown: 'foo',
        quill: '',
        vectorClock: '',
        commentFor: '',
        latitude: latitude ?? 0,
        longitude: longitude ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            OutlinedButton(
              onPressed: _save,
              child: const Text(
                'Save',
                style: TextStyle(color: CupertinoColors.systemOrange),
              ),
            ),
            SizedBox(
              height: 200,
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
                      tileProvider: const CachedTileProvider(),
                    ),
                    MarkerLayerOptions(
                      markers: [
                        Marker(
                          width: 64.0,
                          height: 64.0,
                          point: _currentLocation,
                          builder: (ctx) => const Image(
                            image: AssetImage(
                                'assets/images/map/728975_location_map_marker_pin_place_icon.png'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Container(
                //width: 400,
                padding: const EdgeInsets.all(8.0),
                height: 400,
                color: AppColors.editorBgColor,
                child: Column(
                  children: [
                    QuillToolbar.basic(controller: _controller),
                    Expanded(
                      child: QuillEditor.basic(
                        controller: _controller,
                        readOnly: false, // true for view only mode
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
