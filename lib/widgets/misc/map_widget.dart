import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/map/cached_tile_provider.dart';

class MapWidget extends StatefulWidget {
  const MapWidget({super.key, this.geolocation});

  final Geolocation? geolocation;

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  late final MapController mapController;

  @override
  void initState() {
    super.initState();
    mapController = MapController();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.geolocation == null || widget.geolocation!.latitude == 0) {
      return const Center();
    }

    final loc = LatLng(
      widget.geolocation!.latitude,
      widget.geolocation!.longitude,
    );

    return Center(
      child: IgnorePointer(
        child: SizedBox(
          height: 200,
          child: Listener(
            onPointerSignal: (pointerSignal) {
              if (pointerSignal is PointerScrollEvent) {
                if (pointerSignal.scrollDelta.dy < 0) {
                  mapController.move(
                    mapController.center,
                    mapController.zoom + 1,
                  );
                } else {
                  mapController.move(
                    mapController.center,
                    mapController.zoom - 1,
                  );
                }
              }
            },
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                center: loc,
              ),
              layers: [
                TileLayerOptions(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: ['a', 'b', 'c'],
                  tileProvider: const CachedTileProvider(),
                ),
                MarkerLayerOptions(
                  markers: [
                    Marker(
                      width: 64,
                      height: 64,
                      point: loc,
                      builder: (ctx) => const Opacity(
                        opacity: 0.8,
                        child: Image(
                          image: AssetImage(
                            'assets/images/map/728975_location_map_marker_pin_place_icon.png',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
