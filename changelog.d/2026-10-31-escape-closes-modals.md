### Fixed
- **Escape now closes a sheet even while you are typing in it.** Most sheets
  and pickers ignored Escape as soon as a text field or button inside them had
  focus, so the key worked only on a sheet you had not touched yet. Escape now
  closes any modal that a click outside would close, including the dashboard
  editor panel, the onboarding welcome and the demo AI setup. The mobile
  navigation drawer and the Daily OS check-in spotlight close on Escape too.
  A form with unsaved changes still asks first.

### Changed
- **Every "are you sure?" question now looks the same.** Deleting a label, a
  category, a dictionary term, a checklist, a goal, a day plan, a recording,
  an AI response, an agent, a soul or a template, rolling back a template or a
  soul, and the backfill recovery confirmations all use the app's standard
  confirmation sheet. It is a bottom sheet on a phone and a dialog on a wide
  window, and deletes are marked as destructive throughout. Deleting a
  checklist used to look like a harmless action.
