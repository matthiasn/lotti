import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';
import 'package:lotti/features/events/ui/widgets/event_photo_gallery.dart';
import 'package:lotti/features/journal/util/image_export_service.dart';
import 'package:lotti/utils/platform.dart' as platform;
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

List<EventPhoto> _photos(int n) => [
  for (var i = 0; i < n; i++)
    EventPhoto(
      testImage(),
      filePath: '/tmp/event-photo-$i.png',
      capturedAt: DateTime(2026, 1, i + 1),
    ),
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

      await tester.tap(find.byTooltip('Close'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(EventPhotoGalleryViewer), findsNothing);
    });
  });

  group('EventPhotoGalleryViewer', () {
    testWidgets('shows counter, current date, download, and close controls', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget2(
          EventPhotoGalleryViewer(photos: _photos(5)),
        ),
      );
      await tester.pump();

      expect(find.text('1 / 5'), findsOneWidget);
      expect(find.text('Jan 1, 2026'), findsOneWidget);
      expect(find.byTooltip('Download image'), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);

      final gallery = tester.widget<PhotoViewGallery>(
        find.byType(PhotoViewGallery),
      );
      expect(gallery.enableRotation, isFalse);
      gallery.onPageChanged!(3);
      await tester.pump();

      expect(find.text('4 / 5'), findsOneWidget);
      expect(find.text('Jan 4, 2026'), findsOneWidget);
    });

    testWidgets('download exports the currently visible photo', (tester) async {
      final exported = <String>[];
      await tester.pumpWidget(
        makeTestableWidget2(
          EventPhotoGalleryViewer(
            photos: _photos(3),
            imageExporter: (file) async {
              exported.add(file.path);
              return const ImageExportResult.cancelled();
            },
          ),
        ),
      );
      await tester.pump();

      final gallery = tester.widget<PhotoViewGallery>(
        find.byType(PhotoViewGallery),
      );
      gallery.onPageChanged!(1);
      await tester.pump();
      await tester.tap(find.byTooltip('Download image'));
      await tester.pump();

      expect(exported, ['/tmp/event-photo-1.png']);
    });

    testWidgets('single taps hide and restore every overlay control', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget2(
          EventPhotoGalleryViewer(photos: _photos(3)),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(PhotoView));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('1 / 3'), findsNothing);
      expect(find.text('Jan 1, 2026'), findsNothing);
      expect(find.byTooltip('Download image'), findsNothing);
      expect(find.byTooltip('Close'), findsNothing);

      await tester.tap(find.byType(PhotoView));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.text('Jan 1, 2026'), findsOneWidget);
      expect(find.byTooltip('Download image'), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);
    });

    testWidgets('double tap zoom leaves overlays visible', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget2(
          EventPhotoGalleryViewer(photos: _photos(2)),
        ),
      );
      await tester.pump();

      final photo = find.byType(PhotoView);
      await tester.tap(photo);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(photo);
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byTooltip('Close'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
    });

    testWidgets('uses the file date when capture metadata is unavailable', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget2(
          EventPhotoGalleryViewer(
            photos: [
              EventPhoto(
                testImage(),
                fileDate: DateTime(2025, 12, 24),
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Dec 24, 2025'), findsOneWidget);
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

    testWidgets('keeps close control inside the landscape right safe area', (
      tester,
    ) async {
      const landscapeSize = Size(844, 390);
      const rightInset = 44.0;
      const withoutInset = MediaQueryData(size: landscapeSize);
      const withInset = MediaQueryData(
        size: landscapeSize,
        padding: EdgeInsets.only(right: rightInset),
      );

      await tester.pumpWidget(
        makeTestableWidget2(
          EventPhotoGalleryViewer(photos: _photos(1)),
          mediaQueryData: withoutInset,
        ),
      );
      await tester.pump();
      final closeButton = find.widgetWithIcon(IconButton, LottiIcons.close);
      final rightWithoutInset = tester.getTopRight(closeButton).dx;

      await tester.pumpWidget(
        makeTestableWidget2(
          EventPhotoGalleryViewer(photos: _photos(1)),
          mediaQueryData: withInset,
        ),
      );
      await tester.pump();
      final rightWithInset = tester.getTopRight(closeButton).dx;

      expect(rightWithInset, rightWithoutInset - rightInset);
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
