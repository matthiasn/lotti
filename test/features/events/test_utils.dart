import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';

import '../../widget_test_utils.dart';

/// A valid 1×1 transparent PNG so `Image`/cover widgets have a real
/// [ImageProvider] that decodes without throwing (it simply stays pending in
/// the fake-async test env — enough to exercise the "has image" code path).
final Uint8List _png1x1 = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

ImageProvider testImage() => MemoryImage(_png1x1);

const eventPink = Color(0xFFE91E63);
const eventBlue = Color(0xFF2196F3);

EventCardData buildEventCardData({
  String id = 'e1',
  String title = "Anna's 30th Birthday",
  String dateLabel = 'Sat, 12 May',
  DateTime? sortDate,
  EventStatus status = EventStatus.completed,
  double stars = 5,
  String? categoryName = 'Friends',
  Color categoryColor = eventPink,
  ImageProvider? coverImage,
  double coverCropX = 0.5,
  String? summary = 'A surprise rooftop party.',
  String? location = 'Rooftop Bar',
  int photoCount = 24,
  int taskCount = 2,
}) {
  return EventCardData(
    id: id,
    title: title,
    dateLabel: dateLabel,
    sortDate: sortDate,
    status: status,
    stars: stars,
    categoryName: categoryName,
    categoryColor: categoryColor,
    coverImage: coverImage,
    coverCropX: coverCropX,
    summary: summary,
    location: location,
    photoCount: photoCount,
    taskCount: taskCount,
  );
}

EventDetailData buildEventDetailData({
  EventCardData? card,
  String? whenLabel = '19:30 – 02:00 · 18 friends',
  String? summary = 'A surprise 30th for Anna on the rooftop.',
  List<EventTimelineEntry>? timeline,
  List<EventTaskRef>? tasks,
}) {
  return EventDetailData(
    card: card ?? buildEventCardData(coverImage: testImage()),
    whenLabel: whenLabel,
    summary: summary,
    timeline:
        timeline ??
        [
          EventTimelineEntry(
            timeLabel: '20:15',
            kind: EventTimelineKind.photo,
            entryId: 'photo-1',
            text: 'The reveal moment.',
            photos: [EventPhoto(testImage()), EventPhoto(testImage())],
          ),
          const EventTimelineEntry(
            timeLabel: '20:40',
            kind: EventTimelineKind.note,
            entryId: 'note-1',
            text: "Anna's speech.",
          ),
          const EventTimelineEntry(
            timeLabel: '21:30',
            kind: EventTimelineKind.audio,
            entryId: 'audio-1',
            durationLabel: 'Voice note · 0:42',
            text: 'Toast from Dad',
          ),
        ],
    tasks:
        tasks ??
        const [
          EventTaskRef(title: 'Book the venue', done: true),
          EventTaskRef(
            title: 'Share the album',
            done: false,
            dueLabel: 'Due Fri',
          ),
        ],
  );
}

/// Pumps a Scaffold-based surface (overview/detail views) directly as `home`
/// at the given [size].
Future<void> pumpEventScreen(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
}) async {
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    makeTestableWidget2(child, mediaQueryData: MediaQueryData(size: size)),
  );
  await tester.pump();
}

/// Pumps a component widget inside a bounded box (so [Stack]/[AspectRatio]
/// based widgets get finite constraints).
Future<void> pumpEventComponent(
  WidgetTester tester,
  Widget child, {
  double width = 360,
  double? height,
}) async {
  await tester.pumpWidget(
    makeTestableWidget2(
      Scaffold(
        body: Center(
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    ),
  );
  await tester.pump();
}
