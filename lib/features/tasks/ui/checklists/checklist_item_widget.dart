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
    super.key,
  });

  final String title;
  final bool readOnly;
  final bool isChecked;
  final bool showEditIcon;
  final BoolCallback onChanged;
  final VoidCallback? onEdit;
  final StringCallback? onTitleChange;

  @override
  State<ChecklistItemWidget> createState() => _ChecklistItemWidgetState();
}

class _ChecklistItemWidgetState extends State<ChecklistItemWidget> {
  late bool _isChecked;
  bool _isEditing = false;
  bool _isHovered = false;

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
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final baseBg = colorScheme.surfaceContainerHigh.withValues(alpha: 0.08);
    final checkedBg = colorScheme.primaryContainer.withValues(alpha: 0.10);
    final editingBg =
        colorScheme.surfaceContainerHighest.withValues(alpha: 0.12);

    final animatedBg = _isEditing
        ? editingBg
        : _isChecked
            ? checkedBg
            : baseBg;

    return Theme(
      data: Theme.of(context).copyWith(
        listTileTheme: Theme.of(context).listTileTheme.copyWith(dense: true),
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: _isHovered
                  ? Color.alphaBlend(
                      context.colorScheme.primary.withValues(alpha: 0.05),
                      animatedBg,
                    )
                  : animatedBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.12),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: CheckboxListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: AnimatedCrossFade(
                  duration: checklistCrossFadeDuration,
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
                  secondChild: SizedBox(
                    width: double.infinity,
                    child: Row(
                      children: [
                        Flexible(
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
                        if (widget.showEditIcon)
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
                  crossFadeState: _isEditing
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                ),
                value: _isChecked,
                controlAffinity: ListTileControlAffinity.leading,
                secondary: widget.onEdit != null
                    ? IconButton(
                        icon: const Icon(
                          Icons.edit,
                          size: 20,
                        ),
                        onPressed: widget.onEdit,
                      )
                    : null,
                onChanged: widget.readOnly
                    ? null
                    : (bool? value) {
                        final isChecked = value ?? false;
                        setState(() {
                          _isChecked = isChecked;
                        });

                        widget.onChanged(isChecked);
                      },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
