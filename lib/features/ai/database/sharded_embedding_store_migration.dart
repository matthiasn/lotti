part of 'sharded_embedding_store.dart';

// The directories that held the vectors of a retired model: mxbai-embed-large
// through Ollama, 1024 wide, first in one store and then sharded by category.
// Their index cannot be opened with the current entity, and their vectors
// match no query the current model makes.

/// The retired model's first, single store.
const kRetiredSingleEmbeddingsDirectoryName = 'objectbox_embeddings';

/// The retired model's store, sharded by category.
const kRetiredShardedEmbeddingsDirectoryName = 'objectbox_embeddings_sharded';

/// Every directory a retired model's vectors were kept in.
const List<String> kRetiredEmbeddingsDirectoryNames = [
  kRetiredSingleEmbeddingsDirectoryName,
  kRetiredShardedEmbeddingsDirectoryName,
];

/// Deletes the stores of a retired model under [documentsPath]. The index is
/// a regenerable cache, so nothing is lost that a backfill does not rebuild.
///
/// Best-effort: a store that cannot be deleted now (a locked file, a
/// permission) is tried again at the next start and never keeps the current
/// store from opening.
Future<void> deleteRetiredEmbeddingStores({
  required String documentsPath,
}) async {
  for (final name in kRetiredEmbeddingsDirectoryNames) {
    final directory = Directory(p.join(documentsPath, name));
    if (!directory.existsSync()) continue;
    try {
      await directory.delete(recursive: true);
    } on FileSystemException {
      // Dead data only; the next start tries again.
    }
  }
}
