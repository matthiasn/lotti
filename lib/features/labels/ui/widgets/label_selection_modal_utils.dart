import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/widgets/label_editor_sheet.dart';
import 'package:lotti/features/tasks/ui/labels/label_ui_utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/picker/entity_picker_sheet.dart';

/// Opens the label selector for a journal entry.
///
/// A multi-select [EntityPickerSheet] (the same picker categories use), scoped
/// to the entry's category but unioned with already-assigned labels so
/// out-of-category labels can still be removed. Applying commits the staged set
/// via [LabelsRepository.setLabels]; dismissing discards it.
class LabelSelectionModalUtils {
  LabelSelectionModalUtils._();

  static Future<void> openLabelSelector({
    required BuildContext context,
    required String entryId,
    required List<String> initialLabelIds,
    String? categoryId,
  }) async {
    final staged = ValueNotifier<Set<String>>({...initialLabelIds});
    try {
      await ModalUtils.showSinglePageModal<void>(
        context: context,
        title: context.messages.settingsLabelsTitle,
        stickyActionBarBuilder: (_) =>
            _LabelApplyFooter(staged: staged, entryId: entryId),
        builder: (_) => _LabelPickerBody(
          entryId: entryId,
          initialLabelIds: initialLabelIds,
          categoryId: categoryId,
          staged: staged,
        ),
      );
    } finally {
      staged.dispose();
    }
  }
}

class _LabelPickerBody extends ConsumerWidget {
  const _LabelPickerBody({
    required this.entryId,
    required this.initialLabelIds,
    required this.categoryId,
    required this.staged,
  });

  final String entryId;
  final List<String> initialLabelIds;
  final String? categoryId;
  final ValueNotifier<Set<String>> staged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(availableLabelsForCategoryProvider(categoryId));
    final allLabels =
        ref.watch(labelsStreamProvider).value ?? const <LabelDefinition>[];
    final cache = getIt<EntitiesCacheService>();
    final assignedDefs = initialLabelIds
        .map(cache.getLabelById)
        .whereType<LabelDefinition>()
        .toList();

    List<PickerEntry> entriesBuilder(String query) {
      final result = buildSelectorLabelList(
        available: available,
        assignedDefs: assignedDefs,
        selectedIds: staged.value,
        searchLower: query.toLowerCase(),
      );
      final availableIds = result.availableIds;
      return [
        for (final label in result.items)
          _labelPickerItem(
            label,
            outOfCategory: !availableIds.contains(label.id),
          ),
      ];
    }

    bool shouldShowCreate(String query) {
      if (query.isEmpty) {
        return false;
      }
      final q = query.toLowerCase();
      // Show create unless an existing label already has this exact name
      // (checked across all labels to avoid cross-category duplicates).
      return !allLabels.any((l) => l.name.toLowerCase() == q);
    }

    Future<String?> createFromQuery(String query) async {
      final trimmed = query.trim();
      final result = await ModalUtils.showBottomSheet<LabelDefinition>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        builder: (_) =>
            LabelEditorSheet(initialName: trimmed.isEmpty ? null : trimmed),
      );
      return result?.id;
    }

    return EntityPickerSheet(
      mode: PickerMode.multi,
      entriesBuilder: entriesBuilder,
      searchHintText: context.messages.tasksLabelsSheetSearchHint,
      emptyMessage: context.messages.filterSelectionNoMatches,
      stagedNotifier: staged,
      createFromQuery: createFromQuery,
      shouldShowCreate: shouldShowCreate,
      createRowKey: const ValueKey('label-picker-create'),
    );
  }
}

PickerItem _labelPickerItem(
  LabelDefinition label, {
  required bool outOfCategory,
}) {
  final subtitle = buildLabelSubtitleText(label, outOfCategory: outOfCategory);
  return PickerItem(
    id: label.id,
    rowKey: ValueKey('label-picker-row-${label.id}'),
    leading: _LabelColorDot(label.color),
    title: label.name,
    subtitle: subtitle,
    // The subtitle is visual-only (excluded from the row's child semantics),
    // so fold it into the accessible name.
    semanticLabel: subtitle == null ? label.name : '${label.name}, $subtitle',
  );
}

class _LabelApplyFooter extends ConsumerWidget {
  const _LabelApplyFooter({required this.staged, required this.entryId});

  final ValueNotifier<Set<String>> staged;
  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return buildPickerApplyFooter(
      context: context,
      label: context.messages.tasksLabelsSheetApply,
      buttonKey: const ValueKey('label-picker-apply'),
      onTap: () async {
        final navigator = Navigator.of(context);
        final messages = context.messages;
        final repository = ref.read(labelsRepositoryProvider);
        final ok = await repository.setLabels(
          journalEntityId: entryId,
          labelIds: staged.value.toList(),
        );
        if (!context.mounted) {
          return;
        }
        if (ok ?? false) {
          navigator.pop();
        } else {
          context.showToast(
            tone: DesignSystemToastTone.error,
            title: messages.tasksLabelsUpdateFailed,
          );
        }
      },
    );
  }
}

/// The label leading: a colour dot centred in a slot the same width as the
/// category icon chip, so label and category rows align identically.
class _LabelColorDot extends StatelessWidget {
  const _LabelColorDot(this.colorHex);

  final String? colorHex;

  @override
  Widget build(BuildContext context) {
    final color = colorFromCssHex(colorHex, substitute: Colors.grey);
    return SizedBox(
      width: CategoryIconConstants.iconSizeMedium,
      child: Center(
        child: Container(
          width: CategoryIconConstants.iconSizeSmall,
          height: CategoryIconConstants.iconSizeSmall,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}
