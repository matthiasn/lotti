import 'package:location/location.dart';

class DeviceLocation {
  late Location location;

  DeviceLocation() {
    location = new Location();
    init();
  }

  void init() async {
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }
  }

  Future<LocationData> getCurrentLocation() async {
    LocationData _locationData = await location.getLocation();
    print(_locationData);
    return _locationData;
  }
}
