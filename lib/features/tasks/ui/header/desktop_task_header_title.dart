import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_scope.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The blank-title prompt's style, shared by the read-only placeholder and the
/// editor's hint.
///
/// It lives here rather than at each call site because the two *must* match:
/// a blank task auto-opens the editor, so the hint is the state the user
/// actually sees first, and a weight override applied to only one of them is
/// an override that never ships. Lighter as well as paler — at the title's own
/// weight readers took the prompt for the task's actual name.
TextStyle blankTitleStyle(TextStyle base, DsTokens tokens) => base.copyWith(
  color: tokens.colors.text.lowEmphasis,
  fontWeight: FontWeight.w400,
);

/// Padding shared by [TitleReadOnly]'s blank-title box and [TitleEditor], so
/// focusing changes the border colour and nothing else — no text jumps under
/// the caret.
EdgeInsets titleFieldPadding(DsTokens tokens) => EdgeInsets.symmetric(
  horizontal: tokens.spacing.step4,
  vertical: tokens.spacing.step3,
);

/// Static task title presented as a click-to-edit region: the whole title is
/// the edit target and fires [onTap] to open the editor. There is deliberately
/// no trailing pencil glyph — a persistent pencil drifted into a dead gutter
/// beside short or wrapping titles, so the affordance is carried instead by the
/// hover click-cursor, an "Edit title" Semantics button, and keyboard
/// activation.
///
/// A blank title renders as a **prompt inside real field chrome** — a hairline
/// box on the hover surface carrying an imperative placeholder ("Name this
/// task") in low-emphasis, non-italic type. It used to render the same
/// "No title" report the task list shows, in italic, with no box: the largest
/// mark on a new task's page announced an absence and offered nothing, and
/// every reviewer on the empty-state panel named it as the reason the page
/// read as broken rather than new. A titled task keeps the bare text — chrome
/// around content the user already owns would be noise.
class TitleReadOnly extends StatelessWidget {
  const TitleReadOnly({
    required this.title,
    required this.style,
    required this.onTap,
    super.key,
  });

  final String title;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isEmpty = title.trim().isEmpty;
    final displayText = isEmpty ? context.messages.taskTitlePrompt : title;
    final effectiveStyle = isEmpty ? blankTitleStyle(style, tokens) : style;
    Widget label = Text(
      displayText,
      softWrap: true,
      style: effectiveStyle,
    );
    if (isEmpty) {
      // The same box the editor wears, minus its accent border — so opening
      // the editor is a change of state, not a change of shape, and nothing
      // shifts under the tap.
      label = Container(
        padding: titleFieldPadding(tokens),
        decoration: BoxDecoration(
          // `surface.enabled`, not `surface.hover`: at hover strength the
          // page's one empty region was also its heaviest block, a grey slab
          // under the breadcrumb. Enabled reads as a field without shouting.
          color: tokens.colors.surface.enabled,
          borderRadius: BorderRadius.circular(tokens.radii.s),
          border: Border.all(color: tokens.colors.decorative.level01),
        ),
        child: label,
      );
    }
    return Semantics(
      label: context.messages.taskEditTitleLabel,
      button: true,
      container: true,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onTap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: label,
        ),
      ),
    );
  }
}

/// Inline title editor with commit/cancel icon buttons. The shared save and
/// cancel commands provide Primary+S and Escape.
///
/// **Enter commits, everywhere.** Type a name, press Return — the single most
/// common action on this screen — used to insert a line break into the task's
/// name and leave the editor open with no feedback. A hardware keyboard takes
/// its newline on **Shift+Enter** instead, so a wrapping multi-line title is
/// still reachable where there is a modifier to press; Primary+Enter and
/// Primary+S remain as commit aliases.
///
/// The confirm / cancel pair stays hidden until the field differs from the
/// title it is editing. On a freshly created task the editor opens by itself,
/// and two enabled-looking glyphs on an untouched empty field are two controls
/// that do nothing — one of them an ✕ that reviewers read as "delete the task
/// I just made".
class TitleEditor extends StatelessWidget {
  const TitleEditor({
    required this.controller,
    required this.focusNode,
    required this.style,
    required this.onCommit,
    required this.onCancel,
    this.originalTitle = '',
    super.key,
  });

  /// The title the editor opened on. The confirm/cancel pair appears once the
  /// field differs from it.
  final String originalTitle;

  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle style;
  final VoidCallback onCommit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // A hardware keyboard still needs a way to type a line break in a long
    // title, so desktop keeps `maxLines: null` and takes its newline on
    // Shift+Enter. Touch platforms have no modifier to offer, so there Enter
    // is simply commit.
    final isTouch = switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.android => true,
      _ => false,
    };
    return AppCommandScope(
      handlers: {
        AppCommandId.save: AppCommandHandler(invoke: (_) => onCommit()),
        AppCommandId.cancel: AppCommandHandler(invoke: (_) => onCancel()),
      },
      child: Container(
        padding: titleFieldPadding(tokens),
        decoration: BoxDecoration(
          color: tokens.colors.surface.enabled,
          borderRadius: BorderRadius.circular(tokens.radii.s),
          border: Border.all(color: tokens.colors.interactive.enabled),
        ),
        child: Row(
          children: [
            Expanded(
              child: Shortcuts(
                shortcuts: const <ShortcutActivator, Intent>{
                  // Bare Enter commits. Typing a name and pressing Return is
                  // the single most common action on this screen, and it used
                  // to bury a line break in the title and leave the editor
                  // open with no feedback — the one thing on the page that was
                  // outright wrong rather than merely unpolished.
                  SingleActivator(LogicalKeyboardKey.enter): _CommitIntent(),
                  // Kept as aliases: they were the documented commit gesture,
                  // and the command palette advertises Primary+S alongside.
                  SingleActivator(
                    LogicalKeyboardKey.enter,
                    meta: true,
                  ): _CommitIntent(),
                  SingleActivator(
                    LogicalKeyboardKey.enter,
                    control: true,
                  ): _CommitIntent(),
                  // Shift+Enter is the newline, and only on a keyboard that
                  // has a Shift to press.
                  SingleActivator(
                    LogicalKeyboardKey.enter,
                    shift: true,
                  ): _NewlineIntent(),
                },
                child: Actions(
                  actions: <Type, Action<Intent>>{
                    _CommitIntent: CallbackAction<_CommitIntent>(
                      onInvoke: (_) {
                        onCommit();
                        return null;
                      },
                    ),
                    // Returning null from the action lets the intent fall
                    // through to the framework's own newline handling.
                    _NewlineIntent: DoNothingAction(consumesKey: false),
                  },
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    style: style,
                    cursorColor: tokens.colors.interactive.enabled,
                    minLines: 1,
                    maxLines: null,
                    keyboardType: isTouch
                        ? TextInputType.text
                        : TextInputType.multiline,
                    textInputAction: isTouch
                        ? TextInputAction.done
                        : TextInputAction.newline,
                    onSubmitted: (_) => onCommit(),
                    decoration: InputDecoration(
                      // The same imperative the unfocused blank title shows,
                      // so opening the editor never blanks the instruction
                      // out from under the user.
                      hintText: context.messages.taskTitlePrompt,
                      hintStyle: blankTitleStyle(style, tokens),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      isDense: true,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    // A blank task auto-opens this editor, so the cancel
                    // action must not be the only way out of an empty field.
                    onTapOutside: (_) => focusNode.unfocus(),
                  ),
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                if (value.text == originalTitle) {
                  return const SizedBox.shrink();
                }
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: tokens.spacing.step3),
                    _IconAction(
                      icon: Icons.check_rounded,
                      // The interactive accent, not `alert.success` — that
                      // hue is the app's own *Done* task status, and spending
                      // it on "save this text" put two unrelated greens
                      // inside one 40pt box.
                      color: tokens.colors.interactive.enabled,
                      semanticLabel: MaterialLocalizations.of(
                        context,
                      ).okButtonLabel,
                      onTap: onCommit,
                    ),
                    SizedBox(width: tokens.spacing.step2),
                    _IconAction(
                      icon: Icons.close_rounded,
                      color: TaskShowcasePalette.mediumText(context),
                      semanticLabel: MaterialLocalizations.of(
                        context,
                      ).cancelButtonLabel,
                      onTap: onCancel,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CommitIntent extends Intent {
  const _CommitIntent();
}

class _NewlineIntent extends Intent {
  const _NewlineIntent();
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.color,
    required this.onTap,
    this.semanticLabel,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: tokens.spacing.step6,
        // step9 (48) — the standard hit target. A 24pt square is under every
        // touch minimum, and these two are the controls users hesitate over
        // most: a mis-hit ✕ is the one that feels destructive.
        child: SizedBox.square(
          dimension: tokens.spacing.step9,
          child: Icon(icon, size: tokens.spacing.step5, color: color),
        ),
      ),
    );
  }
}
