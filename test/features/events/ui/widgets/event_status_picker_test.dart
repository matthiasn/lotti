import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/features/events/ui/widgets/event_status_picker.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('eventStatusLabel', () {
    testWidgets('returns the localized status label', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        makeTestableWidget2(
          Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(eventStatusLabel(ctx, EventStatus.tentative), 'Tentative');
      expect(eventStatusLabel(ctx, EventStatus.completed), 'Completed');
      expect(eventStatusLabel(ctx, EventStatus.rescheduled), 'Rescheduled');
    });

    testWidgets('uses Czech and German copy for every event status', (
      tester,
    ) async {
      final expectedLabels = <Locale, List<String>>{
        const Locale('cs'): [
          'Předběžně',
          'Naplánováno',
          'Probíhá',
          'Dokončeno',
          'Zrušeno',
          'Odloženo',
          'Přeplánováno',
          'Zmeškáno',
        ],
        const Locale('de'): [
          'Vorläufig',
          'Geplant',
          'Läuft',
          'Abgeschlossen',
          'Abgesagt',
          'Verschoben',
          'Neu geplant',
          'Verpasst',
        ],
      };

      for (final localeLabels in expectedLabels.entries) {
        late BuildContext localizedContext;
        await tester.pumpWidget(
          makeTestableWidget2(
            Builder(
              builder: (context) => Localizations.override(
                context: context,
                locale: localeLabels.key,
                child: Builder(
                  builder: (context) {
                    localizedContext = context;
                    return const SizedBox();
                  },
                ),
              ),
            ),
          ),
        );

        expect(
          [
            for (final status in EventStatus.values)
              eventStatusLabel(localizedContext, status),
          ],
          localeLabels.value,
        );
      }
    });
  });

  group('showEventStatusPicker', () {
    Widget opener(EventStatus current, void Function(EventStatus?) onResult) {
      return makeTestableWidget2(
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                onResult(
                  await showEventStatusPicker(
                    context: context,
                    current: current,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
    }

    testWidgets('lists every status and returns the tapped one', (
      tester,
    ) async {
      EventStatus? picked;
      var called = false;
      await tester.pumpWidget(
        opener(EventStatus.tentative, (r) {
          picked = r;
          called = true;
        }),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Every status renders as a row (localized labels).
      const labels = [
        'Tentative',
        'Planned',
        'Ongoing',
        'Completed',
        'Cancelled',
        'Postponed',
        'Rescheduled',
        'Missed',
      ];
      expect(labels, hasLength(EventStatus.values.length));
      for (final label in labels) {
        expect(find.text(label), findsWidgets);
      }

      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();

      expect(called, isTrue);
      expect(picked, EventStatus.completed);
    });

    testWidgets('marks the current status with a check', (tester) async {
      await tester.pumpWidget(opener(EventStatus.ongoing, (_) {}));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });
}
