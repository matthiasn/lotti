# English manual translation notes

These are observations made while verifying the English manual against the
production UI. They are intentionally informational: manual work does not edit
application localization without a separate localization change.

## Config Flags: private-entry description

- **ARB key:** `configFlagPrivateDescription`
- **Current wording:** “Enable this to make your entries private by default.
  Private entries are only visible to you.”
- **Screen:** Settings → Advanced Settings → Config Flags, below **Show private
  entries?**
- **Why it feels off:** the `private` config flag is consumed as a
  `showPrivateEntries` visibility control by journal, event, task, category,
  and label surfaces. The description instead sounds like it changes the
  default privacy of newly created entries.
- **Possible direction:** describe including or hiding private entries in app
  lists and selectors, while keeping the privacy of existing and newly created
  entries out of this flag's scope.
