### Fixed
- **Hiding or collapsing a linked entry could bring back a link you had
  removed.** The hide and collapse toggles saved the link as the card had last
  shown it, and that save always won: a link removed meanwhile — on this
  device or another — came back everywhere, and a hidden or collapsed state
  set on another device in between was undone. The toggles now change only
  their own setting on the link as it is stored, and leave a removed link
  removed.
