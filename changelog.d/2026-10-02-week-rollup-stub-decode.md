### Fixed
- **Weekly planning totals stopped updating on a device that had been upgraded
  from an older version.** That older version had stored each week's totals as
  a placeholder it could not read. After the upgrade, every update to those
  totals arriving from another device failed against the placeholder and was
  dropped after a few retries. The placeholder is now replaced by the full
  totals when they arrive.
