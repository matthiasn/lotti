import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_selection_modal.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../widget_test_utils.dart';

void main() {
  DesignSystemTaskFilterState state({
    Set<String> selectedIds = const {'open'},
  }) {
    return DesignSystemTaskFilterState(
      title: 'Filter tasks',
      clearAllLabel: 'Clear all',
      applyLabel: 'Apply',
      statusField: DesignSystemTaskFilterFieldState(
        label: 'Status',
        options: const [
          DesignSystemTaskFilterOption(id: 'open', label: 'Open'),
          DesignSystemTaskFilterOption(id: 'active', label: 'Active'),
          DesignSystemTaskFilterOption(id: 'blocked', label: 'Blocked'),
        ],
        selectedIds: selectedIds,
      ),
    );
  }

  Future<ValueNotifier<DesignSystemTaskFilterState>> pumpPage(
    WidgetTester tester, {
    DesignSystemTaskFilterState? initialState,
    DesignSystemTaskFilterSection section =
        DesignSystemTaskFilterSection.status,
    DesignSystemFilterFieldPageConfig config =
        const DesignSystemFilterFieldPageConfig(),
  }) async {
    final notifier = ValueNotifier(initialState ?? state());
    addTearDown(notifier.dispose);
    await tester.pumpWidget(
      makeTestableWidget(
        Material(
          child: DesignSystemFilterSelectionPage(
            stateNotifier: notifier,
            section: section,
            config: config,
          ),
        ),
      ),
    );
    await tester.pump();
    return notifier;
  }

  Finder option(String id) => find.byKey(
    ValueKey('design-system-filter-selection-option-$id'),
  );

  testWidgets('toggles options in the shared route-scoped draft', (
    tester,
  ) async {
    final notifier = await pumpPage(tester);

    expect(
      tester.widget<DesignSystemSelectionRow>(option('open')).selected,
      isTrue,
    );
    await tester.tap(option('blocked'));
    await tester.pump();
    expect(notifier.value.statusField!.selectedIds, {'open', 'blocked'});

    await tester.tap(option('open'));
    await tester.pump();
    expect(notifier.value.statusField!.selectedIds, {'blocked'});
  });

  testWidgets('disabled options remain unchanged', (tester) async {
    final notifier = await pumpPage(
      tester,
      config: DesignSystemFilterFieldPageConfig(
        appearanceResolver: (id) => id == 'blocked'
            ? const DesignSystemFilterSelectionOptionAppearance(enabled: false)
            : null,
      ),
    );

    expect(
      tester.widget<DesignSystemSelectionRow>(option('blocked')).onTap,
      isNull,
    );
    await tester.tap(option('blocked'));
    expect(notifier.value.statusField!.selectedIds, {'open'});
  });

  testWidgets('renders icon or color-dot appearances without coloring labels', (
    tester,
  ) async {
    const accent = Color(0xFFAA3366);
    await pumpPage(
      tester,
      config: DesignSystemFilterFieldPageConfig(
        appearanceResolver: (id) => switch (id) {
          'open' => const DesignSystemFilterSelectionOptionAppearance(
            icon: Icons.lock_open_rounded,
            foregroundColor: accent,
          ),
          'active' => const DesignSystemFilterSelectionOptionAppearance(
            foregroundColor: accent,
          ),
          _ => null,
        },
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.lock_open_rounded));
    expect(icon.color, accent);
    final dot = tester.widget<Container>(
      find.descendant(of: option('active'), matching: find.byType(Container)),
    );
    expect((dot.decoration! as BoxDecoration).color, accent);
    expect(tester.widget<Text>(find.text('Open')).style?.color, isNot(accent));
  });

  testWidgets('search is case-insensitive and announces an empty result', (
    tester,
  ) async {
    await pumpPage(
      tester,
      config: const DesignSystemFilterFieldPageConfig(
        searchHintText: 'Search status',
      ),
    );

    expect(find.byType(DesignSystemSearch), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'ACT');
    await tester.pump();
    expect(option('active'), findsOneWidget);
    expect(option('open'), findsNothing);

    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump();
    final emptyLabel = tester
        .element(find.byType(DesignSystemFilterSelectionPage))
        .messages
        .filterSelectionNoMatches;
    expect(find.text(emptyLabel), findsOneWidget);
    expect(
      tester.getSemantics(find.text(emptyLabel)).flagsCollection.isLiveRegion,
      isTrue,
    );
  });

  testWidgets('search is inset while selection bands use the full page width', (
    tester,
  ) async {
    await pumpPage(
      tester,
      config: const DesignSystemFilterFieldPageConfig(
        searchHintText: 'Search status',
      ),
    );

    final searchLeft = tester.getTopLeft(find.byType(DesignSystemSearch)).dx;
    final rowLeft = tester.getTopLeft(option('open')).dx;
    final searchWidth = tester.getSize(find.byType(DesignSystemSearch)).width;
    final rowWidth = tester.getSize(option('open')).width;

    expect(rowLeft, lessThan(searchLeft));
    expect(rowWidth, greaterThan(searchWidth));
  });

  testWidgets('groups visible options and omits empty groups after search', (
    tester,
  ) async {
    await pumpPage(
      tester,
      config: DesignSystemFilterFieldPageConfig(
        searchHintText: 'Search status',
        groupsBuilder: (_) => const [
          DesignSystemFilterSelectionGroup(
            label: 'Current',
            optionIds: {'open', 'active'},
          ),
          DesignSystemFilterSelectionGroup(
            label: 'Later',
            optionIds: {'blocked', 'unknown'},
          ),
        ],
      ),
    );

    expect(find.text('Current'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'blocked');
    await tester.pump();
    expect(find.text('Current'), findsNothing);
    expect(find.text('Later'), findsOneWidget);
    expect(option('blocked'), findsOneWidget);
  });

  testWidgets('normalizer runs after every selection change', (tester) async {
    var calls = 0;
    final notifier = await pumpPage(
      tester,
      config: DesignSystemFilterFieldPageConfig(
        normalizeState: (next) {
          calls++;
          return next.replaceFieldSelection(
            DesignSystemTaskFilterSection.status,
            const {'active'},
          );
        },
      ),
    );

    await tester.tap(option('blocked'));
    await tester.pump();
    expect(calls, 1);
    expect(notifier.value.statusField!.selectedIds, {'active'});
  });

  testWidgets('a missing section renders no selection content', (tester) async {
    await pumpPage(
      tester,
      section: DesignSystemTaskFilterSection.category,
    );
    expect(find.byType(DesignSystemSelectionRow), findsNothing);
    expect(find.byType(DesignSystemSearch), findsNothing);
  });
}
