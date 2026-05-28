import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_preferences_controller.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

class ProcessingCategoryFilterButton extends ConsumerWidget {
  const ProcessingCategoryFilterButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(dailyOsPreferencesControllerProvider);
    final hasExclusions = prefs.excludedCategoryIds.isNotEmpty;
    return IconButton(
      icon: Icon(
        hasExclusions ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
      ),
      tooltip: context.messages.dailyOsNextCategoryFilterTooltip,
      onPressed: () => _showProcessingCategories(context, ref),
    );
  }

  Future<void> _showProcessingCategories(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final prefs = ref.read(dailyOsPreferencesControllerProvider);
    final allCategoryIds = _activeCategoryIds();
    final selected =
        await ModalUtils.showSinglePageModal<List<CategoryDefinition>>(
          context: context,
          title: context.messages.dailyOsNextCategoryFilterTitle,
          builder: (_) => _ProcessingCategoryPicker(
            initiallySelectedCategoryIds: allCategoryIds
                .where(prefs.allowsCategoryId)
                .toSet(),
          ),
        );
    if (selected == null) return;

    ref
        .read(dailyOsPreferencesControllerProvider.notifier)
        .setIncludedCategoryIds(
          includedCategoryIds: selected.map((category) => category.id).toSet(),
          allCategoryIds: allCategoryIds,
        );
  }
}

class _ProcessingCategoryPicker extends StatefulWidget {
  const _ProcessingCategoryPicker({
    required this.initiallySelectedCategoryIds,
  });

  final Set<String> initiallySelectedCategoryIds;

  @override
  State<_ProcessingCategoryPicker> createState() =>
      _ProcessingCategoryPickerState();
}

class _ProcessingCategoryPickerState extends State<_ProcessingCategoryPicker> {
  late Set<String> _selectedCategoryIds;

  @override
  void initState() {
    super.initState();
    _selectedCategoryIds = {...widget.initiallySelectedCategoryIds};
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final categories = _activeCategories();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                context.messages.dailyOsNextCategoryFilterDescription,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ),
            SizedBox(width: tokens.spacing.step3),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedCategoryIds = _activeCategoryIds();
                });
              },
              icon: const Icon(Icons.done_all_rounded),
              label: Text(
                context.messages.dailyOsNextCategoryFilterIncludeAll,
              ),
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.step4),
        if (categories.isEmpty)
          Text(
            context.messages.dailyOsNextCategoryFilterEmpty,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.56,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: categories.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: tokens.colors.decorative.level01.withValues(alpha: 0.1),
              ),
              itemBuilder: (context, index) {
                final category = categories[index];
                return _ProcessingCategoryRow(
                  category: category,
                  selected: _selectedCategoryIds.contains(category.id),
                  onTap: () => _toggleCategory(category.id),
                );
              },
            ),
          ),
        SizedBox(height: tokens.spacing.step5),
        FilledButton(
          onPressed: () {
            final cache = getIt<EntitiesCacheService>();
            final selected = _selectedCategoryIds
                .map(cache.getCategoryById)
                .whereType<CategoryDefinition>()
                .toList();
            Navigator.of(context).pop(selected);
          },
          child: Text(context.messages.doneButton),
        ),
      ],
    );
  }

  void _toggleCategory(String categoryId) {
    setState(() {
      if (_selectedCategoryIds.contains(categoryId)) {
        _selectedCategoryIds.remove(categoryId);
      } else {
        _selectedCategoryIds.add(categoryId);
      }
    });
  }
}

Set<String> _activeCategoryIds() {
  return _activeCategories().map((category) => category.id).toSet();
}

List<CategoryDefinition> _activeCategories() {
  return getIt<EntitiesCacheService>().sortedCategories;
}

class _ProcessingCategoryRow extends StatelessWidget {
  const _ProcessingCategoryRow({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final CategoryDefinition category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Semantics(
      button: true,
      selected: selected,
      label: category.name,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step2,
            vertical: tokens.spacing.step3,
          ),
          child: Row(
            children: [
              CategoryIconCompactFromDefinition(
                category,
                size: tokens.spacing.step7,
              ),
              SizedBox(width: tokens.spacing.step4),
              Expanded(
                child: Text(
                  category.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.styles.body.bodyMedium.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected
                    ? tokens.colors.interactive.enabled
                    : tokens.colors.text.lowEmphasis,
                size: tokens.spacing.step6,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
