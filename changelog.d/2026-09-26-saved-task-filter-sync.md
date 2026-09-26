### Fixed
- **Saved task filters created on one device could be missing on another.**
  Filters saved before saved filters synced were never sent, a filter that
  arrived from another device did not show until the app restarted, and
  reordering the list in the meantime deleted it from that device for good.
  A change that failed to send was not retried, and a delete or an edit from
  a device whose clock ran behind could settle differently on each device.
  Every saved filter now reaches every device and stays there: changes are
  sent until they get through, arriving filters appear right away, and
  deletes and edits end the same way everywhere. Filters that exist on only
  one device are sent the first time the updated app starts.
