import 'dart:async';
import 'dart:io';

import 'package:mocktail/mocktail.dart';

/// Exists when asked, but is gone by the time its length is read — the
/// check-then-stat race a concurrent delete opens between `existsSync` and
/// `lengthSync`.
class VanishingFile extends Fake implements File {
  VanishingFile(this.path);

  @override
  final String path;

  @override
  bool existsSync() => true;

  @override
  int lengthSync() => throw FileSystemException('vanished', path);
}

/// Runs [body] with the first [File] created for [path] replaced by a
/// [VanishingFile]; every other file, including later ones for [path], is
/// the real one. Returns whether the substitution happened, so a test can
/// prove the code under test actually probed [path].
Future<bool> runWithVanishingFile(
  String path,
  Future<void> Function() body,
) async {
  var substituted = false;
  await IOOverrides.runZoned(
    body,
    createFile: (candidate) {
      if (!substituted && candidate == path) {
        substituted = true;
        return VanishingFile(candidate);
      }
      // The root zone carries no overrides, so this is dart:io's own File.
      return Zone.root.run(() => File(candidate));
    },
  );
  return substituted;
}
