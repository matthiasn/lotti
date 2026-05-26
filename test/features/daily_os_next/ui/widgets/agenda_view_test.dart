import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/agenda_view.dart';
import 'package:lotti/services/nav_service.dart';

import '../../../../widget_test_utils.dart';

Widget _wrap(Widget child) => makeTestableWidget2(
  child,
  mediaQueryData: const MediaQueryData(size: Size(1280, 900)),
);

const _category = DayAgentCategory(
  id: 'cat_work',
  name: 'Work',
  colorHex: '5ED4B7',
);

DraftPlan _draft({String? taskId}) {
  final day = DateTime(2026, 5, 26);
  return DraftPlan(
    dayDate: day,
    blocks: const [],
    bands: const [],
    capacityMinutes: 480,
    scheduledMinutes: 60,
    agendaItems: [
      AgendaItem(
        id: 'agenda-1',
        title: 'Complete client animation',
        category: _category,
        linkedBlockIds: const ['block-1'],
        taskId: taskId,
        totalEstimateMinutes: 60,
      ),
    ],
  );
}

void main() {
  tearDown(() => beamToNamedOverride = null);

  group('AgendaView', () {
    testWidgets('opens task-backed agenda items through app navigation', (
      tester,
    ) async {
      String? openedPath;
      beamToNamedOverride = (path) => openedPath = path;

      await tester.pumpWidget(_wrap(AgendaView(draft: _draft(taskId: 't1'))));
      await tester.pump();

      await tester.tap(find.text('Complete client animation'));
      await tester.pump();

      expect(openedPath, '/tasks/t1');
    });

    testWidgets('leaves standalone agenda items inert', (tester) async {
      String? openedPath;
      beamToNamedOverride = (path) => openedPath = path;

      await tester.pumpWidget(_wrap(AgendaView(draft: _draft())));
      await tester.pump();

      await tester.tap(find.text('Complete client animation'));
      await tester.pump();

      expect(openedPath, isNull);
    });
  });
}
