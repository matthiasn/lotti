import 'dart:io';

final _adrFile = RegExp(r'^(\d{4})-.+\.md$');

/// Every ADR number in [fileNames] that more than one ADR uses, mapped to
/// those file names (sorted, by number).
///
/// `docs/adr/README.md` makes `ls docs/adr` the index, so the number is an
/// ADR's identity: code comments and concepts cite "ADR 0115", and two files
/// sharing it make every such citation ambiguous. Concurrent pull requests
/// both take the next free number, and nothing else notices — three pairs
/// collided on a single day before this check existed. The analyze workflow
/// runs on push, so a collision shows once both ADRs share a tree: a branch
/// rebased onto the other, or `main` after both merged.
Map<String, List<String>> duplicateAdrNumbers(Iterable<String> fileNames) {
  final byNumber = <String, List<String>>{};
  for (final name in fileNames) {
    final number = _adrFile.firstMatch(name)?.group(1);
    if (number != null) (byNumber[number] ??= []).add(name);
  }
  return {
    for (final number in byNumber.keys.toList()..sort())
      if (byNumber[number]!.length > 1) number: byNumber[number]!..sort(),
  };
}

void main() {
  final names = Directory(
    'docs/adr',
  ).listSync().whereType<File>().map((file) => file.uri.pathSegments.last);
  final duplicates = duplicateAdrNumbers(names);
  for (final MapEntry(key: number, value: files) in duplicates.entries) {
    stderr.writeln(
      'docs/adr: ADR $number is used by ${files.join(', ')} — renumber the '
      'newer one to the next free number and update its citations',
    );
  }
  if (duplicates.isNotEmpty) exitCode = 1;
}
