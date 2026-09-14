### Changed
- **Check-in composer: failure cards read once and recover in two taps.**
  A failure card announces itself to a screen reader as one whole message;
  a refused microphone offers Type instead and Open settings, with the
  field's own Dictate as the retry; the header's status words sit in the
  quiet ink and only their glyph carries the alert colour; the field's
  accent outline means keyboard focus and nothing else; Re-record stays
  after you edit the transcript and asks before replacing it; the
  transcribing note ends with "usually under a minute"; More's sections
  read as its children; the time picker no longer clips its outer rows;
  and at large text sizes the reason under Save may take two lines.
- **Briefing card: the status line is announced.** Screen readers now hear
  the card go from writing to current or failed; the Steady band is neutral
  rather than the accent that means pressable.

### Fixed
- **The Briefing card's running status was never announced to screen
  readers**, because it sat inside the header's excluded semantics.
