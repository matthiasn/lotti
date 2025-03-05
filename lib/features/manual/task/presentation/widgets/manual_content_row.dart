import 'package:flutter/material.dart';
import 'package:lotti/features/manual/task/domain/models/tasks_model.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

class ManualContentRow extends StatelessWidget {
  const ManualContentRow({required this.content, super.key});
  final TaskManual content;

  void _showModalSheet(BuildContext context) {
    final pageIndexNotifier = ValueNotifier<int>(0);

    WoltModalSheet.show<void>(
      context: context,
      modalTypeBuilder: (context) => WoltModalType.dialog(),
      pageIndexNotifier: pageIndexNotifier,
      pageListBuilder: (context) => [
        WoltModalSheetPage(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: content.steps!.map((step) {
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        step.guideText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (step.innerDetail)
                      GestureDetector(
                        onTap: () {
                          pageIndexNotifier.value = 1;
                        },
                        child: const Icon(
                          Icons.help_outline,
                          color: Colors.blue,
                          size: 24,
                        ),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
          isTopBarLayerAlwaysVisible: true,
          trailingNavBarWidget: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ),
        WoltModalSheetPage(
          child: Padding(
            padding: const EdgeInsets.all(16),

            // example image for inner detail
            child: Image.asset('assets/images/manual/action_opt1.png'),
          ),
          trailingNavBarWidget: IconButton(
            onPressed: () => pageIndexNotifier.value = 0,
            icon: const Icon(Icons.arrow_back),
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: (content.imageFirst ?? true)
            ? [
                imageWidget,
                questionIcon,
              ]
            : [
                questionIcon,
                imageWidget,
              ],
      ),
    );
  }
}
