### Fixed
- **A default agent template or soul you deleted came back the next time the
  app started.** The app recreated its bundled templates (Laura, Tom, Shepherd
  and the rest) and souls at every start, deleted or not, and put back the
  default soul on a template even after you had removed it or picked another.
  A device that started before your deletion had synced to it could also
  bring the default back on all your devices. Now a default you delete or
  change stays that way everywhere; defaults added in a later version still
  arrive as usual.
