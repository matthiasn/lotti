import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurable_choices_editor.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../test_data/test_data.dart';
import '../../../../../test_utils/material_ui_finders.dart';
import '../../../../../widget_test_utils.dart';

/// Plays the editor's parent: holds the list, hands every emitted list back
/// in, and records what was emitted so a test can assert on the contract
/// rather than on rendering alone.
class _Host extends StatefulWidget {
  const _Host({
    required this.initial,
    required this.emitted,
    this.showErrors = false,
    this.newChoiceId,
    super.key,
  });

  final List<MeasurableChoice> initial;
  final List<List<MeasurableChoice>> emitted;
  final bool showErrors;
  final String Function()? newChoiceId;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late List<MeasurableChoice> choices = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: MeasurableChoicesEditor(
        choices: choices,
        showErrors: widget.showErrors,
        newChoiceId: widget.newChoiceId ?? () => 'new-id',
        onChanged: (next) {
          widget.emitted.add(next);
          setState(() => choices = next);
        },
      ),
    );
  }
}

void main() {
  Future<List<List<MeasurableChoice>>> pump(
    WidgetTester tester, {
    required List<MeasurableChoice> initial,
    bool showErrors = false,
    String Function()? newChoiceId,
  }) async {
    final emitted = <List<MeasurableChoice>>[];
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        _Host(
          // A fresh host per pump: the same widget type in the same slot
          // would keep its State — and the previous list — otherwise.
          key: UniqueKey(),
          initial: initial,
          emitted: emitted,
          showErrors: showErrors,
          newChoiceId: newChoiceId,
        ),
      ),
    );
    await tester.pump();
    return emitted;
  }

  Finder titleField(String id) =>
      find.byKey(ValueKey('measurable-choice-title-$id'));
  Finder archiveAction(String id) =>
      find.byKey(ValueKey('measurable-choice-archive-$id'));
  Finder restoreAction(String id) =>
      find.byKey(ValueKey('measurable-choice-restore-$id'));
  Finder dragHandle(String id) =>
      find.byKey(ValueKey('measurable-choice-drag-$id'));
  Finder row(String id) => find.byKey(ValueKey('measurable-choice-row-$id'));

  String fieldText(WidgetTester tester, String id) => tester
      .widget<TextField>(
        find.descendant(of: titleField(id), matching: find.byType(TextField)),
      )
      .controller!
      .text;

  group('normalize', () {
    test('keeps active choices in order and trails the archived ones', () {
      expect(
        MeasurableChoicesEditor.normalize(const [
          hydrationBrown,
          hydrationDark,
          hydrationClear,
        ]),
        const [hydrationDark, hydrationClear, hydrationBrown],
      );
    });

    test('is a no-op on an already normalised list', () {
      const list = [hydrationClear, hydrationPale, hydrationBrown];
      expect(MeasurableChoicesEditor.normalize(list), list);
    });
  });

  group('MeasurableChoicesEditor rendering', () {
    testWidgets(
      'lists active choices as editable rows with drag handles and archived '
      'ones under their own section',
      (tester) async {
        await pump(
          tester,
          initial: const [hydrationClear, hydrationPale, hydrationBrown],
        );

        expect(fieldText(tester, hydrationClear.id), 'Clear');
        expect(fieldText(tester, hydrationPale.id), 'Pale');
        expect(dragHandle(hydrationClear.id), findsOneWidget);
        expect(dragHandle(hydrationPale.id), findsOneWidget);
        expect(archiveAction(hydrationClear.id), findsOneWidget);

        // The archived choice is not an editable row.
        expect(titleField(hydrationBrown.id), findsNothing);
        expect(dragHandle(hydrationBrown.id), findsNothing);
        expect(find.text('Archived choices'), findsOneWidget);
        expect(find.text('Brown'), findsOneWidget);
        expect(restoreAction(hydrationBrown.id), findsOneWidget);
        expect(
          find.byKey(const ValueKey('measurable-choices-empty')),
          findsNothing,
        );
      },
    );

    testWidgets('without archived choices the archived section is absent', (
      tester,
    ) async {
      await pump(tester, initial: const [hydrationClear]);
      expect(find.text('Archived choices'), findsNothing);
      expect(find.text('Choices'), findsOneWidget);
    });

    testWidgets(
      'an empty list shows the at-least-one hint quietly, and in error ink '
      'once errors are shown',
      (tester) async {
        await pump(tester, initial: const []);
        final quiet = tester.widget<Text>(
          find.byKey(const ValueKey('measurable-choices-empty')),
        );
        final tokens = tester
            .element(find.byType(MeasurableChoicesEditor))
            .designTokens;
        expect(quiet.data, 'Add at least one choice');
        expect(quiet.style?.color, tokens.colors.text.mediumEmphasis);
        expect(find.byType(ReorderableListView), findsNothing);

        await pump(tester, initial: const [], showErrors: true);
        final loud = tester.widget<Text>(
          find.byKey(const ValueKey('measurable-choices-empty')),
        );
        expect(loud.style?.color, tokens.colors.alert.error.ink);
      },
    );

    testWidgets(
      'a blank title is only called out as an error when errors are shown',
      (tester) async {
        const blank = MeasurableChoice(id: 'blank', title: '   ');
        await pump(tester, initial: const [blank, hydrationClear]);
        expect(find.text('Give this choice a name'), findsNothing);

        await pump(
          tester,
          initial: const [blank, hydrationClear],
          showErrors: true,
        );
        // Only the blank row carries the error.
        expect(find.text('Give this choice a name'), findsOneWidget);
        expect(
          find.descendant(
            of: titleField('blank'),
            matching: find.text('Give this choice a name'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('a blank row names itself by the hint in its actions', (
      tester,
    ) async {
      const blank = MeasurableChoice(id: 'blank', title: '');
      await pump(tester, initial: const [blank]);
      expect(findMaterialTooltip('Reorder Choice name'), findsOneWidget);
      expect(findMaterialTooltip('Archive Choice name'), findsOneWidget);

      await pump(tester, initial: const [hydrationClear]);
      expect(findMaterialTooltip('Reorder Clear'), findsOneWidget);
      expect(findMaterialTooltip('Archive Clear'), findsOneWidget);
    });
  });

  group('MeasurableChoicesEditor edits', () {
    testWidgets('Add choice appends a blank choice with the minted id', (
      tester,
    ) async {
      final emitted = await pump(
        tester,
        initial: const [hydrationClear, hydrationBrown],
        newChoiceId: () => 'minted',
      );

      await tester.tap(find.byKey(const ValueKey('measurable-choice-add')));
      await tester.pump();

      // Appended after the active choices, ahead of the archived tail.
      expect(emitted.single, const [
        hydrationClear,
        MeasurableChoice(id: 'minted', title: ''),
        hydrationBrown,
      ]);
      expect(titleField('minted'), findsOneWidget);
      expect(fieldText(tester, 'minted'), '');
    });

    testWidgets('typing renames the choice in place, id untouched', (
      tester,
    ) async {
      final emitted = await pump(
        tester,
        initial: const [hydrationClear, hydrationPale],
      );

      await tester.enterText(titleField(hydrationPale.id), 'Pale yellow');
      await tester.pump();

      expect(emitted.last, [
        hydrationClear,
        const MeasurableChoice(id: 'hydration-pale', title: 'Pale yellow'),
      ]);
      // The field keeps what was typed through the parent's rebuild.
      expect(fieldText(tester, hydrationPale.id), 'Pale yellow');
      expect(fieldText(tester, hydrationClear.id), 'Clear');
    });

    testWidgets('the archive action retires the choice to the tail', (
      tester,
    ) async {
      final emitted = await pump(
        tester,
        initial: const [hydrationClear, hydrationPale, hydrationDark],
      );

      await tester.tap(archiveAction(hydrationClear.id));
      await tester.pump();

      expect(emitted.single, const [
        hydrationPale,
        hydrationDark,
        MeasurableChoice(id: 'hydration-clear', title: 'Clear', archived: true),
      ]);
      expect(titleField(hydrationClear.id), findsNothing);
      expect(find.text('Archived choices'), findsOneWidget);
      expect(restoreAction(hydrationClear.id), findsOneWidget);
    });

    testWidgets('restore reactivates the choice after the active ones', (
      tester,
    ) async {
      final emitted = await pump(
        tester,
        initial: const [hydrationClear, hydrationBrown, hydrationPale],
      );

      await tester.tap(restoreAction(hydrationBrown.id));
      await tester.pump();

      expect(emitted.single, const [
        hydrationClear,
        hydrationPale,
        MeasurableChoice(
          id: 'hydration-brown',
          title: 'Brown',
          archived: false,
        ),
      ]);
      expect(titleField(hydrationBrown.id), findsOneWidget);
      expect(fieldText(tester, hydrationBrown.id), 'Brown');
      expect(find.text('Archived choices'), findsNothing);
    });

    testWidgets('dragging a handle reorders the active choices only', (
      tester,
    ) async {
      final emitted = await pump(
        tester,
        initial: const [
          hydrationClear,
          hydrationPale,
          hydrationDark,
          hydrationBrown,
        ],
      );

      final from = tester.getCenter(dragHandle(hydrationClear.id));
      final to = tester.getCenter(row(hydrationDark.id));
      final gesture = await tester.startGesture(from);
      await tester.pump();
      // Walk the pointer down in steps so the list animates the gap along.
      const steps = 8;
      final step = (to - from) / steps.toDouble();
      for (var i = 0; i < steps; i++) {
        await gesture.moveBy(step + const Offset(0, 4));
        await tester.pump(const Duration(milliseconds: 32));
      }
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(emitted.single, const [
        hydrationPale,
        hydrationDark,
        hydrationClear,
        hydrationBrown,
      ]);
    });
  });

  group('MeasurableChoicesEditor controllers', () {
    testWidgets(
      'a choice the parent drops loses its controller, so re-adding the id '
      'starts from the new title',
      (tester) async {
        final emitted = <List<MeasurableChoice>>[];
        Widget host(List<MeasurableChoice> choices) =>
            makeTestableWidgetWithScaffold(
              SingleChildScrollView(
                child: MeasurableChoicesEditor(
                  choices: choices,
                  onChanged: emitted.add,
                ),
              ),
            );

        await tester.pumpWidget(host(const [hydrationClear]));
        await tester.pump();
        expect(fieldText(tester, hydrationClear.id), 'Clear');

        await tester.pumpWidget(host(const [hydrationPale]));
        await tester.pump();
        expect(titleField(hydrationClear.id), findsNothing);

        await tester.pumpWidget(
          host(const [MeasurableChoice(id: 'hydration-clear', title: 'Fresh')]),
        );
        await tester.pump();
        // A retained controller would still say "Clear".
        expect(fieldText(tester, hydrationClear.id), 'Fresh');
        expect(emitted, isEmpty);
      },
    );
  });
}
