import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/events/ui/widgets/event_status_picker.dart';
import 'package:lotti/themes/event_status_colors.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

/// English labels of [EventStatus.values], in declaration order.
const _englishLabels = [
  'Tentative',
  'Planned',
  'Ongoing',
  'Completed',
  'Cancelled',
  'Postponed',
  'Rescheduled',
  'Missed',
];

Finder _row(EventStatus status) =>
    find.byKey(ValueKey('event-status-${status.name}'));

DesignSystemSelectionRow _rowWidget(WidgetTester tester, EventStatus status) =>
    tester.widget<DesignSystemSelectionRow>(_row(status));

Icon _leadingIcon(WidgetTester tester, EventStatus status) =>
    _rowWidget(tester, status).leading! as Icon;

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

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
      expect(
        [
          for (final status in EventStatus.values)
            eventStatusLabel(ctx, status),
        ],
        _englishLabels,
      );
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

  group('eventStatusIcon', () {
    test('maps every status to its own icon', () {
      expect(
        {
          for (final status in EventStatus.values)
            status: eventStatusIcon(status),
        },
        {
          EventStatus.tentative: LottiIcons.help,
          EventStatus.planned: LottiIcons.calendar,
          EventStatus.ongoing: LottiIcons.playCircled,
          EventStatus.completed: LottiIcons.confirmCircled,
          EventStatus.cancelled: LottiIcons.closeCircled,
          EventStatus.postponed: LottiIcons.pauseCircled,
          EventStatus.rescheduled: LottiIcons.replay,
          EventStatus.missed: LottiIcons.warning,
        },
      );
    });

    test('no two statuses share an icon', () {
      final icons = EventStatus.values.map(eventStatusIcon).toSet();
      expect(icons, hasLength(EventStatus.values.length));
    });

    test('statuses that share a colour never share an icon', () {
      // Five hues cover eight statuses, so the icon is what tells
      // same-coloured statuses (e.g. Cancelled and Missed) apart.
      for (final brightness in Brightness.values) {
        final byColor = <Color, Set<IconData>>{};
        for (final status in EventStatus.values) {
          final icons = byColor.putIfAbsent(
            status.colorForBrightness(brightness),
            () => <IconData>{},
          );
          expect(
            icons.add(eventStatusIcon(status)),
            isTrue,
            reason: '${status.name} / ${brightness.name}',
          );
        }
      }
    });
  });

  group('EventStatusModalContent', () {
    /// Hosts the content on a pushed route so a row tap's pop has somewhere
    /// to return to; [results] collects what the route resolved to.
    Future<List<EventStatus?>> pumpContent(
      WidgetTester tester,
      EventStatus current, {
      Brightness brightness = Brightness.light,
    }) async {
      final results = <EventStatus?>[];
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => results.add(
                await Navigator.of(context).push<EventStatus>(
                  MaterialPageRoute(
                    builder: (routeContext) => Theme(
                      data: Theme.of(
                        routeContext,
                      ).copyWith(brightness: brightness),
                      child: Scaffold(
                        body: EventStatusModalContent(current: current),
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('push'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('push'));
      await tester.pumpAndSettle();
      return results;
    }

    testWidgets('renders one single-select row per status, in order', (
      tester,
    ) async {
      await pumpContent(tester, EventStatus.planned);

      final rows = tester
          .widgetList<DesignSystemSelectionRow>(
            find.byType(DesignSystemSelectionRow),
          )
          .toList();
      expect(rows.map((r) => r.title), _englishLabels);
      expect(
        rows.map((r) => r.type),
        everyElement(DesignSystemSelectionRowType.singleSelect),
      );
    });

    for (final brightness in Brightness.values) {
      testWidgets(
        'leads each row with the status icon in its ${brightness.name} shade',
        (tester) async {
          await pumpContent(
            tester,
            EventStatus.planned,
            brightness: brightness,
          );
          final tokens = tester
              .element(find.byType(EventStatusModalContent))
              .designTokens;

          for (final status in EventStatus.values) {
            final icon = _leadingIcon(tester, status);
            expect(icon.icon, eventStatusIcon(status), reason: status.name);
            expect(
              icon.color,
              status.colorForBrightness(brightness),
              reason: status.name,
            );
            expect(icon.size, tokens.spacing.step6, reason: status.name);
          }
        },
      );
    }

    testWidgets('selects only the current status', (tester) async {
      await pumpContent(tester, EventStatus.postponed);

      for (final status in EventStatus.values) {
        expect(
          _rowWidget(tester, status).selected,
          status == EventStatus.postponed,
          reason: status.name,
        );
      }
    });

    testWidgets('tapping a row pops the route with that status', (
      tester,
    ) async {
      final results = await pumpContent(tester, EventStatus.planned);

      await tester.tap(_row(EventStatus.missed));
      await tester.pumpAndSettle();

      expect(results, [EventStatus.missed]);
      expect(find.byType(EventStatusModalContent), findsNothing);
    });

    testWidgets('tapping the current status pops with null', (tester) async {
      final results = await pumpContent(tester, EventStatus.ongoing);

      await tester.tap(_row(EventStatus.ongoing));
      await tester.pumpAndSettle();

      expect(results, [null]);
      expect(find.byType(EventStatusModalContent), findsNothing);
    });
  });

  group('showEventStatusPicker', () {
    /// Opens the picker over [current]; the returned list receives the
    /// modal's result once it closes.
    Future<List<EventStatus?>> openPicker(
      WidgetTester tester,
      EventStatus current,
    ) async {
      final results = <EventStatus?>[];
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => results.add(
                await showEventStatusPicker(
                  context: context,
                  current: current,
                ),
              ),
              child: const Text('open picker'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open picker'));
      await tester.pumpAndSettle();
      return results;
    }

    testWidgets('shows the localized title above the status list', (
      tester,
    ) async {
      await openPicker(tester, EventStatus.tentative);

      expect(find.text('Status'), findsOneWidget);
      expect(
        find.byType(DesignSystemSelectionRow),
        findsNWidgets(EventStatus.values.length),
      );
    });

    testWidgets('marks the current status as the selected row', (
      tester,
    ) async {
      await openPicker(tester, EventStatus.completed);

      expect(_rowWidget(tester, EventStatus.completed).selected, isTrue);
      expect(
        EventStatus.values
            .where((s) => _rowWidget(tester, s).selected)
            .toList(),
        [EventStatus.completed],
      );
    });

    testWidgets('resolves to the tapped status and closes', (tester) async {
      final results = await openPicker(tester, EventStatus.tentative);

      await tester.tap(_row(EventStatus.completed));
      await tester.pumpAndSettle();

      expect(results, [EventStatus.completed]);
      expect(find.byType(EventStatusModalContent), findsNothing);
    });

    testWidgets('resolves to null when the current status is tapped', (
      tester,
    ) async {
      final results = await openPicker(tester, EventStatus.completed);

      await tester.tap(_row(EventStatus.completed));
      await tester.pumpAndSettle();

      expect(results, [null]);
      expect(find.byType(EventStatusModalContent), findsNothing);
    });

    testWidgets('resolves to null when closed without a choice', (
      tester,
    ) async {
      final results = await openPicker(tester, EventStatus.planned);

      await tester.tap(find.byIcon(LottiIcons.close));
      await tester.pumpAndSettle();

      expect(results, [null]);
      expect(find.byType(EventStatusModalContent), findsNothing);
    });
  });
}
