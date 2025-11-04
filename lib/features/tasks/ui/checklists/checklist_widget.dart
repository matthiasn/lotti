import 'package:flutter/material.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_wrapper.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/features/tasks/ui/checklists/drag_utils.dart';
import 'package:lotti/features/tasks/ui/checklists/progress_indicator.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// Renders a single checklist with header and items.
///
/// Header shows a progress indicator, the checklist title, an edit button to
/// rename the checklist, and an export button. Export interactions:
/// - Tap/click export → copies the checklist as Markdown (`- [ ]` / `- [x]`).
/// - Long‑press (mobile) or secondary‑click (desktop) export → opens the
///   platform share sheet with an emoji list (⬜/✅) optimized for chat/email.
class ChecklistWidget extends StatefulWidget {
  const ChecklistWidget({
    required this.title,
    required this.itemIds,
    required this.onTitleSave,
    required this.onCreateChecklistItem,
    required this.completionRate,
    required this.id,
    required this.taskId,
    required this.updateItemOrder,
    this.onDelete,
    this.onExportMarkdown,
    this.onShareMarkdown,
    super.key,
  });

  final String id;
  final String taskId;

  final String title;
  final List<String> itemIds;
  final StringCallback onTitleSave;
  final Future<String?> Function(String?) onCreateChecklistItem;
  final Future<void> Function(List<String> linkedChecklistItems)
      updateItemOrder;
  final double completionRate;
  final VoidCallback? onDelete;

  /// Called when the export button is activated (tap/click). Should copy the
  /// checklist as Markdown to the clipboard and provide user feedback.
  final VoidCallback? onExportMarkdown;

  /// Called on long‑press (mobile) or secondary‑click (desktop) of the export
  /// control to trigger a share sheet with an emoji‑based checklist.
  final VoidCallback? onShareMarkdown;

  @override
  State<ChecklistWidget> createState() => _ChecklistWidgetState();
}

class _ChecklistWidgetState extends State<ChecklistWidget> {
  bool _isEditing = false;
  late List<String> _itemIds;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _itemIds = widget.itemIds;
  }

  @override
  void didUpdateWidget(ChecklistWidget oldWidget) {
    if (oldWidget.itemIds != widget.itemIds) {
      setState(() {
        _itemIds = widget.itemIds;
      });
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
        ),
        child: ExpansionTile(
          collapsedIconColor: context.colorScheme.outline,
          iconColor: context.colorScheme.outline,
          tilePadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          collapsedShape: const Border(),
          shape: const Border(),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          maintainState: true,
          key: ValueKey('${widget.id} ${widget.completionRate}'),
          initiallyExpanded: widget.completionRate < 1,
          title: AnimatedCrossFade(
            duration: checklistCrossFadeDuration,
            firstChild: TitleTextField(
              initialValue: widget.title,
              onSave: (title) {
                widget.onTitleSave.call(title);
                setState(() {
                  _isEditing = false;
                });
              },
              resetToInitialValue: true,
              onCancel: () => setState(() {
                _isEditing = false;
              }),
            ),
            secondChild: Row(
              children: [
                ChecklistProgressIndicator(
                  completionRate: widget.completionRate,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.title,
                          softWrap: true,
                          maxLines: 3,
                        ),
                      ),
                      // Edit toggle
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
                      if (widget.onExportMarkdown != null)
                        GestureDetector(
                          onLongPress: widget.onShareMarkdown,
                          onSecondaryTap: widget.onShareMarkdown,
                          behavior: HitTestBehavior.opaque,
                          child: IconButton(
                            tooltip: isMobile
                                ? null
                                : context.messages.checklistExportAsMarkdown,
                            icon: Icon(
                              MdiIcons.exportVariant,
                              color: context.colorScheme.outline,
                              size: 20,
                            ),
                            onPressed: widget.onExportMarkdown,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            crossFadeState: _isEditing
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
          ),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isEditing)
                  IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      MdiIcons.trashCanOutline,
                      size: 20,
                      color: context.colorScheme.outline,
                    ),
                    onPressed: () async {
                      final result = await showDialog<bool>(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: Text(context.messages.checklistDelete),
                            content: Text(
                              context.messages.checklistItemDeleteWarning,
                            ),
                            actions: [
                              LottiTertiaryButton(
                                label:
                                    context.messages.checklistItemDeleteCancel,
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                              ),
                              LottiTertiaryButton(
                                label:
                                    context.messages.checklistItemDeleteConfirm,
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                              ),
                            ],
                          );
                        },
                      );
                      if (result ?? false) {
                        widget.onDelete?.call();
                      }
                    },
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: TitleTextField(
                focusNode: _focusNode,
                onSave: (title) async {
                  final id = await widget.onCreateChecklistItem.call(title);
                  setState(() {
                    if (id != null) {
                      _itemIds = [..._itemIds, id];
                    }
                  });
                },
                clearOnSave: true,
                semanticsLabel: 'Add item to checklist',
              ),
            ),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: _isEditing,
              proxyDecorator: (child, index, animation) =>
                  buildDragDecorator(context, child),
              onReorder: (int oldIndex, int newIndex) {
                final itemIds = [..._itemIds];
                final movedItem = itemIds.removeAt(oldIndex);
                final insertionIndex =
                    newIndex > oldIndex ? newIndex - 1 : newIndex;
                itemIds.insert(insertionIndex, movedItem);
                setState(() {
                  _itemIds = itemIds;
                });

                widget.updateItemOrder(itemIds);
              },
              children: List.generate(
                _itemIds.length,
                (int index) {
                  final itemId = _itemIds.elementAt(index);
                  return ChecklistItemWrapper(
                    itemId,
                    taskId: widget.taskId,
                    checklistId: widget.id,
                    key: Key('$itemId${widget.id}$index'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
