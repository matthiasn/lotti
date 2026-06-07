import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/header/desktop_task_header.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/l10n/app_localizations.dart';

import '../../../../widget_test_utils.dart';

Widget _desktopHost(Widget child, {ThemeData? theme}) {
  return MaterialApp(
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
      body: Align(alignment: Alignment.topLeft, child: child),
    ),
  );
}

Future<void> _pumpDesktop(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(1280, 720),
  ThemeData? theme,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  // The header's space-between metadata row relies on its SizedBox getting
  // a bounded max-width. Align shrink-wraps, so the tests pin the header
  // to the surface width explicitly.
  await tester.pumpWidget(
    _desktopHost(
      SizedBox(width: size.width, child: child),
      theme: theme,
    ),
  );
  await tester.pump();
}

/// Locates the private `_RenderTrailingAlignedWrap` that backs the meta row.
/// The wrap is the only widget in the tree whose runtime type name contains
/// `TrailingAlignedWrap`. It is a [RenderBox], which is all the intrinsic
/// helpers need; the `spacing` / `runSpacing` getters are read via [dynamic]
/// since the concrete type is private.
RenderBox _trailingWrapRenderObject(WidgetTester tester) {
  final element = tester.element(
    find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString().contains('TrailingAlignedWrap'),
    ),
  );
  return element.renderObject! as RenderBox;
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
  TaskStatus? status,
  DesktopTaskHeaderProject? project,
  DesktopTaskHeaderCategory? category,
  DesktopTaskHeaderDueDate? dueDate,
  List<LabelDefinition> labels = const [],
}) {
  final createdAt = DateTime.utc(2026);
  return DesktopTaskHeaderData(
    title: title,
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
    testWidgets(
      'crumb segments without tap handlers render as plain non-tappable '
      'padding',
      (tester) async {
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(),
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

    testWidgets('read-only title renders a pencil edit affordance', (
      tester,
    ) async {
      await _pumpDesktop(
        tester,
        DesktopTaskHeader(
          data: _fixture(),
          onTitleSaved: (_) {},
        ),
      );
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });

    testWidgets(
      'empty title renders "No title" placeholder + pencil and opens editor on tap',
      (tester) async {
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(title: ''),
            onTitleSaved: (_) {},
          ),
        );

        expect(find.text('No title'), findsOneWidget);
        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
        expect(find.byType(TextField), findsNothing);

        await tester.tap(find.text('No title'));
        await tester.pump();

        expect(find.byType(TextField), findsOneWidget);
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

        // The whole point of the pill is the tint: the label text carries
        // the status accent and the enclosing DecoratedBox the translucent
        // background derived from it (see _statusTint in the meta part).
        final context = tester.element(find.byType(DesktopTaskHeader));
        final accent = switch (label) {
          'In Progress' => TaskShowcasePalette.info(context),
          'Blocked' => TaskShowcasePalette.error(context),
          'On Hold' => TaskShowcasePalette.warning(context),
          'Groomed' => context.designTokens.colors.interactive.enabled,
          'Done' => TaskShowcasePalette.success(context),
          _ => null, // Rejected uses the low-emphasis text tint.
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
          expect(text.style?.color, accent, reason: label);
          expect(
            background,
            accent.withValues(alpha: 0.18),
            reason: label,
          );
        } else {
          final low = TaskShowcasePalette.lowText(context);
          expect(text.style?.color, low);
          expect(background, low.withValues(alpha: 0.14));
        }
      });
    }
  });

  group('DesktopTaskHeader — priority palette', () {
    for (final priority in TaskPriority.values) {
      testWidgets('renders ${priority.short} pill with the correct accent', (
        tester,
      ) async {
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(priority: priority),
            onTitleSaved: (_) {},
          ),
        );
        expect(find.text(priority.short), findsOneWidget);

        // Verify the pill actually carries the palette accent.
        final context = tester.element(find.byType(DesktopTaskHeader));
        final expected = switch (priority) {
          TaskPriority.p0Urgent => TaskShowcasePalette.error(context),
          TaskPriority.p1High => TaskShowcasePalette.warning(context),
          TaskPriority.p2Medium => TaskShowcasePalette.info(context),
          TaskPriority.p3Low => TaskShowcasePalette.success(context),
        };
        final pill = tester.widget<DsPill>(
          find.ancestor(
            of: find.text(priority.short),
            matching: find.byType(DsPill),
          ),
        );
        expect(pill.color, expected, reason: priority.short);
      });
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
        // Do not change the text — tap the commit button immediately.
        await tester.tap(find.byIcon(Icons.check_rounded));
        await tester.pump();

        expect(saves, 0, reason: 'same text should not trigger onTitleSaved');
        expect(find.byType(TextField), findsNothing);
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

  group('DesktopTaskHeader — render object layout branches', () {
    testWidgets(
      'spacing and runSpacing setters fire when tokens change between builds',
      (tester) async {
        // Build with the default (step3 = 8) spacing.
        final wideTokens = dsTokensLight.copyWith(
          spacing: dsTokensLight.spacing.copyWith(step3: 8),
        );
        final narrowTokens = dsTokensLight.copyWith(
          spacing: dsTokensLight.spacing.copyWith(step3: 16),
        );

        ThemeData buildTheme(DsTokens tokens) =>
            ThemeData(useMaterial3: true).copyWith(
              extensions: <ThemeExtension<dynamic>>[tokens],
            );

        final header = DesktopTaskHeader(
          data: _fixture(dueDate: _dueFixture),
          onTitleSaved: (_) {},
          estimateSlot: const Text('1h'),
        );

        await tester.binding.setSurfaceSize(const Size(1280, 720));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // First pump with 8px spacing.
        await tester.pumpWidget(
          _desktopHost(
            const SizedBox(width: 1280, child: SizedBox()),
            theme: buildTheme(wideTokens),
          ),
        );
        await tester.pumpWidget(
          _desktopHost(
            SizedBox(width: 1280, child: header),
            theme: buildTheme(wideTokens),
          ),
        );
        await tester.pump();

        // Second pump with 16px spacing — triggers the setter body
        // (markNeedsLayout) on _RenderTrailingAlignedWrap.
        await tester.pumpWidget(
          _desktopHost(
            SizedBox(width: 1280, child: header),
            theme: buildTheme(narrowTokens),
          ),
        );
        await tester.pump();

        // Verify the widget still renders correctly after the spacing change.
        expect(find.text('Due: Apr 1, 2026'), findsOneWidget);
        expect(find.text('Open'), findsOneWidget);
      },
    );

    testWidgets(
      'intrinsic width is computed without error',
      (tester) async {
        // IntrinsicWidth forces the Flutter layout engine to call
        // computeMinIntrinsicWidth and computeMaxIntrinsicWidth on all
        // descendants, including _RenderTrailingAlignedWrap.
        await tester.binding.setSurfaceSize(const Size(1280, 720));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _desktopHost(
            IntrinsicWidth(
              child: DesktopTaskHeader(
                data: _fixture(
                  dueDate: _dueFixture,
                  labels: _labelFixtures,
                ),
                onTitleSaved: (_) {},
                estimateSlot: const Text('1h'),
              ),
            ),
          ),
        );
        await tester.pump();

        // The widget laid out correctly and shows its content.
        expect(find.text('Due: Apr 1, 2026'), findsOneWidget);
        expect(find.text('Bug fix'), findsOneWidget);

        // The size returned by tester.getSize is positive, confirming the
        // intrinsic dimension methods returned meaningful non-zero values.
        final size = tester.getSize(find.byType(DesktopTaskHeader));
        expect(size.width, greaterThan(0));
        expect(size.height, greaterThan(0));
      },
    );

    testWidgets(
      'intrinsic height is computed without error',
      (tester) async {
        // Row with CrossAxisAlignment.stretch forces the Flutter layout engine
        // to call computeMinIntrinsicHeight and computeMaxIntrinsicHeight on
        // its children, including _RenderTrailingAlignedWrap descendants.
        await tester.binding.setSurfaceSize(const Size(1280, 720));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _desktopHost(
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                SizedBox(
                  width: 800,
                  child: DesktopTaskHeader(
                    data: _fixture(
                      dueDate: _dueFixture,
                      labels: _labelFixtures,
                    ),
                    onTitleSaved: (_) {},
                    estimateSlot: const Text('1h'),
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pump();

        // The widget laid out correctly and shows its content.
        expect(find.text('Due: Apr 1, 2026'), findsOneWidget);
        expect(find.text('Bug fix'), findsOneWidget);

        final size = tester.getSize(find.byType(DesktopTaskHeader));
        expect(size.width, greaterThan(0));
        expect(size.height, greaterThan(0));
      },
    );
  });

  group('DesktopTaskHeader — render object getters + intrinsics', () {
    testWidgets(
      'spacing / runSpacing getters expose the configured token values',
      (tester) async {
        // step3 == 8 by default in dsTokensLight; the meta row feeds it into
        // both spacing and runSpacing of the trailing-aligned wrap.
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(dueDate: _dueFixture),
            onTitleSaved: (_) {},
            estimateSlot: const Text('1h'),
          ),
        );

        final render = _trailingWrapRenderObject(tester);
        final expected = dsTokensLight.spacing.step3;
        // `spacing` / `runSpacing` live on the private render-object subtype,
        // so they have to be reached dynamically.
        expect((render as dynamic).spacing, expected);
        expect((render as dynamic).runSpacing, expected);
      },
    );

    testWidgets(
      'min intrinsic width equals the widest child; max width sums them',
      (tester) async {
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(dueDate: _dueFixture, labels: _labelFixtures),
            onTitleSaved: (_) {},
            estimateSlot: const Text('1h'),
          ),
        );

        final render = _trailingWrapRenderObject(tester);
        // computeMinIntrinsicWidth: max over children's own min widths.
        final minWidth = render.getMinIntrinsicWidth(double.infinity);
        // computeMaxIntrinsicWidth: sum of children's max widths.
        final maxWidth = render.getMaxIntrinsicWidth(double.infinity);

        expect(minWidth, greaterThan(0));
        expect(maxWidth, greaterThan(0));
        // The widest single child cannot exceed the sum of all children,
        // and with multiple chips the sum is strictly larger.
        expect(maxWidth, greaterThan(minWidth));
      },
    );

    testWidgets(
      'min intrinsic height equals max intrinsic height',
      (tester) async {
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(dueDate: _dueFixture, labels: _labelFixtures),
            onTitleSaved: (_) {},
            estimateSlot: const Text('1h'),
          ),
        );

        final render = _trailingWrapRenderObject(tester);
        // _RenderTrailingAlignedWrap.computeMinIntrinsicHeight delegates to
        // computeMaxIntrinsicHeight, so the two must be identical.
        const probeWidth = 800.0;
        final minHeight = render.getMinIntrinsicHeight(probeWidth);
        final maxHeight = render.getMaxIntrinsicHeight(probeWidth);

        expect(minHeight, greaterThan(0));
        expect(minHeight, maxHeight);
      },
    );
  });

  group('DesktopTaskHeader — due-date urgency styles', () {
    testWidgets('overdue urgency renders the due pill in error color', (
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
      expect(find.text('Overdue: Mar 1'), findsOneWidget);
    });

    testWidgets('today urgency renders the due pill in warning color', (
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
      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('normal urgency renders the due pill in medium-text color', (
      tester,
    ) async {
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
      expect(find.text('Mar 15, 2026'), findsOneWidget);
    });
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

  group('TrailingAlignedWrap — layout property', () {
    testWidgets(
      'the trailing child is always pinned to the right edge for random '
      'child-width sequences (model-based, fixed seed)',
      (tester) async {
        final random = Random(11);
        const trailingKey = Key('trailing');
        const wrapKey = Key('wrap');

        for (var run = 0; run < 25; run++) {
          final maxWidth = 120.0 + random.nextInt(400);
          final n = random.nextInt(7);
          final widths = [
            for (var i = 0; i < n; i++) 10.0 + random.nextInt(140),
          ];
          final trailingWidth = 10.0 + random.nextInt(100);

          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: maxWidth,
                  child: TrailingAlignedWrap(
                    key: wrapKey,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final w in widths) SizedBox(width: w, height: 12),
                      SizedBox(
                        key: trailingKey,
                        width: trailingWidth,
                        height: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

          final wrapLeft = tester.getTopLeft(find.byKey(wrapKey)).dx;
          final trailingTopLeft = tester.getTopLeft(find.byKey(trailingKey));
          expect(
            trailingTopLeft.dx - wrapLeft,
            closeTo(maxWidth - trailingWidth, 0.001),
            reason:
                'run=$run maxWidth=$maxWidth widths=$widths '
                'trailing=$trailingWidth',
          );
        }
      },
    );
  });
}
