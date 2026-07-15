import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_scope.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Signature for a callback receiving an optional string value, used by
/// [TitleTextField] for its save handler.
typedef StringCallback = void Function(String?);

/// Local submit intent for Enter; Primary+S is supplied by [AppCommandScope].
class _SubmitIntent extends Intent {
  const _SubmitIntent();
}

/// Single/multi-line text field for editing a title (e.g. a task or checklist
/// item), with inline save/cancel affordances and keyboard shortcuts.
///
/// Calls [onSave] with the current text on tapping the save icon, invoking the
/// shared save command, or pressing Enter. When [onCancel] is present, the
/// shared cancel command resets the field as well. A save/discard icon appears
/// once the text differs from [initialValue]. Optional behaviours include
/// [clearOnSave], [resetToInitialValue] on cancel, and [keepFocusOnSave]
/// which re-asserts focus and re-shows the keyboard so the user can keep
/// typing. Picks up external [initialValue] changes via `didUpdateWidget`.
class TitleTextField extends StatefulWidget {
  const TitleTextField({
    required this.onSave,
    this.onCancel,
    this.focusNode,
    this.clearOnSave = false,
    this.resetToInitialValue = false,
    this.initialValue,
    this.semanticsLabel,
    this.hintText,
    this.onTapOutside,
    this.autofocus = false,
    this.keepFocusOnSave = false,
    super.key,
  });

  final String? initialValue;
  final StringCallback onSave;
  final VoidCallback? onCancel;
  final String? semanticsLabel;
  final bool clearOnSave;
  final bool resetToInitialValue;
  final bool autofocus;
  final FocusNode? focusNode;
  final String? hintText;
  final void Function(PointerDownEvent)? onTapOutside;
  final bool keepFocusOnSave;

  @override
  State<TitleTextField> createState() => _TitleTextFieldState();
}

class _TitleTextFieldState extends State<TitleTextField> {
  final _controller = TextEditingController();
  bool _showClearButton = false;
  bool _dirty = false;
  bool _requestRefocus = false;

  @override
  void initState() {
    _controller.text = widget.initialValue ?? '';
    if (widget.initialValue != null) {
      _showClearButton = true;
    }
    super.initState();
  }

  @override
  void didUpdateWidget(TitleTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      _controller.text = widget.initialValue ?? '';
      setState(() {
        _dirty = false;
        _showClearButton = widget.initialValue != null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialValue = widget.initialValue;

    void onSave(String? value) {
      widget.onSave(value ?? _controller.text);
      if (widget.clearOnSave) {
        _controller
          ..clear()
          // Ensure caret is at start for the next input
          ..selection = const TextSelection.collapsed(offset: 0);
      }
      if (widget.keepFocusOnSave && widget.focusNode != null) {
        // Aggressively re-assert focus so typing continues without click
        FocusScope.of(context).requestFocus(widget.focusNode);
        _requestRefocus = true;
        // Also explicitly show the keyboard on platforms that hide it after submit
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          widget.focusNode!.requestFocus();
          try {
            await SystemChannels.textInput.invokeMethod('TextInput.show');
          } catch (_) {}
          // Force caret + keyboard by pinging the inner EditableText
          final editable = FocusManager.instance.primaryFocus?.context
              ?.findAncestorStateOfType<EditableTextState>();
          editable?.requestKeyboard();
        });
      }
      setState(() {
        _showClearButton = widget.resetToInitialValue;
        _dirty = false;
      });
    }

    void onCancel() {
      if (widget.resetToInitialValue && initialValue != null) {
        _controller.text = initialValue;
      } else {
        _controller.clear();
      }
      widget.onCancel?.call();
      setState(() {
        _showClearButton = widget.resetToInitialValue;
        _dirty = false;
      });
    }

    // Handle deferred refocus without relying on post-frame callbacks.
    if (_requestRefocus && widget.focusNode != null && widget.keepFocusOnSave) {
      widget.focusNode!.requestFocus();
      // Avoid setState in build; the flag only gates side-effect.
      _requestRefocus = false;
    }

    final textField = TextField(
      style: context.textTheme.titleMedium,
      controller: _controller,
      onChanged: (value) {
        setState(() {
          _dirty = value != widget.initialValue;
          _showClearButton = value != widget.initialValue;
        });
      },
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      // Prevent Flutter's default onEditingComplete from stealing focus when keeping focus
      onEditingComplete: () {
        if (widget.keepFocusOnSave && widget.focusNode != null) {
          FocusScope.of(context).requestFocus(widget.focusNode);
        }
      },
      onTapOutside: (data) {
        if (!_dirty) {
          widget.onTapOutside?.call(data);
        }
      },
      decoration:
          inputDecoration(
            labelText: widget.hintText ?? context.messages.checklistAddItem,
            semanticsLabel: widget.semanticsLabel,
            themeData: Theme.of(context),
          ).copyWith(
            floatingLabelBehavior: FloatingLabelBehavior.never,
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AnimatedOpacity(
                  curve: Curves.easeInOutQuint,
                  opacity: _dirty ? 1.0 : 0.0,
                  duration: checklistActionIconFadeDuration,
                  child: IconButton(
                    icon: Icon(
                      Icons.check_circle,
                      size: 30,
                      semanticLabel: context.messages.saveButtonLabel,
                    ),
                    onPressed: () => onSave(_controller.text),
                  ),
                ),
                if (widget.onCancel != null)
                  AnimatedOpacity(
                    curve: Curves.easeInOutQuint,
                    opacity: _showClearButton ? 1.0 : 0.0,
                    duration: checklistActionIconFadeDuration,
                    child: IconButton(
                      icon: Icon(
                        Icons.cancel_outlined,
                        color: context.colorScheme.outline,
                        size: 30,
                        semanticLabel: context.messages.editorDiscardChanges,
                      ),
                      onPressed: onCancel,
                    ),
                  ),
              ],
            ),
          ),
      showCursor: true,
      minLines: 1,
      maxLines: 10,
      // Prevent default IME 'done' from closing input and stealing caret.
      textInputAction: TextInputAction.none,
    );

    return AppCommandScope(
      debugLabel: 'title-text-field',
      handlers: {
        AppCommandId.save: AppCommandHandler(
          invoke: (_) => onSave(_controller.text),
        ),
        if (widget.onCancel != null)
          AppCommandId.cancel: AppCommandHandler(invoke: (_) => onCancel()),
      },
      child: Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          // Enter submits without IME unfocus. Primary+S comes from the
          // catalog-driven AppCommandScope above.
          LogicalKeySet(LogicalKeyboardKey.enter): const _SubmitIntent(),
          LogicalKeySet(LogicalKeyboardKey.numpadEnter): const _SubmitIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _SubmitIntent: CallbackAction<_SubmitIntent>(
              onInvoke: (intent) {
                onSave(_controller.text);
                return null;
              },
            ),
          },
          child: textField,
        ),
      ),
    );
  }
}
