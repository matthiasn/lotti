import 'package:flutter/material.dart';
import 'package:lotti/features/manual/task/domain/models/tasks_model.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

class ManualContentRow extends StatelessWidget {
  const ManualContentRow({required this.content, super.key});
  final TaskManual content;

  void _showModalSheet(BuildContext context, {String? customText}) {
    WoltModalSheet.show<void>(
      context: context,
      modalTypeBuilder: (context) => WoltModalType.dialog(),
      pageListBuilder: (context) => [
        WoltModalSheetPage(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              customText ?? content.steps,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          isTopBarLayerAlwaysVisible: true,
          trailingNavBarWidget: IconButton(
            onPressed: Navigator.of(context).pop,
            icon: const Icon(Icons.close),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageWidget = Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(10),
      ),
      width: 200,
      child: Image.asset(content.imagePath ?? ''),
    );

    final questionIcon = IconButton(
      icon: const Icon(Icons.help_outline, color: Colors.blue, size: 24),
      onPressed: () => _showModalSheet(context),
    );

    final innerDetailIcon = (content.innerDetail ?? false)
        ? IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.green, size: 24),
            onPressed: () => _showModalSheet(
              context,
              customText: 'inner detail',
            ),
          )
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: (content.imageFirst ?? true)
            ? [
                imageWidget,
                Row(
                  children: [
                    if (innerDetailIcon != null) innerDetailIcon,
                    questionIcon,
                  ],
                ),
              ]
            : [
                Row(
                  children: [
                    questionIcon,
                    if (innerDetailIcon != null) innerDetailIcon,
                  ],
                ),
                imageWidget,
              ],
      ),
    );
  }
}
