import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
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
  await tester.pumpWidget(_desktopHost(child));
  await tester.pump();
}

DesktopTaskHeaderData _fixture({
  String title = 'Payment confirmation',
  TaskPriority priority = TaskPriority.p1High,
  DesktopTaskHeaderProject? project,
  DesktopTaskHeaderCategory? category,
  DesktopTaskHeaderDueDate? dueDate,
  List<DesktopTaskHeaderLabel> labels = const [],
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

const _labelFixtures = [
  DesktopTaskHeaderLabel(
    id: 'bug-fix',
    label: 'Bug fix',
    color: Color(0xFF1CA3E3),
  ),
  DesktopTaskHeaderLabel(
    id: 'release-blocker',
    label: 'Release blocker',
    color: Color(0xFFFA8C05),
  ),
];

Finder _pencilOpacity() => find.ancestor(
  of: find.byIcon(Icons.edit_outlined),
  matching: find.byType(AnimatedOpacity),
);

void main() {
  group('DesktopTaskHeader — content', () {
    testWidgets(
      'renders title, priority short, project, category, due, labels, '
      'status and ellipsis',
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
            onEllipsisTap: () {},
          ),
        );

        expect(find.text('Payment confirmation'), findsOneWidget);
        expect(find.text('P1'), findsOneWidget);
        expect(
          find.text('Device Sync - Lotti Mobile App Implementation'),
          findsOneWidget,
        );
        expect(find.text('Work'), findsOneWidget);
        expect(find.text('Due: Apr 1, 2026'), findsOneWidget);
        expect(find.text('Bug fix'), findsOneWidget);
        expect(find.text('Release blocker'), findsOneWidget);
        expect(find.text('Open'), findsOneWidget);
        expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
      },
    );

    testWidgets('omits optional groups when not supplied', (tester) async {
      await _pumpDesktop(
        tester,
        DesktopTaskHeader(
          data: _fixture(),
          onTitleSaved: (_) {},
        ),
      );
      expect(find.byIcon(Icons.folder_outlined), findsNothing);
      expect(find.text('Work'), findsNothing);
      expect(find.text('Due: Apr 1, 2026'), findsNothing);
      expect(find.text('Bug fix'), findsNothing);
      // No ellipsis when no handler.
      expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
    });
  });

  group('DesktopTaskHeader — hover affordance', () {
    testWidgets(
      'pencil icon is hidden in default state and visible when hovered',
      (tester) async {
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(),
            onTitleSaved: (_) {},
          ),
        );

        // Present in the tree (AnimatedOpacity + IgnorePointer), but opacity 0.
        expect(
          tester.widget<AnimatedOpacity>(_pencilOpacity()).opacity,
          0,
        );

        final titleCenter = tester.getCenter(find.text('Payment confirmation'));
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer(location: Offset.zero);
        await gesture.moveTo(titleCenter);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        expect(
          tester.widget<AnimatedOpacity>(_pencilOpacity()).opacity,
          1,
        );
      },
    );

    testWidgets(
      'initialHover flag surfaces the pencil immediately',
      (tester) async {
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(),
            onTitleSaved: (_) {},
            initialHover: true,
          ),
        );
        expect(
          tester.widget<AnimatedOpacity>(_pencilOpacity()).opacity,
          1,
        );
      },
    );
  });

  group('DesktopTaskHeader — editing', () {
    testWidgets(
      'tapping the title opens edit mode with check/close',
      (tester) async {
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(),
            onTitleSaved: (_) {},
          ),
        );
        await tester.tap(find.text('Payment confirmation'));
        await tester.pump();

        expect(find.byType(TextField), findsOneWidget);
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);
        expect(find.byIcon(Icons.edit_outlined), findsNothing);
      },
    );

    testWidgets(
      'commit fires onTitleSaved with the edited value',
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
        await tester.enterText(find.byType(TextField), 'Payment flow');
        await tester.tap(find.byIcon(Icons.check_rounded));
        await tester.pump();

        expect(saved, 'Payment flow');
        expect(find.byType(TextField), findsNothing);
        expect(find.text('Payment flow'), findsOneWidget);
      },
    );

    testWidgets(
      'cancel reverts to the original title without calling save',
      (tester) async {
        var saveCalls = 0;
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(),
            onTitleSaved: (_) => saveCalls++,
            initialEditing: true,
          ),
        );
        await tester.enterText(find.byType(TextField), 'Different title');
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pump();

        expect(saveCalls, 0);
        expect(find.byType(TextField), findsNothing);
        expect(find.text('Payment confirmation'), findsOneWidget);
      },
    );
  });

  group('DesktopTaskHeader — callbacks', () {
    testWidgets(
      'tapping priority / status / ellipsis fires the callbacks',
      (tester) async {
        var priority = 0;
        var status = 0;
        var ellipsis = 0;
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(),
            onTitleSaved: (_) {},
            onPriorityTap: () => priority++,
            onStatusTap: () => status++,
            onEllipsisTap: () => ellipsis++,
          ),
        );
        await tester.tap(find.text('P1'));
        await tester.tap(find.text('Open'));
        await tester.tap(find.byIcon(Icons.more_vert_rounded));
        await tester.pump();
        expect(priority, 1);
        expect(status, 1);
        expect(ellipsis, 1);
      },
    );

    testWidgets(
      'tapping category / due / label fires their callbacks',
      (tester) async {
        String? tappedLabel;
        var categoryTaps = 0;
        var dueTaps = 0;
        await _pumpDesktop(
          tester,
          DesktopTaskHeader(
            data: _fixture(
              category: _categoryFixture,
              dueDate: _dueFixture,
              labels: _labelFixtures,
            ),
            onTitleSaved: (_) {},
            onCategoryTap: () => categoryTaps++,
            onDueDateTap: () => dueTaps++,
            onLabelTap: (l) => tappedLabel = l.id,
          ),
        );
        await tester.tap(find.text('Work'));
        await tester.tap(find.text('Due: Apr 1, 2026'));
        await tester.tap(find.text('Release blocker'));
        await tester.pump();
        expect(categoryTaps, 1);
        expect(dueTaps, 1);
        expect(tappedLabel, 'release-blocker');
      },
    );
  });
}
