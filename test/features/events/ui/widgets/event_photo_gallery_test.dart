import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';
import 'package:lotti/features/events/ui/widgets/event_photo_gallery.dart';
import 'package:lotti/utils/platform.dart' as platform;
import 'package:photo_view/photo_view_gallery.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

List<EventPhoto> _photos(int n) => [
  for (var i = 0; i < n; i++) EventPhoto(testImage()),
];

void main() {
  group('EventPhotoGrid', () {
    testWidgets('renders one tile per photo when within the preview', (
      tester,
    ) async {
      await pumpEventComponent(
        tester,
        EventPhotoGrid(photos: _photos(4)),
      );
      expect(find.byType(Image), findsNWidgets(4));
      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('caps the grid and badges the last tile with +N overflow', (
      tester,
    ) async {
      // 360px → 3 columns → a 3×3 preview (9 tiles); 14 photos overflow by 6.
      await pumpEventComponent(
        tester,
        EventPhotoGrid(photos: _photos(14)),
      );
      expect(find.byType(Image), findsNWidgets(9));
      expect(find.text('+6'), findsOneWidget);
    });

    testWidgets('tapping a tile opens the viewer; close dismisses it', (
      tester,
    ) async {
      await pumpEventComponent(
        tester,
        EventPhotoGrid(photos: _photos(4)),
      );

      // The viewer's PhotoView keeps a loading spinner for the undecodable
      // test image, so settle would never complete — pump the transitions.
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(EventPhotoGalleryViewer), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(EventPhotoGalleryViewer), findsNothing);
    });
  });

  group('EventPhotoGalleryViewer', () {
    testWidgets('shows a page indicator and close button for many photos', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget2(
          EventPhotoGalleryViewer(photos: _photos(5)),
        ),
      );
      await tester.pump();

      expect(find.text('1 / 5'), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);

      final gallery = tester.widget<PhotoViewGallery>(
        find.byType(PhotoViewGallery),
      );
      gallery.onPageChanged!(3);
      await tester.pump();

      expect(find.text('4 / 5'), findsOneWidget);
    });

    testWidgets('hides the page indicator for a single photo', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget2(
          EventPhotoGalleryViewer(photos: _photos(1)),
        ),
      );
      await tester.pump();

      expect(find.textContaining(' / '), findsNothing);
    });

    testWidgets(
      'allows landscape while mounted and restores portrait on dispose',
      (tester) async {
        final originalIsMobile = platform.isMobile;
        final originalIsAndroid = platform.isAndroid;
        platform.isMobile = true;
        platform.isAndroid = true;
        addTearDown(() {
          platform.isMobile = originalIsMobile;
          platform.isAndroid = originalIsAndroid;
        });

        final orientationCalls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'SystemChrome.setPreferredOrientations') {
                orientationCalls.add(call);
              }
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null),
        );

        await tester.pumpWidget(
          makeTestableWidget2(EventPhotoGalleryViewer(photos: _photos(1))),
        );
        await tester.pump();

        expect(
          orientationCalls.map((call) => call.arguments),
          [
            [
              'DeviceOrientation.portraitUp',
              'DeviceOrientation.landscapeLeft',
              'DeviceOrientation.landscapeRight',
            ],
          ],
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();

        expect(orientationCalls.last.arguments, [
          'DeviceOrientation.portraitUp',
        ]);
      },
    );
  });
}
