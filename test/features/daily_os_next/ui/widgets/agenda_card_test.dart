import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/agenda_card.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/editable_title.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/link_badge.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/cover_art_thumbnail.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../helpers/fake_entry_controller.dart';
import '../../../../widget_test_utils.dart';

Widget _wrap(Widget child) => makeTestableWidget2(
  child,
  mediaQueryData: const MediaQueryData(size: Size(1280, 900)),
);

Widget _wrapPhone(Widget child) => makeTestableWidget2(
  child,
  mediaQueryData: const MediaQueryData(size: Size(390, 844)),
);

Widget _wrapWithTheme(
  Widget child,
  ThemeData theme, {
  List<Override> overrides = const [],
}) => makeTestableWidgetNoScroll(
  child,
  overrides: overrides,
  mediaQueryData: const MediaQueryData(size: Size(390, 844)),
  theme: theme,
);

const _category = DayAgentCategory(
  id: 'cat_work',
  name: 'Work',
  colorHex: '5ED4B7',
);

JournalImage _image({String id = 'image-1'}) {
  final now = DateTime(2026, 5, 26, 9);
  return JournalImage(
    meta: Metadata(
      id: id,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
    ),
    data: ImageData(
      imageId: 'image-data-$id',
      imageFile: '$id.jpg',
      imageDirectory: '/covers/',
      capturedAt: now,
    ),
  );
}

void main() {
  group('AgendaCard', () {
    testWidgets('renders title, outcome and inline estimate metadata', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const Material(
            child: AgendaCard(
              index: 1,
              item: AgendaItem(
                id: 'a1',
                title: 'Send the leadership deck to Sarah',
                category: _category,
                linkedBlockIds: ['b1'],
                outcome: 'Deck reviewed by Sarah, sent to leadership.',
                totalEstimateMinutes: 120,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Send the leadership deck to Sarah'), findsOneWidget);
      expect(
        find.text('Deck reviewed by Sarah, sent to leadership.'),
        findsOneWidget,
      );
      expect(find.text('120m'), findsOneWidget);
      expect(find.text('Open'), findsNothing);
    });

    testWidgets('shows why metadata when a whyReason is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const Material(
            child: AgendaCard(
              index: 1,
              item: AgendaItem(
                id: 'a1',
                title: 'Deep work',
                category: _category,
                linkedBlockIds: ['b1'],
              ),
              whyReason: 'High-energy window 8–10:30.',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
      expect(find.text('WHY'), findsOneWidget);
      expect(find.byTooltip('High-energy window 8–10:30.'), findsOneWidget);
    });

    testWidgets('omits why metadata when no reason is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const Material(
            child: AgendaCard(
              index: 1,
              item: AgendaItem(
                id: 'a1',
                title: 'Plain item',
                category: _category,
                linkedBlockIds: ['b1'],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
      expect(find.text('WHY'), findsNothing);
    });

    testWidgets('invokes onTap when the card is tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          Material(
            child: AgendaCard(
              index: 1,
              item: const AgendaItem(
                id: 'a1',
                title: 'Open task',
                category: _category,
                linkedBlockIds: ['b1'],
                taskId: 'task-1',
              ),
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pump();

      // Title and link badge both carry the task name for a linked
      // item — tap the card title (first match).
      await tester.tap(find.text('Open task').first);
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets(
      'task-linked items show a link badge that opens the task; '
      'standalone items show the neutral time-block tag',
      (tester) async {
        var opened = 0;
        await tester.pumpWidget(
          _wrap(
            Material(
              child: Column(
                children: [
                  AgendaCard(
                    index: 1,
                    item: const AgendaItem(
                      id: 'a1',
                      title: 'Linked item',
                      category: _category,
                      linkedBlockIds: ['b1'],
                      taskId: 'task-1',
                    ),
                    displayTitle: 'Live task name',
                    onTap: () => opened++,
                  ),
                  const AgendaCard(
                    index: 2,
                    item: AgendaItem(
                      id: 'a2',
                      title: 'Standalone item',
                      category: _category,
                      linkedBlockIds: ['b2'],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();

        // Link badge carries the live task name and opens the task.
        expect(find.byType(LinkBadge), findsOneWidget);
        expect(find.text('Live task name'), findsOneWidget);
        await tester.tap(find.byType(LinkBadge));
        await tester.pump();
        expect(opened, 1);

        // Standalone item carries the neutral tag instead.
        expect(find.byType(StandaloneTag), findsOneWidget);
        final messages = tester.element(find.byType(StandaloneTag)).messages;
        expect(find.text(messages.dailyOsNextStandaloneTag), findsOneWidget);
      },
    );

    testWidgets(
      'standalone titles are click-to-edit and submit the new title; '
      'task-linked titles stay read-only',
      (tester) async {
        final renames = <String>[];
        await tester.pumpWidget(
          _wrap(
            Material(
              child: Column(
                children: [
                  AgendaCard(
                    index: 1,
                    item: const AgendaItem(
                      id: 'a1',
                      title: 'Standalone item',
                      category: _category,
                      linkedBlockIds: ['b1'],
                    ),
                    onRename: renames.add,
                  ),
                  AgendaCard(
                    index: 2,
                    item: const AgendaItem(
                      id: 'a2',
                      title: 'Linked item',
                      category: _category,
                      linkedBlockIds: ['b2'],
                      taskId: 'task-2',
                    ),
                    onRename: renames.add,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();

        // Only the standalone item is editable.
        expect(find.byType(EditableTitle), findsOneWidget);

        await tester.tap(find.text('Standalone item'));
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('daily_os_editable_title_field')),
          'Renamed standalone',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();

        expect(renames, ['Renamed standalone']);
      },
    );

    testWidgets('wraps long titles on phone layouts instead of ellipsizing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapPhone(
          const Material(
            child: AgendaCard(
              index: 2,
              item: AgendaItem(
                id: 'a1',
                title: 'Sprint Roundup presentation for leadership review',
                category: _category,
                linkedBlockIds: ['b1'],
                totalEstimateMinutes: 60,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final title = tester.widget<Text>(
        find.text('Sprint Roundup presentation for leadership review'),
      );
      expect(title.maxLines, greaterThan(1));
      expect(title.overflow, TextOverflow.fade);
    });

    testWidgets('renders task cover art as the leading visual', (
      tester,
    ) async {
      final image = _image();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [createEntryControllerOverride(image)],
          child: _wrapPhone(
            const Material(
              child: AgendaCard(
                index: 3,
                item: AgendaItem(
                  id: 'a1',
                  title: 'Task with cover art',
                  category: _category,
                  linkedBlockIds: ['b1'],
                ),
                coverArtId: 'image-1',
                coverArtCropX: 0.25,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CoverArtThumbnail), findsOneWidget);
      final thumbnail = tester.widget<CoverArtThumbnail>(
        find.byType(CoverArtThumbnail),
      );
      expect(thumbnail.imageId, 'image-1');
      expect(thumbnail.cropX, 0.25);
    });

    testWidgets(
      'solid cover number chooses dark text on light category colors',
      (tester) async {
        await tester.pumpWidget(
          _wrapWithTheme(
            const Material(
              child: AgendaCard(
                index: 1,
                item: AgendaItem(
                  id: 'a1',
                  title: 'Mint cover',
                  category: _category,
                  linkedBlockIds: ['b1'],
                ),
                coverArtId: 'image-1',
              ),
            ),
            ThemeData.light(useMaterial3: true),
            overrides: [createEntryControllerOverride(_image())],
          ),
        );
        await tester.pump();

        final indexText = tester.widget<Text>(find.text('1'));
        expect(indexText.style?.color, dsTokensLight.colors.text.highEmphasis);
      },
    );

    testWidgets(
      'solid cover number chooses dark-theme contrast per category color',
      (tester) async {
        const blueCategory = DayAgentCategory(
          id: 'cat_blue',
          name: 'Blue',
          colorHex: '4AB6E8',
        );
        await tester.pumpWidget(
          _wrapWithTheme(
            const Material(
              child: AgendaCard(
                index: 2,
                item: AgendaItem(
                  id: 'a1',
                  title: 'Blue cover',
                  category: blueCategory,
                  linkedBlockIds: ['b1'],
                ),
                coverArtId: 'image-1',
              ),
            ),
            ThemeData.dark(useMaterial3: true),
            overrides: [createEntryControllerOverride(_image())],
          ),
        );
        await tester.pump();

        final indexText = tester.widget<Text>(find.text('2'));
        expect(
          indexText.style?.color,
          dsTokensDark.colors.text.onInteractiveAlert,
        );
      },
    );

    testWidgets('renders progress metadata alongside a state pill', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const Material(
            child: AgendaCard(
              index: 4,
              item: AgendaItem(
                id: 'a1',
                title: 'Close out shipped work',
                category: _category,
                linkedBlockIds: ['b1'],
                state: AgendaItemState.done,
                progress: 0.75,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 0.75);
    });

    // Drives the non-open branches of `_StateMeta`'s switch: each state maps to
    // a distinct alert color token and localized label, rendered as the state
    // pill's label text. The `open` state is intentionally absent: the meta row
    // only builds `_StateMeta` when `state != open`, so that branch is
    // unreachable through the widget.
    final alertColors = dsTokensLight.colors.alert;
    final stateCases = <(AgendaItemState, String, Color)>[
      (
        AgendaItemState.inProgress,
        'In progress',
        alertColors.warning.defaultColor,
      ),
      (AgendaItemState.overdue, 'Overdue', alertColors.error.defaultColor),
      (AgendaItemState.done, 'Done', alertColors.success.defaultColor),
    ];

    for (final (state, label, expectedColor) in stateCases) {
      testWidgets('maps $state to its alert color and "$label" label', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(
            Material(
              child: AgendaCard(
                index: 4,
                item: AgendaItem(
                  id: 'a1',
                  title: 'Close out shipped work',
                  category: _category,
                  linkedBlockIds: const ['b1'],
                  state: state,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final labelFinder = find.text(label);
        expect(labelFinder, findsOneWidget);
        final labelText = tester.widget<Text>(labelFinder);
        expect(labelText.style?.color, expectedColor);
      });
    }

    testWidgets('omits the state pill for the open state', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Material(
            child: AgendaCard(
              index: 4,
              item: AgendaItem(
                id: 'a1',
                title: 'Plain open item',
                category: _category,
                linkedBlockIds: ['b1'],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Open'), findsNothing);
      expect(find.text('In progress'), findsNothing);
      expect(find.text('Overdue'), findsNothing);
      expect(find.text('Done'), findsNothing);
    });
  });
}
