### Fixed

- **Accepting a day-plan change can no longer leave a block that ends before
  it starts.** When a suggested change moved the same block twice, the second
  move was checked against where the block used to be rather than where the
  first move put it. Such a change is now refused instead of breaking the
  plan.
