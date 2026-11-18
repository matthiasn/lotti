import 'package:flutter/rendering.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_speech_bubble.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// How far the user is through the three things onboarding asks for: the
/// key, the areas and the first task.
@immutable
class OnboardingProgress {
  const OnboardingProgress({required this.done, this.current = 0})
    : assert(done >= 0 && done <= total, 'done counts the three things'),
      assert(current >= 0 && current <= 1, 'current is a fraction');

  /// The number of things onboarding asks for.
  static const total = 3;

  /// How many of them are finished.
  final int done;

  /// How far the one in progress is, from 0 to 1.
  final double current;

  /// The thing being worked on, counted from one; the last once all are
  /// done.
  int get step => done < total ? done + 1 : total;

  @override
  bool operator ==(Object other) =>
      other is OnboardingProgress &&
      other.done == done &&
      other.current == current;

  @override
  int get hashCode => Object.hash(done, current);
}

/// A labelled action on the stage: the link above the main button, or the
/// main button itself.
@immutable
class OnboardingStageAction {
  const OnboardingStageAction({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;

  /// Null disables the action.
  final VoidCallback? onPressed;

  /// Leads the label on the main button; the link takes none.
  final IconData? icon;
}

/// The least height every [OnboardingStage] below takes — the room the host
/// gives the panel — so that each step is as tall as the one before it and
/// the tray, not the panel, takes up what a step has less of.
class OnboardingStageHeight extends InheritedWidget {
  const OnboardingStageHeight({
    required this.minHeight,
    required super.child,
    super.key,
  });

  final double minHeight;

  /// The height set above [context], or zero where none is.
  static double of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<OnboardingStageHeight>()
          ?.minHeight ??
      0;

  @override
  bool updateShouldNotify(OnboardingStageHeight oldWidget) =>
      oldWidget.minHeight != minHeight;
}

/// The one layout every onboarding step is built on, so that nothing moves
/// between steps but what the step is about.
///
/// From the top: a bar with the way back, the progress through the three
/// things and the close button; the [companion] standing at one size; her
/// speech bubble, one fixed height, with the step's [title] and [text]; and a
/// tray holding the step's own [child] under a [caption], with a [helper]
/// line under it, then a foot: the [secondary] link, when there is one, and
/// the [primary] button.
///
/// The stage keeps the frame, not the steps: the bar's two buttons, the
/// bubble's height and the main button's place are the same on every step,
/// a step can only disable what it cannot offer just then. The tray takes exactly
/// what an [OnboardingStageHeight] set by the host leaves, and only its
/// content scrolls, under a fade where it runs into the foot.
///
/// System back and Escape do what the bar does: on a step that shows the
/// back arrow they go back with it — or nothing, while it is disabled —
/// instead of closing the whole flow; on a step without one, the first,
/// they close it as before.
///
/// Without a [companion] — the demo's AI setup, which borrows two of the
/// steps — the [title] and [text] are a plain header.
class OnboardingStage extends StatelessWidget {
  const OnboardingStage({
    required this.title,
    required this.child,
    this.text,
    this.companion,
    this.progress,
    this.onBack,
    this.showBack,
    this.onClose,
    this.showClose,
    this.caption,
    this.helper,
    this.secondary,
    this.primary,
    this.primaryLoading = false,
    this.centered = false,
    super.key,
  });

  /// The step's headline: the first line of her bubble.
  final String title;

  /// What she adds to it, if anything.
  final String? text;

  /// The companion, standing above her bubble. Null leaves her out.
  final Widget? companion;

  /// Shown in the bar; null hides it.
  final OnboardingProgress? progress;

  /// The way back to the previous step.
  final VoidCallback? onBack;

  /// Whether the bar shows the back arrow — disabled while [onBack] is
  /// null. Defaults to whether there is an [onBack], so the first step and
  /// a borrowed one show none; a step past the first passes true, so the
  /// arrow is where it always is even when it cannot be used.
  final bool? showBack;

  /// Leaves the flow: the close button at the end of the bar.
  final VoidCallback? onClose;

  /// Whether the bar shows the close button — disabled while [onClose] is
  /// null, as while a step is being saved. Defaults to whether there is an
  /// [onClose], so a host with no flow to leave shows none.
  final bool? showClose;

  /// A short label over [child], naming what the tray holds.
  final String? caption;

  /// What the step is about: a list, a field, the recorder.
  final Widget child;

  /// A line under [child], saying something about it.
  final Widget? helper;

  /// A quieter action above the main button.
  final OnboardingStageAction? secondary;

  /// The step's main button.
  final OnboardingStageAction? primary;

  /// Shows the main button as busy.
  final bool primaryLoading;

  /// Puts [child] in the middle of the room the tray has over its foot:
  /// for the recorder alone, which is the one thing on its frame and moves
  /// with the voice. Everything else starts at the top, at the same height
  /// on every step. Only where the host sets the stage's height.
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final textHigh = tokens.colors.text.highEmphasis;
    final textMedium = tokens.colors.text.mediumEmphasis;
    final material = MaterialLocalizations.of(context);
    final stageHeight = OnboardingStageHeight.of(context);
    final bounded = stageHeight > 0;

    Widget barButton({
      required IconData icon,
      required String label,
      required VoidCallback? onPressed,
    }) => Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: IconButton(
          tooltip: label,
          onPressed: onPressed,
          iconSize: spacing.step5,
          color: textHigh,
          disabledColor: tokens.colors.text.lowEmphasis,
          icon: Icon(icon),
        ),
      ),
    );

    final bar = SizedBox(
      height: spacing.step9,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (progress case final progress?)
            OnboardingProgressBar(progress: progress),
          if (showBack ?? onBack != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: barButton(
                icon: LottiIcons.back,
                label: material.backButtonTooltip,
                onPressed: onBack,
              ),
            ),
          if (showClose ?? onClose != null)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: barButton(
                icon: LottiIcons.close,
                label: material.closeButtonTooltip,
                onPressed: onClose,
              ),
            ),
        ],
      ),
    );

    // The foot: the link, when the step has one, a size below the main
    // button so it never rivals it, then the main button — pinned at the
    // tray's foot, so it is at one height whether there is a link or not,
    // and a step without one gives the row's room to its content.
    final link = secondary;
    final linkRow = link == null
        ? null
        : Padding(
            padding: EdgeInsets.only(bottom: spacing.step2),
            child: Center(
              child: DesignSystemButton(
                label: link.label,
                onPressed: link.onPressed,
                variant: DesignSystemButtonVariant.tertiary,
                size: DesignSystemButtonSize.medium,
              ),
            ),
          );
    final foot = Padding(
      padding: EdgeInsets.only(top: spacing.step4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ?linkRow,
          if (primary case final primary?)
            DesignSystemButton(
              label: primary.label,
              onPressed: primary.onPressed,
              leadingIcon: primary.icon,
              isLoading: primaryLoading,
              size: DesignSystemButtonSize.large,
              fullWidth: true,
            ),
        ],
      ),
    );

    final helperLine = helper == null
        ? null
        : Padding(
            padding: EdgeInsets.only(top: spacing.step4),
            child: DefaultTextStyle.merge(
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: textMedium,
              ),
              child: helper!,
            ),
          );

    // What the step is about: its caption, then the content and the line
    // that qualifies it. Centred, the content sits midway between the
    // caption (or the tray's top) and the foot.
    final content = centered && bounded
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (caption case final caption?)
                OnboardingTrayCaption(caption)
              else
                const SizedBox.shrink(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [child, ?helperLine],
              ),
              const SizedBox.shrink(),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (caption case final caption?)
                Padding(
                  padding: EdgeInsets.only(bottom: spacing.step4),
                  child: OnboardingTrayCaption(caption),
                ),
              child,
              ?helperLine,
            ],
          );

    final trayColor = tokens.colors.background.level02;
    final tray = DecoratedBox(
      decoration: BoxDecoration(
        color: trayColor,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(tokens.radii.xl),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          spacing.step5,
          spacing.step5,
          spacing.step5,
          // Clears the home indicator where the panel is a sheet flush with
          // the bottom of the screen.
          spacing.step5 + MediaQuery.paddingOf(context).bottom,
        ),
        child: bounded
            // The host gives the stage its height: the foot is pinned and
            // only what is over it scrolls, so a list that opens never
            // pushes the main button away.
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _FadeAtFoot(
                      color: trayColor,
                      extent: spacing.step5,
                      // At least the room over the foot, so centred
                      // content has it to sit in the middle of.
                      child: LayoutBuilder(
                        builder: (context, room) => SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: room.maxHeight,
                            ),
                            child: content,
                          ),
                        ),
                      ),
                    ),
                  ),
                  foot,
                ],
              )
            // No height from the host: the tray is its content's height
            // or its least, whichever is more, and what is left over goes
            // between the content and the foot.
            : ConstrainedBox(
                constraints: BoxConstraints(minHeight: trayMinHeight(tokens)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [content, foot],
                ),
              ),
      ),
    );

    final wide = MediaQuery.sizeOf(context).width >= wideFrom;
    final stage = ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radii.l),
      child: ColoredBox(
        color: tokens.colors.background.level01,
        child: _StageColumn(
          minHeight: stageHeight,
          // On a window too short for both, the tray keeps the room its
          // foot and a sliver of content need, and the stage grows past the
          // host's height so the host scrolls it, rather than squeezing the
          // main button out of reach.
          trayLeast:
              trayMinHeight(tokens) / 2 +
              2 * spacing.step5 +
              MediaQuery.paddingOf(context).bottom,
          top: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Flush with the panel's sides: the glyphs of the way back and
              // the close button then sit on the gutter everything below
              // keeps.
              bar,
              if (companion case final companion?) ...[
                // Decorative: her bubble carries the words.
                ExcludeSemantics(
                  child: SizedBox(
                    height: companionHeight(tokens, stageHeight: stageHeight),
                    child: companion,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    left: spacing.step5,
                    right: spacing.step5,
                    bottom: spacing.step5,
                  ),
                  child: OnboardingSpeechBubble(
                    title: title,
                    text: text,
                    minHeight: bubbleHeight(
                      tokens,
                      MediaQuery.textScalerOf(context),
                      lines: wide ? 2 : 3,
                    ),
                  ),
                ),
              ] else
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    spacing.step5,
                    spacing.step3,
                    spacing.step5,
                    spacing.step5,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: tokens.typography.styles.heading.heading3
                            .copyWith(color: textHigh),
                      ),
                      if (text case final text?)
                        Padding(
                          padding: EdgeInsets.only(top: spacing.step2),
                          child: Text(
                            text,
                            style: tokens.typography.styles.body.bodySmall
                                .copyWith(color: textMedium),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          tray: tray,
        ),
      ),
    );

    // A step leaving the screen in a crossfade has its tickers off; only the
    // one arriving answers back, so one press never goes back twice.
    final current = TickerMode.valuesOf(context).enabled;
    if (!(showBack ?? onBack != null) || !current) return stage;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBack?.call();
      },
      child: stage,
    );
  }

  /// The screen width from which the stage is a dialog in a window, whose
  /// wider bubble needs a line less.
  static const double wideFrom = 600;

  /// The height she stands in, the same on every step of one screen: full
  /// size only on a tall one, a size down on most phones, and small on a
  /// short screen or window — the tray, where the step's own content is,
  /// needs the room more than she does.
  static double companionHeight(
    DsTokens tokens, {
    required double stageHeight,
  }) {
    final spacing = tokens.spacing;
    if (stageHeight <= 0) return spacing.step13 + spacing.step9;
    if (stageHeight < compactBelow(tokens)) return spacing.step12;
    if (stageHeight < fullFrom(tokens)) return spacing.step13;
    return spacing.step13 + spacing.step9;
  }

  /// The stage height under which she stands small.
  static double compactBelow(DsTokens tokens) =>
      tokens.spacing.step13 * 4 + tokens.spacing.step10;

  /// The stage height from which she stands full size.
  static double fullFrom(DsTokens tokens) =>
      tokens.spacing.step13 * 5 + tokens.spacing.step11;

  /// The height of her bubble: a headline over [lines] lines, measured from
  /// the very styles and text scale it is drawn in. Every step's words are
  /// written to fit it — three lines on a phone, two in the wider dialog —
  /// so the tray starts at the same height on each; longer words, or larger
  /// text, grow it.
  static double bubbleHeight(
    DsTokens tokens,
    TextScaler textScaler, {
    int lines = 3,
  }) {
    double lineOf(TextStyle style) => _lineHeight(style, textScaler);

    final styles = tokens.typography.styles;
    return 2 * tokens.spacing.step4 +
        OnboardingSpeechBubble.outlineWidth * 2 +
        lineOf(styles.heading.heading3) +
        tokens.spacing.step2 +
        lines * lineOf(OnboardingSpeechBubble.bodyStyle(tokens));
  }

  static double _lineHeight(TextStyle style, TextScaler textScaler) {
    final painter = TextPainter(
      text: TextSpan(text: ' ', style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    final height = painter.preferredLineHeight;
    painter.dispose();
    return height;
  }

  /// The least the tray's inside takes, so the main button is as low on a
  /// step with little in it as on one with much.
  static double trayMinHeight(DsTokens tokens) =>
      tokens.spacing.step13 + tokens.spacing.step12;
}

/// Fades [child] into the tray's [color] over its last [extent], so content
/// running on under the foot reads as "more below", not as cut off.
class _FadeAtFoot extends StatelessWidget {
  const _FadeAtFoot({
    required this.color,
    required this.extent,
    required this.child,
  });

  final Color color;
  final double extent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: extent,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color.withValues(alpha: 0), color],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A short label over a group in the tray, naming what it holds.
class OnboardingTrayCaption extends StatelessWidget {
  const OnboardingTrayCaption(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // A size below the labels of what it names, so it reads as their
    // heading and not as one more of them.
    return Text(
      text,
      style: tokens.typography.styles.others.caption.copyWith(
        color: tokens.colors.text.mediumEmphasis,
      ),
    );
  }
}

/// Three segments, one per thing onboarding asks for: filled when done, part
/// filled while in progress.
class OnboardingProgressBar extends StatelessWidget {
  const OnboardingProgressBar({required this.progress, super.key});

  final OnboardingProgress progress;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final radius = BorderRadius.circular(tokens.radii.xs);
    return Semantics(
      label: context.messages.onboardingStageProgress(
        progress.step,
        OnboardingProgress.total,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < OnboardingProgress.total; i++)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.step1),
              child: ClipRRect(
                borderRadius: radius,
                child: SizedBox(
                  width: spacing.step8,
                  height: spacing.step2,
                  child: ColoredBox(
                    color: tokens.colors.decorative.level02,
                    child: FractionallySizedBox(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: i < progress.done
                          ? 1
                          : i == progress.done
                          ? progress.current
                          : 0,
                      // Neutral, not the accent: the accent is the main
                      // button's.
                      child: ColoredBox(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The two parts [_StageColumn] lays out.
enum _StageSlot { top, tray }

/// [top] at its own height over [tray]. With a [minHeight] the tray is given
/// exactly what the top leaves of it, so the stage is that tall; without
/// one, the tray takes its own height.
///
/// A column cannot do this: under a scroll view its height is unbounded, so
/// nothing in it can be told to fill the rest.
class _StageColumn
    extends SlottedMultiChildRenderObjectWidget<_StageSlot, RenderBox> {
  const _StageColumn({
    required this.minHeight,
    required this.trayLeast,
    required this.top,
    required this.tray,
  });

  final double minHeight;

  /// The least the tray is given however little [minHeight] leaves it.
  final double trayLeast;
  final Widget top;
  final Widget tray;

  @override
  Iterable<_StageSlot> get slots => _StageSlot.values;

  @override
  Widget childForSlot(_StageSlot slot) => switch (slot) {
    _StageSlot.top => top,
    _StageSlot.tray => tray,
  };

  @override
  RenderStageColumn createRenderObject(BuildContext context) =>
      RenderStageColumn(minHeight: minHeight, trayLeast: trayLeast);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderStageColumn renderObject,
  ) => renderObject
    ..minHeight = minHeight
    ..trayLeast = trayLeast;
}

/// Lays [_StageColumn] out.
@visibleForTesting
class RenderStageColumn extends RenderBox
    with SlottedContainerRenderObjectMixin<_StageSlot, RenderBox> {
  RenderStageColumn({required this._minHeight, this._trayLeast = 0});

  double _minHeight;
  double get minHeight => _minHeight;
  set minHeight(double value) {
    if (value == _minHeight) return;
    _minHeight = value;
    markNeedsLayout();
  }

  /// The least the tray is given, however little [minHeight] leaves it.
  double _trayLeast;
  double get trayLeast => _trayLeast;
  set trayLeast(double value) {
    if (value == _trayLeast) return;
    _trayLeast = value;
    markNeedsLayout();
  }

  double _trayHeight(double topHeight) {
    final left = minHeight - topHeight;
    return left > trayLeast ? left : trayLeast;
  }

  RenderBox get _top => childForSlot(_StageSlot.top)!;
  RenderBox get _tray => childForSlot(_StageSlot.tray)!;

  bool get _bounded => minHeight > 0;

  /// The size for [constraints], with each part measured by [layoutChild]:
  /// the top at its own height, the tray at exactly what the top leaves of
  /// [minHeight], or at its own height where there is none.
  Size _sizeFor(
    BoxConstraints constraints,
    Size Function(RenderBox child, BoxConstraints constraints) layoutChild,
  ) {
    final width = constraints.maxWidth;
    final top = layoutChild(_top, BoxConstraints.tightFor(width: width));
    final trayConstraints = _bounded
        ? BoxConstraints.tightFor(width: width, height: _trayHeight(top.height))
        : BoxConstraints.tightFor(width: width);
    final tray = layoutChild(_tray, trayConstraints);
    return constraints.constrain(Size(width, top.height + tray.height));
  }

  @override
  void performLayout() {
    size = _sizeFor(constraints, ChildLayoutHelper.layoutChild);
    (_tray.parentData! as BoxParentData).offset = Offset(
      0,
      _top.size.height,
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    // A bounded tray scrolls, and a scroll view has no dry size: its height
    // is the one it is given.
    if (!_bounded) {
      return _sizeFor(constraints, ChildLayoutHelper.dryLayoutChild);
    }
    final width = constraints.maxWidth;
    final top = _top.getDryLayout(BoxConstraints.tightFor(width: width));
    return constraints.constrain(
      Size(width, top.height + _trayHeight(top.height)),
    );
  }

  // A bounded tray scrolls, and a scroll view reports no intrinsic size:
  // the top alone says how wide the stage wants to be then.
  @override
  double computeMinIntrinsicWidth(double height) => [
    _top.getMinIntrinsicWidth(double.infinity),
    if (!_bounded) _tray.getMinIntrinsicWidth(double.infinity),
  ].reduce((a, b) => a > b ? a : b);

  @override
  double computeMaxIntrinsicWidth(double height) => [
    _top.getMaxIntrinsicWidth(double.infinity),
    if (!_bounded) _tray.getMaxIntrinsicWidth(double.infinity),
  ].reduce((a, b) => a > b ? a : b);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _intrinsicHeight(width, (child) => child.getMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _intrinsicHeight(width, (child) => child.getMaxIntrinsicHeight(width));

  double _intrinsicHeight(
    double width,
    double Function(RenderBox child) heightOf,
  ) {
    final top = heightOf(_top);
    if (_bounded) return top + _trayHeight(top);
    return top + heightOf(_tray);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in children) {
      context.paintChild(
        child,
        offset + (child.parentData! as BoxParentData).offset,
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in [_tray, _top]) {
      final childOffset = (child.parentData! as BoxParentData).offset;
      final hit = result.addWithPaintOffset(
        offset: childOffset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }
}
