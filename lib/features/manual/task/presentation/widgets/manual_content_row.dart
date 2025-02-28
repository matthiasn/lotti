import 'package:flutter/material.dart';
import 'package:lotti/features/manual/task/domain/models/tasks_model.dart';

class ManualContentRow extends StatelessWidget {
  const ManualContentRow({required this.content, super.key});
  final TaskManual content;
  @override
  Widget build(BuildContext context) {
    final imageWidget = Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(10),
      ),
      width: content.imageWidth,
      child: Image.asset(content.imagePath!),
    );

    final textWidget = SizedBox(
      width: 120,
      child: Text(
        content.steps,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: content.imageFirst!
            ? [imageWidget, textWidget]
            : [textWidget, imageWidget],
      ),
    );
  }
}
