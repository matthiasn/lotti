import 'package:delta_markdown/delta_markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_styles.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_tools.dart';

/// A non-scrollable text viewer widget that shows a gradient fade when content is clipped
class TextViewerWidgetNonScrollable extends StatefulWidget {
  const TextViewerWidgetNonScrollable({
    required this.entryText,
    required this.maxHeight,
    super.key,
  });

  final EntryText? entryText;
  final double maxHeight;

  @override
  State<TextViewerWidgetNonScrollable> createState() =>
      _TextViewerWidgetNonScrollableState();
}

class _TextViewerWidgetNonScrollableState
    extends State<TextViewerWidgetNonScrollable> {
  bool _showGradient = false;
  final GlobalKey _quillKey = GlobalKey();
  QuillController? _controller;

  @override
  void initState() {
    super.initState();
    _createController();
    // Schedule initial overflow check after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  @override
  void didUpdateWidget(TextViewerWidgetNonScrollable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entryText != widget.entryText) {
      _createController();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _createController() {
    _controller?.dispose();
    final serializedQuill = widget.entryText?.quill;
    final markdown =
        widget.entryText?.markdown ?? widget.entryText?.plainText ?? '';
    final quill = serializedQuill ?? markdownToDelta(markdown);
    _controller = makeController(serializedQuill: quill)..readOnly = true;
  }

  void _checkOverflow() {
    // Measure actual rendered height to determine overflow
    final renderBox =
        _quillKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final actualHeight = renderBox.size.height;
      final shouldShow =
          actualHeight >= widget.maxHeight - 2; // Small tolerance

      if (shouldShow != _showGradient && mounted) {
        setState(() {
          _showGradient = shouldShow;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Re-trigger overflow check when layout constraints change
        WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());

        return LimitedBox(
          maxHeight: widget.maxHeight,
          child: _showGradient
              ? ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: const [
                        Colors.black,
                        Colors.black,
                        Colors.transparent,
                      ],
                      stops: [
                        0.0,
                        (bounds.height - 32) / bounds.height,
                        1.0,
                      ],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: AbsorbPointer(
                    child: QuillEditor(
                      key: _quillKey,
                      controller: _controller!,
                      scrollController: ScrollController(),
                      focusNode: FocusNode(),
                      config: QuillEditorConfig(
                        customStyles:
                            customEditorStyles(themeData: Theme.of(context)),
                      ),
                    ),
                  ),
                )
              : AbsorbPointer(
                  child: QuillEditor(
                    key: _quillKey,
                    controller: _controller!,
                    scrollController: ScrollController(),
                    focusNode: FocusNode(),
                    config: QuillEditorConfig(
                      customStyles:
                          customEditorStyles(themeData: Theme.of(context)),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
