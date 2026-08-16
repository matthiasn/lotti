import 'package:lotti/features/nudges/model/nudge_entity_view.dart';

/// Which agent kind a banner speaks for. The dock renders every kind
/// through one substrate; the kind decides surfaces and semantics
/// (ADR 0059 Decision 6).
enum NudgeBannerKind { goal, relationship }

/// The navigation surfaces the shell may show the banner dock on. The
/// shell maps its own destination kinds onto these; the dock filters its
/// tenants per kind with [nudgeKindShowsOn].
enum NudgeBannerSurface { tasks, dailyOs, habits, people }

/// Whether [kind]'s banners may speak on [surface] — the per-kind
/// visibility gate (ADR 0059 Decision 6): goal nudges keep exactly their
/// pre-generalization surfaces; relationship nudges add the People pages.
///
/// Both switches are deliberately exhaustive with no default: adding a
/// kind OR a surface must force an explicit decision here rather than
/// silently granting the new surface to every existing kind.
bool nudgeKindShowsOn(NudgeBannerKind kind, NudgeBannerSurface surface) =>
    switch (kind) {
      NudgeBannerKind.goal => switch (surface) {
        NudgeBannerSurface.tasks ||
        NudgeBannerSurface.dailyOs ||
        NudgeBannerSurface.habits => true,
        NudgeBannerSurface.people => false,
      },
      NudgeBannerKind.relationship => switch (surface) {
        NudgeBannerSurface.tasks ||
        NudgeBannerSurface.dailyOs ||
        NudgeBannerSurface.habits ||
        NudgeBannerSurface.people => true,
      },
    };

/// One live banner: the nudge, the subject it advertises for (a goal
/// title, a person's name), its kind, and where a tap lands. Sources
/// (one provider per kind) build these; the dock and the sheets consume
/// them without knowing the kind's domain.
typedef NudgeBannerEntry = ({
  NudgeEntityView nudge,
  String subjectTitle,
  NudgeBannerKind kind,
  String tapRoute,
});
