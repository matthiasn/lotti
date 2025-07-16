import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/widgets/misc/map_widget.dart';

void main() {
  group('MapWidget', () {
    Widget createTestWidget({
      Geolocation? geolocation,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: MapWidget(
            geolocation: geolocation,
          ),
        ),
      );
    }

    testWidgets('renders empty Center when geolocation is null',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(),
      );

      expect(find.byType(Center), findsOneWidget);
      expect(find.byType(FlutterMap), findsNothing);
    });

    testWidgets('renders empty Center when latitude is 0', (tester) async {
      final geolocation = Geolocation(
        createdAt: DateTime.now(),
        latitude: 0,
        longitude: 10,
        geohashString: 'test',
      );

      await tester.pumpWidget(
        createTestWidget(
          geolocation: geolocation,
        ),
      );

      expect(find.byType(Center), findsOneWidget);
      expect(find.byType(FlutterMap), findsNothing);
    });

    testWidgets('renders FlutterMap when valid geolocation provided',
        (tester) async {
      final geolocation = Geolocation(
        createdAt: DateTime.now(),
        latitude: 37.7749,
        longitude: -122.4194,
        geohashString: '9q8yy',
      );

      await tester.pumpWidget(
        createTestWidget(
          geolocation: geolocation,
        ),
      );

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(TileLayer), findsOneWidget);
      expect(find.byType(MarkerLayer), findsOneWidget);
    });

    testWidgets('map container has correct height', (tester) async {
      final geolocation = Geolocation(
        createdAt: DateTime.now(),
        latitude: 37.7749,
        longitude: -122.4194,
        geohashString: '9q8yy',
      );

      await tester.pumpWidget(
        createTestWidget(
          geolocation: geolocation,
        ),
      );

      final sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(Center),
          matching: find.byType(SizedBox),
        ),
      );

      expect(sizedBox.height, 300);
    });

    testWidgets('marker is positioned at correct location', (tester) async {
      const testLatitude = 37.7749;
      const testLongitude = -122.4194;

      final geolocation = Geolocation(
        createdAt: DateTime.now(),
        latitude: testLatitude,
        longitude: testLongitude,
        geohashString: '9q8yy',
      );

      await tester.pumpWidget(
        createTestWidget(
          geolocation: geolocation,
        ),
      );

      final markerLayer = tester.widget<MarkerLayer>(
        find.byType(MarkerLayer),
      );

      expect(markerLayer.markers.length, 1);
      final marker = markerLayer.markers.first;
      expect(marker.point.latitude, testLatitude);
      expect(marker.point.longitude, testLongitude);
      expect(marker.width, 64);
      expect(marker.height, 64);
    });

    testWidgets('marker displays location pin image', (tester) async {
      final geolocation = Geolocation(
        createdAt: DateTime.now(),
        latitude: 37.7749,
        longitude: -122.4194,
        geohashString: '9q8yy',
      );

      await tester.pumpWidget(
        createTestWidget(
          geolocation: geolocation,
        ),
      );

      expect(find.byType(Image), findsOneWidget);

      final image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as AssetImage).assetName,
        'assets/images/map/728975_location_map_marker_pin_place_icon.png',
      );
    });

    testWidgets('handles scroll events for zooming', (tester) async {
      final geolocation = Geolocation(
        createdAt: DateTime.now(),
        latitude: 37.7749,
        longitude: -122.4194,
        geohashString: '9q8yy',
      );

      await tester.pumpWidget(
        createTestWidget(
          geolocation: geolocation,
        ),
      );

      // Find the specific Listener that handles scroll events (direct child of SizedBox)
      final listener = find
          .descendant(
            of: find.byType(SizedBox),
            matching: find.byType(Listener),
          )
          .first;

      // Simulate scroll up (zoom in)
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(listener),
          scrollDelta: const Offset(0, -100),
        ),
      );
      await tester.pumpAndSettle();

      // Note: In a real test, we'd need to verify the zoom changed,
      // but due to the way MapController works, we can't easily verify
      // the zoom level changed in the test environment.
      // The actual zoom behavior would need to be tested in integration tests.

      // Simulate scroll down (zoom out)
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(listener),
          scrollDelta: const Offset(0, 100),
        ),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('initializes MapController in initState', (tester) async {
      final geolocation = Geolocation(
        createdAt: DateTime.now(),
        latitude: 37.7749,
        longitude: -122.4194,
        geohashString: '9q8yy',
      );

      await tester.pumpWidget(
        createTestWidget(
          geolocation: geolocation,
        ),
      );

      final flutterMap = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(flutterMap.mapController, isNotNull);
    });

    testWidgets('map is centered on provided location', (tester) async {
      const testLatitude = 40.7128;
      const testLongitude = -74.0060;

      final geolocation = Geolocation(
        createdAt: DateTime.now(),
        latitude: testLatitude,
        longitude: testLongitude,
        geohashString: 'dr5ru',
      );

      await tester.pumpWidget(
        createTestWidget(
          geolocation: geolocation,
        ),
      );

      final mapOptions = tester
          .widget<FlutterMap>(
            find.byType(FlutterMap),
          )
          .options;

      expect(mapOptions.initialCenter.latitude, testLatitude);
      expect(mapOptions.initialCenter.longitude, testLongitude);
    });

    testWidgets('uses correct tile provider URL', (tester) async {
      final geolocation = Geolocation(
        createdAt: DateTime.now(),
        latitude: 37.7749,
        longitude: -122.4194,
        geohashString: '9q8yy',
      );

      await tester.pumpWidget(
        createTestWidget(
          geolocation: geolocation,
        ),
      );

      final tileLayer = tester.widget<TileLayer>(find.byType(TileLayer));
      expect(
        tileLayer.urlTemplate,
        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      );
    });
  });
}
