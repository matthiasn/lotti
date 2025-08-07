import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_picker.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';

class CategoryCreateModal extends ConsumerStatefulWidget {
  const CategoryCreateModal({
    required this.onCategoryCreated,
    required this.initialName,
    this.initialColor,
    this.initialIcon,
    super.key,
  });

  final void Function(CategoryDefinition) onCategoryCreated;
  final String initialName;
  final String? initialColor;
  final CategoryIcon? initialIcon;

  @override
  ConsumerState<CategoryCreateModal> createState() =>
      _CategoryCreateModalState();
}

class _CategoryCreateModalState extends ConsumerState<CategoryCreateModal> {
  late TextEditingController _nameController;
  late Color _pickerColor;
  CategoryIcon? _selectedIcon;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _pickerColor = widget.initialColor != null
        ? colorFromCssHex(widget.initialColor)
        : Colors.red;
    _selectedIcon = widget.initialIcon;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height *
            CategoryIconConstants.modalMaxHeightRatio,
      ),
      padding: const EdgeInsets.all(CategoryIconConstants.sectionSpacing),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: context.messages.habitCategoryLabel,
                    ),
                  ),
                  const SizedBox(height: CategoryIconConstants.sectionSpacing),
                  Text(
                    context.messages.colorLabel,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: CategoryIconConstants.sectionSpacing),
                  ColorPicker(
                    pickerColor: _pickerColor,
                    enableAlpha: false,
                    labelTypes: const [],
                    onColorChanged: (color) {
                      setState(() {
                        _pickerColor = color;
                      });
                    },
                    pickerAreaBorderRadius: BorderRadius.circular(
                        CategoryIconConstants.colorPickerBorderRadius),
                  ),
                  const SizedBox(height: CategoryIconConstants.sectionSpacing),
                  _buildIconPicker(),
                  const SizedBox(height: CategoryIconConstants.sectionSpacing),
                ],
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              LottiTertiaryButton(
                onPressed: () => Navigator.pop(context),
                label: context.messages.cancelButton,
              ),
              const SizedBox(width: CategoryIconConstants.smallSectionSpacing),
              LottiTertiaryButton(
                onPressed: () async {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  final messages = context.messages;
                  final theme = Theme.of(context);

                  final categoryName = _nameController.text.trim();

                  // Validate input
                  if (categoryName.isEmpty) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text(messages.categoryNameRequired),
                        backgroundColor: theme.colorScheme.error,
                      ),
                    );
                    return;
                  }

                  try {
                    final repository = ref.read(categoryRepositoryProvider);
                    final category = await repository.createCategory(
                      name: categoryName,
                      color: colorToCssHex(_pickerColor),
                      icon: _selectedIcon,
                    );
                    widget.onCategoryCreated(category);
                    navigator.pop();
                  } catch (e, s) {
                    // Log the actual error with stack trace for debugging
                    debugPrint('Error creating category: $e\n$s');

                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text(messages.categoryCreationError),
                        backgroundColor: theme.colorScheme.error,
                      ),
                    );
                  }
                },
                label: context.messages.saveLabel,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconPicker() {
    final iconDisplayName =
        _selectedIcon?.displayName ?? CategoryIconStrings.chooseIconText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          CategoryIconStrings.iconLabel,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: CategoryIconConstants.smallSectionSpacing),
        InkWell(
          onTap: _showIconPicker,
          borderRadius:
              BorderRadius.circular(CategoryIconConstants.borderRadius),
          child: Container(
            padding: const EdgeInsets.all(CategoryIconConstants.sectionSpacing),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius:
                  BorderRadius.circular(CategoryIconConstants.borderRadius),
            ),
            child: Row(
              children: [
                Container(
                  width: CategoryIconConstants.iconPreviewSize,
                  height: CategoryIconConstants.iconPreviewSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _pickerColor,
                      width: CategoryIconConstants.borderWidth,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      _selectedIcon?.iconData ?? Icons.category,
                      color: _selectedIcon != null
                          ? _pickerColor
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      size: CategoryIconConstants.standardIconSize,
                    ),
                  ),
                ),
                const SizedBox(width: CategoryIconConstants.sectionSpacing),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        iconDisplayName,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      Text(
                        CategoryIconStrings.createModeIconHint,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    size: CategoryIconConstants.arrowIconSize),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showIconPicker() async {
    final result = await showDialog<CategoryIcon>(
      context: context,
      builder: (context) => CategoryIconPicker(
        selectedIcon: _selectedIcon,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedIcon = result;
      });
    }
  }
}
