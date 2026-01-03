import 'package:flutter/material.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';
import 'package:lotti/themes/theme.dart';

// ignore: avoid_positional_boolean_parameters
typedef BoolCallback = void Function(bool);

class ChecklistItemWidget extends StatefulWidget {
  const ChecklistItemWidget({
    required this.title,
    required this.isChecked,
    required this.onChanged,
    this.onTitleChange,
    this.showEditIcon = true,
    this.readOnly = false,
    this.onEdit,
    this.index = 0,
    super.key,
  });

  final String title;
  final bool readOnly;
  final bool isChecked;
  final bool showEditIcon;
  final BoolCallback onChanged;
  final VoidCallback? onEdit;
  final StringCallback? onTitleChange;

  /// Index in the list for ReorderableDragStartListener.
  final int index;

  @override
  State<ChecklistItemWidget> createState() => _ChecklistItemWidgetState();
}

class _ChecklistItemWidgetState extends State<ChecklistItemWidget> {
  late bool _isChecked;
  bool _isEditing = false;
  bool _isHovered = false;
  bool _showCompletionHighlight = false;

  @override
  void initState() {
    _isChecked = widget.isChecked;
    super.initState();
  }

  @override
  void didUpdateWidget(ChecklistItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isChecked != widget.isChecked) {
      setState(() {
        _isChecked = widget.isChecked;
      });

      if (!oldWidget.isChecked && widget.isChecked) {
        _triggerCompletionHighlight();
      }
    }
  }

  void _triggerCompletionHighlight() {
    if (_showCompletionHighlight) return;
    setState(() {
      _showCompletionHighlight = true;
    });

    Future<void>.delayed(checklistCompletionAnimationDuration).then((_) {
      if (!mounted) return;
      setState(() {
        _showCompletionHighlight = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    // Subtle hover background (no border, no card frame)
    final hoverBg = colorScheme.surfaceContainerHigh.withValues(alpha: 0.08);

    // Completion highlight effect (subtle glow only)
    final boxShadow = _showCompletionHighlight
        ? [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.2),
              blurRadius: 8,
            ),
          ]
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            // Only show background on hover, otherwise transparent
            color: _isHovered ? hoverBg : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: boxShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Row(
              children: [
                // Drag handle - always visible on the LEFT
                ReorderableDragStartListener(
                  index: widget.index,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 20,
                      color: colorScheme.outline.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                // Checkbox
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Checkbox(
                    value: _isChecked,
                    onChanged: widget.readOnly
                        ? null
                        : (bool? value) {
                            final isChecked = value ?? false;
                            final wasChecked = _isChecked;
                            setState(() {
                              _isChecked = isChecked;
                            });

                            if (!wasChecked && isChecked) {
                              _triggerCompletionHighlight();
                            }

                            widget.onChanged(isChecked);
                          },
                  ),
                ),
                const SizedBox(width: 4),
                // Title (expandable)
                Expanded(
                  child: AnimatedCrossFade(
                    duration: checklistCrossFadeDuration,
                    crossFadeState: _isEditing
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    firstChild: TitleTextField(
                      initialValue: widget.title,
                      onSave: (title) {
                        setState(() {
                          _isEditing = false;
                        });
                        widget.onTitleChange?.call(title);
                      },
                      resetToInitialValue: true,
                      onCancel: () => setState(() {
                        _isEditing = false;
                      }),
                    ),
                    secondChild: GestureDetector(
                      onTap: widget.showEditIcon
                          ? () => setState(() => _isEditing = true)
                          : null,
                      child: Text(
                        widget.title,
                        softWrap: true,
                        maxLines: 4,
                        overflow: TextOverflow.fade,
                        style: () {
                          final baseStyle = context.textTheme.bodyMedium;
                          if (!_isChecked) return baseStyle;

                          final strikethroughStyle = TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: (baseStyle?.color ??
                                    context.colorScheme.onSurface)
                                .withValues(alpha: 0.6),
                          );
                          return baseStyle?.merge(strikethroughStyle) ??
                              strikethroughStyle;
                        }(),
                      ),
                    ),
                  ),
                ),
                // Edit button
                if (widget.showEditIcon && !_isEditing)
                  IconButton(
                    icon: Icon(
                      Icons.edit,
                      color: context.colorScheme.outline,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _isEditing = !_isEditing;
                      });
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
