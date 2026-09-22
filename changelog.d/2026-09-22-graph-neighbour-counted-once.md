### Fixed
- **The task graph showed some linked entries twice and overstated its "more
  links" counts.** An entry linked to a task in more than one way — say, both
  as a follow-up and as a blocker, or by a link recorded in each direction —
  was placed in the graph once per link. It could appear twice, crowd other
  entries out of the view, and be counted twice in a "more links · N" bubble.
  Each linked entry now appears once, and the counts match what they hide.
