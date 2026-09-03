import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/ui/jumbotron_widget.dart';

import '../../../widget_test_utils.dart';

PlazaTask _task(String id, String title) => PlazaTask(
  id: id,
  createdAt: DateTime.utc(2026, 7),
  title: title,
  state: PlazaTaskState.blocked,
  progress: 0,
  checklistItems: 0,
  linkedTaskIds: const [],
  categoryColor: 0,
);

void main() {
  final now = DateTime.utc(2026, 7, 15);
  final headlines = [
    for (var i = 0; i < 4; i++) attentionFor(_task('$i', 'Headline $i'), now),
  ];

  Widget host({List<String> covers = const []}) => makeTestableWidget2(
    Center(
      child: SizedBox(
        width: 900,
        height: 480,
        child: JumbotronWidget(
          projectLabel: 'Project Waddle',
          taskCount: 28,
          attentionCount: 7,
          headlines: headlines,
          covers: covers,
          widthMeters: 30,
          pxPerMeter: 30,
        ),
      ),
    ),
  );

  testWidgets('project name, counts and the top three headlines', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    expect(find.text('Project Waddle'), findsOneWidget);
    expect(find.text('28 tasks · 7 need attention'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      expect(find.textContaining('Headline $i'), findsOneWidget);
    }
    expect(find.textContaining('Headline 3'), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cycles the hero covers every few seconds', (tester) async {
    await tester.pumpWidget(
      host(covers: ['https://x.invalid/a.webp', 'https://x.invalid/b.webp']),
    );
    Image image() => tester.widget<Image>(find.byType(Image));
    expect((image().image as NetworkImage).url, endsWith('a.webp'));
    await tester.pump(const Duration(seconds: 6));
    expect((image().image as NetworkImage).url, endsWith('b.webp'));
    await tester.pump(const Duration(seconds: 6));
    expect((image().image as NetworkImage).url, endsWith('a.webp'));
  });
}
