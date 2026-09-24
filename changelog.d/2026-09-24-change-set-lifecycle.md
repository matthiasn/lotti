### Fixed
- **A confirmed suggestion could come back as open and be applied twice.**
  When confirming one suggestion failed while you confirmed another in the
  same card, or while the agent withdrew one or a created follow-up task
  updated its checklist moves, the second confirmation could be undone on
  screen after its change had already been made, and confirming it again made
  the change a second time. Every update of a card now changes only its own
  suggestion.
- **Decisions made on two devices at once could be lost.** Confirming a
  suggestion on one device while another device accepted or dismissed a
  different one in the same card kept only one device's decisions once they
  synced, and an applied change could show up as open again. Both devices now
  keep every decision, and a confirmation always wins over a dismissal of the
  same suggestion, since only it was actually applied.
