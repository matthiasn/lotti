part of 'desktop_task_header.dart';

class _TitleReadOnly extends StatelessWidget {
  const _TitleReadOnly({
    required this.title,
    required this.style,
    required this.onTap,
  });

  final String title;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isEmpty = title.trim().isEmpty;
    final displayText = isEmpty ? context.messages.taskTitleEmpty : title;
    final effectiveStyle = isEmpty
        ? style.copyWith(
            color: TaskShowcasePalette.mediumText(context),
            fontStyle: FontStyle.italic,
          )
        : style;
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  displayText,
                  softWrap: true,
                  style: effectiveStyle,
                ),
              ),
              SizedBox(width: tokens.spacing.step2),
              Padding(
                padding: EdgeInsets.only(top: tokens.spacing.step1),
                child: Icon(
                  Icons.edit_outlined,
                  size: 14,
                  color: TaskShowcasePalette.lowText(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitleEditor extends StatelessWidget {
  const _TitleEditor({
    required this.controller,
    required this.focusNode,
    required this.style,
    required this.onCommit,
    required this.onCancel,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle style;
  final VoidCallback onCommit;
  final VoidCallback onCancel;

  static const _capsuleRadius = 8.0;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: tokens.colors.surface.hover,
        borderRadius: BorderRadius.circular(_capsuleRadius),
        border: Border.all(color: tokens.colors.interactive.enabled),
      ),
      child: Row(
        children: [
          Expanded(
            child: Shortcuts(
              shortcuts: const <ShortcutActivator, Intent>{
                SingleActivator(LogicalKeyboardKey.escape): _CancelIntent(),
                SingleActivator(
                  LogicalKeyboardKey.enter,
                  meta: true,
                ): _CommitIntent(),
                SingleActivator(
                  LogicalKeyboardKey.enter,
                  control: true,
                ): _CommitIntent(),
                SingleActivator(
                  LogicalKeyboardKey.keyS,
                  meta: true,
                ): _CommitIntent(),
                SingleActivator(
                  LogicalKeyboardKey.keyS,
                  control: true,
                ): _CommitIntent(),
              },
              child: Actions(
                actions: <Type, Action<Intent>>{
                  _CommitIntent: CallbackAction<_CommitIntent>(
                    onInvoke: (_) {
                      onCommit();
                      return null;
                    },
                  ),
                  _CancelIntent: CallbackAction<_CancelIntent>(
                    onInvoke: (_) {
                      onCancel();
                      return null;
                    },
                  ),
                },
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: style,
                  cursorColor: tokens.colors.interactive.enabled,
                  minLines: 1,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
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
                ),
              ),
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
          _IconAction(
            icon: Icons.check_rounded,
            color: tokens.colors.alert.success.defaultColor,
            semanticLabel: MaterialLocalizations.of(context).okButtonLabel,
            onTap: onCommit,
          ),
          SizedBox(width: tokens.spacing.step2),
          _IconAction(
            icon: Icons.close_rounded,
            color: TaskShowcasePalette.mediumText(context),
            semanticLabel: MaterialLocalizations.of(context).cancelButtonLabel,
            onTap: onCancel,
          ),
        ],
      ),
    );
  }
}

class _CommitIntent extends Intent {
  const _CommitIntent();
}

class _CancelIntent extends Intent {
  const _CancelIntent();
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
    return InkResponse(
      onTap: onTap,
      radius: 16,
      child: SizedBox.square(
        dimension: 24,
        child: Icon(icon, size: 20, color: color, semanticLabel: semanticLabel),
      ),
    );
  }
}
