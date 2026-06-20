import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';
import 'package:lotti/features/events/ui/widgets/event_photo_gallery.dart';

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
  });
}
