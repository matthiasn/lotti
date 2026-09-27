### Fixed
- **An accepted task suggestion no longer undoes you changing the field
  back.** Say you accepted the agent's new title on one device, didn't like
  it and put the old title back, and the same suggestion was then accepted
  on another device that hadn't caught up yet. The agent's title came back,
  because the field looked untouched again. The task now remembers which
  suggestions have already changed it, so each one changes a field at most
  once. The same goes for status, priority, estimate, due date and
  language. Accepting a suggestion again after reopening it no longer
  re-applies it either. To get its value back, edit the field or accept a
  new suggestion. Both devices need this version.
