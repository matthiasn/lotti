import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/labels/constants/label_color_presets.dart';
import 'package:lotti/features/labels/state/label_editor_controller.dart';
import 'package:lotti/utils/color.dart';

class LabelEditorSheet extends ConsumerStatefulWidget {
  const LabelEditorSheet({
    this.label,
    this.onSaved,
    super.key,
  });

  final LabelDefinition? label;
  final void Function(LabelDefinition label)? onSaved;

  @override
  ConsumerState<LabelEditorSheet> createState() => _LabelEditorSheetState();
}

class _LabelEditorSheetState extends ConsumerState<LabelEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.label?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.label?.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(labelEditorControllerProvider(widget.label));
    ref.listen(
      labelEditorControllerProvider(widget.label),
      (previous, next) {
        if (previous?.name != next.name && next.name != _nameController.text) {
          _nameController.text = next.name;
        }
        if (previous?.description != next.description &&
            next.description != _descriptionController.text) {
          _descriptionController.text = next.description ?? '';
        }
      },
    );

    final controller =
        ref.read(labelEditorControllerProvider(widget.label).notifier);

    final saveEnabled = !state.isSaving && state.name.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  widget.label == null ? Icons.add : Icons.edit,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label == null ? 'Create label' : 'Edit label',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Label name',
                hintText: 'Bug, Release blocker, Sync…',
              ),
              onChanged: controller.setName,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Explain when to apply this label',
              ),
              minLines: 2,
              maxLines: 4,
              onChanged: controller.setDescription,
            ),
            const SizedBox(height: 24),
            Text(
              'Color',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              padding: const EdgeInsets.all(12),
              child: ColorPicker(
                color: colorFromCssHex(
                  state.colorHex,
                  substitute: Theme.of(context).colorScheme.primary,
                ),
                onColorChanged: controller.setColor,
                pickersEnabled: const <ColorPickerType, bool>{
                  ColorPickerType.custom: true,
                  ColorPickerType.wheel: true,
                  ColorPickerType.accent: false,
                  ColorPickerType.primary: false,
                  ColorPickerType.bw: false,
                  ColorPickerType.both: false,
                },
                customColorSwatchesAndNames: {
                  for (final preset in labelColorPresets)
                    ColorTools.createPrimarySwatch(
                      colorFromCssHex(
                        preset.hex,
                        substitute: Colors.blue,
                      ),
                    ): preset.name,
                },
                pickerTypeLabels: const <ColorPickerType, String>{
                  ColorPickerType.custom: 'Quick presets',
                  ColorPickerType.wheel: 'Custom color',
                },
                colorNameTextStyle: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 24),
            SwitchListTile.adaptive(
              value: state.isPrivate,
              onChanged: (value) =>
                  controller.setPrivate(isPrivateValue: value),
              title: const Text('Private label'),
              subtitle: const Text(
                'Private labels are only visible to you and will not sync to shared devices.',
              ),
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                state.errorMessage!,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: state.isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: saveEnabled
                        ? () async {
                            final navigator = Navigator.of(context);
                            final result = await controller.save();
                            if (!mounted) return;
                            if (result != null) {
                              widget.onSaved?.call(result);
                              navigator.pop(result);
                            }
                          }
                        : null,
                    child: state.isSaving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.label == null ? 'Create' : 'Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
