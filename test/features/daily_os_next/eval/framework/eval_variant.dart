import 'package:lotti/features/daily_os_next/agents/domain/day_agent_config.dart';
import 'package:meta/meta.dart';

/// A named change to the planning contract the model is told about.
///
/// Variants are a matrix dimension rather than a separate run, so one pass
/// yields the A/B directly instead of two runs that may also differ in model,
/// sampling, or fixture. [evalBaselineVariantId] is mandatory in any variant
/// set (`runEvalMatrix` enforces it): a delta without a control measures
/// nothing.
///
/// Scope is deliberately narrow. [DayAgentConfig] is the only prompt input the
/// pipeline harness can vary without touching production code — it renders
/// into the system prompt's `Planning defaults:` block — so that is what a
/// variant may change. Swapping a prompt section or reordering context needs a
/// production seam that does not exist yet.
@immutable
class EvalVariant {
  const EvalVariant({
    required this.id,
    required this.rationale,
    this.configure,
  });

  final String id;

  /// What this variant is trying to find out. Read this before the config.
  final String rationale;

  /// Transforms the config derived from the scenario. Null leaves it alone.
  final DayAgentConfig Function(DayAgentConfig base)? configure;

  /// The config this variant hands the model, given the scenario's own.
  DayAgentConfig apply(DayAgentConfig base) => configure?.call(base) ?? base;
}

/// Id of the mandatory control variant.
const String evalBaselineVariantId = 'baseline';

/// Production defaults, unchanged — the control every other variant is read
/// against.
const EvalVariant evalBaselineVariant = EvalVariant(
  id: evalBaselineVariantId,
  rationale:
      'Production planning defaults, unchanged. Every other variant is a '
      'delta against this.',
);

/// The default variant set: control only.
///
/// Deliberately not seeded with speculative variants. A variant that tightens
/// the contract also changes what the *scenarios* ask for: `crowdedDay`
/// requires three tasks totalling 300 minutes, so halving capacity makes
/// `requiredWorkPlaced` and `withinCapacity` mutually unsatisfiable and the
/// cell fails whatever the model does — a result that reads as a finding but
/// is an artefact of the fixture. Variants are worth adding once a judged
/// baseline run says which part of the prompt is actually weak, and each one
/// has to be checked against the scenarios it will run under.
const List<EvalVariant> evalVariants = [evalBaselineVariant];
