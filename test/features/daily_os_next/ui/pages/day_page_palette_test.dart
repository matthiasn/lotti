// The day page's colour discipline (docs/implementation_plans/
// 2026-11-10_daily_os_day_page_redesign.md, "Colour discipline"): every
// colour the page paints is one of the design-system tokens the table allows,
// or a category's own hue on a fill. The regression guard for "random blue".
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/plan_view_toggle.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';
import 'day_page_test_helpers.dart';

const _deep = DayAgentCategory(id: 'deep', name: 'Deep', colorHex: '7C5CFF');
const _health = DayAgentCategory(
  id: 'health',
  name: 'Health',
  colorHex: '34D399',
);
final _day = DateTime(2026, 5, 26);

TimeBlock _block(
  String id,
  DayAgentCategory category,
  int hour,
  int minutes, {
  TimeBlockState state = TimeBlockState.drafted,
  TimeBlockType type = TimeBlockType.ai,
  String? taskId,
}) {
  final start = _day.add(Duration(hours: hour));
  return TimeBlock(
    id: id,
    title: 'Block $id',
    start: start,
    end: start.add(Duration(minutes: minutes)),
    type: type,
    state: state,
    category: category,
    reason: 'A reason for $id',
    taskId: taskId,
  );
}

/// A day with every state the page can show: planned blocks of two
/// categories, a task-linked and a standalone item, one done, one in
/// progress, one overdue, and recorded time beside them.
DraftPlan _plan() => DraftPlan(
  dayDate: _day,
  blocks: [
    _block('a', _deep, 9, 60),
    _block('b', _health, 11, 30),
    _block('c', _deep, 14, 90, taskId: 'task-c'),
  ],
  bands: const [],
  capacityMinutes: 480,
  scheduledMinutes: 180,
  agendaItems: const [
    AgendaItem(
      id: 'i-a',
      title: 'Done thing',
      category: _deep,
      linkedBlockIds: ['a'],
      state: AgendaItemState.done,
      totalEstimateMinutes: 60,
    ),
    AgendaItem(
      id: 'i-b',
      title: 'Doing thing',
      category: _health,
      linkedBlockIds: ['b'],
      state: AgendaItemState.inProgress,
      progress: 0.5,
      totalEstimateMinutes: 30,
    ),
    AgendaItem(
      id: 'i-c',
      title: 'Late thing',
      category: _deep,
      linkedBlockIds: ['c'],
      taskId: 'task-c',
      state: AgendaItemState.overdue,
      outcome: 'Shipped',
    ),
  ],
);

final List<TimeBlock> _actuals = [
  _block(
    'r1',
    _deep,
    9,
    45,
    state: TimeBlockState.completed,
    type: TimeBlockType.manual,
  ),
];

/// Every token the colour table allows, by RGB: tints are alpha variants of
/// their token, so alpha does not count.
Set<int> _allowedTokens(DsTokens tokens) {
  final c = tokens.colors;
  return {
    for (final color in [
      c.interactive.enabled,
      c.interactive.hover,
      c.interactive.pressed,
      c.aiCard.background,
      c.aiCard.backgroundRaised,
      c.aiCard.border,
      c.aiCard.borderSoft,
      c.aiCard.accent,
      c.aiCard.accentSoft,
      c.alert.success.defaultColor,
      c.alert.success.ink,
      c.alert.error.defaultColor,
      c.alert.error.ink,
      c.alert.warning.defaultColor,
      c.alert.warning.ink,
      c.text.highEmphasis,
      c.text.mediumEmphasis,
      c.text.lowEmphasis,
      c.text.onInteractiveAlert,
      c.decorative.level01,
      c.decorative.level02,
      c.decorative.level03,
      c.background.level01,
      c.background.level02,
      c.background.level03,
      c.surface.enabled,
      c.surface.hover,
      c.surface.focusPressed,
      c.surface.selected,
      c.surface.active,
    ])
      _rgb(color),
  };
}

int _rgb(Color color) => color.toARGB32() & 0x00FFFFFF;

/// The explicit colours under the page, each with where it was found. Text
/// is reported apart: category hues are allowed on fills, never on text.
({List<(Color, String)> fills, List<(Color, String)> text}) _paintedColors(
  WidgetTester tester,
) {
  final fills = <(Color, String)>[];
  final text = <(Color, String)>[];
  void add(List<(Color, String)> into, Color? color, Widget where) {
    if (color == null || color.a == 0) return;
    into.add((color, where.runtimeType.toString()));
  }

  void decoration(Decoration? decoration, Widget where) {
    if (decoration is BoxDecoration) {
      add(fills, decoration.color, where);
      final border = decoration.border;
      if (border is Border) {
        for (final side in [border.top, border.right, border.bottom]) {
          add(fills, side.color, where);
        }
      }
    } else if (decoration is ShapeDecoration) {
      add(fills, decoration.color, where);
    }
  }

  for (final element
      in find
          .descendant(
            of: find.byType(DayPage),
            matching: find.byWidgetPredicate((_) => true),
          )
          .evaluate()) {
    switch (element.widget) {
      case final Icon w:
        add(fills, w.color, w);
      case final ColoredBox w:
        add(fills, w.color, w);
      case final Container w:
        add(fills, w.color, w);
        decoration(w.decoration, w);
      case final DecoratedBox w:
        decoration(w.decoration, w);
      case final Ink w:
        decoration(w.decoration, w);
      case final Material w when w.type != MaterialType.transparency:
        add(fills, w.color, w);
      case final Text w:
        add(text, w.style?.color, w);
      default:
    }
  }
  return (fills: fills, text: text);
}

void main() {
  for (final brightness in Brightness.values) {
    for (final view in PlanView.values) {
      testWidgets('${view.name} in ${brightness.name} paints only the colours '
          'the table allows', (tester) async {
        setTestSurfaceSize(tester, const Size(1280, 1400));
        await tester.pumpWidget(
          wrapDayPage(
            DayPage(draft: _plan()),
            actualBlocks: _actuals,
            theme: brightness == Brightness.dark
                ? DesignSystemTheme.dark()
                : DesignSystemTheme.light(),
            mediaQueryData: const MediaQueryData(size: Size(1280, 1400)),
          ),
        );
        await tester.pump();
        tester
            .widget<PlanViewToggle>(find.byType(PlanViewToggle))
            .onChanged(view);
        await tester.pump();
        await tester.pump();

        final tokens = tester.element(find.byType(DayPage)).designTokens;
        final allowed = _allowedTokens(tokens);
        // A category's hue, and the opaque block fills the timeline mixes
        // from it: the hue at each tint alpha, composited over the canvas.
        final isLight = brightness == Brightness.light;
        final categories = {
          for (final category in [_deep, _health])
            for (final hue in [
              categoryColorFromHex(category.colorHex),
              for (final tracked in [false, true])
                Color.alphaBlend(
                  categoryColorFromHex(category.colorHex).withValues(
                    alpha: timelineBlockTintAlpha(
                      tracked: tracked,
                      isLight: isLight,
                    ),
                  ),
                  tokens.colors.background.level01,
                ),
            ])
              _rgb(hue),
        };
        final painted = _paintedColors(tester);

        // The scan saw the page, not an empty tree.
        expect(painted.fills, isNotEmpty);
        expect(painted.text, isNotEmpty);
        final strayFills = [
          for (final (color, where) in painted.fills)
            if (!allowed.contains(_rgb(color)) &&
                !categories.contains(_rgb(color)))
              '$where ${color.toARGB32().toRadixString(16)}',
        ];
        final strayText = [
          for (final (color, where) in painted.text)
            if (!allowed.contains(_rgb(color)))
              '$where ${color.toARGB32().toRadixString(16)}',
        ];
        expect(strayFills.toSet(), isEmpty, reason: 'fills off the table');
        expect(strayText.toSet(), isEmpty, reason: 'text off the table');
      });
    }
  }
}
