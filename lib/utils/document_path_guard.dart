import 'package:path/path.dart' as p;

/// Any segment Win32 would trim to empty, `.` or `..`: only dots and spaces.
final RegExp _onlyDotsAndSpaces = RegExp(r'^[. ]+$');

/// Whether [path] lies inside [root] (or is [root]) once the operating system
/// is done interpreting it.
///
/// Journal media paths are assembled from a directory and file name that
/// arrive by sync, so a faulty or hostile peer can put `..` in them. Sinks
/// that touch the filesystem on such a path refuse it rather than rewrite it,
/// like the attachment ingestor and the image-path migration do. `p.isWithin`
/// alone is not enough on Windows, which trims trailing dots and spaces from
/// each segment, so `.. ` or `...` act as `..` there. Such a segment
/// surviving normalization means the path is not inside [root].
bool isInsideDocuments(String root, String path) {
  final normalizedRoot = p.normalize(root);
  final normalized = p.normalize(path);
  if (normalized == normalizedRoot) return true;
  if (!p.isWithin(normalizedRoot, normalized)) return false;
  return !p
      .split(p.relative(normalized, from: normalizedRoot))
      .any(_onlyDotsAndSpaces.hasMatch);
}
