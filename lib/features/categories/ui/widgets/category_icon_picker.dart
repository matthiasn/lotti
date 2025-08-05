import 'package:flutter/material.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';

/// Modal dialog for selecting category icons from the available set.
/// 
/// This widget displays all available CategoryIcon values in a grid layout,
/// allowing users to select an icon for their category. The currently selected
/// icon is highlighted with a colored border and background.
/// 
/// Example:
/// ```dart
/// final selectedIcon = await showDialog<CategoryIcon>(
///   context: context,
///   builder: (context) => CategoryIconPicker(
///     selectedIcon: currentIcon,
///     onIconSelected: (icon) => print('Selected: $icon'),
///   ),
/// );
/// ```
class CategoryIconPicker extends StatelessWidget {
  const CategoryIconPicker({
    super.key,
    this.selectedIcon,
    this.onIconSelected,
  });

  /// The currently selected icon (will be highlighted if provided)
  final CategoryIcon? selectedIcon;
  
  /// Callback called when an icon is selected. If null, selection has no effect.
  final ValueChanged<CategoryIcon>? onIconSelected;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: CategoryIconConstants.pickerMaxWidth,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(CategoryIconConstants.pickerPadding),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      CategoryIconStrings.chooseIconTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(CategoryIconConstants.pickerPadding),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: CategoryIconConstants.pickerGridColumns,
                  crossAxisSpacing: CategoryIconConstants.pickerGridSpacing,
                  mainAxisSpacing: CategoryIconConstants.pickerGridSpacing,
                ),
                itemCount: CategoryIcon.values.length,
                itemBuilder: (context, index) {
                  final icon = CategoryIcon.values[index];
                  final isSelected = icon == selectedIcon;
                  
                  return InkWell(
                    onTap: () {
                      onIconSelected?.call(icon);
                      Navigator.of(context).pop(icon);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected 
                          ? Theme.of(context).colorScheme.primary.withValues(
                              alpha: CategoryIconConstants.selectedBackgroundAlpha) 
                          : Colors.transparent,
                        border: Border.all(
                          color: isSelected 
                            ? Theme.of(context).colorScheme.primary 
                            : Colors.grey.shade300,
                          width: isSelected 
                            ? CategoryIconConstants.selectedBorderWidth 
                            : CategoryIconConstants.unselectedBorderWidth,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icon.iconData,
                            size: CategoryIconConstants.pickerIconSize,
                            color: isSelected 
                              ? Theme.of(context).colorScheme.primary 
                              : Colors.grey.shade700,
                          ),
                          const SizedBox(height: CategoryIconConstants.iconTextSpacing),
                          Text(
                            icon.displayName,
                            style: TextStyle(
                              fontSize: CategoryIconConstants.pickerTextSize,
                              color: isSelected 
                                ? Theme.of(context).colorScheme.primary 
                                : Colors.grey.shade700,
                              fontWeight: isSelected 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
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
