import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet_state.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Standard modal action bar for a filter overview.
class DesignSystemTaskFilterActionBar extends StatefulWidget {
  const DesignSystemTaskFilterActionBar({
    required this.state,
    required this.onChanged,
    this.onApplyPressed,
    this.onClearAllPressed,
    this.onSavePressed,
    this.canSave = false,
    this.initialSaveName,
    super.key,
  });

  final DesignSystemTaskFilterState state;
  final ValueChanged<DesignSystemTaskFilterState> onChanged;
  final ValueChanged<DesignSystemTaskFilterState>? onApplyPressed;
  final ValueChanged<DesignSystemTaskFilterState>? onClearAllPressed;
  final ValueChanged<String>? onSavePressed;
  final bool canSave;
  final String? initialSaveName;

  @visibleForTesting
  static const Key saveButtonKey = ValueKey(
    'design-system-task-filter-save',
  );

  @visibleForTesting
  static const Key saveNamePopupKey = ValueKey(
    'design-system-task-filter-save-popup',
  );

  @visibleForTesting
  static const Key saveNamePopupFieldKey = ValueKey(
    'design-system-task-filter-save-popup-field',
  );

  @visibleForTesting
  static const Key saveNamePopupCommitKey = ValueKey(
    'design-system-task-filter-save-popup-commit',
  );

  @override
  State<DesignSystemTaskFilterActionBar> createState() =>
      _DesignSystemTaskFilterActionBarState();
}

class _DesignSystemTaskFilterActionBarState
    extends State<DesignSystemTaskFilterActionBar> {
  final MenuController _saveMenu = MenuController();

  @override
  Widget build(BuildContext context) {
    final spacing = context.designTokens.spacing;
    final hasFilters = widget.state.appliedCount > 0;

    return DesignSystemModalActionBar(
      glass: true,
      padding: EdgeInsets.fromLTRB(
        spacing.step5,
        spacing.step4,
        spacing.step5,
        spacing.step5,
      ),
      secondary: [
        DesignSystemButton(
          key: const ValueKey('design-system-task-filter-clear'),
          label: widget.state.clearAllLabel,
          variant: DesignSystemButtonVariant.secondary,
          size: DesignSystemButtonSize.large,
          onPressed: hasFilters
              ? () {
                  final cleared = widget.state.clearAll();
                  widget.onChanged(cleared);
                  widget.onClearAllPressed?.call(cleared);
                }
              : null,
        ),
        if (widget.onSavePressed != null)
          MenuAnchor(
            controller: _saveMenu,
            menuChildren: [
              _SaveNamePopup(
                key: DesignSystemTaskFilterActionBar.saveNamePopupKey,
                initialValue: widget.initialSaveName ?? '',
                activeFilterCount: widget.state.appliedCount,
                onCancel: _saveMenu.close,
                onCommit: (name) {
                  _saveMenu.close();
                  widget.onSavePressed?.call(name);
                },
              ),
            ],
            builder: (context, controller, child) {
              return DesignSystemButton(
                key: DesignSystemTaskFilterActionBar.saveButtonKey,
                label: context.messages.tasksSavedFiltersSaveButtonLabel,
                variant: DesignSystemButtonVariant.secondary,
                size: DesignSystemButtonSize.large,
                onPressed: widget.canSave
                    ? () {
                        if (controller.isOpen) {
                          controller.close();
                        } else {
                          controller.open();
                        }
                      }
                    : null,
              );
            },
          ),
      ],
      primary: DesignSystemButton(
        key: const ValueKey('design-system-task-filter-apply'),
        label: widget.state.applyLabel,
        leadingIcon: Icons.check_rounded,
        size: DesignSystemButtonSize.large,
        fullWidth: true,
        onPressed: widget.onApplyPressed == null
            ? null
            : () => widget.onApplyPressed!(widget.state),
      ),
    );
  }
}

class _SaveNamePopup extends StatefulWidget {
  const _SaveNamePopup({
    required this.initialValue,
    required this.activeFilterCount,
    required this.onCancel,
    required this.onCommit,
    super.key,
  });

  final String initialValue;
  final int activeFilterCount;
  final VoidCallback onCancel;
  final ValueChanged<String> onCommit;

  @override
  State<_SaveNamePopup> createState() => _SaveNamePopupState();
}

class _SaveNamePopupState extends State<_SaveNamePopup> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  final FocusNode _focusNode = FocusNode();
  late bool _canCommit = _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleTextChanged)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    final canCommit = _controller.text.trim().isNotEmpty;
    if (canCommit != _canCommit) setState(() => _canCommit = canCommit);
  }

  void _commit() {
    if (_canCommit) widget.onCommit(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final messages = context.messages;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: spacing.step13 * 2),
      child: Padding(
        padding: EdgeInsets.all(spacing.step4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              messages.tasksSavedFiltersSavePopupTitle,
              style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
            SizedBox(height: spacing.step3),
            Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.escape) {
                  widget.onCancel();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                key: DesignSystemTaskFilterActionBar.saveNamePopupFieldKey,
                controller: _controller,
                focusNode: _focusNode,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _commit(),
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: messages.tasksSavedFiltersSavePopupHint,
                  hintStyle: tokens.typography.styles.body.bodyMedium.copyWith(
                    color: tokens.colors.text.lowEmphasis,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: spacing.step3,
                    vertical: spacing.step2,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(tokens.radii.s),
                    borderSide: BorderSide(
                      color: tokens.colors.decorative.level01,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(tokens.radii.s),
                    borderSide: BorderSide(
                      color: tokens.colors.interactive.enabled,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: spacing.step2),
            Text(
              messages.tasksSavedFiltersSavePopupHelper(
                widget.activeFilterCount,
              ),
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
            SizedBox(height: spacing.step4),
            Row(
              children: [
                DesignSystemButton(
                  label: messages.tasksSavedFiltersSavePopupCancel,
                  variant: DesignSystemButtonVariant.secondary,
                  onPressed: widget.onCancel,
                ),
                SizedBox(width: spacing.step3),
                Expanded(
                  child: DesignSystemButton(
                    key: DesignSystemTaskFilterActionBar.saveNamePopupCommitKey,
                    label: messages.tasksSavedFiltersSavePopupSave,
                    fullWidth: true,
                    onPressed: _canCommit ? _commit : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
