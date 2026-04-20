import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Re-requests keyboard focus for [focusNode] on the next frame and asks the
/// platform to show the soft keyboard.
///
/// Used by both the inline checklist card and the full-list modal after a new
/// item is persisted, so users can keep appending items without re-tapping the
/// add field. The `TextInput.show` channel is unavailable on embedders that
/// don't implement text input (e.g. the test binding, some desktop configs);
/// those cases surface as `MissingPluginException` or `PlatformException` and
/// are treated as no-ops, with a debug breadcrumb so a real platform
/// regression is still visible during development.
void scheduleChecklistAddFieldFocus(BuildContext context, FocusNode focusNode) {
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (!context.mounted) return;
    focusNode
      ..unfocus()
      ..requestFocus();
    try {
      await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    } on MissingPluginException catch (e) {
      assert(() {
        debugPrint(
          'scheduleChecklistAddFieldFocus: text-input channel '
          'unavailable on this embedder ($e)',
        );
        return true;
      }(), 'debug-only breadcrumb');
    } on PlatformException catch (e) {
      assert(() {
        debugPrint(
          'scheduleChecklistAddFieldFocus: platform refused to show '
          'keyboard ($e)',
        );
        return true;
      }(), 'debug-only breadcrumb');
    }
  });
}

/// Grey-background filter strip with Open / Done / All tabs.
///
/// Used by both `ChecklistCard._Body` and `ChecklistFullListModal` so the
/// two surfaces render the filter control identically (same tab widths,
/// underline, background tint, and typography).
class ChecklistFilterStrip extends StatelessWidget {
  const ChecklistFilterStrip({
    required this.filter,
    required this.onFilterChanged,
    super.key,
  });

  final ChecklistFilter filter;
  final ValueChanged<ChecklistFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: tokens.spacing.step8,
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.06),
          child: Row(
            children: [
              ChecklistFilterTab(
                label: context.messages.taskStatusOpen,
                isSelected: filter == ChecklistFilter.openOnly,
                onTap: () => onFilterChanged(ChecklistFilter.openOnly),
              ),
              ChecklistFilterTab(
                label: context.messages.taskStatusDone,
                isSelected: filter == ChecklistFilter.doneOnly,
                onTap: () => onFilterChanged(ChecklistFilter.doneOnly),
              ),
              ChecklistFilterTab(
                label: context.messages.taskStatusAll,
                isSelected: filter == ChecklistFilter.all,
                onTap: () => onFilterChanged(ChecklistFilter.all),
              ),
              const Spacer(),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: tokens.colors.decorative.level01,
        ),
      ],
    );
  }
}

/// Single tab inside a [ChecklistFilterStrip].
class ChecklistFilterTab extends StatelessWidget {
  const ChecklistFilterTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accentColor = tokens.colors.interactive.enabled;
    final tabWidth = tokens.spacing.step10;
    final horizontalLabelPadding = tokens.spacing.step3;
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      // GestureDetector (not InkWell) so the Material ripple does not
      // visually compete with the custom selected-state highlight (the
      // tinted background + the underline bar). minWidth — not a fixed
      // width — keeps long localizations from truncating while still
      // giving short labels a uniform tap target.
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: tabWidth),
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accentColor.withValues(alpha: 0.24)
                        : Colors.transparent,
                  ),
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalLabelPadding,
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: isSelected
                          ? tokens.colors.text.highEmphasis
                          : tokens.colors.text.lowEmphasis,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
              Container(
                height: 3,
                color: isSelected ? accentColor : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Minimal pill-shaped "Add item" text field used by both the inline checklist
/// card body and the full-list modal. Clears its own controller only after
/// the parent reports the create succeeded — so a short-circuited submit
/// (rapid double-tap, persistence failure) does not silently lose the user's
/// typed text.
class ChecklistAddItemField extends StatefulWidget {
  const ChecklistAddItemField({
    required this.focusNode,
    required this.onSubmitted,
    super.key,
  });

  final FocusNode focusNode;

  /// Called with the trimmed (non-empty) submitted value. Should resolve to
  /// `true` when the new item was created and persisted, or `false` when
  /// the create was short-circuited / failed; the field uses this to decide
  /// whether to clear its controller.
  final Future<bool> Function(String) onSubmitted;

  @override
  State<ChecklistAddItemField> createState() => _ChecklistAddItemFieldState();
}

class _ChecklistAddItemFieldState extends State<ChecklistAddItemField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    final success = await widget.onSubmitted(trimmed);
    if (mounted && success) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.only(
        left: tokens.spacing.step3,
        right: tokens.spacing.step3,
        bottom: tokens.spacing.step4,
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokens.radii.l),
          border: Border.all(color: tokens.colors.decorative.level01),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step4,
          vertical: tokens.spacing.step3,
        ),
        child: TextField(
          controller: _controller,
          focusNode: widget.focusNode,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
          decoration: InputDecoration(
            hintText: context.messages.checklistAddItem,
            hintStyle: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          onSubmitted: _submit,
          textInputAction: TextInputAction.done,
        ),
      ),
    );
  }
}
