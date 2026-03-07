import 'dart:ffi';
import 'dart:io';

import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/database/objectbox_embedding_store.dart'
    deferred as objectbox_store;

Future<void>? _loadObjectBoxFuture;

Future<EmbeddingStore> openObjectBoxEmbeddingStoreForTests({
  required String documentsPath,
}) async {
  await (_loadObjectBoxFuture ??= _loadObjectBoxLibrary());
  return objectbox_store.ObjectBoxEmbeddingStore.open(
    documentsPath: documentsPath,
  );
}

Future<void> _loadObjectBoxLibrary() async {
  final sourcePath = _objectBoxTestLibrarySourcePath;
  if (sourcePath == null) {
    throw StateError('ObjectBox macOS test library not found in Pods.');
  }

  DynamicLibrary.open(sourcePath);
  await objectbox_store.loadLibrary();
}

String? get _objectBoxTestLibrarySourcePath {
  if (!Platform.isMacOS) {
    return null;
  }

  final root = Directory.current.path;
  const candidates = [
    'macos/Pods/ObjectBox/ObjectBox.xcframework/macos-arm64_x86_64/ObjectBox.framework/ObjectBox',
    'ios/Pods/ObjectBox/ObjectBox.xcframework/macos-arm64_x86_64/ObjectBox.framework/ObjectBox',
  ];

  for (final candidate in candidates) {
    final path = '$root/$candidate';
    if (File(path).existsSync()) {
      return path;
    }
  }

  return null;
}
