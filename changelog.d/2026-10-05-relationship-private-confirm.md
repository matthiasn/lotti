### Fixed
- **Confirming a suggested task could fail for good while private entries
  were hidden.** A suggestion made from a private check-in was applied with
  the same reads that hide private entries from the screen, so with private
  entries hidden the check-in looked gone, the confirmation failed, and the
  suggestion was withdrawn on every device. Confirming now reads what the
  agent read, and the task is created, private like its check-in.
