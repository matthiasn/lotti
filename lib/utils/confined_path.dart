import 'package:path/path.dart' as p;

/// The path of [file] inside [directory] under [root], confined to [root].
///
/// Journal media is stored as a documents-relative directory plus a file name,
/// and both arrive by sync from other devices. Joining them as given would let
/// a `..` segment — written by a faulty or hostile peer — resolve outside the
/// documents directory, and every reader, writer and "reveal in file manager"
/// action would then follow it there. Empty, `.` and `..` segments are
/// dropped, and both separators are accepted (paths travel between operating
/// systems), so a well-formed entry resolves exactly as before and any other
/// stays under [root].
String confinedDocumentPath(String root, String directory, String file) {
  final segments = [
    for (final part in '$directory/$file'.replaceAll(r'\', '/').split('/'))
      if (part.isNotEmpty && part != '.' && part != '..') part,
  ];
  return p.joinAll([root, ...segments]);
}
