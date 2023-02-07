import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lotti/classes/entry_text.dart';

class TextViewerWidget extends StatelessWidget {
  const TextViewerWidget({
    super.key,
    required this.entryText,
    required this.maxHeight,
  });

  final EntryText? entryText;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return LimitedBox(
      maxHeight: maxHeight,
      child: Markdown(
        data: entryText?.markdown ?? '',
        shrinkWrap: true,
      ),
    );
  }
}
