### Fixed
- **Applying the label picker could remove a label the agent had just
  added.** The picker saved the whole set of labels you chose, so a label the
  task agent added while it was open was taken off again and remembered as
  one you had rejected. The picker now saves only the labels you added or
  removed.
- **A label you removed could come back.** If the task agent had decided to
  add a label just before you took it off, its write put it back. The agent
  now checks the task as it is when it writes, and a label you removed stays
  off.
