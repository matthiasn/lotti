### Fixed
- **Confirm all on a person's suggestions could stop partway.** The batch ran
  inside the suggestions band itself, and the chat shows that band only while
  it is on screen, so scrolling away mid-batch quietly left the remaining
  suggestions unconfirmed. The batch now runs on its own, and every
  suggestion you confirmed together is applied whether or not the band is
  still showing.
