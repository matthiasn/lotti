import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_picker.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';

/// Returns the width to pass to `flutter_colorpicker.ColorPicker` given
/// the [available] horizontal space inside the modal.
///
/// In `portraitOnly: true` mode the package sizes the whole picker
/// (saturation square + hue slider below it) from `colorPickerWidth`,
/// so this single value drives the entire layout. The result is
/// clamped to the design-system maximum so wide modals don't render a
/// disproportionately huge picker; the lower bound is `0.0` so an
/// extremely narrow surface (split-view, tight column) shrinks the
/// picker rather than overflowing it (red-team review by
/// gemini-code-assist on PR #3215).
@visibleForTesting
double pickerSquareWidthFor(double available) {
  return available.clamp(
    0.0,
    CategoryIconConstants.colorPickerMaxSquareWidth,
  );
}

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
        maxHeight:
            MediaQuery.of(context).size.height *
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
                  // `flutter_colorpicker` ships two layouts keyed off
                  // `MediaQuery.of(context).orientation`:
                  //   * portrait — saturation square on top, hue slider
                  //     below; both derive their width from
                  //     `colorPickerWidth`, so the whole picker is
                  //     exactly `colorPickerWidth` wide.
                  //   * landscape — saturation square on the left, a
                  //     `sliderByPaletteType` Row on the right whose
                  //     slider column is hard-coded to 260 px wide
                  //     regardless of `colorPickerWidth`.
                  // Desktop hosts (macOS, Linux, web) report landscape
                  // orientation, so the package picks the landscape
                  // branch inside our WoltModalSheet page and the
                  // 260-px slider blew past the modal's right edge.
                  //
                  // `portraitOnly: true` forces the portrait branch
                  // regardless of host orientation; the LayoutBuilder
                  // then sizes the entire picker to fit available
                  // width. The lower clamp is 0 (not a "preferred
                  // minimum"): on extremely narrow surfaces — tight
                  // split-views, custom test rigs — enforcing a fixed
                  // minimum like 200 px would re-introduce a small
                  // overflow. Scaling gracefully down to whatever
                  // space we get is the safer default.
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final squareWidth = pickerSquareWidthFor(
                        constraints.maxWidth,
                      );
                      return ColorPicker(
                        pickerColor: _pickerColor,
                        enableAlpha: false,
                        labelTypes: const [],
                        colorPickerWidth: squareWidth,
                        portraitOnly: true,
                        onColorChanged: (color) {
                          setState(() {
                            _pickerColor = color;
                          });
                        },
                        pickerAreaBorderRadius: BorderRadius.circular(
                          CategoryIconConstants.colorPickerBorderRadius,
                        ),
                      );
                    },
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
                  final navigator = Navigator.of(context);
                  final messages = context.messages;

                  final categoryName = _nameController.text.trim();

                  if (categoryName.isEmpty) {
                    context.showToast(
                      tone: DesignSystemToastTone.error,
                      title: messages.categoryNameRequired,
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
                    DevLogger.error(
                      name: 'CategoryCreateModal',
                      message: 'Error creating category',
                      error: e,
                      stackTrace: s,
                    );

                    if (!context.mounted) return;
                    context.showToast(
                      tone: DesignSystemToastTone.error,
                      title: messages.categoryCreationError,
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
        _selectedIcon?.displayName ?? context.messages.categoryIconChooseHint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.messages.categoryIconLabel,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: CategoryIconConstants.smallSectionSpacing),
        InkWell(
          onTap: _showIconPicker,
          borderRadius: BorderRadius.circular(
            CategoryIconConstants.borderRadius,
          ),
          child: Container(
            padding: const EdgeInsets.all(CategoryIconConstants.sectionSpacing),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(
                CategoryIconConstants.borderRadius,
              ),
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
                      // With no icon yet the main line already reads
                      // "Select an icon" — no second instruction.
                      if (_selectedIcon != null)
                        Text(
                          context.messages.categoryIconEditHint,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: CategoryIconConstants.arrowIconSize,
                ),
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
