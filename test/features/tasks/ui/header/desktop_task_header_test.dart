import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/tasks/ui/header/desktop_task_header.dart';
import 'package:lotti/l10n/app_localizations.dart';

import '../../../../widget_test_utils.dart';

Widget _desktopHost(Widget child) {
  return MaterialApp(
    theme: resolveTestTheme(),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      FormBuilderLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: child),
    ),
  );
}

Future<void> _pumpDesktop(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(1280, 720),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  // The header's space-between metadata row relies on its SizedBox getting
  // a bounded max-width. Align shrink-wraps, so the tests pin the header
  // to the surface width explicitly.
  await tester.pumpWidget(
    _desktopHost(SizedBox(width: size.width, child: child)),
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
  TaskPriority priority = TaskPriority.p1High,
  DesktopTaskHeaderProject? project,
  DesktopTaskHeaderCategory? category,
  DesktopTaskHeaderDueDate? dueDate,
  List<LabelDefinition> labels = const [],
}) {
  final createdAt = DateTime.utc(2026);
  return DesktopTaskHeaderData(
    title: title,
    priority: priority,
    status: TaskStatus.open(
      id: 'fx-open',
      createdAt: createdAt,
      utcOffset: 0,
    ),
    project: project,
    category: category,
    dueDate: dueDate,
    labels: labels,
  );
}

const _projectFixture = DesktopTaskHeaderProject(
  label: 'Device Sync - Lotti Mobile App Implementation',
  icon: Icons.folder_outlined,
);

const _categoryFixture = DesktopTaskHeaderCategory(
  label: 'Work',
  color: Color(0xFF1CA3E3),
  icon: Icons.work_outline_rounded,
);

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

void main() {
  group('DesktopTaskHeader — content + layout', () {
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
        expect(find.text('P1'), findsOneWidget);
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
            data: _fixture(),
            onTitleSaved: (_) {},
            onCategoryTap: () => category++,
            onProjectTap: () => project++,
            onAddLabelTap: () => addLabel++,
            onDueDateTap: () => due++,
          ),
        );
        expect(find.text('unassigned'), findsOneWidget);
        expect(find.text('No project'), findsOneWidget);
        expect(find.text('Add Label'), findsOneWidget);
        expect(find.text('No due date'), findsOneWidget);

        await tester.tap(find.text('unassigned'));
        await tester.tap(find.text('No project'));
        await tester.tap(find.text('Add Label'));
        await tester.tap(find.text('No due date'));
        await tester.pump();
        expect(category, 1);
        expect(project, 1);
        expect(addLabel, 1);
        expect(due, 1);
      },
    );
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
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

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
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pump();

      expect(saved, 'Payment flow');
    });
  });

  group('DesktopTaskHeader — metadata layout', () {
    testWidgets('wide viewport: right group sits far right of left group', (
      tester,
    ) async {
      await _pumpDesktop(
        tester,
        DesktopTaskHeader(
          data: _fixture(dueDate: _dueFixture),
          onTitleSaved: (_) {},
          estimateSlot: const Text('0h / 1h'),
        ),
      );
      final dueLeft = tester.getTopLeft(find.text('Due: Apr 1, 2026')).dx;
      final statusLeft = tester.getTopLeft(find.text('Open')).dx;
      expect(
        statusLeft > dueLeft + 300,
        isTrue,
        reason:
            'Status should be well to the right of Due (space-between pushes '
            'groups to opposite ends on a wide row)',
      );
    });

    testWidgets(
      'narrow viewport: the right group wraps onto its own row below',
      (tester) async {
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(dueDate: _dueFixture),
            onTitleSaved: (_) {},
            estimateSlot: const Text('0h / 1h'),
          ),
          size: const Size(360, 800),
        );
        final dueTop = tester.getTopLeft(find.text('Due: Apr 1, 2026')).dy;
        final statusTop = tester.getTopLeft(find.text('Open')).dy;
        expect(
          statusTop > dueTop + 10,
          isTrue,
          reason:
              'On a narrow viewport the right group should wrap to its own '
              'row, sitting below the left group',
        );
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
      await tester.tap(find.text('P1'));
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
  });
}
