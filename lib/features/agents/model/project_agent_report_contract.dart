/// Shared wire contract for `update_project_report`.
///
/// This is the single source of truth for:
/// - tool argument names sent by the project agent
/// - persisted provenance keys for project-agent-authored health
/// - allowed health-band values
///
/// `project_tool_definitions.dart` wraps these constants in the JSON Schema
/// exposed to the model, while the workflow and UI parsing reuse the same
/// field names and values directly.
abstract final class ProjectAgentReportToolArgs {
  static const markdown = 'markdown';
  static const tldr = 'tldr';
  static const healthBand = 'health_band';
  static const healthRationale = 'health_rationale';
  static const healthConfidence = 'health_confidence';

  static const required = <String>[
    markdown,
    tldr,
    healthBand,
    healthRationale,
  ];
}

abstract final class ProjectAgentReportProvenanceKeys {
  static const healthBand = 'project_health_band';
  static const healthRationale = 'project_health_rationale';
  static const healthConfidence = 'project_health_confidence';
}

/// Canonical wire values accepted from the project-agent report tool.
abstract final class ProjectAgentHealthBandValues {
  static const surviving = 'surviving';
  static const onTrack = 'on_track';
  static const watch = 'watch';
  static const atRisk = 'at_risk';
  static const blocked = 'blocked';

  static const values = <String>[
    surviving,
    onTrack,
    watch,
    atRisk,
    blocked,
  ];
}
