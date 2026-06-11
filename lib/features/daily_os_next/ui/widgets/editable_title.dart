import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Click-to-edit title for standalone (no-task) agenda items and day
/// blocks (`prototype/shared.jsx → EditableTitle`, handoff v2 item 3).
///
/// Display mode shows the title with a pencil revealed on hover only
/// (the whole title is the tap target; Semantics announces editability,
/// so touch users lose nothing). Tapping swaps in a text field:
/// **Enter / blur saves, Esc cancels**. Task-linked titles must not use
/// this — they are edited on the task itself.
class EditableTitle extends StatefulWidget {
  const EditableTitle({
    required this.value,
    required this.onSubmitted,
    this.style,
    super.key,
  });

  /// Current title.
  final String value;

  /// Called with the trimmed new title when the edit is saved with a
  /// non-empty value that differs from [value].
  final ValueChanged<String> onSubmitted;

  /// Text style for both the display label and the editor.
  final TextStyle? style;

  @override
  State<EditableTitle> createState() => _EditableTitleState();
}

class _EditableTitleState extends State<EditableTitle> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _editing = false;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant EditableTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_editing) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    // Blur saves — the prototype's blur-commits behavior.
    if (!_focusNode.hasFocus && _editing) _save();
  }

  void _startEditing() {
    setState(() {
      _editing = true;
      _controller
        ..text = widget.value
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.value.length,
        );
    });
  }

  void _save() {
    final next = _controller.text.trim();
    setState(() => _editing = false);
    if (next.isEmpty || next == widget.value) return;
    widget.onSubmitted(next);
  }

  void _cancel() {
    setState(() {
      _editing = false;
      _controller.text = widget.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final style =
        widget.style ??
        tokens.typography.styles.subtitle.subtitle2.copyWith(
          color: tokens.colors.text.highEmphasis,
        );

    if (_editing) {
      return Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.escape): _CancelEditIntent(),
        },
        child: Actions(
          actions: {
            _CancelEditIntent: CallbackAction<_CancelEditIntent>(
              onInvoke: (_) {
                _cancel();
                return null;
              },
            ),
          },
          child: TextField(
            key: const Key('daily_os_editable_title_field'),
            controller: _controller,
            focusNode: _focusNode,
            // The field mounts on the edit-mode rebuild; autofocus asks
            // for focus once it is attached, which is reliable across
            // platforms (a synchronous requestFocus from the tap handler
            // can fire before the field exists).
            autofocus: true,
            style: style,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: tokens.colors.background.level03,
              contentPadding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step3,
                vertical: tokens.spacing.step2,
              ),
              enabledBorder: _border(tokens),
              focusedBorder: _border(tokens),
            ),
            onSubmitted: (_) => _save(),
          ),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.text,
      child: Semantics(
        button: true,
        label: context.messages.dailyOsNextEditTitleHint,
        child: InkWell(
          key: const Key('daily_os_editable_title_display'),
          onTap: _startEditing,
          borderRadius: BorderRadius.circular(tokens.radii.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  widget.value,
                  style: style,
                  maxLines: 2,
                  overflow: TextOverflow.fade,
                  softWrap: true,
                ),
              ),
              SizedBox(width: tokens.spacing.step2),
              AnimatedOpacity(
                // Hover-reveal only: a resident pencil on every editable
                // row is chrome noise; the whole title is the tap target
                // and the Semantics label announces editability.
                opacity: _hovering ? 0.6 : 0.0,
                duration: const Duration(milliseconds: 120),
                child: Icon(
                  Icons.edit_outlined,
                  size: tokens.typography.size.caption,
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  OutlineInputBorder _border(DsTokens tokens) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(tokens.radii.s),
      borderSide: BorderSide(
        color: tokens.colors.interactive.enabled.withValues(alpha: 0.4),
      ),
    );
  }
}

class _CancelEditIntent extends Intent {
  const _CancelEditIntent();
}
