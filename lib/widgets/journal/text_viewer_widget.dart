import 'package:flutter/cupertino.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/themes/theme.dart';

class TextViewerWidget extends StatelessWidget {
  const TextViewerWidget({
    required this.entryText,
    required this.maxHeight,
    super.key,
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
        styleSheet: MarkdownStyleSheet.fromCupertinoTheme(
          CupertinoThemeData(
            textTheme: CupertinoTextThemeData(
              textStyle: TextStyle(
                color: styleConfig().primaryTextColor,
                fontSize: fontSizeMedium,
                fontFamily: mainFont,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
