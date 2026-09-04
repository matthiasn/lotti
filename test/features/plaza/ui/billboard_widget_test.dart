import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/ui/billboard_widget.dart';
import 'package:lotti/features/plaza/ui/plaza_style.dart';

import '../../../widget_test_utils.dart';

final _now = DateTime.utc(2026, 7, 15);

PlazaTask _task({
  PlazaTaskState state = PlazaTaskState.open,
  DateTime? due,
  String? cover,
}) => PlazaTask(
  id: 'bb',
  createdAt: DateTime.utc(2026, 7),
  title: 'Fuel the shuttle',
  state: state,
  progress: 0,
  checklistItems: 0,
  linkedTaskIds: const [],
  categoryColor: 0xFF4AB6E8,
  due: due,
  coverImageUrl: cover,
);

Widget _host(
  PlazaTask task, {
  double heightMeters = 8.5,
  bool reasonFirst = false,
  VoidCallback? onCoverChanged,
}) => makeTestableWidget2(
  Center(
    child: SizedBox(
      width: 600,
      height: heightMeters * 40,
      child: BillboardWidget(
        attention: attentionFor(task, _now),
        widthMeters: 15,
        heightMeters: heightMeters,
        pxPerMeter: 40,
        reasonFirst: reasonFirst,
        onCoverChanged: onCoverChanged,
      ),
    ),
  ),
);

/// A cover the test decodes when it chooses.
Completer<ImageInfo> _pendingCover(String url) {
  final provider = NetworkImage(url);
  final decoded = Completer<ImageInfo>();
  PaintingBinding.instance.imageCache.putIfAbsent(
    provider,
    () => OneFrameImageStreamCompleter(decoded.future),
  );
  addTearDown(provider.evict);
  return decoded;
}

double _frameAlpha(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map((c) => c.decoration)
    .whereType<BoxDecoration>()
    .firstWhere((d) => d.border != null)
    .border!
    .top
    .color
    .a;

void main() {
  late ui.Image coverImage;
  setUpAll(() async {
    coverImage = await createTestImage();
  });
  tearDownAll(() => coverImage.dispose());

  testWidgets('a roof panel leads with the reason and has no fly-there', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(_task(state: PlazaTaskState.blocked), reasonFirst: true),
    );
    expect(find.text('fly there ›'), findsNothing);
    // The reason sits on a solid band in the state colour, in the
    // panel's own dark ink; the title is a small line on the scrim.
    final reason = tester.widget<Text>(find.text('blocked — needs a decision'));
    expect(reason.style!.color, PlazaStyle.panel);
    expect(reason.style!.fontWeight, FontWeight.w800);
    final band = tester.widget<Container>(
      find
          .ancestor(
            of: find.text('blocked — needs a decision'),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(band.color, PlazaStyle.lantern(LanternState.blocked));
    final title = tester.widget<Text>(find.text('Fuel the shuttle'));
    expect(title.style!.color, PlazaStyle.text);
    expect(title.style!.fontSize, lessThan(reason.style!.fontSize! * 1.5));
  });

  testWidgets('a roof panel with nothing to say keeps the title big', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_task(), reasonFirst: true));
    final title = tester.widget<Text>(find.text('Fuel the shuttle'));
    expect(title.style!.color, PlazaStyle.text);
    expect(find.text('fly there ›'), findsNothing);
  });

  testWidgets('a blocked task: title, reason, chip, fly-there, red frame', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_task(state: PlazaTaskState.blocked)));
    expect(find.text('Fuel the shuttle'), findsOneWidget);
    expect(find.text('blocked — needs a decision'), findsOneWidget);
    expect(find.text('✕  BLOCKED'), findsOneWidget);
    expect(find.text('fly there ›'), findsOneWidget);
    final framed = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.border != null);
    expect(
      framed.border!.top.color.withValues(alpha: 1),
      PlazaStyle.lantern(LanternState.blocked),
    );
  });

  testWidgets("the face is still: an anomaly's frame is at full glow", (
    tester,
  ) async {
    await tester.pumpWidget(_host(_task(state: PlazaTaskState.blocked)));
    expect(_frameAlpha(tester), 1);
    await tester.pump(const Duration(seconds: 2));
    expect(_frameAlpha(tester), 1);
    // Nothing on the panel listens to anything.
    expect(find.byType(ValueListenableBuilder<double>), findsNothing);
  });

  testWidgets('a due-soon task shows its date at full glow', (tester) async {
    await tester.pumpWidget(_host(_task(due: _now)));
    expect(find.text('due today — finish it'), findsOneWidget);
    expect(_frameAlpha(tester), 1);
  });

  testWidgets('a cover that lands late asks for one more capture', (
    tester,
  ) async {
    const url = 'https://demo.invalid/late-cover.webp';
    final decoded = _pendingCover(url);
    var changes = 0;
    await tester.pumpWidget(
      _host(
        _task(state: PlazaTaskState.blocked, cover: url),
        onCoverChanged: () => changes++,
      ),
    );
    expect(changes, 0);
    decoded.complete(ImageInfo(image: coverImage.clone()));
    await tester.pump();
    expect(changes, 1);
    await tester.pump();
    expect(changes, 1, reason: 'a rebuild is not a new cover');
  });

  testWidgets('cover art gets the middle of the panel', (tester) async {
    await tester.pumpWidget(
      _host(
        _task(state: PlazaTaskState.blocked, cover: 'https://x.invalid/c.webp'),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a squat roof panel keeps the cover, then drops the reason', (
    tester,
  ) async {
    final task = _task(
      state: PlazaTaskState.blocked,
      cover: 'https://x.invalid/c.webp',
    );
    // 7 m on a 15 m panel: still tall enough for the reason line.
    await tester.pumpWidget(_host(task, heightMeters: 7));
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('blocked — needs a decision'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_host(task, heightMeters: 4));
    expect(find.text('blocked — needs a decision'), findsNothing);
    expect(tester.widget<Text>(find.text('Fuel the shuttle')).maxLines, 1);
    expect(tester.takeException(), isNull);
  });
}
