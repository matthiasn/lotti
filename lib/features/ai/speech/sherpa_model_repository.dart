import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model_files/pinned_model_files.dart';
import 'package:lotti/features/ai/speech/sherpa_model_catalog.dart';

export 'package:lotti/features/ai/speech/sherpa_model_catalog.dart';

/// The embedded speech models on this device, by catalog id, in
/// `<application support>/sherpa_models/<id>/<revision>`. Downloads go
/// through [PinnedModelFiles]: explicit, coalesced, and verified against the
/// pinned size and SHA-256 before they count as installed.
class SherpaModelRepository {
  SherpaModelRepository({
    http.Client? client,
    Future<Directory> Function()? supportDirectory,
    this.models = sherpaModels,
  }) : _files = PinnedModelFiles(
         folder: 'sherpa_models',
         client: client,
         supportDirectory: supportDirectory,
       );

  final PinnedModelFiles _files;
  final List<SherpaModel> models;

  SherpaModel model(String id) => models.firstWhere(
    (model) => model.id == id,
    orElse: () => throw ArgumentError.value(id, 'id', 'Unknown speech model'),
  );

  Future<String> modelDirectory(String id) async => _files.directory(model(id));

  /// Availability checks ignore unknown synced model IDs instead of failing
  /// unrelated provider discovery. Direct downloads still reject unknown IDs.
  Future<bool> isAvailable(String id) async =>
      models.any((model) => model.id == id) && await isInstalled(id);

  // Async, so an unknown id fails the returned future, not the call.
  Future<bool> isInstalled(String id) async => _files.isInstalled(model(id));

  /// Downloading requires an explicit user action; inference only reads files.
  Future<String> install(
    String id, {
    void Function(double)? onProgress,
  }) async => _files.install(model(id), onProgress: onProgress);

  /// Removes only this device's files; synced model configuration is retained.
  Future<void> remove(String id) async => _files.remove(model(id));

  void close() => _files.close();
}

final sherpaModelRepositoryProvider = Provider<SherpaModelRepository>((ref) {
  final repository = SherpaModelRepository();
  ref.onDispose(repository.close);
  return repository;
});
