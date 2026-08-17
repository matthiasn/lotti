import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';

/// Resolves the skill a profile's `SkillAssignment` names.
///
/// Built-in skills **live as code, not as DB rows** — see [builtInSkills] —
/// so the registry is authoritative for every id it knows and is consulted
/// first. Ids it does not know (demo-seeded skills, and the per-user layer
/// the skill-management UI will add) fall through to the config store.
///
/// Resolving an assignment through the store *alone* is what this function
/// exists to stop. Nothing ever writes [builtInSkills] into
/// `ai_config.sqlite`: installs carrying those rows got them from an earlier
/// release, and a fresh install has none. Every assignment on every profile
/// then resolves to `null`, so each automated capability the profile owns is
/// silently skipped — and transcription in particular degrades to
/// `ProfileAutomationService`'s direct fallback, a provider-ranked search over
/// every configured audio model that never consults the subject's category or
/// profile at all. The symptom is a category pinned to one provider quietly
/// transcribing through a different one.
///
/// Returns `null` when neither source knows [skillId], or when a stored config
/// with that id turns out not to be a skill.
Future<AiConfigSkill?> resolveAssignedSkill({
  required String skillId,
  required AiConfigRepository aiConfigRepository,
}) async {
  final builtIn = findBuiltInSkill(skillId);
  if (builtIn != null) return builtIn;

  final stored = await aiConfigRepository.getConfigById(skillId);
  return stored is AiConfigSkill ? stored : null;
}
