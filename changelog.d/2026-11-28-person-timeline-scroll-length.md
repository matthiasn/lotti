### Fixed
- **Scrolling back up a person's history redrew rows you had just seen.** The
  page kept only what was on screen, so every row was built again on the way
  back up, its photos loading a second time. It now keeps a couple of screens
  either side ready, and the way back up shows the rows as you left them.
- **A person's history seemed many times longer than it is once a recording's
  words were opened.** With *Show more* open on a long recording, the page
  worked out its length from that one tall row: the scrollbar thumb shrank and
  jumped whenever the row was on screen — most of all when scrolling back up to
  it — and dragging the thumb or jumping to the end overshot. The history now
  keeps a steady length however many rows are opened.
