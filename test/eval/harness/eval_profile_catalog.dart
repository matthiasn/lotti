// Profile-catalog loading for Level 2 eval runs.
//
// `EvalProfile` labels are the comparison slots used by reports. Loading them
// from JSON lets one run compare arbitrary local/frontier model classes without
// editing Dart code.

import 'dart:convert';
import 'dart:io';

import 'eval_models.dart';
import 'eval_profile_config.dart';
import 'profiles.dart';

const kEvalProfilesPathEnv = 'EVAL_PROFILES';

class EvalProfileCatalog {
  EvalProfileCatalog({
    required List<EvalProfile> profiles,
    required this.sourceLabel,
    required this.usesExternalProfiles,
  }) : profiles = List.unmodifiable(profiles);

  final List<EvalProfile> profiles;
  final String sourceLabel;
  final bool usesExternalProfiles;
}

abstract final class EvalProfileCatalogLoader {
  static EvalProfileCatalog fromEnvironment(
    Map<String, String> environment, {
    String dartDefineValue = '',
  }) {
    final configured = dartDefineValue.trim().isNotEmpty
        ? dartDefineValue.trim()
        : (environment[kEvalProfilesPathEnv]?.trim() ?? '');
    if (configured.isEmpty) {
      return EvalProfileCatalog(
        profiles: kDefaultProfiles,
        sourceLabel: 'built-in default profiles',
        usesExternalProfiles: false,
      );
    }
    return fromJsonSource(configured);
  }

  static EvalProfileCatalog fromJsonSource(String source) {
    final trimmed = source.trim();
    final rawJson = _looksLikeJson(trimmed)
        ? trimmed
        : _readProfileFile(File(trimmed));
    final decoded = jsonDecode(rawJson);
    final profiles = _profilesFromDecodedJson(decoded);
    validateEvalProfiles(profiles);
    return EvalProfileCatalog(
      profiles: profiles,
      sourceLabel: _looksLikeJson(trimmed) ? 'inline JSON' : File(trimmed).path,
      usesExternalProfiles: true,
    );
  }

  static String _readProfileFile(File file) {
    if (!file.existsSync()) {
      throw StateError('Missing eval profile catalog: ${file.path}');
    }
    return file.readAsStringSync();
  }

  static List<EvalProfile> _profilesFromDecodedJson(Object? decoded) {
    final rawProfiles = switch (decoded) {
      final List<dynamic> list => list,
      final Map<String, dynamic> map => map['profiles'],
      _ => null,
    };
    if (rawProfiles is! List<dynamic>) {
      throw StateError(
        'Eval profile catalog must be a JSON array or an object with a '
        '"profiles" array.',
      );
    }
    try {
      return [
        for (final profile in rawProfiles)
          EvalProfile.fromJson(profile as Map<String, dynamic>),
      ];
    } on Object catch (error) {
      throw StateError('Invalid eval profile catalog: $error');
    }
  }
}

void validateEvalProfiles(List<EvalProfile> profiles) {
  if (profiles.isEmpty) {
    throw StateError('Eval profile catalog must contain at least one profile.');
  }
  final seenNames = <String>{};
  for (final profile in profiles) {
    if (profile.name.trim().isEmpty) {
      throw StateError('Eval profile name must not be empty.');
    }
    if (!seenNames.add(profile.name)) {
      throw StateError('Duplicate eval profile name: ${profile.name}');
    }
    if (profile.modelId.trim().isEmpty) {
      throw StateError(
        'Eval profile ${profile.name} modelId must not be empty.',
      );
    }
    final classIsLocal =
        profile.modelClass == EvalModelClass.localSmall ||
        profile.modelClass == EvalModelClass.localReasoning;
    if (profile.isLocal != classIsLocal) {
      throw StateError(
        'Invalid eval profile ${profile.name}: inconsistent '
        'isLocal/modelClass (${profile.isLocal}/${profile.modelClass.name})',
      );
    }
    if (!profile.temperature.isFinite) {
      throw StateError(
        'Eval profile ${profile.name} temperature must be finite.',
      );
    }
    if (profile.trialCount <= 0) {
      throw StateError(
        'Eval profile ${profile.name} trialCount must be positive.',
      );
    }
    if (profile.tokenBudget <= 0) {
      throw StateError(
        'Eval profile ${profile.name} tokenBudget must be positive.',
      );
    }
    final maxCompletionTokens = profile.maxCompletionTokens;
    if (maxCompletionTokens != null && maxCompletionTokens <= 0) {
      throw StateError(
        'Eval profile ${profile.name} maxCompletionTokens must be positive.',
      );
    }
    for (final cost in [
      ('inputTokenCostMicros', profile.inputTokenCostMicros),
      ('outputTokenCostMicros', profile.outputTokenCostMicros),
      ('cachedInputTokenCostMicros', profile.cachedInputTokenCostMicros),
      ('thoughtsTokenCostMicros', profile.thoughtsTokenCostMicros),
    ]) {
      final (name, value) = cost;
      if (value <= 0) {
        throw StateError(
          'Eval profile ${profile.name} $name must be positive.',
        );
      }
    }
    evalProfileConfig(profile);
  }
}

bool _looksLikeJson(String value) {
  if (value.isEmpty) return false;
  return value.startsWith('{') || value.startsWith('[');
}
