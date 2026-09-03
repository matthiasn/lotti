import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';
import 'package:lotti/features/events/ui/widgets/event_photo_gallery.dart';
import 'package:lotti/features/journal/util/image_export_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/platform.dart' as platform;
import 'package:mocktail/mocktail.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

List<EventPhoto> _photos(int n, {int? coverIndex}) => [
  for (var i = 0; i < n; i++)
    EventPhoto(
      testImage(),
      id: 'photo-$i',
      isCover: i == coverIndex,
      filePath: '/tmp/event-photo-$i.png',
      capturedAt: DateTime(2026, 1, i + 1),
    ),
];

/// The gallery page currently in view, driven the way a swipe would land it.
Future<void> _showPage(WidgetTester tester, int index) async {
  tester.widget<PhotoViewGallery>(find.byType(PhotoViewGallery)).onPageChanged!(
    index,
  );
  await tester.pump();
}

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

    testWidgets('badges the chosen cover tile, and only that one', (
      tester,
    ) async {
      await pumpEventComponent(
        tester,
        EventPhotoGrid(photos: _photos(4, coverIndex: 2)),
      );

      final badge = find.text('Cover');
      expect(badge, findsOneWidget);
      // The badge sits on the third tile — the one whose hero tag is index 2.
      final hero = tester.widget<Hero>(
        find.descendant(
          of: find.ancestor(of: badge, matching: find.byType(ClipRRect)).first,
          matching: find.byType(Hero),
        ),
      );
      expect(hero.tag, 'event_photo_2');
    });

    // 360px → 3 columns → a 3×3 preview; the last visible tile stands for
    // its own photo and everything past the cap.
    testWidgets('a chosen cover past the preview cap badges the +N tile', (
      tester,
    ) async {
      await pumpEventComponent(
        tester,
        EventPhotoGrid(photos: _photos(14, coverIndex: 12)),
      );

      final badge = find.text('Cover');
      expect(badge, findsOneWidget);
      final tile = find.ancestor(of: badge, matching: find.byType(ClipRRect));
      expect(
        find.descendant(of: tile.first, matching: find.text('+6')),
        findsOneWidget,
      );
    });

    testWidgets('the +N tile itself being the cover also badges it, and a '
        'cover inside the preview badges its own tile only', (tester) async {
      // Index 8 is the +N tile's own photo.
      await pumpEventComponent(
        tester,
        EventPhotoGrid(photos: _photos(14, coverIndex: 8)),
      );
      expect(find.text('Cover'), findsOneWidget);

      await pumpEventComponent(
        tester,
        EventPhotoGrid(photos: _photos(14, coverIndex: 1)),
      );
      final badge = find.text('Cover');
      expect(badge, findsOneWidget);
      final hero = tester.widget<Hero>(
        find.descendant(
          of: find.ancestor(of: badge, matching: find.byType(ClipRRect)).first,
          matching: find.byType(Hero),
        ),
      );
      expect(hero.tag, 'event_photo_1');
    });

    testWidgets('a grid without a chosen cover badges nothing', (
      tester,
    ) async {
      await pumpEventComponent(tester, EventPhotoGrid(photos: _photos(4)));
      expect(find.text('Cover'), findsNothing);
    });

    testWidgets('hands set-cover through to the viewer for the tapped photo', (
      tester,
    ) async {
      final chosen = <String>[];
      await pumpEventComponent(
        tester,
        EventPhotoGrid(
          photos: _photos(3),
          onSetCover: (id) async {
            chosen.add(id);
            return true;
          },
        ),
      );

      await tester.tap(find.byType(InkWell).at(1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(EventPhotoGalleryViewer), findsOneWidget);

      await tester.tap(find.text('Set cover'));
      await tester.pump();

      expect(chosen, ['photo-1']);
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

    // The place to say "this one" is while looking at it: the pill names the
    // photo in view, flips to "Cover" at once, and the previous cover stops
    // claiming the word — without waiting for the page to resolve again.
    testWidgets('Set cover reports the photo in view and moves the Cover '
        'state to it', (tester) async {
      final chosen = <String>[];
      await tester.pumpWidget(
        makeTestableWidget2(
          EventPhotoGalleryViewer(
            photos: _photos(3, coverIndex: 1),
            onSetCover: (id) async {
              chosen.add(id);
              return true;
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Set cover'), findsOneWidget);
      expect(find.text('Cover'), findsNothing);

      await tester.tap(find.text('Set cover'));
      await tester.pump();

      expect(chosen, ['photo-0']);
      expect(find.text('Cover'), findsOneWidget);
      expect(find.text('Set cover'), findsNothing);

      await _showPage(tester, 1);
      expect(find.text('Set cover'), findsOneWidget);
      expect(find.text('Cover'), findsNothing);
    });

    // The controller reports the persistence layer's verdict; a rejected write
    // is already logged where it was rejected, so the viewer only takes the
    // pill back and tells the user.
    testWidgets('a write reported as not stored takes the pill back to Set '
        'cover and tells the user, without logging it again', (tester) async {
      final logging = MockLoggingService();
      getIt.registerSingleton<LoggingService>(logging);
      addTearDown(getIt.reset);
      await tester.pumpWidget(
        makeTestableWidget2(
          EventPhotoGalleryViewer(
            photos: _photos(2),
            onSetCover: (_) async => false,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Set cover'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Set cover'), findsOneWidget);
      expect(find.text('Cover'), findsNothing);
      expect(
        find.text("That didn't save — please try again."),
        findsOneWidget,
      );
      verifyNever(
        () => logging.captureException(
          any<dynamic>(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
          stackTrace: any<dynamic>(named: 'stackTrace'),
          level: any(named: 'level'),
          type: any(named: 'type'),
        ),
      );
    });

    // Mirrors the download button: a thrown failure is captured under the
    // gallery's log domain and told to the user, and the pill goes back —
    // never a "Cover" the database does not agree with.
    testWidgets('a failed write takes the pill back to Set cover, logs it and '
        'tells the user', (tester) async {
      final logging = MockLoggingService();
      getIt.registerSingleton<LoggingService>(logging);
      addTearDown(getIt.reset);
      await tester.pumpWidget(
        makeTestableWidget2(
          EventPhotoGalleryViewer(
            photos: _photos(2),
            onSetCover: (_) async => throw StateError('db down'),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Set cover'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Set cover'), findsOneWidget);
      expect(find.text('Cover'), findsNothing);
      expect(
        find.text("That didn't save — please try again."),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      verify(
        () => logging.captureException(
          any<dynamic>(),
          domain: 'event_photo_gallery',
          subDomain: 'setCover',
          stackTrace: any<dynamic>(named: 'stackTrace'),
          level: any(named: 'level'),
          type: any(named: 'type'),
        ),
      ).called(1);
    });

    testWidgets('the chosen cover reads Cover, and tapping it does nothing', (
      tester,
    ) async {
      final chosen = <String>[];
      await tester.pumpWidget(
        makeTestableWidget2(
          EventPhotoGalleryViewer(
            photos: _photos(3, coverIndex: 1),
            initialIndex: 1,
            onSetCover: (id) async {
              chosen.add(id);
              return true;
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Cover'), findsOneWidget);
      await tester.tap(find.text('Cover'));
      await tester.pump();
      expect(chosen, isEmpty);
      expect(find.byIcon(LottiIcons.confirmCircled), findsOneWidget);
    });

    testWidgets('no cover control without a handler, or for a photo without '
        'an id', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget2(
          EventPhotoGalleryViewer(photos: _photos(2, coverIndex: 0)),
        ),
      );
      await tester.pump();
      expect(find.text('Cover'), findsNothing);
      expect(find.text('Set cover'), findsNothing);

      await tester.pumpWidget(
        makeTestableWidget2(
          EventPhotoGalleryViewer(
            photos: [EventPhoto(testImage()), EventPhoto(testImage())],
            onSetCover: (_) async => true,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Set cover'), findsNothing);
    });

    testWidgets('the page counter keeps clear of the cover pill on a phone', (
      tester,
    ) async {
      // A real phone surface: on the default 800 px test view a centred
      // counter and the right-hand cluster never meet.
      await pumpEventScreen(
        tester,
        EventPhotoGalleryViewer(
          photos: _photos(3),
          onSetCover: (_) async => true,
        ),
      );

      final counter = tester.getRect(find.text('1 / 3'));
      final pill = tester.getRect(find.text('Set cover'));
      expect(counter.right, lessThan(pill.left));
      expect(counter.left, greaterThan(0));
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
