import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/ui/checklist_ticks.dart';
import 'package:lotti/features/plaza/ui/facade_widget.dart';
import 'package:lotti/features/plaza/ui/plaza_style.dart';

import '../../../widget_test_utils.dart';

final _now = DateTime.utc(2026, 7, 15);

PlazaTask _task({
  PlazaTaskState state = PlazaTaskState.open,
  double progress = 0,
  int checklistItems = 0,
  List<String> openItems = const [],
  List<String> links = const [],
  DateTime? due,
  String? coverUrl,
}) {
  return PlazaTask(
    id: 'facade-test',
    createdAt: DateTime.utc(2026, 3, 2, 9),
    title: 'Negotiate sardine futures',
    state: state,
    progress: progress,
    checklistItems: checklistItems,
    openChecklistItems: openItems,
    linkedTaskIds: links,
    categoryColor: 0xFF5C9DFF,
    due: due,
    coverImageUrl: coverUrl,
  );
}

Widget _host(
  PlazaTask task, {
  FacadeVariant variant = FacadeVariant.live,
  ChecklistTicks? ticks,
  VoidCallback? onOpen,
  VoidCallback? onCoverChanged,
  bool focused = false,
  double widthMeters = 12,
  double heightMeters = 16,
}) {
  return makeTestableWidget2(
    Center(
      child: SizedBox(
        width: widthMeters * 45,
        height: heightMeters * 45,
        child: FacadeWidget(
          task: task,
          attention: attentionFor(task, _now),
          variant: variant,
          widthMeters: widthMeters,
          pxPerMeter: 45,
          ticks: ticks,
          onOpen: onOpen,
          onCoverChanged: onCoverChanged,
          focused: focused,
        ),
      ),
    ),
  );
}

Completer<ImageInfo> _pendingCover(String url) {
  final provider = NetworkImage(url);
  final decoded = Completer<ImageInfo>();
  PaintingBinding.instance.imageCache.putIfAbsent(
    provider,
    () => OneFrameImageStreamCompleter(decoded.future),
  );
  addTearDown(() => provider.evict());
  return decoded;
}

void main() {
  late ui.Image coverImage;
  setUpAll(() async {
    coverImage = await createTestImage();
  });
  tearDownAll(() => coverImage.dispose());

  testWidgets('a late decoded cover invalidates its sign texture once', (
    tester,
  ) async {
    const url = 'https://demo.invalid/delayed-cover.webp';
    final decoded = _pendingCover(url);
    var invalidations = 0;
    final task = _task(coverUrl: url);
    await tester.pumpWidget(
      _host(
        task,
        variant: FacadeVariant.sign,
        onCoverChanged: () => invalidations++,
      ),
    );
    expect(invalidations, 0);
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNull);
    decoded.complete(ImageInfo(image: coverImage.clone()));
    await tester.pump();
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
    expect(invalidations, 1);
    await tester.pumpWidget(
      _host(
        task,
        variant: FacadeVariant.sign,
        onCoverChanged: () => invalidations++,
      ),
    );
    await tester.pump();
    expect(
      invalidations,
      1,
      reason: 'ordinary rebuilds do not re-capture a static sign',
    );
  });

  testWidgets('a replacement cover failure invalidates the previous picture', (
    tester,
  ) async {
    const firstUrl = 'https://demo.invalid/first-cover.webp';
    const nextUrl = 'https://demo.invalid/next-cover.webp';
    final first = _pendingCover(firstUrl);
    final next = _pendingCover(nextUrl);
    var invalidations = 0;
    await tester.pumpWidget(
      _host(
        _task(coverUrl: firstUrl),
        variant: FacadeVariant.sign,
        onCoverChanged: () => invalidations++,
      ),
    );
    first.complete(ImageInfo(image: coverImage.clone()));
    await tester.pump();
    expect(invalidations, 1);
    await tester.pumpWidget(
      _host(
        _task(coverUrl: nextUrl),
        variant: FacadeVariant.sign,
        onCoverChanged: () => invalidations++,
      ),
    );
    next.completeError(StateError('cover unavailable'));
    await tester.pump();
    await tester.pump();
    expect(invalidations, 2);
    expect(find.byType(RawImage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tall live wall never overflows its checklist', (
    tester,
  ) async {
    // The landmark at the closeup stop: a 16.5 × 28.8 m wall, four items
    // whose rows must fit the space the column gives them or be dropped.
    for (final height in [28.8, 24.0, 20.0, 14.0, 9.0]) {
      await tester.pumpWidget(
        _host(
          _task(
            state: PlazaTaskState.blocked,
            due: DateTime.utc(2026, 7, 20),
            links: ['a'],
            checklistItems: 4,
            openItems: [
              'Draft the passenger ruling request',
              'Copy the current manifest',
              'Ask the harbour master',
              'File the customs form',
            ],
          ),
          widthMeters: 16.5,
          heightMeters: height,
        ),
      );
      expect(tester.takeException(), isNull, reason: 'height $height');
    }
  });

  testWidgets('a finished task is a quiet, small sign', (tester) async {
    double titlePx(PlazaTaskState state, FacadeVariant variant) {
      final text = tester.widget<Text>(find.text('Negotiate sardine futures'));
      return text.style!.fontSize!;
    }

    for (final variant in FacadeVariant.values) {
      await tester.pumpWidget(
        _host(_task(), variant: variant),
      );
      final open = titlePx(PlazaTaskState.open, variant);
      await tester.pumpWidget(
        _host(_task(state: PlazaTaskState.done), variant: variant),
      );
      final done = titlePx(PlazaTaskState.done, variant);
      expect(done, closeTo(open * 0.55, 1e-6), reason: '$variant');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('live facade shows title, chip, meta and progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _task(
          state: PlazaTaskState.inProgress,
          due: DateTime.utc(2026, 7, 17),
          links: ['a', 'b'],
          checklistItems: 4,
          progress: 0.5,
          openItems: ['Check bay two', 'Ask the dock crew'],
        ),
      ),
    );
    expect(find.text('Negotiate sardine futures'), findsOneWidget);
    expect(find.textContaining('IN PROGRESS'), findsOneWidget);
    expect(find.text('due Jul 17  ·  links 2'), findsOneWidget);
    expect(find.text('2/4'), findsOneWidget);
    expect(find.text('Check bay two'), findsOneWidget);
    // The progress light bar is scene geometry, not part of the widget.
    expect(find.byType(FractionallySizedBox), findsNothing);
  });

  testWidgets('sign facade keeps title, cover, chip and bar only', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _task(
          state: PlazaTaskState.inProgress,
          due: DateTime.utc(2026, 7, 17),
          checklistItems: 2,
          openItems: ['Check bay two'],
          coverUrl: 'https://demo.invalid/cover.webp',
        ),
        variant: FacadeVariant.sign,
      ),
    );
    expect(find.text('Negotiate sardine futures'), findsOneWidget);
    expect(find.textContaining('IN PROGRESS'), findsOneWidget);
    expect(find.textContaining('due Jul 17'), findsNothing);
    expect(find.text('Check bay two'), findsNothing);
    expect(find.text('DETAILS ›'), findsNothing);
    // Cover art stays: it is what makes a street read from a distance.
    expect(find.byType(Image), findsOneWidget);
    // Bigger type than the live variant for the same wall.
    final sign = tester.widget<Text>(find.text('Negotiate sardine futures'));
    await tester.pumpWidget(_host(_task()));
    final live = tester.widget<Text>(find.text('Negotiate sardine futures'));
    expect(sign.style!.fontSize, greaterThan(live.style!.fontSize!));
  });

  testWidgets('overdue overrides the chip', (tester) async {
    await tester.pumpWidget(_host(_task(due: DateTime.utc(2026, 7))));
    expect(find.textContaining('OVERDUE'), findsOneWidget);
    expect(find.textContaining('OPEN'), findsNothing);
  });

  testWidgets('the sign variant carries the state as a full-width band', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(_task(state: PlazaTaskState.blocked), variant: FacadeVariant.sign),
    );
    final band = tester.widget<Text>(find.textContaining('BLOCKED'));
    expect(band.textAlign, TextAlign.center);
    expect(band.data, startsWith('✕'));
    await tester.pumpWidget(_host(_task(state: PlazaTaskState.blocked)));
    final chip = tester.widget<Text>(find.textContaining('BLOCKED'));
    expect(band.style!.fontSize, greaterThan(chip.style!.fontSize!));
  });

  testWidgets('a long word shrinks the title instead of breaking mid-word', (
    tester,
  ) async {
    final wordy = PlazaTask(
      id: 'w',
      createdAt: DateTime.utc(2026, 3, 2, 9),
      title: 'Recalibrate the interplanetary sardine pods',
      state: PlazaTaskState.open,
      progress: 0,
      checklistItems: 0,
      linkedTaskIds: const [],
      categoryColor: 0xFF5C9DFF,
    );
    Widget host(double widthMeters) => makeTestableWidget2(
      Center(
        child: SizedBox(
          width: widthMeters * 45,
          height: 500,
          child: FacadeWidget(
            task: wordy,
            attention: attentionFor(wordy, _now),
            variant: FacadeVariant.sign,
            widthMeters: widthMeters,
            pxPerMeter: 45,
          ),
        ),
      ),
    );
    await tester.pumpWidget(host(12));
    final wide = tester.widget<Text>(find.text(wordy.title)).style!.fontSize!;
    await tester.pumpWidget(host(5));
    final narrow = tester.widget<Text>(find.text(wordy.title)).style!.fontSize!;
    expect(narrow, lessThan(wide));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ticking on the wall goes through the shared ticks', (
    tester,
  ) async {
    final ticks = ChecklistTicks();
    await tester.pumpWidget(
      _host(
        _task(
          state: PlazaTaskState.inProgress,
          checklistItems: 3,
          progress: 1 / 3,
          openItems: ['Check bay two', 'Ask the dock crew'],
        ),
        ticks: ticks,
      ),
    );
    expect(find.text('1/3'), findsOneWidget);
    await tester.tap(find.text('Check bay two'));
    await tester.pump();
    expect(ticks.isTicked('facade-test', 0), isTrue);
    expect(find.text('2/3'), findsOneWidget);
    final struck = tester.widget<Text>(find.text('Check bay two'));
    expect(struck.style?.decoration, TextDecoration.lineThrough);

    // A tick from elsewhere (the side panel) shows on the wall too.
    ticks.toggle('facade-test', 1);
    await tester.pump();
    expect(find.text('3/3'), findsOneWidget);
  });

  testWidgets('without ticks the items are inert; DETAILS fires its callback', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      _host(
        _task(
          state: PlazaTaskState.inProgress,
          checklistItems: 1,
          openItems: ['Check bay two'],
        ),
        onOpen: () => opened++,
      ),
    );
    await tester.tap(find.text('Check bay two'));
    await tester.pump();
    expect(
      tester.widget<Text>(find.text('Check bay two')).style?.decoration,
      isNull,
    );
    await tester.tap(find.text('DETAILS ›'));
    expect(opened, 1);
  });

  testWidgets('the DETAILS button and the state chip use the design colours', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(_task(state: PlazaTaskState.blocked), onOpen: () {}),
    );
    expect(find.textContaining('BLOCKED'), findsOneWidget);
    // The button's fill is ink on the wall's Material, so the hover wash
    // shows over it.
    final open = tester.widget<Ink>(
      find.ancestor(of: find.text('DETAILS ›'), matching: find.byType(Ink)),
    );
    expect((open.decoration! as BoxDecoration).color, PlazaStyle.teal);
  });

  testWidgets('focused draws the teal ring', (tester) async {
    await tester.pumpWidget(_host(_task(), focused: true));
    final ringed = tester
        .widgetList<Container>(find.byType(Container))
        .where((c) => c.foregroundDecoration != null);
    expect(ringed, hasLength(1));
    final border =
        (ringed.first.foregroundDecoration! as BoxDecoration).border!;
    expect(border.top.color, PlazaStyle.teal);
    await tester.pumpWidget(_host(_task()));
    expect(
      tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.foregroundDecoration != null),
      isEmpty,
    );
  });

  testWidgets('a broken cover collapses without throwing', (tester) async {
    await tester.pumpWidget(
      _host(_task(coverUrl: 'https://demo.invalid/cover.webp')),
    );
    expect(find.byType(Image), findsOneWidget);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(RawImage), findsNothing);
  });

  testWidgets('a live wall with cover art keeps its checklist rows', (
    tester,
  ) async {
    // A 15 m panel on a 20 m wall: the cover must not eat the list.
    final task = _task(
      state: PlazaTaskState.blocked,
      coverUrl: 'https://x.invalid/c.webp',
      checklistItems: 4,
      openItems: [for (var i = 0; i < 4; i++) 'Item $i'],
    );
    await tester.pumpWidget(
      makeTestableWidget2(
        Center(
          child: SizedBox(
            width: 540,
            height: 675, // 15 m at 45 px/m
            child: FacadeWidget(
              task: task,
              attention: attentionFor(task, _now),
              variant: FacadeVariant.live,
              widthMeters: 12,
              pxPerMeter: 45,
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget);
    expect(find.textContaining('Item '), findsAtLeast(2));
  });

  testWidgets('a short wall shows only the items that fit, no overflow', (
    tester,
  ) async {
    final task = _task(
      state: PlazaTaskState.inProgress,
      checklistItems: 8,
      openItems: [for (var i = 0; i < 8; i++) 'Item $i'],
    );
    await tester.pumpWidget(
      makeTestableWidget2(
        Center(
          child: SizedBox(
            width: 540,
            height: 420, // a 9.3 m wall at 45 px/m
            child: FacadeWidget(
              task: task,
              attention: attentionFor(task, _now),
              variant: FacadeVariant.live,
              widthMeters: 12,
              pxPerMeter: 45,
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final shown = find.textContaining('Item ');
    expect(shown.evaluate().length, lessThan(8));
    expect(shown.evaluate().length, greaterThan(0));
    expect(find.text('Item 0'), findsOneWidget);
  });
}
