### Fixed
- **A pull request's details now scroll to the very end of its description.**
  The "Open on GitHub" bar floats over the page, and the last lines of a long
  description stayed hidden behind it however far you scrolled. The page now
  leaves exactly the bar's height of room below the description.
- **Screenshots written as HTML in a pull request's description now show as
  images.** Descriptions that size their screenshots with `<img>` tags, as many
  screenshot tables do, showed the tags as text. They are now loaded and shown
  like any other image of the description, at the width the tag asks for, with
  the full-size viewer and "Add to task".
