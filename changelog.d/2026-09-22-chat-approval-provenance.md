### Fixed
- **The task agent could suggest undoing a rename or archive you approved in
  chat.** Checking items off in chat was already protected, but a title change
  or an archived item you accepted there looked like any other edit to the
  agent, so it could propose renaming the item back or restoring it. Approved
  titles and archive states are now held to the same rule as check-offs: the
  agent leaves them alone until you approve something new.
