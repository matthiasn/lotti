### Fixed
- **The day planner could invent filler work on a day with nothing to plan.**
  The planner was never told that a plan for a day still under way needs at
  least one block. When it had nothing to schedule, or everything was blocked,
  it sent an empty plan, got it rejected, and sometimes tried again with
  made-up blocks like "Open flexible time". It is now told to leave a single
  buffer block with a note saying why the day is empty.
