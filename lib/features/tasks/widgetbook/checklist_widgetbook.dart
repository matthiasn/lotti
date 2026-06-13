import 'package:flutter/material.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/features/tasks/widgetbook/checklist_mock_data.dart';
import 'package:lotti/features/tasks/widgetbook/checklist_widgetbook_widgets.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookFolder buildChecklistWidgetbookFolder() {
  return WidgetbookFolder(
    name: 'Checklist',
    children: [
      WidgetbookComponent(
        name: 'To-dos checklist',
        useCases: [
          WidgetbookUseCase(
            name: 'Interactive',
            builder: (context) => const ChecklistShowcasePage(),
          ),
        ],
      ),
    ],
  );
}

/// Standalone interactive checklist showcase.
///
/// Manages its own state (items, filter, reorder, edit, archive, delete)
/// using the same [ChecklistItemData] model as the main app.
/// No real controllers or database dependencies.
class ChecklistShowcasePage extends StatefulWidget {
  const ChecklistShowcasePage({super.key});

  @override
  State<ChecklistShowcasePage> createState() => _ChecklistShowcasePageState();
}

class _ChecklistShowcasePageState extends State<ChecklistShowcasePage> {
  late List<ChecklistItemData> _items;
  ChecklistFilter _filter = ChecklistFilter.openOnly;
  bool _isExpanded = true;
  final _addController = TextEditingController();
  final _addFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _items = ChecklistMockData.items();
  }

  @override
  void dispose() {
    _addController.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  List<ChecklistItemData> get _filteredItems {
    if (_filter == ChecklistFilter.all) return _items;
    return _items.where((item) => !item.isChecked && !item.isArchived).toList();
  }

  int get _completedCount => _items.where((i) => i.isChecked).length;

  double get _completionRate =>
      _items.isEmpty ? 0.0 : _completedCount / _items.length;

  int _nextId = 100;

  int _realIndexOf(ChecklistItemData item) =>
      _items.indexWhere((e) => e.id == item.id);

  void _toggleItem(int filteredIndex) {
    final item = _filteredItems[filteredIndex];
    final realIndex = _realIndexOf(item);
    if (realIndex < 0) return;
    setState(() {
      _items[realIndex] = item.copyWith(
        isChecked: !item.isChecked,
        checkedAt: !item.isChecked ? DateTime.now() : null,
      );
    });
  }

  void _editItem(int filteredIndex, String newTitle) {
    if (newTitle.trim().isEmpty) return;
    final item = _filteredItems[filteredIndex];
    final realIndex = _realIndexOf(item);
    if (realIndex < 0) return;
    setState(() {
      _items[realIndex] = item.copyWith(title: newTitle.trim());
    });
  }

  void _archiveItem(int filteredIndex) {
    final item = _filteredItems[filteredIndex];
    final realIndex = _realIndexOf(item);
    if (realIndex < 0) return;
    setState(() {
      _items[realIndex] = item.copyWith(isArchived: !item.isArchived);
    });
  }

  void _deleteItem(int filteredIndex) {
    final item = _filteredItems[filteredIndex];
    final realIndex = _realIndexOf(item);
    if (realIndex < 0) return;
    setState(() {
      _items.removeAt(realIndex);
    });
  }

  void _addItem(String title) {
    if (title.trim().isEmpty) return;
    setState(() {
      _items.add(
        ChecklistItemData(
          title: title.trim(),
          isChecked: false,
          linkedChecklists: const ['checklist-1'],
          id: 'item-${_nextId++}',
        ),
      );
    });
    _addController.clear();
    _addFocus.requestFocus();
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final adjustedNew = newIndex > oldIndex ? newIndex - 1 : newIndex;
      if (_filter == ChecklistFilter.all) {
        final item = _items.removeAt(oldIndex);
        _items.insert(adjustedNew, item);
      } else {
        final filtered = _filteredItems;
        final movingItem = filtered[oldIndex];
        final targetItem = filtered[adjustedNew.clamp(0, filtered.length - 1)];
        final realOld = _realIndexOf(movingItem);
        final realTarget = _realIndexOf(targetItem);
        final item = _items.removeAt(realOld);
        _items.insert(realTarget, item);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final filtered = _filteredItems;

    return DecoratedBox(
      decoration: BoxDecoration(color: tokens.colors.background.level01),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.colors.background.level02,
            borderRadius: BorderRadius.circular(tokens.radii.m),
            border: Border.all(color: tokens.colors.decorative.level01),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Header(
                title: ChecklistMockData.checklistTitle,
                completedCount: _completedCount,
                totalCount: _items.length,
                completionRate: _completionRate,
                isExpanded: _isExpanded,
                tokens: tokens,
                onToggleExpand: () =>
                    setState(() => _isExpanded = !_isExpanded),
              ),
              if (_isExpanded && _items.isNotEmpty) ...[
                FilterTabs(
                  filter: _filter,
                  tokens: tokens,
                  onFilterChanged: (f) => setState(() => _filter = f),
                ),
                ItemsColumn(
                  items: filtered,
                  tokens: tokens,
                  onToggle: _toggleItem,
                  onEdit: _editItem,
                  onArchive: _archiveItem,
                  onDelete: _deleteItem,
                  onReorder: _reorder,
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: tokens.colors.decorative.level01,
                ),
                const SizedBox(height: 8),
                AddItemField(
                  controller: _addController,
                  focusNode: _addFocus,
                  hintText: messages.checklistAddItem,
                  tokens: tokens,
                  onSubmitted: _addItem,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
