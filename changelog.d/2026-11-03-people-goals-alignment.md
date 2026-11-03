### Fixed
- **A person's agent could brief with an outdated AI profile.** It kept the
  profile that the person's category named when the agent was created, so
  moving the person to another category, or changing that category's profile,
  left the agent on the old one. It now follows the person's current category,
  then your default profile — unless you chose an AI setup for that agent
  yourself, which still wins.

### Changed
- **People and Goals now look and work alike.** The category above a
  person's or a goal's name is one tap from the category picker. The ⋮ menu
  is the same rounded menu on both pages and dims the page behind it. Editing
  a person reads like editing a goal, ending in a *Your agent* section, and
  editing a goal is one page with *Cancel* and one *Save new version* instead
  of two steps — leaving it with unsaved changes asks first.
- **Agent internals show a person's AI setup**, with the model that runs and
  a tap to change it, as they already did for tasks and goals.
