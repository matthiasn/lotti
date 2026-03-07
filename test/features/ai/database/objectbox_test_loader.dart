import 'dart:ffi';
import 'dart:io';

import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/database/objectbox_embedding_store.dart'
    deferred as objectbox_store;
import 'package:lotti/features/ai/database/real_objectbox_ops.dart'
    deferred as real_ops;
import 'package:lotti/objectbox.g.dart' deferred as obx show openStore;

Future<void>? _loadObjectBoxFuture;

/// Whether the ObjectBox native library is available on this platform.
///
/// Returns `false` on platforms where the native library cannot be located
/// (e.g. Linux CI without a pre-installed `libobjectbox.so`).
bool get isObjectBoxAvailable => _objectBoxTestLibrarySourcePath != null;

Future<EmbeddingStore> openObjectBoxEmbeddingStoreForTests({
  required String documentsPath,
}) async {
  await (_loadObjectBoxFuture ??= _loadObjectBoxLibrary());

  final directoryPath = '$documentsPath/objectbox_embeddings';
  await Directory(directoryPath).create(recursive: true);

  final store = await obx.openStore(directory: directoryPath);
  return objectbox_store.ObjectBoxEmbeddingStore(
    real_ops.RealObjectBoxOps(store),
  );
}

Future<void> _loadObjectBoxLibrary() async {
  final sourcePath = _objectBoxTestLibrarySourcePath;
  if (sourcePath == null) {
    throw StateError(
      'ObjectBox native library not found. '
      'On macOS, ensure Pods are installed. '
      'On Linux, install libobjectbox.so to a standard library path.',
    );
  }

  DynamicLibrary.open(sourcePath);
  await objectbox_store.loadLibrary();
  await real_ops.loadLibrary();
  await obx.loadLibrary();
}

String? get _objectBoxTestLibrarySourcePath {
  if (Platform.isMacOS) {
    return _findMacOsLibrary();
  }
  if (Platform.isLinux) {
    return _findLinuxLibrary();
  }
  return null;
}

String? _findMacOsLibrary() {
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

String? _findLinuxLibrary() {
  const candidates = [
    '/usr/lib/libobjectbox.so',
    '/usr/local/lib/libobjectbox.so',
  ];

  final root = Directory.current.path;
  final localCandidate = '$root/lib/libobjectbox.so';

  if (File(localCandidate).existsSync()) {
    return localCandidate;
  }

  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return candidate;
    }
  }

  return null;
}
