import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:wisely/blocs/audio/player_cubit.dart';
import 'package:wisely/blocs/audio/player_state.dart';
import 'package:wisely/map/cached_tile_provider.dart';

class MapWidget extends StatefulWidget {
  const MapWidget({Key? key}) : super(key: key);

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
    return BlocBuilder<AudioPlayerCubit, AudioPlayerState>(
        builder: (BuildContext context, AudioPlayerState state) {
      double? longitude = state.audioNote?.geolocation?.longitude;
      double? latitude = state.audioNote?.geolocation?.latitude;
      if (longitude == null || latitude == null) {
        return const Center();
      }
      LatLng loc = LatLng(latitude, longitude);

      return Center(
        child: SizedBox(
          height: 180,
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
                center: loc,
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
                      point: loc,
                      builder: (ctx) => const Opacity(
                        opacity: 0.8,
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
      );
    });
  }
}
