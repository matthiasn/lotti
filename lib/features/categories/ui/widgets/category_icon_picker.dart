import 'package:flutter/material.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/themes/gamey/glows.dart';
import 'package:lotti/themes/theme.dart';

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
///   ),
/// );
/// ```
class CategoryIconPicker extends StatelessWidget {
  const CategoryIconPicker({
    super.key,
    this.selectedIcon,
  });

  /// The currently selected icon (will be highlighted if provided)
  final CategoryIcon? selectedIcon;

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
              padding: const EdgeInsets.all(
                CategoryIconConstants.pickerPadding,
              ),
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
                padding: const EdgeInsets.all(
                  CategoryIconConstants.pickerPadding,
                ),
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
                      Navigator.of(context).pop(icon);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.colorScheme.primaryContainer.withValues(
                                alpha: CategoryIconConstants
                                    .selectedBackgroundAlpha,
                              )
                            : context.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.6),
                        border: Border.all(
                          color: isSelected
                              ? context.colorScheme.primary.withValues(
                                  alpha: 0.6,
                                )
                              : context.colorScheme.outline.withValues(
                                  alpha: 0.1,
                                ),
                          width: CategoryIconConstants.pickerBorderWidth,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isSelected
                            ? GameyGlows.iconGlow(
                                context.colorScheme.primary,
                                isActive: true,
                              )
                            : [
                                BoxShadow(
                                  color: context.colorScheme.shadow.withValues(
                                    alpha: 0.08,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icon.iconData,
                            size: CategoryIconConstants.pickerIconSize,
                            color: isSelected
                                ? context.colorScheme.primary
                                : context.colorScheme.onSurface.withValues(
                                    alpha: 0.8,
                                  ),
                          ),
                          const SizedBox(
                            height: CategoryIconConstants.iconTextSpacing,
                          ),
                          Text(
                            icon.displayName,
                            style: TextStyle(
                              fontSize: CategoryIconConstants.pickerTextSize,
                              color: isSelected
                                  ? context.colorScheme.primary
                                  : context.colorScheme.onSurface.withValues(
                                      alpha: 0.8,
                                    ),
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
