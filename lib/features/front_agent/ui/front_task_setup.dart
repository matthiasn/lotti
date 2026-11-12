import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_date_picker_modal.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_anchor.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_task_draft.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_chips.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Keys of [FrontTaskSetup], by the inbox item's segment index.
abstract final class FrontTaskSetupKeys {
  static Key ask(int index) => ValueKey('front-task-setup-ask-$index');
  static Key status(int index) => ValueKey('front-task-setup-status-$index');
  static Key priority(int index) =>
      ValueKey('front-task-setup-priority-$index');
  static Key due(int index) => ValueKey('front-task-setup-due-$index');
  static Key create(int index) => ValueKey('front-task-setup-create-$index');
  static Key back(int index) => ValueKey('front-task-setup-back-$index');

  /// A row of one of the chips' menus: [name] is the choice it sets.
  static Key option(int index, String name) =>
      ValueKey('front-task-setup-option-$index-$name');
}

/// What an inbox item's card asks once *Make it a task* is tapped: one line
/// in her voice, then the task's status, priority and due day as three
/// chips, each opening a short menu right where it sits — the conversation
/// is never left for a form — and create. The chips and the two buttons
/// share one line where it fits, the buttons at its end; where it does not,
/// the buttons drop below, still at the end ([_Band]).
///
/// Status and priority wear the glyphs the task wears everywhere else, so
/// an urgent task reads urgent before it is made. Enter creates and Escape
/// goes back while the step itself holds focus, which it takes when it
/// opens; once focus moves to a chip or a button, the key is theirs.
///
/// The chips start at what she read from the words ([FrontTaskChoices.of]),
/// so create alone makes the task as she understood it; a chip changed is
/// the user's word over hers. Nothing is written until create
/// (decision 1).
class FrontTaskSetup extends StatefulWidget {
  const FrontTaskSetup({
    required this.index,
    required this.initial,
    required this.onCreate,
    required this.onBack,
    this.heard = false,
    this.endInset = 0,
    this.busy = false,
    this.failed = false,
    super.key,
  });

  /// Whether the words set any of the chips: she says what she heard only
  /// when she heard something, else she just asks.
  final bool heard;

  /// Room kept after *Create task* — the overflow's slot in the row it
  /// replaces, so *Create task* ends where *Make it a task* did.
  final double endInset;

  /// The inbox item's segment index, which keys the controls.
  final int index;

  /// What the chips start at.
  final FrontTaskChoices initial;

  /// Makes the task, set up as chosen.
  final ValueChanged<FrontTaskChoices> onCreate;

  /// Goes back to the card's own actions, nothing made.
  final VoidCallback onBack;

  /// While the task is being made: create spins, and nothing can change.
  final bool busy;

  /// The last create did not go through: the line says so, and create can
  /// be tapped again.
  final bool failed;

  @override
  State<FrontTaskSetup> createState() => _FrontTaskSetupState();
}

class _FrontTaskSetupState extends State<FrontTaskSetup> {
  late FrontTaskChoices _choices = widget.initial;

  /// The step's own focus: Enter and Escape act only while it holds it.
  final _focus = FocusNode(debugLabel: 'front-task-setup');

  @override
  void initState() {
    super.initState();
    // Asked for, not left to autofocus: autofocus yields to whatever already
    // holds focus, and Enter must reach this step, the one just opened.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// Enter creates and Escape leaves while the step itself holds focus.
  /// Once focus is on a chip or button in it the key is theirs: ignored
  /// here, it reaches their own activation.
  KeyEventResult _onKey(KeyEvent event, VoidCallback create) {
    if (widget.busy || event is! KeyDownEvent || !_focus.hasPrimaryFocus) {
      return KeyEventResult.ignored;
    }
    final action = switch (event.logicalKey) {
      LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter => create,
      LogicalKeyboardKey.escape => widget.onBack,
      _ => null,
    };
    if (action == null) return KeyEventResult.ignored;
    action();
    return KeyEventResult.handled;
  }

  void _set(FrontTaskChoices choices) => setState(() => _choices = choices);

  Future<void> _pickDate() async {
    final today = _today();
    final due = _choices.due;
    final horizon = DateTime(today.year + 10);
    // The range holds the day already set — a past one, or one past the
    // horizon — so the picker shows it as it is and Done keeps it, rather
    // than clamping it to a day the user never chose.
    final result = await showDesignSystemDatePicker(
      context: context,
      title: context.messages.taskDueDateLabel,
      initialDate: due ?? today,
      firstDate: due != null && due.isBefore(today) ? due : today,
      lastDate: due != null && due.isAfter(horizon) ? due : horizon,
    );
    final date = result?.date;
    if (date == null || !mounted) return;
    _set(_choices.copyWith(due: () => _day(date)));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final index = widget.index;
    final enabled = !widget.busy;
    final today = _today();
    final tomorrow = _tomorrow();

    DesignSystemContextMenuItem option(
      String name,
      String label, {
      required bool selected,
      required VoidCallback onTap,
      bool startsGroup = false,
    }) => DesignSystemContextMenuItem(
      key: FrontTaskSetupKeys.option(index, name),
      label: label,
      isSelected: selected,
      startsGroup: startsGroup,
      onTap: onTap,
    );

    // A chip that says the value it sets and opens its menu where it is.
    Widget chip({
      required Key key,
      required Widget glyph,
      required String label,
      required String semanticsLabel,
      required List<DesignSystemContextMenuItem> items,
    }) => DesignSystemContextMenuAnchor(
      fitContent: true,
      // The menus open over Cancel and Create: the tap that closes one must
      // not also press them.
      consumeOutsideTap: true,
      items: items,
      builder: (context, {required toggle, required isOpen}) =>
          DesignSystemChip(
            key: key,
            label: label,
            avatar: glyph,
            trailing: Icon(
              isOpen ? LottiIcons.chevronUp : LottiIcons.chevronDown,
              size: IconSizes.xs,
              color: tokens.colors.text.mediumEmphasis,
            ),
            semanticsLabel: semanticsLabel,
            size: DesignSystemChipSize.compactPillTouch,
            outlined: true,
            selected: isOpen,
            onPressed: enabled ? toggle : null,
          ),
    );

    final due = _choices.due;
    // The due day escalates as the task will: today warns, past is late.
    final dueInk = switch (due) {
      null => tokens.colors.text.mediumEmphasis,
      _ when due.isBefore(today) => TaskShowcasePalette.error(context),
      _ when due == today => TaskShowcasePalette.warning(context),
      _ => tokens.colors.text.mediumEmphasis,
    };
    final dueLabel = switch (due) {
      null => messages.taskNoDueDateLabel,
      _ when due == today => messages.taskDueToday,
      _ when due == tomorrow => messages.taskDueTomorrow,
      // The year only when it is not this one, so a day next year never
      // reads as the same day this year.
      _ => messages.taskDueDateWithDate(
        (due.year == today.year ? DateFormat.MMMd : DateFormat.yMMMd)(
          Localizations.localeOf(context).toLanguageTag(),
        ).format(due),
      ),
    };
    final statusLabel = taskLabelFromStatusString(
      _choices.start.dbStatus,
      context,
    );
    final priorityLabel = _choices.priority.localizedLabel(context);

    final chips = Wrap(
      spacing: tokens.spacing.step2,
      runSpacing: tokens.spacing.step2,
      children: [
        chip(
          key: FrontTaskSetupKeys.status(index),
          glyph: _StatusGlyph(_choices.start),
          label: statusLabel,
          semanticsLabel: '${messages.taskStatusLabel} $statusLabel',
          items: [
            for (final start in FrontTaskStart.values)
              option(
                start.name,
                taskLabelFromStatusString(start.dbStatus, context),
                selected: start == _choices.start,
                onTap: () => _set(_choices.copyWith(start: start)),
              ),
          ],
        ),
        chip(
          key: FrontTaskSetupKeys.priority(index),
          glyph: TaskShowcasePriorityGlyph(
            priority: _choices.priority,
          ),
          label: priorityLabel,
          semanticsLabel: messages.taskPriorityTooltip(priorityLabel),
          items: [
            for (final priority in TaskPriority.values)
              option(
                priority.short,
                priority.localizedLabel(context),
                selected: priority == _choices.priority,
                onTap: () => _set(_choices.copyWith(priority: priority)),
              ),
          ],
        ),
        chip(
          key: FrontTaskSetupKeys.due(index),
          glyph: Icon(
            LottiIcons.calendar,
            size: IconSizes.s,
            color: dueInk,
          ),
          label: dueLabel,
          semanticsLabel: dueLabel,
          items: [
            option(
              'today',
              messages.frontTaskSetupToday,
              selected: due == today,
              // The day as of the tap, not of the last build: a setup left
              // open over midnight must not save yesterday.
              onTap: () => _set(_choices.copyWith(due: _today)),
            ),
            option(
              'tomorrow',
              messages.frontTaskSetupTomorrow,
              selected: due == tomorrow,
              onTap: () => _set(_choices.copyWith(due: _tomorrow)),
            ),
            option(
              'pick',
              messages.frontTaskSetupPickDate,
              selected: due != null && due != today && due != tomorrow,
              onTap: _pickDate,
            ),
            option(
              'none',
              messages.taskNoDueDateLabel,
              selected: due == null,
              startsGroup: true,
              onTap: () => _set(_choices.copyWith(due: () => null)),
            ),
          ],
        ),
      ],
    );

    void create() => widget.onCreate(_choices);

    // As tall as the row it replaces, whose overflow sets its height: the
    // gap above the divider stays what it was.
    // A wrap, not a row: where even the two buttons do not fit side by side
    // — a narrow card, large text — Create task goes under Cancel rather than
    // past the band's edge, where a tap would miss it.
    final actions = Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: tokens.spacing.step2,
      runSpacing: tokens.spacing.step1,
      children: [
        DesignSystemButton(
          key: FrontTaskSetupKeys.back(index),
          label: messages.cancelButton,
          variant: DesignSystemButtonVariant.quiet,
          onPressed: enabled ? widget.onBack : null,
        ),
        DesignSystemButton(
          key: FrontTaskSetupKeys.create(index),
          label: widget.failed
              ? messages.frontDoorTryAgain
              : messages.frontTaskSetupCreate,
          isLoading: widget.busy,
          onPressed: enabled ? create : null,
        ),
      ],
    );

    return Focus(
      focusNode: _focus,
      onKeyEvent: (node, event) => _onKey(event, create),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.failed
                ? messages.frontDoorActionFailed
                : widget.heard
                ? messages.frontTaskSetupAsk
                : messages.frontTaskSetupAskPlain,
            key: FrontTaskSetupKeys.ask(index),
            style: tokens.typography.styles.others.caption.copyWith(
              color: widget.failed
                  ? tokens.colors.alert.error.ink
                  : tokens.colors.text.mediumEmphasis,
            ),
          ),
          // No gap: the chips' touch boxes already pad them from the
          // question they answer.
          _Band(
            gap: tokens.spacing.step3,
            runGap: tokens.spacing.step1,
            endInset: widget.endInset,
            children: [
              chips,
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: DesignSystemContextMenuButton.extent(tokens),
                ),
                // As wide as the buttons, centred in the row's height.
                child: Align(widthFactor: 1, heightFactor: 1, child: actions),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static DateTime _today() => _day(clock.now());

  // The next calendar day, not 24 hours on: across a clock change those
  // land on different days.
  static DateTime _tomorrow() {
    final today = _today();
    return DateTime(today.year, today.month, today.day + 1);
  }

  static DateTime _day(DateTime at) => DateTime(at.year, at.month, at.day);
}

/// The task's own status glyph for [start], at the chip's glyph size.
class _StatusGlyph extends StatelessWidget {
  const _StatusGlyph(this.start);

  final FrontTaskStart start;

  @override
  Widget build(BuildContext context) => TaskShowcaseStatusGlyph(
    status: taskStatusFromString(start.dbStatus),
  );
}

/// Lays its two children — the chips, then the buttons — on one line when
/// they fit, the buttons at the end and both centred on it; otherwise the
/// buttons go [runGap] below the chips, still at the end. The buttons keep
/// [endInset] clear after them, unless that alone would break the one line.
class _Band extends MultiChildRenderObjectWidget {
  const _Band({
    required this.gap,
    required this.runGap,
    required this.endInset,
    required super.children,
  }) : assert(children.length == 2, 'The chips, then the buttons.');

  final double gap;
  final double runGap;
  final double endInset;

  @override
  _RenderBand createRenderObject(BuildContext context) => _RenderBand(
    gap: gap,
    runGap: runGap,
    endInset: endInset,
    textDirection: Directionality.of(context),
  );

  @override
  void updateRenderObject(BuildContext context, _RenderBand renderObject) {
    renderObject
      ..gap = gap
      ..runGap = runGap
      ..endInset = endInset
      ..textDirection = Directionality.of(context);
  }
}

class _BandParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderBand extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _BandParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _BandParentData> {
  _RenderBand({
    required this._gap,
    required this._runGap,
    required this._endInset,
    required this._textDirection,
  });

  double _gap;
  double get gap => _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  double _runGap;
  double get runGap => _runGap;
  set runGap(double value) {
    if (value == _runGap) return;
    _runGap = value;
    markNeedsLayout();
  }

  double _endInset;
  double get endInset => _endInset;
  set endInset(double value) {
    if (value == _endInset) return;
    _endInset = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _BandParentData) {
      child.parentData = _BandParentData();
    }
  }

  /// Where each child goes for [lead] and [trail] sizes, and the band's own
  /// size, within [constraints].
  ({Offset lead, Offset trail, Size size}) _place(
    BoxConstraints constraints,
    Size lead,
    Size trail,
  ) {
    final line = lead.width + _gap + trail.width;
    final oneLine = line <= constraints.maxWidth;
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : line + _endInset;
    // The inset is kept where it fits: on a shared line only if the line
    // still fits with it; on a stacked one only as much as the buttons
    // leave, so they never reach past the band's start, where a tap would
    // miss them.
    final inset = oneLine
        ? (line + _endInset <= constraints.maxWidth ? _endInset : 0.0)
        : math.max(0, math.min(_endInset, width - trail.width)).toDouble();
    final Offset leadAt;
    final Offset trailAt;
    final double height;
    if (oneLine) {
      height = math.max(lead.height, trail.height);
      leadAt = Offset(0, (height - lead.height) / 2);
      trailAt = Offset(
        width - inset - trail.width,
        (height - trail.height) / 2,
      );
    } else {
      height = lead.height + _runGap + trail.height;
      leadAt = Offset.zero;
      trailAt = Offset(width - inset - trail.width, lead.height + _runGap);
    }
    Offset mirror(Offset at, Size child) => _textDirection == TextDirection.rtl
        ? Offset(width - at.dx - child.width, at.dy)
        : at;
    return (
      lead: mirror(leadAt, lead),
      trail: mirror(trailAt, trail),
      size: constraints.constrain(Size(width, height)),
    );
  }

  // Intrinsics follow the same rule as layout: the widest is one line with
  // the room after it, the narrowest stacks the two; the height is what a
  // given width lays out to.
  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    firstChild!.getMinIntrinsicWidth(height),
    lastChild!.getMinIntrinsicWidth(height) + _endInset,
  );

  @override
  double computeMaxIntrinsicWidth(double height) =>
      getDryLayout(const BoxConstraints()).width;

  @override
  double computeMinIntrinsicHeight(double width) =>
      getDryLayout(BoxConstraints(maxWidth: width)).height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final loose = constraints.loosen();
    return _place(
      constraints,
      firstChild!.getDryLayout(loose),
      lastChild!.getDryLayout(loose),
    ).size;
  }

  @override
  void performLayout() {
    final lead = firstChild!;
    final trail = lastChild!;
    final loose = constraints.loosen();
    lead.layout(loose, parentUsesSize: true);
    trail.layout(loose, parentUsesSize: true);
    final placed = _place(constraints, lead.size, trail.size);
    (lead.parentData! as _BandParentData).offset = placed.lead;
    (trail.parentData! as _BandParentData).offset = placed.trail;
    size = placed.size;
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
