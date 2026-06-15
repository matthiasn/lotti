import 'dart:convert';
import 'dart:io';

void writeEvalJsonArtifact(
  Map<String, dynamic> value, {
  required String path,
  required bool overwrite,
  required String description,
}) {
  final file = File(path);
  final entityType = FileSystemEntity.typeSync(path, followLinks: false);
  if (entityType == FileSystemEntityType.link) {
    throw StateError('Refusing to write $description to symlink output.');
  }
  if (entityType != FileSystemEntityType.notFound && !overwrite) {
    throw StateError(
      'Refusing to overwrite existing $description. Set the matching '
      'overwrite env var to 1.',
    );
  }

  file.parent.createSync(recursive: true);
  final tempDir = file.parent.createTempSync('.${file.uri.pathSegments.last}.');
  try {
    File('${tempDir.path}/artifact.json')
      ..writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(value)}\n',
        flush: true,
      )
      ..renameSync(file.path);
  } finally {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  }
}
