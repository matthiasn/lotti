import 'dart:async';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

/// Reads the pixel size of the picture at [path] from its header — the
/// codec is opened, its dimensions asked for, and nothing is decoded.
///
/// This is the one way to learn a photograph's size that does not cost the
/// photograph: resolving a `FileImage` would decode it at native resolution
/// and park a 12-megapixel bitmap in the image cache under a key nothing
/// else uses. Throws when the bytes are not a picture, like the codec does.
Future<Size> readImageFileSize(String path) async {
  final buffer = await ui.ImmutableBuffer.fromFilePath(path);
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      return Size(descriptor.width.toDouble(), descriptor.height.toDouble());
    } finally {
      descriptor.dispose();
    }
  } finally {
    buffer.dispose();
  }
}

/// How [FileImageSize] learns a picture's size. Production reads the file's
/// header ([readImageFileSize]); a test hands in the size it wants known.
typedef ImageFileSizeReader = Future<Size> Function(String path);

/// Builds with the pixel size of the picture at [path] once it is known, and
/// with `null` until then.
///
/// A surface that lets the user *move* a picture needs the picture's own
/// dimensions to turn a drag in logical pixels into a fraction of the image
/// — the avatar crop and the banner's drag-to-reposition both do. Neither
/// should own the read-and-remember dance, so it lives here once.
///
/// A picture whose header cannot be read — a file that is not an image, or
/// is still being written — keeps the size at `null`, and the host stays
/// un-draggable rather than moving against a guess.
class FileImageSize extends StatefulWidget {
  const FileImageSize({
    required this.path,
    required this.builder,
    this.read = readImageFileSize,
    super.key,
  });

  /// The file on disk.
  final String path;

  /// Draws the host; [Size] is null until the picture's size is known.
  final Widget Function(BuildContext context, Size? size) builder;

  /// Reads the size of the picture at a path.
  final ImageFileSizeReader read;

  @override
  State<FileImageSize> createState() => _FileImageSizeState();
}

class _FileImageSizeState extends State<FileImageSize> {
  Size? _size;

  /// Which read is current. A read that finishes after the path has changed
  /// — or after the widget is gone — belongs to a picture nobody is asking
  /// about any more, and is dropped.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_read());
  }

  @override
  void didUpdateWidget(FileImageSize oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _size = null;
      unawaited(_read());
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _read() async {
    final generation = ++_generation;
    final Size size;
    try {
      size = await widget.read(widget.path);
    } catch (_) {
      return;
    }
    if (!mounted || generation != _generation || size == _size) return;
    setState(() => _size = size);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _size);
}
