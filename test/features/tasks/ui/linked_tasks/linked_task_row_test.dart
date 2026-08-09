import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/state/task_one_liner_provider.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_task_row.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/entity_factories.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';

void main() {
  late MockNavService mockNavService;

  setUp(() {
    mockNavService = MockNavService();
    getIt.registerSingleton<NavService>(mockNavService);
  });

  tearDown(() async {
    await getIt.reset();
  });

  LinkedTaskRowData buildRowData() => LinkedTaskRowData(
    task: TestTaskFactory.create(id: 'other-task', title: 'Other Task'),
  );

  group('LinkedTaskRow', () {
    testWidgets(
      'renders one template — status glyph, title, chevron — with no per-row '
      'direction glyph or caption (the section header states the relationship)',
      (tester) async {
        await tester.pumpWidget(
          WidgetTestBench(
            child: LinkedTaskRow(
              data: buildRowData(),
              manageMode: false,
            ),
          ),
        );

        expect(find.text('Other Task'), findsOneWidget);
        expect(find.byType(StatusGlyph), findsOneWidget);
        expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
        expect(find.byType(SvgPicture), findsNothing);
      },
    );

    testWidgets('renders the AI one-liner in accent ink with ellipsis', (
      tester,
    ) async {
      const oneLiner =
          'A deliberately long AI summary that cannot fit in this linked row';
      await tester.pumpWidget(
        WidgetTestBench(
          overrides: [
            taskOneLinerProvider.overrideWith(
              (ref, taskId) async => oneLiner,
            ),
          ],
          child: SizedBox(
            width: 540,
            child: LinkedTaskRow(
              data: buildRowData(),
              manageMode: false,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final richText = tester.widget<RichText>(
        find.text(oneLiner, findRichText: true),
      );
      final rootSpan = richText.text as TextSpan;
      final summarySpan = rootSpan.children!.first as TextSpan;
      final context = tester.element(find.byType(LinkedTaskRow));

      expect(summarySpan.text, oneLiner);
      expect(
        summarySpan.style?.color,
        context.designTokens.colors.aiCard.accent,
      );
      expect(richText.maxLines, 1);
      expect(richText.overflow, TextOverflow.ellipsis);
    });

    testWidgets(
      'shows the plain chevron in manage mode when onUnlink is null',
      (tester) async {
        await tester.pumpWidget(
          WidgetTestBench(
            child: LinkedTaskRow(
              data: buildRowData(),
              manageMode: true,
            ),
          ),
        );

        expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
        expect(find.byIcon(Icons.link_off), findsNothing);
      },
    );

    testWidgets(
      'shows the unlink button in manage mode when onUnlink is supplied',
      (tester) async {
        var unlinkCalled = false;
        await tester.pumpWidget(
          WidgetTestBench(
            child: LinkedTaskRow(
              data: buildRowData(),
              manageMode: true,
              onUnlink: () async {
                unlinkCalled = true;
                return 1;
              },
            ),
          ),
        );

        expect(find.byIcon(Icons.link_off), findsOneWidget);
        expect(find.byIcon(Icons.arrow_forward_ios), findsNothing);

        await tester.tap(find.byIcon(Icons.link_off));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Confirmation dialog gates the callback.
        expect(unlinkCalled, isFalse);
        await tester.tap(find.widgetWithText(DesignSystemButton, 'Unlink'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(unlinkCalled, isTrue);
      },
    );

    testWidgets(
      'shows the edit button in manage mode when onEdit is supplied, '
      'alongside the unlink button',
      (tester) async {
        var editCalled = false;
        await tester.pumpWidget(
          WidgetTestBench(
            child: LinkedTaskRow(
              data: buildRowData(),
              manageMode: true,
              onEdit: () async => editCalled = true,
              onUnlink: () async => 1,
            ),
          ),
        );

        expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);
        expect(find.byIcon(Icons.link_off), findsOneWidget);
        expect(find.byIcon(Icons.arrow_forward_ios), findsNothing);

        await tester.tap(find.byIcon(Icons.swap_horiz_rounded));
        await tester.pump();

        expect(editCalled, isTrue);
      },
    );

    testWidgets(
      'shows only the edit button in manage mode when onUnlink is null',
      (tester) async {
        await tester.pumpWidget(
          WidgetTestBench(
            child: LinkedTaskRow(
              data: buildRowData(),
              manageMode: true,
              onEdit: () async {},
            ),
          ),
        );

        expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);
        expect(find.byIcon(Icons.link_off), findsNothing);
        expect(find.byIcon(Icons.arrow_forward_ios), findsNothing);
      },
    );

    testWidgets('cancelling the unlink dialog does not invoke onUnlink', (
      tester,
    ) async {
      var unlinkCalled = false;
      await tester.pumpWidget(
        WidgetTestBench(
          child: LinkedTaskRow(
            data: buildRowData(),
            manageMode: true,
            onUnlink: () async {
              unlinkCalled = true;
              return 1;
            },
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.link_off));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.widgetWithText(DesignSystemButton, 'Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(unlinkCalled, isFalse);
    });

    testWidgets(
      'reports a failure when the unlink removed nothing — a delete that '
      'matches no row returns zero and throws nothing, so without the count '
      'it looked exactly like a successful unlink',
      (tester) async {
        await tester.pumpWidget(
          WidgetTestBench(
            child: LinkedTaskRow(
              data: buildRowData(),
              manageMode: true,
              onUnlink: () async => 0,
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.link_off));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.widgetWithText(DesignSystemButton, 'Unlink'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(SnackBar), findsWidgets);
      },
    );

    testWidgets(
      'shows a SnackBar when onUnlink throws',
      (tester) async {
        await tester.pumpWidget(
          WidgetTestBench(
            child: LinkedTaskRow(
              data: buildRowData(),
              manageMode: true,
              onUnlink: () async => throw Exception('delete failed'),
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.link_off));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.widgetWithText(DesignSystemButton, 'Unlink'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(SnackBar), findsOneWidget);
      },
    );

    testWidgets('tapping the row in browse mode navigates to the other task', (
      tester,
    ) async {
      await tester.pumpWidget(
        WidgetTestBench(
          // Desktop sizing routes navigation through NavService instead of
          // pushing TaskDetailsPage onto the navigator.
          mediaQueryData: const MediaQueryData(size: Size(1280, 900)),
          child: LinkedTaskRow(
            data: buildRowData(),
            manageMode: false,
          ),
        ),
      );

      await tester.tap(find.text('Other Task'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(
        () => mockNavService.pushDesktopTaskDetail('other-task'),
      ).called(1);
    });

    testWidgets(
      'the row stays navigable in manage mode — the edit/unlink buttons are '
      'additive, so a live-looking row is never a dead tap target',
      (tester) async {
        await tester.pumpWidget(
          WidgetTestBench(
            mediaQueryData: const MediaQueryData(size: Size(1280, 900)),
            child: LinkedTaskRow(
              data: buildRowData(),
              manageMode: true,
            ),
          ),
        );

        final rowInkWell = tester.widget<InkWell>(find.byType(InkWell).first);
        expect(rowInkWell.onTap, isNotNull);
      },
    );
  });

  group('LinkedTaskRow trailing-rail geometry', () {
    /// Renders one row at a fixed width and reports the box the title got.
    ///
    /// Measured rather than asserted from the source: a rail "reserved" by a
    /// SizedBox the actions then overflow, or sized from a text style the rows
    /// do not render at, still reads as correct in the widget tree while
    /// visibly re-wrapping the title. Only the laid-out width catches that.
    Future<Size> titleBoxAt(
      WidgetTester tester, {
      required bool manageMode,
    }) async {
      await tester.pumpWidget(
        WidgetTestBench(
          // Align, not a bare SizedBox: the bench hands its child tight
          // constraints, so a width set any other way is silently ignored and
          // the row is measured at the full 800pt surface instead of a phone.
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 390,
              child: LinkedTaskRow(
                data: LinkedTaskRowData(
                  task: TestTaskFactory.create(
                    id: 'other-task',
                    title:
                        'Migrate the relationship picker to the shared sheet',
                  ),
                ),
                manageMode: manageMode,
                onEdit: () async {},
                onUnlink: () async => 1,
              ),
            ),
          ),
        ),
      );
      return tester.getSize(
        find.text('Migrate the relationship picker to the shared sheet'),
      );
    }

    testWidgets(
      'the title keeps the same box when manage mode is toggled, so entering '
      'manage mode never re-wraps every row',
      (tester) async {
        final browsing = await titleBoxAt(tester, manageMode: false);
        final managing = await titleBoxAt(tester, manageMode: true);

        expect(managing.width, browsing.width);
        expect(managing.height, browsing.height);
      },
    );

    testWidgets('the row offers no unbounded trailing content to overflow', (
      tester,
    ) async {
      await titleBoxAt(tester, manageMode: true);
      expect(tester.takeException(), isNull);
    });

    /// Row height at a width where the title fits one line and the status sits
    /// trailing — the case where the trailing rail, not the text, sets the
    /// height, and so the only case that can catch the rail growing.
    Future<double> wideRowHeight(
      WidgetTester tester, {
      required bool manageMode,
    }) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 900,
              child: LinkedTaskRow(
                data: buildRowData(),
                manageMode: manageMode,
                onEdit: () async {},
                onUnlink: () async => 1,
              ),
            ),
          ),
        ),
      );
      return tester.getSize(find.byType(LinkedTaskRow)).height;
    }

    testWidgets(
      'the row keeps its height across modes too, so turning Manage on does '
      'not grow every row and jump the card taller',
      (tester) async {
        final browsing = await wideRowHeight(tester, manageMode: false);
        final managing = await wideRowHeight(tester, manageMode: true);

        expect(managing, browsing);
      },
    );
  });

  group('LinkedTaskRow manage-mode hit areas', () {
    testWidgets(
      'both actions keep the full 48pt target on the axis that tells them '
      'apart — they sit in an adjacent pair, so a horizontal mis-tap is the '
      'one that fires the wrong action',
      (tester) async {
        await tester.pumpWidget(
          WidgetTestBench(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 900,
                child: LinkedTaskRow(
                  data: buildRowData(),
                  manageMode: true,
                  onEdit: () async {},
                  onUnlink: () async => 1,
                ),
              ),
            ),
          ),
        );

        for (final icon in [Icons.swap_horiz_rounded, Icons.link_off]) {
          final size = tester.getSize(
            find
                .ancestor(
                  of: find.byIcon(icon),
                  matching: find.byType(IconButton),
                )
                .first,
          );
          expect(size.width, greaterThanOrEqualTo(48));
          // Vertically the button stops at the list item's content box; the
          // row's own padding sits directly above and below it and belongs to
          // the row's tap target, so a high or low tap opens the task rather
          // than landing on nothing.
          expect(size.height, greaterThanOrEqualTo(32));
        }
      },
    );

    testWidgets(
      'the row itself stays a 48pt target while costing far less than the '
      '68pt a square action box forced on every row of both modes',
      (tester) async {
        for (final manageMode in [false, true]) {
          await tester.pumpWidget(
            WidgetTestBench(
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 900,
                  child: LinkedTaskRow(
                    data: buildRowData(),
                    manageMode: manageMode,
                    onEdit: () async {},
                    onUnlink: () async => 1,
                  ),
                ),
              ),
            ),
          );

          final height = tester.getSize(find.byType(LinkedTaskRow)).height;
          expect(
            height,
            greaterThanOrEqualTo(48),
            reason: 'manage=$manageMode',
          );
          expect(height, lessThan(60), reason: 'manage=$manageMode');
        }
      },
    );
  });

  group('LinkedTaskRow emphasis ladder', () {
    /// The colour the status label is actually painted at, at a given row width.
    ///
    /// Asserted on the rendered ink rather than on which slot the label landed
    /// in: the wide layout styles it directly while the narrow one inherits the
    /// list item's subtitle style, so the same intent has two code paths and
    /// only one of them was carrying the emphasis.
    Future<Color?> statusInkAt(WidgetTester tester, double width) async {
      await tester.pumpWidget(
        WidgetTestBench(
          // Align, not a bare SizedBox: the bench hands its child tight
          // constraints, so a width set any other way is silently ignored and
          // every case ends up measuring the same 800pt row.
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: LinkedTaskRow(
                data: buildRowData(),
                manageMode: false,
              ),
            ),
          ),
        ),
      );
      final richText = tester.widget<RichText>(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText && widget.text.toPlainText().contains('Open'),
        ),
      );
      // The span carrying the label, not the root: the narrow path overrides
      // the colour on a child span, so reading the root style reports the
      // inherited value the override exists to replace.
      Color? ink;
      richText.text.visitChildren((span) {
        if (span is TextSpan && (span.text?.contains('Open') ?? false)) {
          ink = span.style?.color ?? richText.text.style?.color;
        }
        return true;
      });
      return ink;
    }

    testWidgets(
      'the status label sits below the section eyebrow at both widths, so the '
      'narrow layout ranks the same three roles the wide one does',
      (tester) async {
        final narrow = await statusInkAt(tester, 390);
        final wide = await statusInkAt(tester, 720);

        expect(narrow, dsTokensLight.colors.text.lowEmphasis);
        expect(wide, dsTokensLight.colors.text.lowEmphasis);
        // ...and strictly below the eyebrow that groups it.
        expect(narrow, isNot(dsTokensLight.colors.text.mediumEmphasis));
      },
    );
  });

  group('StatusGlyph', () {
    testWidgets('renders an icon colored for the given status', (
      tester,
    ) async {
      final status = TaskStatus.done(
        id: 's-done',
        createdAt: DateTime(2024),
        utcOffset: 0,
      );

      await tester.pumpWidget(
        WidgetTestBench(child: StatusGlyph(status: status)),
      );

      expect(find.byType(Icon), findsOneWidget);
    });
  });
}
