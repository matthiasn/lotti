# Project plaza

Plaza turns a desktop project into a walkable nighttime district. Each task
has a building and a billboard showing its title, status, due date and checklist
progress. Larger signs emphasize priority; overdue work burns above its signs.
Completed tasks have quiet green buildings set back from the street, with green
roof lights that remain readable in the aerial overview.

Open **Explore project** from a project's details, or **Explore category**
under a category in the Projects list. A category has an avenue for each
project. Entering a project opens its own task world; Back returns to the
category. Completed projects occupy the more distant avenues. Category worlds
only show projects within the selected category and the current privacy scope.

Black-and-white penguin companions stroll through the streets and open square,
alone or in pairs, with balancing flippers and orange webbed feet. Companions
occasionally glance toward one another as if in conversation, with eyes leading
the turn and independent blinks. A mix of compact, standard and upright builds
gives the crowd variety. They are ambient scene characters; reduced-motion
settings pause them.

The existing walk, drag-to-look, beacon navigation, search, Home, Overview and
Morning walk remain available. Nearby task facades offer checklist edits and
open the regular task details page. Animated penguin companions walk through the streets and plaza, alone or in pairs.
They respect the system reduced-motion preference.

The feature targets desktop Flutter GPU / Impeller. Unsupported renderers show
an unavailable message with a way back. Mobile controls and agent-directed world
regeneration remain future work.

## Ownership

Plaza owns scene generation, the street and flight geometry, status presentation,
billboards, facade detail levels, camera controls, ambient animation and the
world's navigation routes. Generation accepts configuration rather than fixed
placements, leaving room for alternative layouts.

It delegates project membership and privacy filtering to the journal database,
category definitions to the entity cache, checklist persistence to the existing
persistence service, and task editing to the regular task details page. Rendering
and widget textures belong to `flutter_scene`.

## Code map

- `data/task_projection.dart` projects journal task/checklist facts.
- `data/plaza_repository.dart` reads scoped project and category snapshots.
- `state/project_plaza_provider.dart` refreshes snapshots and the attention clock.
- `scene/project_world_generator.dart` and `category_world_generator.dart`
  generate task timelines and project avenues.
- `domain/` holds geometry, attention, routes, collisions and the Morning walk.
- `scene/` builds geometry, manages facade detail and captures, and animates
  status lights, flames and ambient life.
- `ui/project_plaza_page.dart` and `category_plaza_page.dart` connect app data
  and navigation to the reusable `ui/plaza_view.dart` renderer.
- `ui/` also contains the captured billboard/facade widgets and localized chrome.
- `dev_main.dart` is a separate penguin-fixture launcher for visual review and
  measurements; shipping routes never depend on its demo projection.

For fixture commands, headless checks and measurement limits, see the
[operator notes](../../../docs/plaza/HANDOVER.md). Runtime flow and invariants
live in [the Plaza concept](../../../knowledge/features/plaza.md).
