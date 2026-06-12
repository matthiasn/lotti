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
const kEvalProfileNamesEnv = 'EVAL_PROFILE_NAMES';
const kEvalPromptVariantsPathEnv = 'EVAL_PROMPT_VARIANTS';
const kEvalPromptVariantNamesEnv = 'EVAL_PROMPT_VARIANT_NAMES';

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
    String dartDefineProfileNames = '',
  }) {
    final requestedProfileNames = _profileNames(
      environment,
      dartDefineProfileNames,
    );
    final configured = dartDefineValue.trim().isNotEmpty
        ? dartDefineValue.trim()
        : (environment[kEvalProfilesPathEnv]?.trim() ?? '');
    if (configured.isEmpty) {
      final profiles = _selectProfiles(
        kDefaultProfiles,
        requestedProfileNames,
      );
      return EvalProfileCatalog(
        profiles: profiles,
        sourceLabel: _sourceLabel(
          'built-in default profiles',
          requestedProfileNames,
        ),
        usesExternalProfiles: false,
      );
    }
    return fromJsonSource(
      configured,
      requestedProfileNames: requestedProfileNames,
    );
  }

  static EvalProfileCatalog fromJsonSource(
    String source, {
    List<String>? requestedProfileNames,
  }) {
    final trimmed = source.trim();
    final rawJson = _looksLikeJson(trimmed)
        ? trimmed
        : _readProfileFile(File(trimmed));
    final decoded = jsonDecode(rawJson);
    final allProfiles = _profilesFromDecodedJson(decoded);
    validateEvalProfiles(allProfiles);
    final profiles = _selectProfiles(allProfiles, requestedProfileNames);
    validateEvalProfiles(profiles);
    final baseSourceLabel = _looksLikeJson(trimmed)
        ? 'inline JSON'
        : File(trimmed).path;
    return EvalProfileCatalog(
      profiles: profiles,
      sourceLabel: _sourceLabel(baseSourceLabel, requestedProfileNames),
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

  static List<String>? _profileNames(
    Map<String, String> environment,
    String dartDefineProfileNames,
  ) {
    final fromDefine = dartDefineProfileNames.trim();
    final configured = fromDefine.isNotEmpty
        ? fromDefine
        : (environment[kEvalProfileNamesEnv]?.trim() ?? '');
    if (configured.isEmpty) return null;
    return _parseCsvSelection(configured, label: kEvalProfileNamesEnv);
  }

  static List<String> _parseCsvSelection(
    String value, {
    required String label,
  }) {
    final selected = value.split(',').map((entry) => entry.trim()).toList();
    if (selected.any((entry) => entry.isEmpty)) {
      throw StateError('$label must not contain empty entries.');
    }
    final seen = <String>{};
    for (final entry in selected) {
      if (!seen.add(entry)) {
        throw StateError('$label contains duplicate entry: $entry');
      }
    }
    return List.unmodifiable(selected);
  }

  static List<EvalProfile> _selectProfiles(
    List<EvalProfile> profiles,
    List<String>? requestedProfileNames,
  ) {
    if (requestedProfileNames == null) {
      return List<EvalProfile>.unmodifiable(profiles);
    }
    final byName = {
      for (final profile in profiles) profile.name: profile,
    };
    final missing = [
      for (final name in requestedProfileNames)
        if (!byName.containsKey(name)) name,
    ];
    if (missing.isNotEmpty) {
      throw StateError(
        'Unknown eval profile name(s): ${missing.join(', ')}. '
        'Available profile names: ${_sortedList(byName.keys).join(', ')}',
      );
    }
    return List<EvalProfile>.unmodifiable([
      for (final name in requestedProfileNames) byName[name]!,
    ]);
  }

  static String _sourceLabel(String source, List<String>? names) {
    if (names == null) return source;
    return '$source filtered to ${names.join(', ')}';
  }

  static List<String> _sortedList(Iterable<String> values) =>
      values.toList()..sort();
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

class EvalAgentDirectiveVariantCatalog {
  EvalAgentDirectiveVariantCatalog({
    required List<EvalAgentDirectiveVariant> variants,
    required this.sourceLabel,
    required this.usesExternalVariants,
  }) : variants = List.unmodifiable(variants);

  final List<EvalAgentDirectiveVariant> variants;
  final String sourceLabel;
  final bool usesExternalVariants;
}

abstract final class EvalAgentDirectiveVariantCatalogLoader {
  static EvalAgentDirectiveVariantCatalog fromEnvironment(
    Map<String, String> environment, {
    String dartDefineValue = '',
    String dartDefineVariantNames = '',
  }) {
    final requestedVariantNames = _variantNames(
      environment,
      dartDefineVariantNames,
    );
    final configured = dartDefineValue.trim().isNotEmpty
        ? dartDefineValue.trim()
        : (environment[kEvalPromptVariantsPathEnv]?.trim() ?? '');
    if (configured.isEmpty) {
      final variants = _selectVariants(
        const [EvalAgentDirectiveVariant()],
        requestedVariantNames,
      );
      return EvalAgentDirectiveVariantCatalog(
        variants: variants,
        sourceLabel: EvalProfileCatalogLoader._sourceLabel(
          'built-in default prompt variant',
          requestedVariantNames,
        ),
        usesExternalVariants: false,
      );
    }
    return fromJsonSource(
      configured,
      requestedVariantNames: requestedVariantNames,
    );
  }

  static EvalAgentDirectiveVariantCatalog fromJsonSource(
    String source, {
    List<String>? requestedVariantNames,
  }) {
    final trimmed = source.trim();
    final rawJson = _looksLikeJson(trimmed)
        ? trimmed
        : _readPromptVariantFile(File(trimmed));
    final decoded = jsonDecode(rawJson);
    final allVariants = _variantsFromDecodedJson(decoded);
    validateEvalAgentDirectiveVariants(allVariants);
    final variants = _selectVariants(allVariants, requestedVariantNames);
    validateEvalAgentDirectiveVariants(variants);
    final baseSourceLabel = _looksLikeJson(trimmed)
        ? 'inline JSON'
        : File(trimmed).path;
    return EvalAgentDirectiveVariantCatalog(
      variants: variants,
      sourceLabel: EvalProfileCatalogLoader._sourceLabel(
        baseSourceLabel,
        requestedVariantNames,
      ),
      usesExternalVariants: true,
    );
  }

  static String _readPromptVariantFile(File file) {
    if (!file.existsSync()) {
      throw StateError('Missing eval prompt variant catalog: ${file.path}');
    }
    return file.readAsStringSync();
  }

  static List<EvalAgentDirectiveVariant> _variantsFromDecodedJson(
    Object? decoded,
  ) {
    final rawVariants = switch (decoded) {
      final List<dynamic> list => list,
      final Map<String, dynamic> map =>
        map['promptVariants'] ?? map['agentDirectiveVariants'],
      _ => null,
    };
    if (rawVariants is! List<dynamic>) {
      throw StateError(
        'Eval prompt variant catalog must be a JSON array or an object with a '
        '"promptVariants" array.',
      );
    }
    try {
      return [
        for (final variant in rawVariants)
          EvalAgentDirectiveVariant.fromJson(
            variant as Map<String, dynamic>,
          ),
      ];
    } on Object catch (error) {
      throw StateError('Invalid eval prompt variant catalog: $error');
    }
  }

  static List<String>? _variantNames(
    Map<String, String> environment,
    String dartDefineVariantNames,
  ) {
    final fromDefine = dartDefineVariantNames.trim();
    final configured = fromDefine.isNotEmpty
        ? fromDefine
        : (environment[kEvalPromptVariantNamesEnv]?.trim() ?? '');
    if (configured.isEmpty) return null;
    return EvalProfileCatalogLoader._parseCsvSelection(
      configured,
      label: kEvalPromptVariantNamesEnv,
    );
  }

  static List<EvalAgentDirectiveVariant> _selectVariants(
    List<EvalAgentDirectiveVariant> variants,
    List<String>? requestedVariantNames,
  ) {
    if (requestedVariantNames == null) {
      return List<EvalAgentDirectiveVariant>.unmodifiable(variants);
    }
    final byName = {
      for (final variant in variants) variant.name: variant,
    };
    final missing = [
      for (final name in requestedVariantNames)
        if (!byName.containsKey(name)) name,
    ];
    if (missing.isNotEmpty) {
      throw StateError(
        'Unknown eval prompt variant name(s): ${missing.join(', ')}. '
        'Available prompt variant names: '
        '${EvalProfileCatalogLoader._sortedList(byName.keys).join(', ')}',
      );
    }
    return List<EvalAgentDirectiveVariant>.unmodifiable([
      for (final name in requestedVariantNames) byName[name]!,
    ]);
  }
}

void validateEvalAgentDirectiveVariants(
  List<EvalAgentDirectiveVariant> variants,
) {
  if (variants.isEmpty) {
    throw StateError(
      'Eval prompt variant catalog must contain at least one variant.',
    );
  }
  final seenNames = <String>{};
  for (final variant in variants) {
    if (variant.name.trim().isEmpty) {
      throw StateError('Eval prompt variant name must not be empty.');
    }
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(variant.name)) {
      throw StateError(
        'Eval prompt variant ${variant.name} must contain only A-Z, a-z, '
        '0-9, dot, underscore, or dash.',
      );
    }
    if (!seenNames.add(variant.name)) {
      throw StateError('Duplicate eval prompt variant name: ${variant.name}');
    }
    if (variant.generalDirective.length > 2000) {
      throw StateError(
        'Eval prompt variant ${variant.name} generalDirective is too long.',
      );
    }
    if (variant.reportDirective.length > 1000) {
      throw StateError(
        'Eval prompt variant ${variant.name} reportDirective is too long.',
      );
    }
    if (variant.name == 'default' &&
        (variant.generalDirective.trim().isNotEmpty ||
            variant.reportDirective.trim().isNotEmpty)) {
      throw StateError(
        'Eval prompt variant default must not add directives.',
      );
    }
    if (variant.name != 'default' &&
        variant.generalDirective.trim().isEmpty &&
        variant.reportDirective.trim().isEmpty) {
      throw StateError(
        'Eval prompt variant ${variant.name} has empty directives; use the '
        'reserved name "default" for the empty baseline.',
      );
    }
  }
}

bool _looksLikeJson(String value) {
  if (value.isEmpty) return false;
  return value.startsWith('{') || value.startsWith('[');
}
