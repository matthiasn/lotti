### Fixed
- **A person's agent briefed with the wrong AI model.** It kept the profile
  its person's category named the day the agent was created, so moving the
  person or changing the category's profile left it on the old one. It now
  follows the person's current category, then your default profile — unless
  you chose a model for that agent yourself, which still wins.

### Changed
- **People and Goals now look and work alike.** A person's category above
  their name is one tap from the category picker. The ⋮ menu is the same
  rounded menu on both pages and dims the page behind it. Editing a person
  reads like editing a goal, ending in a *Your agent* section, and editing a
  goal is one page with one *Save new version* instead of two steps.
- **Agent internals show a person's AI setup**, with the model that runs and
  a tap to change it, as they already did for tasks and goals.
