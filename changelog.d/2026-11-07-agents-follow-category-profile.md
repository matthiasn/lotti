### Fixed
- **Changing a category's AI profile now reaches the agents already in it.** An
  agent created from its category's profile kept a copy of that profile for
  good, so moving a category from a Whisper profile to a Voxtral one left its
  people, goals, tasks and projects transcribing and thinking on Whisper. Agents
  now look up their profile on every run: the one you picked for the agent
  first, then whatever the category names now, then your Settings default. The
  projects list names the profile each agent actually runs on.
- **Task agents in a category without its own AI profile no longer start
  switched off.** They, and project agents in such a category, now run on your
  Settings default until the category names a profile. Task agents created
  switched off this way before are turned back on; agents you turned off
  yourself stay off.
- **Names of the people in a category are spelled right in its recordings.**
  Every recording and dictation filed in a category now hands the speech
  model the names of the people in that category, and the correction that
  follows a Whisper transcript fixes misheard ones — even in a category with
  no speech dictionary entries. Private people are never sent.
