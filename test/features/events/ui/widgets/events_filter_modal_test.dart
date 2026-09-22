import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_selection_modal.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/events/ui/widgets/events_filter_modal.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';
import '../../../categories/test_utils.dart';

void main() {
  final penguins = CategoryTestUtils.createTestCategory(
    id: 'penguins',
    name: 'Penguin Operations',
    color: '#29B6F6',
    icon: CategoryIcon.values.first,
  );
  final fish = CategoryTestUtils.createTestCategory(
    id: 'fish',
    name: 'Fish Diplomacy',
    color: '#FFA726',
  );

  Future<BuildContext> pumpHost(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late BuildContext hostContext;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: Builder(
            builder: (context) {
              hostContext = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    return hostContext;
  }

  group('buildEventsFilterSheetState', () {
    testWidgets('offers Unassigned first, then each category styled', (
      tester,
    ) async {
      final context = await pumpHost(tester);

      final state = buildEventsFilterSheetState(
        context,
        selectedCategoryIds: const {},
        categories: [penguins, fish],
      );

      expect(state.title, 'Filter events');
      final field = state.categoryField!;
      expect(field.label, 'Category');
      expect(field.options.map((o) => o.id), ['', 'penguins', 'fish']);
      expect(field.options.first.label, 'Unassigned');
      final penguinOption = field.options[1];
      expect(penguinOption.icon, CategoryIcon.values.first.iconData);
      expect(penguinOption.iconColor, const Color(0xFF29B6F6));
      // Events filter by category only: every other section stays out.
      expect(state.statusField, isNull);
      expect(state.hasSortSection, isFalse);
    });

    testWidgets('drops a selection whose category no longer exists', (
      tester,
    ) async {
      final context = await pumpHost(tester);

      final state = buildEventsFilterSheetState(
        context,
        selectedCategoryIds: const {'fish', '', 'deleted'},
        categories: [penguins, fish],
      );

      expect(state.categoryField!.selectedIds, {'fish', ''});
    });
  });

  testWidgets('opens on the category list and applies the picked set', (
    tester,
  ) async {
    final context = await pumpHost(tester);
    Set<String>? applied;

    unawaited(
      showEventsFilterModal(
        context: context,
        selectedCategoryIds: const {'penguins'},
        categories: [penguins, fish],
        onApplied: (ids) => applied = ids,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // One dimension, so the modal skips its overview.
    expect(find.byType(DesignSystemFilterSelectionPage), findsOneWidget);
    expect(find.byType(DesignSystemTaskFilterSheet), findsNothing);

    tester
        .widget<DesignSystemSelectionRow>(
          find.byKey(
            const ValueKey('design-system-filter-selection-option-fish'),
          ),
        )
        .onTap!();
    await tester.pump();
    tester
        .widget<DesignSystemButton>(
          find.byKey(const ValueKey('design-system-task-filter-apply')),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    expect(applied, {'penguins', 'fish'});
  });

  testWidgets('dismissing applies nothing', (tester) async {
    final context = await pumpHost(tester);
    var applyCalls = 0;

    unawaited(
      showEventsFilterModal(
        context: context,
        selectedCategoryIds: const {},
        categories: [penguins, fish],
        onApplied: (_) => applyCalls++,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    Navigator.of(
      tester.element(find.byType(DesignSystemFilterSelectionPage)),
    ).pop();
    await tester.pumpAndSettle();

    expect(applyCalls, 0);
  });
}
