### Fixed
- **Older journals can upgrade without a missing-column error.** Upgrades from
  early database versions now add task priority columns before creating the
  index that uses them, preserving existing entries during the upgrade.
