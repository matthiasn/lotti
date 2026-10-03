import 'package:path/path.dart' as p;

/// An empty segment, or one Windows would trim to empty, `.` or `..`.
final RegExp _onlyDotsAndSpaces = RegExp(r'^[. ]*$');

/// The path of [file] inside [directory] under [root], confined to [root].
///
/// Journal media is stored as a documents-relative directory plus a file name,
/// and both arrive by sync from other devices. Joining them as given would let
/// a `..` segment — written by a faulty or hostile peer — resolve outside the
/// documents directory, and every reader, writer and "reveal in file manager"
/// action would then follow it there. Segments made only of dots and spaces
/// are dropped — `.` and `..`, and their Windows spellings `...` or `.. `,
/// which Win32 trims back to `..` — and both separators are accepted (paths
/// travel between operating systems), so a well-formed entry resolves exactly
/// as before and any other stays under [root].
String confinedDocumentPath(String root, String directory, String file) {
  final segments = [
    for (final part in '$directory/$file'.replaceAll(r'\', '/').split('/'))
      if (!_onlyDotsAndSpaces.hasMatch(part)) part,
  ];
  return p.joinAll([root, ...segments]);
}
