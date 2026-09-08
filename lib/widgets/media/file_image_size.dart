import 'dart:io';

import 'package:material_ui/material_ui.dart';

/// Builds with the pixel size of the picture at [path] once it has decoded,
/// and with `null` until then.
///
/// A surface that lets the user *move* a picture needs the picture's own
/// dimensions to turn a drag in logical pixels into a fraction of the image
/// — the avatar crop and the banner's drag-to-reposition both do. Neither
/// should own the decode-and-listen dance, so it lives here once.
///
/// The stream is started after the first frame: a picture already in the
/// image cache completes its listener synchronously, and doing that inside
/// a build would be a `setState` mid-build.
class FileImageSize extends StatefulWidget {
  const FileImageSize({required this.path, required this.builder, super.key});

  /// The file on disk.
  final String path;

  /// Draws the host; [Size] is null until the picture has decoded.
  final Widget Function(BuildContext context, Size? size) builder;

  @override
  State<FileImageSize> createState() => _FileImageSizeState();
}

class _FileImageSizeState extends State<FileImageSize> {
  Size? _size;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _scheduleListen();
  }

  @override
  void didUpdateWidget(FileImageSize oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _stop();
      _size = null;
      _scheduleListen();
    }
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  void _scheduleListen() {
    final path = widget.path;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.path != path) return;
      _stop();
      final stream = FileImage(File(path)).resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener((info, _) {
        final size = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
        info.dispose();
        if (!mounted || size == _size) return;
        setState(() => _size = size);
      });
      _stream = stream;
      _listener = listener;
      stream.addListener(listener);
    });
  }

  void _stop() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _size);
}
