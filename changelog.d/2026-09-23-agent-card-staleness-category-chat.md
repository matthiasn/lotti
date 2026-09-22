### Fixed
- **The task's AI summary no longer looks current while an update is
  waiting.** After you changed a task, the summary card said nothing until the
  agent's short update countdown ran out, so an out-of-date summary read as if
  it were current. The card now shows *Out of date*, with *Update now* beside
  it, from the moment the change is queued.
- **"Ask about this category" now knows which category you are asking
  about.** The chat was given only an internal identifier, never the
  category's name or its knowledge brief, and in a busy category it saw an
  arbitrary handful of tasks — so its answers often made little sense. It now
  receives the category's name and knowledge brief, can answer from the brief
  directly, and looks at the most recently updated tasks first.
