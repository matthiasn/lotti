import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_agenda_row.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_row_scaffold.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/editable_title.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

const _category = DayAgentCategory(
  id: 'cat_work',
  name: 'Work',
  colorHex: '5ED4B7',
);

AgendaItem _item({
  String title = 'Deep work on the migration',
  String? taskId,
  AgendaItemState state = AgendaItemState.open,
  int? estimate = 120,
  double? progress,
  String? outcome,
}) => AgendaItem(
  id: 'a1',
  title: title,
  category: _category,
  linkedBlockIds: const ['b1'],
  taskId: taskId,
  totalEstimateMinutes: estimate,
  progress: progress,
  outcome: outcome,
  state: state,
);

final _ten = DateTime(2026, 5, 26, 10);

Future<void> _pump(
  WidgetTester tester,
  AgendaItem item, {
  DateTime? start,
  String? displayTitle,
  String? whyReason,
  VoidCallback? onTap,
  ValueChanged<String>? onRename,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Material(
        child: Align(
          alignment: Alignment.topCenter,
          child: DayAgendaRow(
            item: item,
            start: start,
            displayTitle: displayTitle,
            whyReason: whyReason,
            onTap: onTap,
            onRename: onRename,
          ),
        ),
      ),
      mediaQueryData: MediaQueryData(
        size: const Size(600, 800),
        textScaler: TextScaler.linear(textScale),
      ),
    ),
  );
}

DsTokens _tokens(WidgetTester tester) =>
    tester.element(find.byType(DayAgendaRow)).designTokens;

TextStyle _styleOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

void main() {
  group('DayAgendaRow time column', () {
    testWidgets("shows the first block's start, low-emphasis and tabular", (
      tester,
    ) async {
      await _pump(tester, _item(), start: _ten);

      final time = find.text('10:00 AM');
      expect(time, findsOneWidget);
      final style = _styleOf(tester, '10:00 AM');
      expect(style.color, _tokens(tester).colors.text.lowEmphasis);
      expect(style.fontFeatures, dayFigures);
    });

    testWidgets('shows a dash for an item with no block', (tester) async {
      await _pump(tester, _item());

      expect(find.text('—'), findsOneWidget);
    });

    testWidgets("is the grid's time column, then a gutter, at any text size", (
      tester,
    ) async {
      await _pump(tester, _item(), start: _ten, textScale: 1.5);
      final tokens = _tokens(tester);

      final dot = tester.getTopLeft(
        find.byKey(const Key('daily_os_agenda_row_dot')),
      );
      final row = tester.getTopLeft(find.byType(DayAgendaRow));
      expect(
        dot.dx - row.dx,
        closeTo(
          // A phone-width row: the tighter step4 inset.
          tokens.spacing.step4 +
              DayRowScaffold.timeColumnWidth(
                tester.element(find.byType(DayRowScaffold)),
              ) +
              tokens.spacing.step2 +
              // The dot is centred in a mark slot one caption glyph wide.
              (tokens.typography.size.caption - tokens.spacing.step2) / 2,
          0.5,
        ),
      );
    });
  });

  group('DayAgendaRow anatomy', () {
    testWidgets('a step2 dot in the category colour leads the title', (
      tester,
    ) async {
      await _pump(tester, _item(), start: _ten);
      final tokens = _tokens(tester);
      final dot = find.byKey(const Key('daily_os_agenda_row_dot'));

      expect(tester.getSize(dot), Size.square(tokens.spacing.step2));
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: dot,
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration.color, categoryColorFromHex(_category.colorHex));
      expect(decoration.shape, BoxShape.circle);
      expect(
        tester.getTopLeft(find.text('Deep work on the migration')).dx,
        greaterThan(tester.getTopRight(dot).dx),
      );
    });

    testWidgets('an open title is high-emphasis bodySmall', (tester) async {
      await _pump(tester, _item());
      final tokens = _tokens(tester);

      final style = _styleOf(tester, 'Deep work on the migration');
      expect(style.color, tokens.colors.text.highEmphasis);
      expect(
        style.fontSize,
        tokens.typography.styles.body.bodySmall.fontSize,
      );
      expect(style.decoration, isNull);
    });

    testWidgets('the estimate sits at the right, tabular and medium-emphasis', (
      tester,
    ) async {
      await _pump(tester, _item());

      final estimate = find.text('2h');
      expect(
        tester.getTopLeft(estimate).dx,
        greaterThan(
          tester.getTopRight(find.text('Deep work on the migration')).dx,
        ),
      );
      final style = _styleOf(tester, '2h');
      expect(style.color, _tokens(tester).colors.text.mediumEmphasis);
      expect(style.fontFeatures, dayFigures);
    });

    testWidgets('an item without an estimate shows none', (tester) async {
      await _pump(tester, _item(estimate: null));

      expect(find.text('2h'), findsNothing);
    });

    testWidgets('meets the touch-target height', (tester) async {
      await _pump(tester, _item(estimate: null));

      expect(
        tester.getSize(find.byType(DayAgendaRow)).height,
        greaterThanOrEqualTo(TapTargets.minimum),
      );
    });

    testWidgets('a one-line row is centred in the touch target', (
      tester,
    ) async {
      await _pump(tester, _item());

      final row = tester.getRect(find.byType(DayAgendaRow));
      final title = tester.getRect(find.text('Deep work on the migration'));
      expect(title.center.dy, closeTo(row.center.dy, 1));
    });

    testWidgets('the check and the chevron centre on the title line', (
      tester,
    ) async {
      await _pump(
        tester,
        _item(taskId: 'task-1', state: AgendaItemState.done),
      );

      final title = tester.getRect(find.text('Deep work on the migration'));
      for (final icon in [LottiIcons.confirm, LottiIcons.chevronRight]) {
        expect(
          tester.getRect(find.byIcon(icon)).center.dy,
          closeTo(title.center.dy, 1),
        );
      }
    });

    testWidgets('a row has one line when there is nothing more to say', (
      tester,
    ) async {
      await _pump(tester, _item());

      expect(find.byIcon(LottiIcons.aiSpark), findsNothing);
      expect(find.byType(RichText), findsNWidgets(3)); // time, title, estimate
    });
  });

  group('DayAgendaRow second line', () {
    testWidgets("the agent's reason: a violet spark, quiet words, two lines", (
      tester,
    ) async {
      await _pump(
        tester,
        _item(),
        whyReason: 'Your best hours; nothing else until noon.',
      );
      final accent = _tokens(tester).colors.aiCard.accent;

      expect(
        tester.widget<Icon>(find.byIcon(LottiIcons.aiSpark)).color,
        accent,
      );
      final reason = tester.widget<Text>(
        find.text('Your best hours; nothing else until noon.'),
      );
      expect(reason.style?.color, _tokens(tester).colors.text.lowEmphasis);
      expect(reason.maxLines, 2);
      expect(reason.overflow, TextOverflow.ellipsis);
    });

    testWidgets(
      "a linked row leads with its task's name; the agenda's wording joins "
      'the outcome on the meta line',
      (tester) async {
        await _pump(
          tester,
          _item(taskId: 'task-1', outcome: 'Schema shipped'),
          displayTitle: 'Migration project',
        );

        expect(find.text('Migration project'), findsOneWidget);
        expect(
          find.text('Schema shipped · Deep work on the migration'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      "the agenda's wording stays off the meta line when the task's name "
      'already says it',
      (tester) async {
        await _pump(
          tester,
          _item(taskId: 'task-1', outcome: 'Schema shipped'),
          displayTitle: 'Plan the deep work on the migration this week',
        );

        expect(
          find.text('Plan the deep work on the migration this week'),
          findsOneWidget,
        );
        // Only the outcome: "Deep work on the migration" is inside the name.
        expect(find.text('Schema shipped'), findsOneWidget);
        expect(find.textContaining('· Deep work'), findsNothing);
      },
    );

    testWidgets('a linked task named like the item is not repeated', (
      tester,
    ) async {
      await _pump(
        tester,
        _item(taskId: 'task-1'),
        displayTitle: 'Deep work on the migration',
      );

      expect(find.text('Deep work on the migration'), findsOneWidget);
    });

    testWidgets("a standalone item's display title is not shown", (
      tester,
    ) async {
      await _pump(tester, _item(), displayTitle: 'Something else');

      expect(find.text('Something else'), findsNothing);
    });

    testWidgets('overdue joins the meta line in error ink', (tester) async {
      await _pump(
        tester,
        _item(state: AgendaItemState.overdue, outcome: 'Schema shipped'),
      );

      final rich = tester.widget<RichText>(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText() == 'Schema shipped · Overdue',
        ),
      );
      TextSpan? overdue;
      rich.text.visitChildren((span) {
        if (span is TextSpan && span.text == 'Overdue') overdue = span;
        return true;
      });
      expect(overdue?.style?.color, _tokens(tester).colors.alert.error.ink);
    });

    testWidgets('overdue alone is the whole meta line', (tester) async {
      await _pump(tester, _item(state: AgendaItemState.overdue));

      expect(find.text('Overdue'), findsOneWidget);
    });
  });

  group('DayAgendaRow category dot', () {
    testWidgets('names its category, to a pointer and a screen reader', (
      tester,
    ) async {
      await _pump(tester, _item());

      final tooltip = tester.widget<Tooltip>(
        find.ancestor(
          of: find.byKey(const Key('daily_os_agenda_row_dot')),
          matching: find.byType(Tooltip),
        ),
      );
      expect(tooltip.message, _item().category.name);
    });
  });

  group('DayAgendaRow in progress', () {
    testWidgets('a teal edge runs down the row', (tester) async {
      await _pump(tester, _item(state: AgendaItemState.inProgress));
      final tokens = _tokens(tester);

      final edge = find.byKey(const Key('day_row_active_edge'));
      expect(tester.getSize(edge).width, tokens.spacing.step1);
      expect(
        tester.getSize(edge).height,
        tester.getSize(find.byType(DayAgendaRow)).height,
      );
      expect(
        tester
            .widget<ColoredBox>(
              find.descendant(of: edge, matching: find.byType(ColoredBox)),
            )
            .color,
        tokens.colors.interactive.enabled,
      );
    });

    testWidgets('the title steps up to subtitle2', (tester) async {
      await _pump(tester, _item(state: AgendaItemState.inProgress));

      expect(
        _styleOf(tester, 'Deep work on the migration').fontSize,
        _tokens(tester).typography.styles.subtitle.subtitle2.fontSize,
      );
    });

    // The bar disagreed with the clock (35m tracked of a 1h 30m block read
    // as "behind" at 3:55 PM); "Now" and the teal edge carry the state.
    for (final progress in [null, 0.0, 0.4, 1.0]) {
      testWidgets('progress $progress shows no bar', (tester) async {
        await _pump(
          tester,
          _item(state: AgendaItemState.inProgress, progress: progress),
        );

        expect(find.byType(LinearProgressIndicator), findsNothing);
      });
    }

    testWidgets(
      'every item keeps one meta line and up to two of reason, under way '
      'or not',
      (tester) async {
        for (final state in [
          AgendaItemState.inProgress,
          AgendaItemState.open,
        ]) {
          await _pump(
            tester,
            _item(state: state, outcome: 'Shipped'),
            whyReason: 'Because the morning is quiet',
          );

          expect(tester.widget<Text>(find.text('Shipped')).maxLines, 1);
          expect(
            tester
                .widget<Text>(find.text('Because the morning is quiet'))
                .maxLines,
            2,
          );
        }
      },
    );

    testWidgets(
      'the meta and the reason run under the figure, not beside it',
      (tester) async {
        await _pump(
          tester,
          _item(outcome: 'Shipped'),
          whyReason: 'Because the morning is quiet',
        );

        // The meta starts under the name …
        expect(
          tester.getTopLeft(find.text('Shipped')).dx,
          closeTo(
            tester.getTopLeft(find.text('Deep work on the migration')).dx,
            0.01,
          ),
        );
        // … and the reason's line box reaches past where the figure starts.
        final reasonBox = tester.getRect(
          find
              .ancestor(
                of: find.text('Because the morning is quiet'),
                matching: find.byType(Expanded),
              )
              .first,
        );
        expect(
          reasonBox.right,
          greaterThan(tester.getTopLeft(find.text('2h')).dx),
        );
      },
    );
  });

  group('DayAgendaRow done', () {
    testWidgets('is struck through in low-emphasis ink, the check its mark', (
      tester,
    ) async {
      await _pump(
        tester,
        _item(state: AgendaItemState.done),
        whyReason: 'A reason it no longer needs',
      );
      final tokens = _tokens(tester);

      // Explicit ink, not a blanket opacity that fades the check too.
      expect(find.byType(Opacity), findsNothing);
      final title = _styleOf(tester, 'Deep work on the migration');
      expect(title.decoration, TextDecoration.lineThrough);
      expect(title.color, tokens.colors.text.lowEmphasis);
      // A finished item drops its reason.
      expect(find.text('A reason it no longer needs'), findsNothing);
      // The check in the time's own ink: green would read as a category.
      expect(
        tester.widget<Icon>(find.byIcon(LottiIcons.confirm)).color,
        tokens.colors.text.mediumEmphasis,
      );
      // The check takes the category dot's place; the time stays trailing.
      expect(
        find.byKey(const Key('daily_os_agenda_row_dot')),
        findsNothing,
      );
      expect(find.text('2h'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byIcon(LottiIcons.confirm)).dx,
        lessThan(tester.getTopLeft(find.text('Deep work on the migration')).dx),
      );
    });

    testWidgets('a done standalone title is no longer editable', (
      tester,
    ) async {
      await _pump(
        tester,
        _item(state: AgendaItemState.done),
        onRename: (_) {},
      );

      expect(find.byType(EditableTitle), findsNothing);
    });

    testWidgets('an open row is fully opaque', (tester) async {
      await _pump(tester, _item());

      expect(find.byType(Opacity), findsNothing);
    });
  });

  group('DayAgendaRow task-linked versus standalone', () {
    testWidgets('a task-linked row ends in a chevron and opens the task', (
      tester,
    ) async {
      var opened = 0;
      await _pump(tester, _item(taskId: 'task-1'), onTap: () => opened++);

      final chevron = tester.widget<Icon>(find.byIcon(LottiIcons.chevronRight));
      expect(chevron.color, _tokens(tester).colors.text.lowEmphasis);

      await tester.tap(find.byType(DayAgendaRow));
      expect(opened, 1);
    });

    testWidgets('a standalone row carries no chevron and no ink', (
      tester,
    ) async {
      await _pump(tester, _item());

      expect(find.byIcon(LottiIcons.chevronRight), findsNothing);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets(
      'a standalone title is click-to-edit and submits the new title',
      (tester) async {
        final renames = <String>[];
        await _pump(tester, _item(), onRename: renames.add);

        await tester.tap(find.text('Deep work on the migration'));
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('daily_os_editable_title_field')),
          'Renamed',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();

        expect(renames, ['Renamed']);
      },
    );

    testWidgets('a task-linked title stays read-only', (tester) async {
      await _pump(tester, _item(taskId: 'task-1'), onRename: (_) {});

      expect(find.byType(EditableTitle), findsNothing);
    });
  });
}
