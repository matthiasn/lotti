import 'package:flutter/foundation.dart';
import 'package:lotti/features/ai/util/known_models.dart';

/// Outcome of the setup-preview modal. `excludedProviderModelIds` is the
/// set of `KnownModel.providerModelId` values the user unticked — the
/// caller threads that through `runFtueSetupForType` so the matching
/// rows are removed after the standard FTUE preset runs.
@immutable
class AiProviderSetupPreviewResult {
  const AiProviderSetupPreviewResult({
    required this.confirmed,
    required this.excludedProviderModelIds,
  });

  const AiProviderSetupPreviewResult.cancelled()
    : confirmed = false,
      excludedProviderModelIds = const <String>{};

  final bool confirmed;
  final Set<String> excludedProviderModelIds;
}

/// Per-provider preview data the modal renders.
///
/// Bundles the FTUE preset's `KnownModel` list with the seeded profile
/// name and the test-category name so the modal can ship one widget tree
/// for every provider type. `models` may be empty (Ollama) — the caller
/// is expected to short-circuit and skip the modal in that case via
/// `AiProviderSetupPreviewModal.skipsPreviewFor(...)`.
@immutable
class AiProviderSetupPreviewPreset {
  const AiProviderSetupPreviewPreset({
    required this.providerName,
    required this.profileName,
    required this.categoryName,
    required this.models,
  });

  final String providerName;
  final String profileName;
  final String categoryName;
  final List<KnownModel> models;
}

/// Modal: "{Provider} connected · Live · Review what Lotti will add".
///
/// Renders three sections:
/// - **New models** — checkbox per row; unticking a row records its
///   `providerModelId` in the excluded set. All boxes start ticked.
/// - **Already added** — read-only rows for models the provider already
///   owns. No checkboxes; just chips. Empty if the user is setting up
///   the provider for the first time.
/// - **Inference profile + test category** — confirms what the FTUE
///   will seed alongside the model rows.
///
/// Replaces the old `FtueSetupDialog` confirmation. Footer:
/// `Customize` (cancel — returns to the provider form) and
/// `Accept & finish` (returns `confirmed: true` with the excluded set).
