import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_selection.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_variant.dart';
import 'package:lotti/features/design_system/components/celebration/completion_burst.dart';
import 'package:lotti/features/design_system/components/celebration/completion_glow.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_controller.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/features/settings/state/celebration_preferences_controller.dart';
import 'package:lotti/features/tasks/ui/header/desktop_task_header.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_chips.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/l10n/app_localizations.dart';

import '../../../../widget_test_utils.dart';

Widget _desktopHost(
  Widget child, {
  ThemeData? theme,
  List<Override> overrides = const [],
  TargetPlatform platform = TargetPlatform.windows,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: resolveTestTheme(theme),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        FormBuilderLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: AppCommandHost(
          handlers: const <AppCommandId, AppCommandHandler>{},
          platform: platform,
          child: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    ),
  );
}

Future<void> _pumpDesktop(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(1280, 720),
  ThemeData? theme,
  List<Override> overrides = const [],
  TargetPlatform platform = TargetPlatform.windows,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  // The title line pins the status pill to the trailing edge, so the header
  // needs a bounded max-width to resolve that anchor. Align shrink-wraps, so
  // the tests pin the header to the surface width explicitly.
  await tester.pumpWidget(
    _desktopHost(
      SizedBox(width: size.width, child: child),
      theme: theme,
      overrides: overrides,
      platform: platform,
    ),
  );
  await tester.pump();
}

LabelDefinition _label({
  required String id,
  required String name,
  required String color,
  String? description,
}) {
  final ts = DateTime.utc(2026);
  return LabelDefinition(
    id: id,
    createdAt: ts,
    updatedAt: ts,
    name: name,
    color: color,
    vectorClock: null,
    description: description,
  );
}

DesktopTaskHeaderData _fixture({
  String title = 'Payment confirmation',
  String? oneLiner,
  TaskPriority priority = TaskPriority.p1High,
  TaskStatus? status,
  DesktopTaskHeaderProject? project,
  DesktopTaskHeaderCategory? category,
  DesktopTaskHeaderDueDate? dueDate,
  List<LabelDefinition> labels = const [],
}) {
  final createdAt = DateTime.utc(2026);
  return DesktopTaskHeaderData(
    title: title,
    oneLiner: oneLiner,
    priority: priority,
    status:
        status ??
        TaskStatus.open(id: 'fx-open', createdAt: createdAt, utcOffset: 0),
    project: project,
    category: category,
    dueDate: dueDate,
    labels: labels,
  );
}

const _projectFixture = DesktopTaskHeaderProject(
  label: 'Device Sync - Lotti Mobile App Implementation',
);

const _categoryFixture = DesktopTaskHeaderCategory(
  label: 'Work',
  color: Color(0xFF1CA3E3),
);

/// The 10×10 breadcrumb swatch's decoration — only rendered for a task that
/// HAS a category, filled with that category's colour. Located by its
/// 10×10 square rather than by key, since it is a bare [Container].
BoxDecoration _categorySwatchDecoration(WidgetTester tester) {
  final swatch = tester
      .widgetList<Container>(find.byType(Container))
      .firstWhere(
        (c) =>
            c.constraints?.maxWidth == 10 &&
            c.constraints?.maxHeight == 10 &&
            c.decoration is BoxDecoration,
      );
  return swatch.decoration! as BoxDecoration;
}

const _dueFixture = DesktopTaskHeaderDueDate(label: 'Due: Apr 1, 2026');

final _labelFixtures = <LabelDefinition>[
  _label(
    id: 'bug-fix',
    name: 'Bug fix',
    color: '#1CA3E3',
    description: 'Fixes a defect, not new behaviour.',
  ),
  _label(id: 'release-blocker', name: 'Release blocker', color: '#FA8C05'),
];

/// English label the priority chip renders (TaskPriority.localizedLabel under
/// the test's en locale) — the chip spells out the priority instead of "P2".
String _priorityLabel(TaskPriority priority) => switch (priority) {
  TaskPriority.p0Urgent => 'Urgent',
  TaskPriority.p1High => 'High',
  TaskPriority.p2Medium => 'Medium',
  TaskPriority.p3Low => 'Low',
};

void main() {
  group('DesktopTaskHeader — content + layout', () {
    testWidgets('shows the complete AI one-liner between title and metadata', (
      tester,
    ) async {
      const oneLiner =
          'Settlement is ready for final verification once the complete '
          'audit trail and every linked payment record have been reviewed';
      await _pumpDesktop(
        tester,
        DesktopTaskHeader(
          data: _fixture(oneLiner: oneLiner),
          onTitleSaved: (_) {},
        ),
        size: const Size(480, 720),
      );

      final summary = tester.widget<Text>(find.text(oneLiner));
      final context = tester.element(find.text(oneLiner));
      expect(summary.style?.color, context.designTokens.colors.aiCard.accent);
      expect(summary.maxLines, isNull);
      expect(summary.overflow, TextOverflow.clip);
      expect(
        tester.getSize(find.text(oneLiner)).height,
        greaterThan(summary.style!.fontSize! * 2),
      );

      final textOrder = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .where(
            (text) =>
                text == 'Payment confirmation' ||
                text == oneLiner ||
                text == 'Open',
          )
          .toList();
      expect(textOrder, ['Payment confirmation', oneLiner, 'Open']);
    });

    testWidgets(
      'renders title, classification line, metadata line and no ellipsis',
      (tester) async {
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(
              project: _projectFixture,
              category: _categoryFixture,
              dueDate: _dueFixture,
              labels: _labelFixtures,
            ),
            onTitleSaved: (_) {},
            estimateSlot: const Text('1h / 2h'),
          ),
        );

        expect(find.text('Payment confirmation'), findsOneWidget);
        // Classification row
        expect(find.text('Work'), findsOneWidget);
        expect(
          find.text('Device Sync - Lotti Mobile App Implementation'),
          findsOneWidget,
        );
        expect(find.text('Bug fix'), findsOneWidget);
        expect(find.text('Release blocker'), findsOneWidget);
        // Metadata row
        expect(find.text('Due: Apr 1, 2026'), findsOneWidget);
        expect(find.text('1h / 2h'), findsOneWidget);
        expect(find.text('High'), findsOneWidget);
        expect(find.text('Open'), findsOneWidget);
        // No ellipsis in the header — lives in the app bar.
        expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
        expect(find.byIcon(Icons.more_horiz), findsNothing);
      },
    );

    testWidgets(
      'renders placeholder chips when classification/metadata are empty',
      (tester) async {
        var category = 0;
        var project = 0;
        var addLabel = 0;
        var due = 0;
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            // A category, so the project placeholder is in play at all.
            data: _fixture(category: _categoryFixture),
            onTitleSaved: (_) {},
            onCategoryTap: () => category++,
            onProjectTap: () => project++,
            onAddLabelTap: () => addLabel++,
            onDueDateTap: () => due++,
          ),
        );
        expect(find.text('Work'), findsOneWidget);
        expect(find.text('No project'), findsOneWidget);
        expect(find.text('Add label'), findsOneWidget);
        expect(find.text('Set due date'), findsOneWidget);

        await tester.tap(find.text('Work'));
        await tester.tap(find.text('No project'));
        await tester.tap(find.text('Add label'));
        await tester.tap(find.text('Set due date'));
        await tester.pump();
        expect(category, 1);
        expect(project, 1);
        expect(addLabel, 1);
        expect(due, 1);
      },
    );
    testWidgets(
      'crumb segments without tap handlers render as plain non-tappable '
      'padding',
      (tester) async {
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(category: _categoryFixture),
            onTitleSaved: (_) {},
          ),
        );

        // With onCategoryTap/onProjectTap omitted, neither crumb gets an
        // InkWell — the breadcrumb row contains no tappable surface.
        final crumbRow = find.ancestor(
          of: find.text('No project'),
          matching: find.byType(Row),
        );
        expect(
          find.descendant(of: crumbRow.first, matching: find.byType(InkWell)),
          findsNothing,
        );
        // Tapping the crumb text is a no-op rather than a crash.
        await tester.tap(find.text('No project'), warnIfMissed: false);
        await tester.pump();
      },
    );
  });

  // An unset category no longer reports itself in the crumb at all. The old
  // "No category" segment — a hollow square plus a low-emphasis caption — was
  // the first element in reading order and read as a disabled checkbox from
  // another design system; every panel reviewer flagged it. The offer now
  // lives in the metadata lane as a dashed "Set category" chip speaking the
  // same verb-first grammar as "Set due date", and the crumb renders only
  // when there is real ancestry to show.
  group('DesktopTaskHeader — breadcrumb without a category', () {
    testWidgets(
      'offers a dashed "Set category" chip in the lane instead of a '
      '"No category" crumb',
      (tester) async {
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(data: _fixture(), onTitleSaved: (_) {}),
        );

        expect(find.text('No category'), findsNothing);
        expect(find.text('Set category'), findsOneWidget);
      },
    );

    testWidgets(
      'a four-offer add-lane breaks a deliberate 2+2 below the balance '
      'breakpoint instead of stranding the widest chip alone',
      (tester) async {
        // No category, no due date, no labels, unset estimate: the full
        // first-run set of four dashed chips, at a phone-ish lane width
        // below the 460 balance breakpoint.
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(),
            onTitleSaved: (_) {},
            estimateSlot: const Text('Add estimate'),
            estimateIsSet: false,
          ),
          size: const Size(400, 800),
        );

        final category = tester.getTopLeft(find.text('Set category'));
        final due = tester.getTopLeft(find.text('Set due date'));
        final label = tester.getTopLeft(find.text('Add label'));
        final estimate = tester.getTopLeft(find.text('Add estimate'));

        // Row one: the two Set chips. Row two: the two Add chips. A greedy
        // wrap packed three chips onto row one and stranded the widest
        // alone — the raggedness that undermined the two-run grammar on
        // every phone.
        expect((category.dy - due.dy).abs(), lessThan(8));
        expect((label.dy - estimate.dy).abs(), lessThan(8));
        expect(label.dy, greaterThan(category.dy));
        expect(
          label.dx,
          category.dx,
          reason: 'the second run starts back on the lane rail',
        );
      },
    );

    testWidgets('omits the separator and the project segment', (tester) async {
      await _pumpDesktop(
        tester,
        DesktopTaskHeader(
          data: _fixture(),
          onTitleSaved: (_) {},
          onCategoryTap: () {},
          onProjectTap: () {},
        ),
      );

      expect(find.text('No project'), findsNothing);
      expect(find.text('/'), findsNothing);
    });

    testWidgets('the "Set category" chip opens the category picker', (
      tester,
    ) async {
      var categoryTaps = 0;
      await _pumpDesktop(
        tester,
        DesktopTaskHeader(
          data: _fixture(),
          onTitleSaved: (_) {},
          onCategoryTap: () => categoryTaps++,
        ),
      );

      await tester.tap(find.text('Set category'));
      await tester.pump();

      expect(categoryTaps, 1);
    });

    testWidgets(
      'renders no swatch at all — the square is reserved for a colour the '
      'task actually has',
      (tester) async {
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(data: _fixture(), onTitleSaved: (_) {}),
        );

        expect(
          tester
              .widgetList<Container>(find.byType(Container))
              .where(
                (c) =>
                    c.constraints?.maxWidth == 10 &&
                    c.constraints?.maxHeight == 10 &&
                    c.decoration is BoxDecoration,
              ),
          isEmpty,
          reason:
              'a swatch standing for an absence is the checkbox-impostor '
              'read this layout exists to prevent',
        );
      },
    );

    testWidgets('still names a project the task actually belongs to', (
      tester,
    ) async {
      // An uncategorized project is a real thing — `createProject` takes a
      // nullable category and `createTask(projectId:)` copies it onto the new
      // task — so this pairing reaches the header legitimately. The project
      // segment stands alone on the rail: no separator with nothing real on
      // its other side.
      await _pumpDesktop(
        tester,
        DesktopTaskHeader(
          data: _fixture(project: _projectFixture),
          onTitleSaved: (_) {},
        ),
      );

      expect(find.text('No category'), findsNothing);
      expect(find.text('/'), findsNothing);
      expect(
        find.text('Device Sync - Lotti Mobile App Implementation'),
        findsOneWidget,
      );
    });
  });

  group('DesktopTaskHeader — breadcrumb with a category', () {
    testWidgets('shows the separator and the project placeholder', (
      tester,
    ) async {
      await _pumpDesktop(
        tester,
        DesktopTaskHeader(
          data: _fixture(category: _categoryFixture),
          onTitleSaved: (_) {},
        ),
      );

      expect(find.text('Work'), findsOneWidget);
      expect(find.text('/'), findsOneWidget);
      expect(find.text('No project'), findsOneWidget);
      // A category the task actually has fills its swatch with the category
      // colour — the one place on the page that colour is used as a fill.
      expect(_categorySwatchDecoration(tester).color, _categoryFixture.color);
      // And with the crumb naming the category, the lane's dashed offer
      // stands down — the two affordances never coexist.
      expect(find.text('Set category'), findsNothing);
    });

    testWidgets('shows the separator and the project name', (tester) async {
      await _pumpDesktop(
        tester,
        DesktopTaskHeader(
          data: _fixture(
            category: _categoryFixture,
            project: _projectFixture,
          ),
          onTitleSaved: (_) {},
        ),
      );

      expect(find.text('/'), findsOneWidget);
      expect(
        find.text('Device Sync - Lotti Mobile App Implementation'),
        findsOneWidget,
      );
      expect(find.text('No project'), findsNothing);
    });
  });

  group('DesktopTaskHeader — title editing', () {
    testWidgets('tap read-only title transitions to editor', (tester) async {
      await _pumpDesktop(
        tester,
        DesktopTaskHeader(
          data: _fixture(),
          onTitleSaved: (_) {},
        ),
      );
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Payment confirmation'));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      // Untouched, the field offers no confirm/cancel: on a freshly opened
      // editor both would be no-ops, and reviewers read the bare X as
      // "delete the task I just made".
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      await tester.enterText(find.byType(TextField), 'Payment flow');
      await tester.pump();
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets(
      'read-only title shows no pencil glyph (the whole title is the edit '
      'target)',
      (tester) async {
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(),
            onTitleSaved: (_) {},
          ),
        );
        // The persistent pencil was removed: it drifted into a dead gutter
        // beside short / wrapping titles. The edit affordance is the whole
        // title (covered by the tap / Semantics / keyboard tests).
        expect(find.byIcon(Icons.edit_outlined), findsNothing);
        expect(find.text('Payment confirmation'), findsOneWidget);
      },
    );

    testWidgets(
      'empty title prompts with an imperative in field chrome, not a '
      '"No title" report, and opens the editor on tap',
      (tester) async {
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(title: ''),
            onTitleSaved: (_) {},
          ),
        );

        // An invitation, not a report of absence: "No title" is what the task
        // *list* says about this task; the detail page asks for one.
        expect(find.text('Name this task'), findsOneWidget);
        expect(find.text('No title'), findsNothing);
        expect(find.byIcon(Icons.edit_outlined), findsNothing);
        expect(find.byType(TextField), findsNothing);

        // The prompt wears real field chrome so it reads as tappable rather
        // than as greyed-out body copy — a hairline box on the hover surface.
        final context = tester.element(find.text('Name this task'));
        final tokens = context.designTokens;
        final box = tester.widget<Container>(
          find
              .ancestor(
                of: find.text('Name this task'),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = box.decoration! as BoxDecoration;
        expect(decoration.color, tokens.colors.surface.enabled);
        expect(
          (decoration.border! as Border).top.color,
          tokens.colors.decorative.level01,
        );

        await tester.tap(find.text('Name this task'));
        await tester.pump();

        expect(find.byType(TextField), findsOneWidget);
      },
    );

    testWidgets(
      'the prompt is lighter as well as paler, in BOTH the read-only box and '
      'the editor hint — a blank task opens the editor, so a weight override '
      'applied to only one of them never ships',
      (tester) async {
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(title: ''),
            onTitleSaved: (_) {},
          ),
        );

        final readOnly = tester.widget<Text>(find.text('Name this task'));
        expect(readOnly.style?.fontWeight, FontWeight.w400);

        await tester.tap(find.text('Name this task'));
        await tester.pump();

        final hint = tester
            .widget<TextField>(find.byType(TextField))
            .decoration!
            .hintStyle;
        expect(hint?.fontWeight, FontWeight.w400);
        expect(
          hint?.color,
          readOnly.style?.color,
          reason: 'one style, so the two states cannot drift apart',
        );
      },
    );

    testWidgets(
      'Enter commits the title; the newline moves to Shift+Enter',
      (tester) async {
        String? saved;
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(title: ''),
            onTitleSaved: (value) => saved = value,
            initialEditing: true,
          ),
        );

        await tester.enterText(find.byType(TextField), 'Buy milk');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        // Typing a name and pressing Return is the most common action on this
        // screen; it used to bury a line break in the title and leave the
        // editor open with no feedback.
        expect(saved, 'Buy milk');
        expect(find.byType(TextField), findsNothing);
      },
    );

    testWidgets(
      'losing focus commits the edit — the text is in front of the user and '
      'they typed it, so discarding on a stray tap is the ruder outcome',
      (tester) async {
        String? saved;
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(title: ''),
            onTitleSaved: (value) => saved = value,
            initialEditing: true,
          ),
        );

        await tester.enterText(find.byType(TextField), 'Buy milk');
        await tester.pump();

        // Focus goes away without the commit button being pressed — a tap
        // elsewhere on the page, or the keyboard being dismissed.
        primaryFocus?.unfocus();
        await tester.pumpAndSettle();

        expect(saved, 'Buy milk');
        expect(find.byType(TextField), findsNothing);
      },
    );

    testWidgets(
      "the keyboard's own done action commits, not just the Enter shortcut "
      '— on a phone that is the control the user actually presses',
      (tester) async {
        String? saved;
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(title: ''),
            onTitleSaved: (value) => saved = value,
            initialEditing: true,
          ),
          platform: TargetPlatform.iOS,
        );

        await tester.enterText(find.byType(TextField), 'Buy milk');
        await tester.pump();
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(saved, 'Buy milk');
      },
    );

    testWidgets(
      'a titled task keeps the bare title — no field chrome around content '
      'the user already owns',
      (tester) async {
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(),
            onTitleSaved: (_) {},
          ),
        );

        expect(
          find.ancestor(
            of: find.text('Payment confirmation'),
            matching: find.byType(Container),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'initialEditing seeds the editor with the same imperative as the '
      'placeholder, so auto-opening never blanks the instruction',
      (tester) async {
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(title: ''),
            onTitleSaved: (_) {},
            initialEditing: true,
          ),
        );

        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.decoration?.hintText, 'Name this task');
        expect(field.controller?.text, isEmpty);
      },
    );

    testWidgets(
      'read-only title exposes an accessible button via Semantics',
      (tester) async {
        final handle = tester.ensureSemantics();

        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(),
            onTitleSaved: (_) {},
          ),
        );

        // The Semantics(label: ...) node merges with the Text below it, so
        // both strings appear in the rendered semantic label. The important
        // part is that the a11y label is present and the node is a button.
        final node = tester.getSemantics(find.text('Payment confirmation'));
        expect(node.label, contains('Edit task title'));
        expect(node.label, contains('Payment confirmation'));
        expect(
          node.flagsCollection.isButton,
          isTrue,
          reason: 'read-only title should expose a button role for a11y',
        );

        handle.dispose();
      },
    );

    testWidgets(
      'keyboard activation on the read-only title opens the editor',
      (tester) async {
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(),
            onTitleSaved: (_) {},
          ),
        );

        expect(find.byType(TextField), findsNothing);

        // Focus the title, then dispatch the platform activate intent
        // (the same intent Enter/Space produce via default shortcuts).
        final focusableFinder = find.descendant(
          of: find.byType(FocusableActionDetector),
          matching: find.text('Payment confirmation'),
        );
        expect(focusableFinder, findsOneWidget);

        Focus.of(tester.element(focusableFinder)).requestFocus();
        await tester.pump();

        Actions.maybeInvoke<ActivateIntent>(
          tester.element(focusableFinder),
          const ActivateIntent(),
        );
        await tester.pump();

        expect(find.byType(TextField), findsOneWidget);
      },
    );

    testWidgets('commit saves new value and returns to read-only', (
      tester,
    ) async {
      String? saved;
      await _pumpDesktop(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            return DesktopTaskHeader(
              data: _fixture(title: saved ?? 'Payment confirmation'),
              onTitleSaved: (v) => setState(() => saved = v),
              initialEditing: true,
            );
          },
        ),
      );
      await tester.enterText(find.byType(TextField), 'Payment flow');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pump();

      expect(saved, 'Payment flow');
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Payment flow'), findsOneWidget);
    });

    testWidgets('cancel discards edits and restores original title', (
      tester,
    ) async {
      var saves = 0;
      await _pumpDesktop(
        tester,
        DesktopTaskHeader(
          data: _fixture(),
          onTitleSaved: (_) => saves++,
          initialEditing: true,
        ),
      );
      await tester.enterText(find.byType(TextField), 'Different title');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(saves, 0);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Payment confirmation'), findsOneWidget);
    });

    testWidgets('⌘S saves while the title editor is focused', (tester) async {
      String? saved;
      await _pumpDesktop(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            return DesktopTaskHeader(
              data: _fixture(title: saved ?? 'Payment confirmation'),
              onTitleSaved: (v) => setState(() => saved = v),
              initialEditing: true,
            );
          },
        ),
        platform: TargetPlatform.macOS,
      );
      await tester.enterText(find.byType(TextField), 'Payment flow');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pump();

      expect(saved, 'Payment flow');
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Payment flow'), findsOneWidget);
    });

    testWidgets('Ctrl+S saves while the title editor is focused', (
      tester,
    ) async {
      String? saved;
      await _pumpDesktop(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            return DesktopTaskHeader(
              data: _fixture(title: saved ?? 'Payment confirmation'),
              onTitleSaved: (v) => setState(() => saved = v),
              initialEditing: true,
            );
          },
        ),
      );
      await tester.enterText(find.byType(TextField), 'Payment flow');
      await tester.pump();

      final fieldContext = tester.element(find.byType(TextField));
      final commandController = AppCommandControllerProvider.of(fieldContext);
      expect(
        commandController.isAvailable(fieldContext, AppCommandId.save),
        isTrue,
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pump();

      expect(saved, 'Payment flow');
    });
  });

  group('DesktopTaskHeader — metadata layout', () {
    testWidgets(
      'status leads a left-aligned attribute lane below the title (no '
      'right-anchored dead gutter)',
      (tester) async {
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(dueDate: _dueFixture, labels: _labelFixtures),
            onTitleSaved: (_) {},
            estimateSlot: const Text('0h / 1h'),
          ),
        );
        final titleBox = tester.getRect(find.text('Payment confirmation'));
        final status = tester.getTopLeft(find.text('Open'));
        final priority = tester.getTopLeft(find.text('High'));
        final due = tester.getTopLeft(find.text('Due: Apr 1, 2026'));

        // The metadata lane sits below the title (status is no longer on the
        // title line — that anchor left a void beside short / wrapping titles).
        expect(
          status.dy,
          greaterThan(titleBox.bottom - 4),
          reason: 'the attribute lane drops below the title',
        );
        // Status leads the attribute lane: it is the left-most chip and the
        // priority/due chips follow to its right on the same row.
        expect(
          status.dx,
          lessThan(priority.dx),
          reason: 'status is the leading chip',
        );
        expect(priority.dx, lessThan(due.dx));
        expect(
          (status.dy - priority.dy).abs(),
          lessThan(8),
          reason: 'status shares the attribute lane row with priority/due',
        );
        // The lane starts near the content's left edge — the cluster is
        // left-aligned, never pushed to a far-right anchor that would leave a
        // dead gutter (a right-pinned status on this 1280px surface would land
        // ~1000px+ in). The small offset is the status pill's own leading
        // glyph + padding before its label text.
        expect(
          status.dx,
          lessThan(titleBox.left + 40),
          reason: 'attribute lane is left-aligned under the title',
        );
      },
    );

    testWidgets(
      'labels sit in their own lane below the attribute lane',
      (tester) async {
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(dueDate: _dueFixture, labels: _labelFixtures),
            onTitleSaved: (_) {},
            estimateSlot: const Text('0h / 1h'),
          ),
        );
        final statusBottom = tester.getBottomLeft(find.text('Open')).dy;
        final labelTop = tester.getTopLeft(find.text('Bug fix')).dy;
        expect(
          labelTop,
          greaterThan(statusBottom),
          reason: 'the free-form label lane drops below the attribute lane',
        );
      },
    );

    testWidgets(
      'narrow viewport: attribute lane wraps and labels remain a separate '
      'lane below it',
      (tester) async {
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(dueDate: _dueFixture, labels: _labelFixtures),
            onTitleSaved: (_) {},
            estimateSlot: const Text('0h / 1h'),
          ),
          size: const Size(360, 800),
        );
        final status = tester.getTopLeft(find.text('Open'));
        final labelTop = tester.getTopLeft(find.text('Bug fix')).dy;
        // Even at mobile width the label lane is below the status that leads
        // the attribute lane.
        expect(labelTop, greaterThan(status.dy));
      },
    );

    testWidgets(
      'narrow viewport: status and priority lead; the due date and estimate '
      'wrap together as a full second row',
      (tester) async {
        // A lane one pixel too narrow for the due chip breaks into two
        // *balanced* rows: the state pair (status + its caret-bearing
        // priority) up top, the time pair (due + estimate) below. What this
        // pins is that the break lands on the semantic seam and that the
        // wrapped row is itself full — not a lone chip stranded under a row
        // with slack left in it.
        Widget header() => DesktopTaskHeader(
          data: _fixture(dueDate: _dueFixture, labels: _labelFixtures),
          onTitleSaved: (_) {},
          estimateSlot: const Text('0h / 1h'),
        );
        Rect chipRect(String label) => tester.getRect(
          find.ancestor(of: find.text(label), matching: find.byType(DsPill)),
        );

        // Measure the lane on one line before narrowing it. A hard-coded phone
        // width cannot express "one pixel too narrow for the due chip": glyph
        // metrics differ between hosts (a square test font locally, real
        // proportional fonts on CI), so the same number lands on either side
        // of the wrap depending on where the suite runs. Deriving the width
        // from the chips themselves pins the *wrap*, which is the behaviour
        // under test, rather than one machine's font.
        await _pumpDesktop(tester, header(), size: const Size(1280, 800));
        final statusChip = chipRect('Open');
        final priorityChip = chipRect('High');
        final dueChip = chipRect('Due: Apr 1, 2026');
        final estimateWidth = tester.getRect(find.text('0h / 1h')).width;
        final chipGap = priorityChip.left - statusChip.right;

        // One pixel short of what the due chip needs to stay on row one.
        final laneWidth = priorityChip.right + chipGap + dueChip.width - 1;
        // ...and still wide enough for the time pair to share row two, which
        // is what makes the wrap a two-row break rather than a three-row one.
        expect(
          laneWidth,
          greaterThanOrEqualTo(dueChip.width + chipGap + estimateWidth),
          reason: 'the calibrated lane must still hold due + estimate together',
        );

        await _pumpDesktop(tester, header(), size: Size(laneWidth, 800));
        final status = tester.getTopLeft(find.text('Open')).dy;
        final priority = tester.getTopLeft(find.text('High')).dy;
        final due = tester.getTopLeft(find.text('Due: Apr 1, 2026')).dy;
        final estimate = tester.getTopLeft(find.text('0h / 1h')).dy;
        final labelTop = tester.getTopLeft(find.text('Bug fix')).dy;

        expect((priority - status).abs(), lessThan(8));
        expect(
          due,
          greaterThan(status),
          reason:
              'the state pair holds row one and the time pair wraps below it, '
              'rather than the due chip splitting off from the estimate',
        );
        expect(
          (due - estimate).abs(),
          lessThan(8),
          reason:
              'due and estimate share the second row — the wrap lands on the '
              'semantic seam, not mid-pair',
        );
        // The label lane still sits below the whole attribute lane.
        expect(labelTop, greaterThan(due));
      },
    );

    testWidgets(
      'wrapped rows sit a step further apart than the chips within a row',
      (tester) async {
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(dueDate: _dueFixture),
            onTitleSaved: (_) {},
            estimateSlot: const Text('0h / 1h'),
          ),
          size: const Size(420, 800),
        );
        final context = tester.element(find.text('Open'));
        final spacing = context.designTokens.spacing;
        final lane = tester.widget<Wrap>(find.byType(Wrap).first);

        // Two axes, two values. Reusing the horizontally-justified step2 for
        // runSpacing put the wrapped rows closer together than the chips
        // inside a row, which read as one crowded slab rather than two rows.
        expect(lane.spacing, spacing.step2);
        expect(lane.runSpacing, spacing.step3);
        expect(lane.runSpacing, greaterThan(lane.spacing));
      },
    );
  });

  group('DesktopTaskHeader — label overflow', () {
    final manyLabels = <LabelDefinition>[
      _label(id: 'l1', name: 'Design', color: '#1CA3E3'),
      _label(id: 'l2', name: 'UX', color: '#A855F7'),
      _label(id: 'l3', name: 'Backend', color: '#F97316'),
      _label(id: 'l4', name: 'Frontend', color: '#22C55E'),
      _label(id: 'l5', name: 'QA', color: '#EAB308'),
      _label(id: 'l6', name: 'Research', color: '#EC4899'),
    ];

    testWidgets(
      'caps the label lane at 4 chips and collapses the rest behind "+N"',
      (tester) async {
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(labels: manyLabels),
            onTitleSaved: (_) {},
          ),
        );
        // First four labels visible; the 5th/6th are collapsed.
        expect(find.text('Design'), findsOneWidget);
        expect(find.text('Frontend'), findsOneWidget);
        expect(find.text('QA'), findsNothing);
        expect(find.text('Research'), findsNothing);
        // The overflow affordance shows the hidden count.
        expect(find.text('+2'), findsOneWidget);
        expect(find.text('Show fewer'), findsNothing);
      },
    );

    testWidgets(
      'tapping "+N" reveals all labels and a "Show fewer" control that '
      're-collapses',
      (tester) async {
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(labels: manyLabels),
            onTitleSaved: (_) {},
          ),
        );
        await tester.tap(find.text('+2'));
        await tester.pump();
        // All labels now visible; the "+N" chip becomes "Show fewer".
        expect(find.text('QA'), findsOneWidget);
        expect(find.text('Research'), findsOneWidget);
        expect(find.text('+2'), findsNothing);
        expect(find.text('Show fewer'), findsOneWidget);

        await tester.tap(find.text('Show fewer'));
        await tester.pump();
        // Collapsed again.
        expect(find.text('Research'), findsNothing);
        expect(find.text('+2'), findsOneWidget);
      },
    );

    testWidgets(
      'no overflow control when the labels fit under the cap',
      (tester) async {
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(labels: _labelFixtures),
            onTitleSaved: (_) {},
          ),
        );
        expect(find.text('Bug fix'), findsOneWidget);
        expect(find.text('Release blocker'), findsOneWidget);
        expect(find.text('Show fewer'), findsNothing);
        expect(find.textContaining('+'), findsNothing);
      },
    );

    testWidgets(
      'expanded label overflow re-collapses when the task labels change',
      (tester) async {
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(labels: manyLabels),
            onTitleSaved: (_) {},
          ),
        );
        await tester.tap(find.text('+2'));
        await tester.pump();
        expect(find.text('Research'), findsOneWidget); // expanded

        // A different task's labels arrive in the same header instance — the
        // overflow collapses again (didUpdateWidget resets the expansion).
        final otherLabels = <LabelDefinition>[
          _label(id: 'o1', name: 'Alpha', color: '#1CA3E3'),
          _label(id: 'o2', name: 'Beta', color: '#A855F7'),
          _label(id: 'o3', name: 'Gamma', color: '#F97316'),
          _label(id: 'o4', name: 'Delta', color: '#22C55E'),
          _label(id: 'o5', name: 'Epsilon', color: '#EAB308'),
        ];
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(labels: otherLabels),
            onTitleSaved: (_) {},
          ),
        );
        expect(find.text('Epsilon'), findsNothing);
        expect(find.text('+1'), findsOneWidget);
      },
    );
  });

  group('DesktopTaskHeader — callbacks', () {
    testWidgets('tapping priority / status fires callbacks', (tester) async {
      var priority = 0;
      var status = 0;
      await _pumpDesktop(
        tester,
        DesktopTaskHeader(
          data: _fixture(),
          onTitleSaved: (_) {},
          onPriorityTap: () => priority++,
          onStatusTap: () => status++,
        ),
      );
      await tester.tap(find.text('High'));
      await tester.tap(find.text('Open'));
      await tester.pump();
      expect(priority, 1);
      expect(status, 1);
    });

    testWidgets(
      'tapping category / project / due / label fires each callback',
      (tester) async {
        String? tappedLabel;
        var categoryTaps = 0;
        var projectTaps = 0;
        var dueTaps = 0;
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(
              project: _projectFixture,
              category: _categoryFixture,
              dueDate: _dueFixture,
              labels: _labelFixtures,
            ),
            onTitleSaved: (_) {},
            onCategoryTap: () => categoryTaps++,
            onProjectTap: () => projectTaps++,
            onDueDateTap: () => dueTaps++,
            onLabelTap: (l) => tappedLabel = l.id,
          ),
        );
        await tester.tap(find.text('Work'));
        await tester.tap(
          find.text('Device Sync - Lotti Mobile App Implementation'),
        );
        await tester.tap(find.text('Due: Apr 1, 2026'));
        await tester.tap(find.text('Release blocker'));
        await tester.pump();
        expect(categoryTaps, 1);
        expect(projectTaps, 1);
        expect(dueTaps, 1);
        expect(tappedLabel, 'release-blocker');
      },
    );

    testWidgets('long-press on label with description opens dialog', (
      tester,
    ) async {
      await _pumpDesktop(
        tester,
        DesktopTaskHeader(
          data: _fixture(labels: _labelFixtures),
          onTitleSaved: (_) {},
        ),
      );
      await tester.longPress(find.text('Bug fix'));
      await tester.pumpAndSettle();
      expect(find.text('Fixes a defect, not new behaviour.'), findsOneWidget);
    });

    testWidgets(
      'long-press dialog dismisses when the close button is tapped',
      (tester) async {
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(labels: _labelFixtures),
            onTitleSaved: (_) {},
          ),
        );
        await tester.longPress(find.text('Bug fix'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);

        // The dialog renders a single TextButton — the localized close button.
        await tester.tap(find.byType(TextButton));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      },
    );

    testWidgets('Escape in the title editor cancels back to read-only', (
      tester,
    ) async {
      await _pumpDesktop(
        tester,
        DesktopTaskHeader(
          data: _fixture(),
          onTitleSaved: (_) {},
          initialEditing: true,
        ),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'A different title');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      // Editor closes, original read-only title is back.
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Payment confirmation'), findsOneWidget);
    });
  });

  group('DesktopTaskHeader — status pill tinting', () {
    final createdAt = DateTime.utc(2026);
    final cases = <(TaskStatus, String)>[
      (
        TaskStatus.inProgress(
          id: 'tint-in-progress',
          createdAt: createdAt,
          utcOffset: 0,
        ),
        'In Progress',
      ),
      (
        TaskStatus.blocked(
          id: 'tint-blocked',
          createdAt: createdAt,
          utcOffset: 0,
          reason: 'waiting',
        ),
        'Blocked',
      ),
      (
        TaskStatus.onHold(
          id: 'tint-hold',
          createdAt: createdAt,
          utcOffset: 0,
          reason: 'paused',
        ),
        'On Hold',
      ),
      (
        TaskStatus.groomed(
          id: 'tint-groomed',
          createdAt: createdAt,
          utcOffset: 0,
        ),
        'Groomed',
      ),
      (
        TaskStatus.done(id: 'tint-done', createdAt: createdAt, utcOffset: 0),
        'Done',
      ),
      (
        TaskStatus.rejected(
          id: 'tint-rejected',
          createdAt: createdAt,
          utcOffset: 0,
        ),
        'Rejected',
      ),
    ];

    for (final entry in cases) {
      final status = entry.$1;
      final label = entry.$2;
      testWidgets('renders the $label status with its tinted pill', (
        tester,
      ) async {
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(status: status),
            onTitleSaved: (_) {},
          ),
        );
        expect(find.text(label), findsOneWidget);

        // The status's *colour* identity is carried by the translucent tinted
        // background (a low-alpha wash of the status accent) plus the
        // per-status glyph — NOT by the label text, which is kept at high
        // contrast (accent-coloured text on its own accent tint is a WCAG
        // contrast failure). So: background == accent@18%, label == the
        // high-emphasis text colour (see _statusTint in the meta part).
        final context = tester.element(find.byType(DesktopTaskHeader));
        final accent = switch (label) {
          'In Progress' => TaskShowcasePalette.info(context),
          'Blocked' => TaskShowcasePalette.error(context),
          'On Hold' => TaskShowcasePalette.warning(context),
          'Groomed' => context.designTokens.colors.interactive.enabled,
          'Done' => TaskShowcasePalette.success(context),
          _ => null, // Rejected uses a neutral low-emphasis wash.
        };
        final text = tester.widget<Text>(find.text(label));
        final box = tester.widget<DecoratedBox>(
          find
              .ancestor(
                of: find.text(label),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final background = (box.decoration as BoxDecoration).color;
        if (accent != null) {
          // High-contrast label; tinted background carries the accent.
          expect(
            text.style?.color,
            TaskShowcasePalette.highText(context),
            reason: label,
          );
          expect(background, accent.withValues(alpha: 0.18), reason: label);
        } else {
          // Rejected: medium-emphasis (still legible) struck text on the
          // same filled+bordered DsPill shell the set chips wear — the pill
          // is rendered through the shared primitive now, and a dismissed
          // status is a neutral fact, not a fifth accent.
          expect(
            text.style?.color,
            TaskShowcasePalette.mediumText(context),
          );
          expect(
            text.style?.decoration,
            TextDecoration.lineThrough,
          );
          final tokens = context.designTokens;
          expect(background, tokens.colors.surface.enabled);
          expect(
            ((box.decoration as BoxDecoration).border! as Border).top.color,
            tokens.colors.decorative.level02,
          );
        }
      });
    }
  });

  group('DesktopTaskHeader — priority palette', () {
    for (final priority in TaskPriority.values) {
      testWidgets(
        'renders ${priority.short} as a neutral filled chip with its priority '
        'glyph carrying the colour',
        (tester) async {
          await _pumpDesktop(
            tester,
            DesktopTaskHeader(
              data: _fixture(priority: priority),
              onTitleSaved: (_) {},
            ),
          );
          // The chip spells out the priority (Urgent/High/Medium/Low) instead
          // of the opaque "P2" code.
          final label = _priorityLabel(priority);
          expect(find.text(label), findsOneWidget);

          // Priority shares the neutral filled shell with the other attribute
          // chips (the status pill is the lane's only tinted accent), so its
          // pill carries no tint colour, and it gets the quiet low-vision
          // border…
          final pill = tester.widget<DsPill>(
            find.ancestor(
              of: find.text(label),
              matching: find.byType(DsPill),
            ),
          );
          expect(pill.variant, DsPillVariant.filled, reason: priority.short);
          expect(
            pill.color,
            isNull,
            reason: '${priority.short} uses the neutral shell',
          );
          expect(pill.bordered, isTrue, reason: priority.short);

          // …and the urgency signal is carried by the distinct per-priority
          // glyph (red P0 → green P3).
          final glyph = tester.widget<TaskShowcasePriorityGlyph>(
            find.byType(TaskShowcasePriorityGlyph),
          );
          expect(glyph.priority, priority, reason: priority.short);
        },
      );
    }
  });

  group('DesktopTaskHeader — status tint invariants', () {
    // Property-style coverage for the `_statusTint` switch in the meta part.
    // `_statusTint` needs a BuildContext (it reads palette + design tokens),
    // so it cannot be driven by Glados, which has no WidgetTester. Instead we
    // exhaustively pump every TaskStatus variant and assert the two invariants
    // that must hold no matter which branch the switch takes: the pill's
    // translucent background must have a valid alpha in [0, 1], and the
    // foreground (label) colour must never be fully transparent. If a new
    // TaskStatus variant is ever added without a matching switch arm the
    // build switch becomes non-exhaustive (compile error) — and if an arm is
    // added with a bad colour this test fails at runtime.
    final createdAt = DateTime.utc(2026);
    final statuses = <TaskStatus>[
      TaskStatus.open(id: 'inv-open', createdAt: createdAt, utcOffset: 0),
      TaskStatus.inProgress(
        id: 'inv-in-progress',
        createdAt: createdAt,
        utcOffset: 0,
      ),
      TaskStatus.groomed(id: 'inv-groomed', createdAt: createdAt, utcOffset: 0),
      TaskStatus.blocked(
        id: 'inv-blocked',
        createdAt: createdAt,
        utcOffset: 0,
        reason: 'waiting',
      ),
      TaskStatus.onHold(
        id: 'inv-hold',
        createdAt: createdAt,
        utcOffset: 0,
        reason: 'paused',
      ),
      TaskStatus.done(id: 'inv-done', createdAt: createdAt, utcOffset: 0),
      TaskStatus.rejected(
        id: 'inv-rejected',
        createdAt: createdAt,
        utcOffset: 0,
      ),
    ];

    for (final status in statuses) {
      testWidgets(
        'pill tint for ${status.runtimeType} has a valid background alpha and '
        'an opaque foreground',
        (tester) async {
          await _pumpDesktop(
            tester,
            DesktopTaskHeader(
              data: _fixture(status: status),
              onTitleSaved: (_) {},
            ),
          );

          final context = tester.element(find.byType(DesktopTaskHeader));
          final label = status.localizedLabel(context);
          final text = tester.widget<Text>(find.text(label));
          final box = tester.widget<DecoratedBox>(
            find
                .ancestor(
                  of: find.text(label),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          );
          final background = (box.decoration as BoxDecoration).color;

          expect(background, isNotNull, reason: '${status.runtimeType}');
          expect(
            background!.a,
            inInclusiveRange(0.0, 1.0),
            reason: 'background alpha out of range for ${status.runtimeType}',
          );
          final foreground = text.style?.color;
          expect(foreground, isNotNull, reason: '${status.runtimeType}');
          expect(
            foreground!.a,
            greaterThan(0.0),
            reason: 'foreground transparent for ${status.runtimeType}',
          );
        },
      );
    }
  });

  group('DesktopTaskHeader — title editor edge cases', () {
    testWidgets(
      'a title change arriving while the editor is open does NOT clobber '
      'the in-progress edit (didUpdateWidget guard)',
      (tester) async {
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(),
            onTitleSaved: (_) {},
            initialEditing: true,
          ),
        );
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'My half-typed edit');
        await tester.pump();

        // A sync delivers a new title from elsewhere while editing.
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(title: 'Synced title from another device'),
            onTitleSaved: (_) {},
            initialEditing: true,
          ),
        );
        await tester.pump();

        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller?.text, 'My half-typed edit');
      },
    );

    testWidgets(
      'committing unchanged text does not fire onTitleSaved',
      (tester) async {
        var saves = 0;
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(),
            onTitleSaved: (_) => saves++,
            initialEditing: true,
          ),
        );
        // There is nothing to commit, so there is no commit button to press.
        // The guard is now structural rather than a no-op handler.
        expect(find.byIcon(Icons.check_rounded), findsNothing);
        expect(saves, 0, reason: 'same text should not trigger onTitleSaved');
        expect(find.byType(TextField), findsOneWidget);
      },
    );

    testWidgets(
      'committing empty text does not fire onTitleSaved',
      (tester) async {
        var saves = 0;
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(),
            onTitleSaved: (_) => saves++,
            initialEditing: true,
          ),
        );
        await tester.enterText(find.byType(TextField), '   ');
        await tester.pump();
        await tester.tap(find.byIcon(Icons.check_rounded));
        await tester.pump();

        expect(
          saves,
          0,
          reason: 'whitespace-only text should not trigger save',
        );
        expect(find.byType(TextField), findsNothing);
      },
    );

    testWidgets(
      'title controller updates when widget receives new title while not editing',
      (tester) async {
        var currentTitle = 'Original title';
        late StateSetter outerSetState;

        await _pumpDesktop(
          tester,
          StatefulBuilder(
            builder: (context, setState) {
              outerSetState = setState;
              return DesktopTaskHeader(
                data: _fixture(title: currentTitle),
                onTitleSaved: (_) {},
              );
            },
          ),
        );

        expect(find.text('Original title'), findsOneWidget);

        // Update the title externally while NOT in editing mode.
        outerSetState(() => currentTitle = 'Updated title');
        await tester.pump();

        expect(find.text('Updated title'), findsOneWidget);
        expect(find.text('Original title'), findsNothing);
      },
    );

    testWidgets(
      'Ctrl+Enter saves while the title editor is focused',
      (tester) async {
        String? saved;
        await _pumpDesktop(
          tester,
          StatefulBuilder(
            builder: (context, setState) {
              return DesktopTaskHeader(
                data: _fixture(title: saved ?? 'Payment confirmation'),
                onTitleSaved: (v) => setState(() => saved = v),
                initialEditing: true,
              );
            },
          ),
        );
        await tester.enterText(find.byType(TextField), 'New title via ctrl');
        await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
        await tester.pump();

        expect(saved, 'New title via ctrl');
        expect(find.byType(TextField), findsNothing);
      },
    );

    testWidgets(
      'Meta+Enter saves while the title editor is focused',
      (tester) async {
        String? saved;
        await _pumpDesktop(
          tester,
          StatefulBuilder(
            builder: (context, setState) {
              return DesktopTaskHeader(
                data: _fixture(title: saved ?? 'Payment confirmation'),
                onTitleSaved: (v) => setState(() => saved = v),
                initialEditing: true,
              );
            },
          ),
        );
        await tester.enterText(find.byType(TextField), 'New title via meta');
        await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
        await tester.pump();

        expect(saved, 'New title via meta');
        expect(find.byType(TextField), findsNothing);
      },
    );
  });

  group('DesktopTaskHeader — due-date urgency styles', () {
    DsPill dueChip(WidgetTester tester, String label) {
      return tester.widget<DsPill>(
        find
            .ancestor(of: find.text(label), matching: find.byType(DsPill))
            .first,
      );
    }

    // Ink, not the fill strength: an urgent due pill leaves `labelColor`
    // null, so this colour also paints the pill's label and owes AA.
    Color paletteError(WidgetTester tester) => TaskShowcasePalette.errorInk(
      tester.element(find.byType(DesktopTaskHeader)),
    );
    Color paletteWarning(WidgetTester tester) => TaskShowcasePalette.warningInk(
      tester.element(find.byType(DesktopTaskHeader)),
    );
    Color paletteHigh(WidgetTester tester) => TaskShowcasePalette.highText(
      tester.element(find.byType(DesktopTaskHeader)),
    );

    testWidgets('overdue urgency renders a tinted due pill in error color', (
      tester,
    ) async {
      await _pumpDesktop(
        tester,
        DesktopTaskHeader(
          data: _fixture(
            dueDate: const DesktopTaskHeaderDueDate(
              label: 'Overdue: Mar 1',
              urgency: DesktopTaskHeaderDueUrgency.overdue,
            ),
          ),
          onTitleSaved: (_) {},
        ),
      );
      final pill = dueChip(tester, 'Overdue: Mar 1');
      expect(pill.variant, DsPillVariant.tinted);
      expect(pill.color, paletteError(tester));
    });

    testWidgets('today urgency renders a tinted due pill in warning color', (
      tester,
    ) async {
      await _pumpDesktop(
        tester,
        DesktopTaskHeader(
          data: _fixture(
            dueDate: const DesktopTaskHeaderDueDate(
              label: 'Today',
              urgency: DesktopTaskHeaderDueUrgency.today,
            ),
          ),
          onTitleSaved: (_) {},
        ),
      );
      final pill = dueChip(tester, 'Today');
      expect(pill.variant, DsPillVariant.tinted);
      expect(pill.color, paletteWarning(tester));
    });

    testWidgets(
      'normal urgency renders a filled due pill in medium-text color (one '
      'consistent chip grammar with the rest of the row)',
      (tester) async {
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(
              dueDate: const DesktopTaskHeaderDueDate(
                label: 'Mar 15, 2026',
                // ignore: avoid_redundant_argument_values
                urgency: DesktopTaskHeaderDueUrgency.normal,
              ),
            ),
            onTitleSaved: (_) {},
          ),
        );
        final pill = dueChip(tester, 'Mar 15, 2026');
        expect(pill.variant, DsPillVariant.filled);
        // The due date carries high emphasis (a tier above priority/estimate).
        expect(pill.labelColor, paletteHigh(tester));
      },
    );
  });

  group('DesktopTaskHeader — label pill without description', () {
    testWidgets(
      'long-press on label without description shows no dialog',
      (tester) async {
        final noDescLabel = _label(
          id: 'no-desc',
          name: 'No Description',
          color: '#FF0000',
          // description is null
        );

        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(labels: [noDescLabel]),
            onTitleSaved: (_) {},
          ),
        );
        await tester.longPress(find.text('No Description'));
        await tester.pumpAndSettle();

        // No dialog should appear for a label without a description.
        expect(find.byType(AlertDialog), findsNothing);
      },
    );
  });

  group('DesktopTaskHeader — task-done celebration', () {
    final createdAt = DateTime.utc(2026);
    TaskStatus open() =>
        TaskStatus.open(id: 'o', createdAt: createdAt, utcOffset: 0);
    TaskStatus done() =>
        TaskStatus.done(id: 'd', createdAt: createdAt, utcOffset: 0);

    Widget header(TaskStatus status) => DesktopTaskHeader(
      data: _fixture(status: status),
      onTitleSaved: (_) {},
    );

    testWidgets('celebrates the transition into Done on the status pill', (
      tester,
    ) async {
      await _pumpDesktop(tester, header(open()));
      expect(find.byType(CompletionGlow), findsNothing);
      expect(find.byType(CompletionBurst), findsNothing);

      // Re-pump with Done → the staged glow + spark burst play.
      await _pumpDesktop(tester, header(done()));
      await tester.pump(const Duration(milliseconds: 560));
      expect(find.byType(CompletionGlow), findsOneWidget);
      expect(find.byType(CompletionBurst), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('does not celebrate a task that opened already Done', (
      tester,
    ) async {
      await _pumpDesktop(tester, header(done()));
      await tester.pump(const Duration(milliseconds: 560));
      expect(find.byType(CompletionGlow), findsNothing);
      expect(find.byType(CompletionBurst), findsNothing);
    });

    testWidgets('stays silent when task celebrations are switched off', (
      tester,
    ) async {
      final overrides = [
        celebrationPreferencesProvider.overrideWithValue(
          const CelebrationPreferences.allEnabled().copyWith(tasks: false),
        ),
      ];
      await _pumpDesktop(tester, header(open()), overrides: overrides);
      // Transition into Done with the task switch off → no glow, no burst.
      await _pumpDesktop(tester, header(done()), overrides: overrides);
      await tester.pump(const Duration(milliseconds: 560));
      expect(find.byType(CompletionGlow), findsNothing);
      expect(find.byType(CompletionBurst), findsNothing);

      await tester.pumpAndSettle();
    });

    testWidgets('stays silent when the master switch is off (tasks on)', (
      tester,
    ) async {
      final overrides = [
        celebrationPreferencesProvider.overrideWithValue(
          // Tasks still on, but the whole celebration system is off.
          const CelebrationPreferences.allEnabled().copyWith(enabled: false),
        ),
      ];
      await _pumpDesktop(tester, header(open()), overrides: overrides);
      await _pumpDesktop(tester, header(done()), overrides: overrides);
      await tester.pump(const Duration(milliseconds: 560));
      expect(find.byType(CompletionGlow), findsNothing);
      expect(find.byType(CompletionBurst), findsNothing);

      await tester.pumpAndSettle();
    });

    testWidgets('flows the selected variant into the burst', (tester) async {
      final overrides = [
        celebrationPreferencesProvider.overrideWithValue(
          const CelebrationPreferences.allEnabled().copyWith(
            tasksSelection: const FixedSelection(CelebrationVariant.fireworks),
          ),
        ),
      ];
      await _pumpDesktop(tester, header(open()), overrides: overrides);
      await _pumpDesktop(tester, header(done()), overrides: overrides);
      await tester.pump(const Duration(milliseconds: 560));

      final burst = tester.widget<CompletionBurst>(
        find.byType(CompletionBurst),
      );
      expect(burst.params?.variant, CelebrationVariant.fireworks);
      await tester.pumpAndSettle();
    });

    group('completion haptic honours the independent haptics switch', () {
      late List<String> haptics;

      setUp(() => haptics = <String>[]);

      void captureHaptics(WidgetTester tester) {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              haptics.add(call.arguments as String? ?? '');
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
      }

      testWidgets('fires the heavy impact when haptics are on', (tester) async {
        captureHaptics(tester);
        await _pumpDesktop(tester, header(open()));
        await _pumpDesktop(tester, header(done()));
        await tester.pump();

        expect(haptics, contains('HapticFeedbackType.heavyImpact'));
        await tester.pumpAndSettle();
      });

      testWidgets('stays silent when haptics are off', (tester) async {
        captureHaptics(tester);
        final overrides = [
          celebrationPreferencesProvider.overrideWithValue(
            const CelebrationPreferences.allEnabled().copyWith(haptics: false),
          ),
        ];
        await _pumpDesktop(tester, header(open()), overrides: overrides);
        await _pumpDesktop(tester, header(done()), overrides: overrides);
        await tester.pump();

        expect(haptics, isEmpty);
        await tester.pumpAndSettle();
      });
    });
  });
}
