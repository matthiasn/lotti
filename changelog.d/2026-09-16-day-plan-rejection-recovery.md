### Fixed

- **A day plan is no longer lost to one malformed piece of it.** A stray empty
  buffer block, an energy band the assistant got wrong, or a plan sent as text
  rather than a list used to discard the whole schedule; the plan is now kept
  and the bad part dropped. Work itself is still never silently discarded.
