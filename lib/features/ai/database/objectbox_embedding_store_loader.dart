import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/database/objectbox_embedding_store.dart'
    deferred as objectbox_store;
import 'package:path/path.dart' as p;

Future<void>? _loadObjectBoxStoreLibraryFuture;

Future<EmbeddingStore> openObjectBoxEmbeddingStore({
  required String documentsPath,
}) async {
  await (_loadObjectBoxStoreLibraryFuture ??= _loadObjectBoxStoreLibrary());
  return objectbox_store.ObjectBoxEmbeddingStore.open(
    documentsPath: documentsPath,
  );
}

Future<void> _loadObjectBoxStoreLibrary() async {
  _preloadObjectBoxNativeLibrary();
  await objectbox_store.loadLibrary();
}

void _preloadObjectBoxNativeLibrary() {
  if (!Platform.isMacOS) {
    return;
  }

  for (final candidate in _macOsObjectBoxLibraryCandidates()) {
    if (!File(candidate).existsSync()) {
      continue;
    }

    try {
      DynamicLibrary.open(candidate);
      return;
    } on Object {
      // Try the next location.
    }
  }
}

Iterable<String> _macOsObjectBoxLibraryCandidates() sync* {
  final executable = File(Platform.resolvedExecutable);
  final macOsDirectory = executable.parent;
  final contentsDirectory = macOsDirectory.parent;
  final frameworksDirectory = Directory(
    p.join(contentsDirectory.path, 'Frameworks'),
  );

  yield p.join(
    frameworksDirectory.path,
    'ObjectBox.framework',
    'ObjectBox',
  );
  yield p.join(
    frameworksDirectory.path,
    'ObjectBox.framework',
    'Versions',
    'A',
    'ObjectBox',
  );
  yield p.join(Directory.current.path, 'lib', 'libobjectbox.dylib');
  yield '/usr/local/lib/libobjectbox.dylib';
}
