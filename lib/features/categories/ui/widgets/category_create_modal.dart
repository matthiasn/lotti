import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/color.dart';

class CategoryCreateModal extends ConsumerStatefulWidget {
  const CategoryCreateModal({
    required this.onCategoryCreated,
    required this.initialName,
    this.initialColor,
    super.key,
  });

  final void Function(CategoryDefinition) onCategoryCreated;
  final String initialName;
  final String? initialColor;

  @override
  ConsumerState<CategoryCreateModal> createState() =>
      _CategoryCreateModalState();
}

class _CategoryCreateModalState extends ConsumerState<CategoryCreateModal> {
  late TextEditingController _nameController;
  late Color _pickerColor;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _pickerColor = widget.initialColor != null
        ? colorFromCssHex(widget.initialColor)
        : Colors.red;
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
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: context.messages.habitCategoryLabel,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.messages.colorLabel,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          ColorPicker(
            pickerColor: _pickerColor,
            enableAlpha: false,
            labelTypes: const [],
            onColorChanged: (color) {
              setState(() {
                _pickerColor = color;
              });
            },
            pickerAreaBorderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.messages.cancelButton),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () async {
                  final repository = ref.read(categoriesRepositoryProvider);
                  final category = await repository.createCategory(
                    name: _nameController.text,
                    color: colorToCssHex(_pickerColor),
                  );
                  widget.onCategoryCreated(category);
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                child: Text(context.messages.saveLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
