### Changed
- **After a call, the person page asks instead of assuming.** Coming back from
  a call or message started in Lotti, the offer now reads "Did you reach Pip?"
  rather than stating that you called — the app only knows the dialer opened.
  Its "Yes, log it" no longer competes with the filled "Log check-in" below.

### Fixed
- **Closing a check-in prefilled with a call lost the call.** Backing out of
  the sheet — even by accident — cleared what the app knew about the call.
  The offer now comes back with it until you log it, dismiss it, or it expires.
