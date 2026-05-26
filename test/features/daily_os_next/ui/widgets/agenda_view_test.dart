// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/agenda_card.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/agenda_view.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/capacity_meter.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
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

    testWidgets('comfortable capacity (< 90%) shows comfortable overline', (
      tester,
    ) async {
      final draft = DraftPlan(
        dayDate: DateTime(2026, 5, 26),
        blocks: const [],
        bands: const [],
        capacityMinutes: 600,
        scheduledMinutes: 300, // 50% utilisation.
        agendaItems: const [],
      );
      await tester.pumpWidget(_wrap(AgendaView(draft: draft)));

      final messages = tester.element(find.byType(AgendaView)).messages;
      expect(
        find.text(messages.dailyOsNextAgendaCapacityComfortable),
        findsOneWidget,
      );
      expect(
        find.text(messages.dailyOsNextAgendaCapacityNearFull),
        findsNothing,
      );
      expect(
        find.text(messages.dailyOsNextAgendaCapacityOver),
        findsNothing,
      );
    });

    testWidgets('near-full capacity (90–100%) shows near-full overline', (
      tester,
    ) async {
      final draft = DraftPlan(
        dayDate: DateTime(2026, 5, 26),
        blocks: const [],
        bands: const [],
        capacityMinutes: 600,
        scheduledMinutes: 570, // 95%.
        agendaItems: const [],
      );
      await tester.pumpWidget(_wrap(AgendaView(draft: draft)));

      final messages = tester.element(find.byType(AgendaView)).messages;
      expect(
        find.text(messages.dailyOsNextAgendaCapacityNearFull),
        findsOneWidget,
      );
    });

    testWidgets('over-capacity (> 100%) shows over overline', (tester) async {
      final draft = DraftPlan(
        dayDate: DateTime(2026, 5, 26),
        blocks: const [],
        bands: const [],
        capacityMinutes: 600,
        scheduledMinutes: 720, // 120%.
        agendaItems: const [],
      );
      await tester.pumpWidget(_wrap(AgendaView(draft: draft)));

      final messages = tester.element(find.byType(AgendaView)).messages;
      expect(
        find.text(messages.dailyOsNextAgendaCapacityOver),
        findsOneWidget,
      );
    });

    testWidgets('summary string interpolates scheduled / capacity hours', (
      tester,
    ) async {
      final draft = DraftPlan(
        dayDate: DateTime(2026, 5, 26),
        blocks: const [],
        bands: const [],
        capacityMinutes: 240,
        scheduledMinutes: 90, // 1h 30m of 4h.
        agendaItems: const [],
      );
      await tester.pumpWidget(_wrap(AgendaView(draft: draft)));

      final messages = tester.element(find.byType(AgendaView)).messages;
      expect(
        find.text(messages.dailyOsNextAgendaSummary('1h 30m', '4h')),
        findsOneWidget,
      );
      expect(find.byType(CapacityMeter), findsOneWidget);
    });

    testWidgets('empty agenda items renders the empty-state message', (
      tester,
    ) async {
      final draft = DraftPlan(
        dayDate: DateTime(2026, 5, 26),
        blocks: const [],
        bands: const [],
        capacityMinutes: 240,
        scheduledMinutes: 0,
        agendaItems: const [],
      );
      await tester.pumpWidget(_wrap(AgendaView(draft: draft)));

      final messages = tester.element(find.byType(AgendaView)).messages;
      expect(find.text(messages.dailyOsNextAgendaEmpty), findsOneWidget);
      expect(find.byType(AgendaCard), findsNothing);
    });

    testWidgets(
      'category mix renders one legend per used category, dropped blocks excluded',
      (tester) async {
        const work = DayAgentCategory(
          id: 'w',
          name: 'Work',
          colorHex: '5ED4B7',
        );
        const personal = DayAgentCategory(
          id: 'p',
          name: 'Personal',
          colorHex: 'FF00AA',
        );
        final start = DateTime(2026, 5, 26, 9);
        final draft = DraftPlan(
          dayDate: DateTime(2026, 5, 26),
          blocks: [
            TimeBlock(
              id: 'b1',
              title: 'Deep work',
              start: start,
              end: start.add(const Duration(minutes: 90)),
              type: TimeBlockType.ai,
              state: TimeBlockState.drafted,
              category: work,
            ),
            TimeBlock(
              id: 'b2',
              title: 'Errands',
              start: start.add(const Duration(hours: 2)),
              end: start.add(const Duration(hours: 2, minutes: 30)),
              type: TimeBlockType.manual,
              state: TimeBlockState.drafted,
              category: personal,
            ),
            TimeBlock(
              id: 'b3',
              title: 'Cancelled review',
              start: start.add(const Duration(hours: 4)),
              end: start.add(const Duration(hours: 5)),
              type: TimeBlockType.ai,
              state: TimeBlockState.dropped,
              category: work,
            ),
          ],
          bands: const [],
          capacityMinutes: 480,
          scheduledMinutes: 120,
          agendaItems: const [],
        );
        await tester.pumpWidget(_wrap(AgendaView(draft: draft)));

        // 90m of Work (dropped 60m excluded), 30m of Personal.
        expect(find.text('Work · 1h 30m'), findsOneWidget);
        expect(find.text('Personal · 0h 30m'), findsOneWidget);
      },
    );

    testWidgets('zero-capacity day computes ratio safely (no divide-by-zero)', (
      tester,
    ) async {
      final draft = DraftPlan(
        dayDate: DateTime(2026, 5, 26),
        blocks: const [],
        bands: const [],
        capacityMinutes: 0,
        scheduledMinutes: 0,
        agendaItems: const [],
      );
      await tester.pumpWidget(_wrap(AgendaView(draft: draft)));

      // Ratio defaults to 0 → comfortable overline.
      final messages = tester.element(find.byType(AgendaView)).messages;
      expect(
        find.text(messages.dailyOsNextAgendaCapacityComfortable),
        findsOneWidget,
      );
    });
  });
}
