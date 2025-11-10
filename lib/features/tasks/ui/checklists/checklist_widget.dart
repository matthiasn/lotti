import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_wrapper.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/features/tasks/ui/checklists/drag_utils.dart';
import 'package:lotti/features/tasks/ui/checklists/progress_indicator.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/app_prefs_service.dart';
import 'package:lotti/themes/theme.dart';
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
    this.completedCount,
    this.totalCount,
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
  final int? completedCount;
  final int? totalCount;
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

enum ChecklistFilter { openOnly, all }

class _ChecklistWidgetState extends State<ChecklistWidget> {
  bool _isEditing = false;
  late List<String> _itemIds;
  final FocusNode _focusNode = FocusNode();
  bool _isCreatingItem = false;

  // Filter state
  ChecklistFilter _filter = ChecklistFilter.openOnly;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    _itemIds = widget.itemIds;
    _isExpanded = widget.completionRate < 1;
    final key = 'checklist_filter_mode_${widget.id}';
    makeSharedPrefsService().getBool(key).then((value) {
      if (!mounted) return;
      if (value != null) {
        setState(() {
          _filter = value ? ChecklistFilter.openOnly : ChecklistFilter.all;
        });
      }
    });
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
    // Compute counts for header label
    final total = widget.totalCount ?? _itemIds.length;
    final completed = widget.completedCount ??
        (total == 0 ? 0 : (widget.completionRate * total).round());

    Widget buildHeaderActions() {
      // (legacy helpers removed)

      // We now return only the title row; subtitle built separately
      return Row(
        children: [
          Expanded(
            child: Text(
              widget.title,
              softWrap: true,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_isExpanded)
            IconButton(
              icon: Icon(
                Icons.edit,
                color: context.colorScheme.outline,
                size: 20,
              ),
              tooltip: context.messages.editMenuTitle,
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      );
    }

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
          onExpansionChanged: (expanded) =>
              setState(() => _isExpanded = expanded),
          title: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedCrossFade(
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
                  secondChild: buildHeaderActions(),
                  crossFadeState: _isEditing
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                ),
                if (!_isExpanded) const SizedBox(height: 10),
                Row(
                  children: [
                    ChecklistProgressIndicator(
                      completionRate: widget.completionRate,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      total == 0
                          ? ''
                          : context.messages
                              .checklistCompletedShort(completed, total),
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colorScheme.outline,
                      ),
                    ),
                    if (_isExpanded) ...[
                      const Spacer(),
                      SegmentedButton<ChecklistFilter>(
                        showSelectedIcon: false,
                        style: ButtonStyle(
                          padding: const WidgetStatePropertyAll(
                            EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          ),
                          textStyle: WidgetStateProperty.resolveWith(
                            (states) {
                              final base =
                                  Theme.of(context).textTheme.labelSmall;
                              if (states.contains(WidgetState.selected)) {
                                return base?.copyWith(
                                  fontWeight: FontWeight.w600,
                                );
                              }
                              return base;
                            },
                          ),
                          foregroundColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withValues(alpha: 0.8),
                          ),
                          backgroundColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.06)
                                : Colors.transparent,
                          ),
                          side: WidgetStateProperty.resolveWith(
                            (states) => BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(
                                    alpha: states.contains(WidgetState.selected)
                                        ? 0.5
                                        : 0.3,
                                  ),
                              width: 0.6,
                            ),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        segments: <ButtonSegment<ChecklistFilter>>[
                          ButtonSegment(
                            value: ChecklistFilter.openOnly,
                            label: Text(context.messages.taskStatusOpen),
                          ),
                          ButtonSegment(
                            value: ChecklistFilter.all,
                            label: Text(context.messages.taskStatusAll),
                          ),
                        ],
                        selected: <ChecklistFilter>{_filter},
                        onSelectionChanged: (sel) {
                          setState(() => _filter = sel.first);
                          makeSharedPrefsService().setBool(
                            key: 'checklist_filter_mode_${widget.id}',
                            value: _filter == ChecklistFilter.openOnly,
                          );
                        },
                      ),
                      const SizedBox(width: 6),
                      Theme(
                        data: Theme.of(context).copyWith(
                          popupMenuTheme: PopupMenuThemeData(
                            color: context.colorScheme.surfaceContainerHighest,
                            elevation: 8,
                            surfaceTintColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: context.colorScheme.outlineVariant
                                    .withValues(alpha: 0.3),
                                width: 0.8,
                              ),
                            ),
                          ),
                        ),
                        child: PopupMenuButton<String>(
                          tooltip: 'More',
                          position: PopupMenuPosition.under,
                          icon: const Icon(Icons.more_vert_rounded, size: 18),
                          onSelected: (value) async {
                            Future<void> deleteAction() async {
                              final result = await showDialog<bool>(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title:
                                        Text(context.messages.checklistDelete),
                                    content: Text(
                                      context
                                          .messages.checklistItemDeleteWarning,
                                    ),
                                    actions: [
                                      LottiTertiaryButton(
                                        label: context
                                            .messages.checklistItemDeleteCancel,
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                      ),
                                      LottiTertiaryButton(
                                        label: context.messages
                                            .checklistItemDeleteConfirm,
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
                            }

                            final actions = <String, Future<void> Function()>{
                              'export': () async =>
                                  widget.onExportMarkdown?.call(),
                              'share': () async =>
                                  widget.onShareMarkdown?.call(),
                              'delete': deleteAction,
                            };
                            await actions[value]?.call();
                          },
                          itemBuilder: (context) => <PopupMenuEntry<String>>[
                            if (widget.onExportMarkdown != null)
                              PopupMenuItem(
                                value: 'export',
                                child: Row(
                                  children: [
                                    Icon(MdiIcons.exportVariant, size: 18),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        context
                                            .messages.checklistExportAsMarkdown,
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: false,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (widget.onShareMarkdown != null)
                              const PopupMenuItem(
                                value: 'share',
                                child: Row(
                                  children: [
                                    Icon(Icons.ios_share, size: 18),
                                    SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Share',
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: false,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  const Icon(Icons.delete_outline, size: 18),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      context.messages.checklistDelete,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: false,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          children: [
            // Removed: dedicated trash can while editing; use overflow menu instead
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FocusTraversalGroup(
                child: FocusScope(
                  child: TitleTextField(
                    key: ValueKey('add-input-${widget.id}'),
                    focusNode: _focusNode,
                    onSave: (title) async {
                      if (_isCreatingItem) return;
                      _isCreatingItem = true;
                      final id = await widget.onCreateChecklistItem.call(title);
                      setState(() {
                        if (id != null) {
                          _itemIds = [..._itemIds, id];
                        }
                      });
                      _isCreatingItem = false;
                      // Ensure the add field truly regains keyboard focus after rebuilds
                      WidgetsBinding.instance.addPostFrameCallback((_) async {
                        if (!mounted) return;
                        _focusNode.unfocus();
                        FocusScope.of(context).requestFocus(_focusNode);
                        try {
                          await SystemChannels.textInput
                              .invokeMethod('TextInput.show');
                        } catch (_) {}
                        final editable = FocusManager
                            .instance.primaryFocus?.context
                            ?.findAncestorStateOfType<EditableTextState>();
                        editable?.requestKeyboard();
                      });
                    },
                    clearOnSave: true,
                    keepFocusOnSave: true,
                    autofocus: _itemIds.isEmpty,
                    semanticsLabel: 'Add item to checklist',
                  ),
                ),
              ),
            ),
            if (_itemIds.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  'No items yet',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.outline,
                  ),
                ),
              )
            else if (_filter == ChecklistFilter.openOnly &&
                widget.completionRate == 1 &&
                _itemIds.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  context.messages.checklistAllDone,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.outline,
                  ),
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
                    hideIfChecked:
                        !_isEditing && _filter == ChecklistFilter.openOnly,
                    key: Key('$itemId${widget.id}$index'),
                  );
                },
              ),
            ),
          ],
        ),
      ), // end ExpansionTile
    );
  }
}
