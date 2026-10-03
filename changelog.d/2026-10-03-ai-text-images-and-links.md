### Security
- **Images in AI and agent text are no longer loaded.** A summary, report,
  chat reply or reasoning trace that contains an image now shows where the
  image would have come from instead of fetching it. A crafted image link in
  model output could otherwise send data to an outside server the moment the
  text appeared, without a click.
- **Links in AI and agent text only open web pages and email.** Tapping a link
  now opens `https`, `http` and `mailto` addresses and ignores any other kind,
  such as file paths or other apps' links. Links to tasks and other places in
  Lotti work as before.
