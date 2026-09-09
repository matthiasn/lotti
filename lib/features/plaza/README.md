# Project plaza

Plaza turns a desktop project into a walkable nighttime district. Each task
has a building and a billboard showing its title, status, due date and checklist
progress. Larger signs emphasize priority; overdue work burns above its signs.
Completed tasks have quiet green buildings set back from the street, with green
roofs that remain readable in the aerial overview. Recessed shopfronts and
stepped tower silhouettes give each task a place along the avenue. Glass media
towers, structural façade details and illuminated crowns extend that character
into a denser surrounding city with closer street frontage and a fuller skyline;
soft light spills connect signs to the paving.

Linked tasks are joined by sagging cables above their roofs, with fixed lamps
and travelling lights. Directed relationships flow from source to destination;
ordinary associations flow both ways. Selecting a task or looking at it highlights its incident
cables. **Connections** hides or shows the cables without changing task data.
Only links whose endpoints are visible in the same project are included.

Open **Explore project** from a project's details, or **Explore category**
under a category in the Projects list. A category has an avenue for each
project. Entering a project opens its own task world; Back returns to the
category. Completed projects occupy the more distant avenues. Category worlds
only show projects within the selected category and the current privacy scope.

Black-and-white penguin companions stroll through the streets and open square,
alone or in pairs, with balancing flippers and orange webbed feet. Companions
occasionally glance toward one another as if in conversation, with eyes leading
the turn and independent blinks. A mix of compact, standard and upright builds
gives the crowd variety. Smaller penguins share the district with tawny meerkats,
which scamper on four paws, forage and frequently rise into a lookout facing the
camera. Both species start hidden; separate **Penguins** and **Meerkats**
checkboxes show each species.
Shared traffic control gives them room to finish steps and yield at crossings.
Reduced-motion settings pause both species.

The existing walk, drag-to-look, beacon navigation, search, Home, Overview and
Morning walk remain available. Flights follow rounded curves with gentle turns
and climbs. Hold **Shift** while walking or flying for **8× speed** through the
district. Nearby task facades offer checklist edits and
open the regular task details page.

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
