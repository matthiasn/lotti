import 'package:lotti/features/agents/model/agent_domain_entity.dart';

/// Composes an agent's system prompt from its [scaffold] (the kind-specific role
/// description) plus the assigned template version's directives and the optional
/// soul personality.
///
/// Shared by the agent context builders, which differ only in their scaffold:
/// the directive/soul layering (new general/report directives, soul-vs-legacy
/// heading selection, legacy single-field fallback) is identical across kinds.
String composeAgentSystemPrompt({
  required String scaffold,
  required AgentTemplateVersionEntity? version,
  required SoulDocumentVersionEntity? soulVersion,
}) {
  if (version == null) return scaffold;

  final generalDirective = version.generalDirective.trim();
  final reportDirective = version.reportDirective.trim();
  final hasNewDirectives =
      generalDirective.isNotEmpty || reportDirective.isNotEmpty;

  final buf = StringBuffer()..write(scaffold);

  if (hasNewDirectives) {
    if (reportDirective.isNotEmpty) {
      buf
        ..writeln()
        ..writeln()
        ..writeln('## Report Directive')
        ..writeln()
        ..write(reportDirective);
    }

    if (soulVersion != null) {
      // Soul assigned: separate personality from operational directives.
      _appendSoulPersonality(buf, soulVersion);
      if (generalDirective.isNotEmpty) {
        buf
          ..writeln()
          ..writeln()
          ..writeln('## Your Operational Directives')
          ..writeln()
          ..write(generalDirective);
      }
    } else {
      // No soul: legacy combined heading.
      final effectiveGeneralDirective = generalDirective.isNotEmpty
          ? generalDirective
          : version.directives;
      if (effectiveGeneralDirective.trim().isNotEmpty) {
        buf
          ..writeln()
          ..writeln()
          ..writeln('## Your Personality & Directives')
          ..writeln()
          ..write(effectiveGeneralDirective);
      }
    }
  } else {
    // Legacy fallback: single directives field.
    final legacyDirective = version.directives.trim();
    if (legacyDirective.isNotEmpty) {
      buf
        ..writeln()
        ..writeln()
        ..writeln('## Your Personality & Directives')
        ..writeln()
        ..write(legacyDirective);
    }
  }

  return buf.toString();
}

/// Appends the soul personality fields to the prompt buffer.
void _appendSoulPersonality(
  StringBuffer buf,
  SoulDocumentVersionEntity soul,
) {
  buf
    ..writeln()
    ..writeln()
    ..writeln('## Your Personality')
    ..writeln()
    ..write(soul.voiceDirective);

  if (soul.toneBounds.trim().isNotEmpty) {
    buf
      ..writeln()
      ..writeln()
      ..write(soul.toneBounds);
  }
  if (soul.coachingStyle.trim().isNotEmpty) {
    buf
      ..writeln()
      ..writeln()
      ..write(soul.coachingStyle);
  }
  if (soul.antiSycophancyPolicy.trim().isNotEmpty) {
    buf
      ..writeln()
      ..writeln()
      ..write(soul.antiSycophancyPolicy);
  }
}
