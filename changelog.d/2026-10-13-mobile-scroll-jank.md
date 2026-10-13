### Fixed
- **Scrolling stays smooth while sync is busy.** Received images and other
  large attachments are now decrypted in the background and downloaded only
  once you stop scrolling or typing. The reminder banners at the top of the
  app no longer reload every time any agent writes something. Together these
  removed the stutter on task details, pages and settings, most noticeable on
  phones.
- **Saving no longer hangs for seconds after sync activity.** A sync
  bookkeeping step read the device's whole sync history each time it ran,
  which held up local saves for two to three seconds on phones with a long
  history. It now reads only the entries it needs.
