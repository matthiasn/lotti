### Fixed
- **Goals no longer leave callbacks running after navigation or refresh.**
  Pending progress and banner reads stop when their view is disposed, avoiding
  late provider errors and unnecessary deadline timers.
- Goal banners reuse the loaded goal list during banner-only refreshes,
  reducing repeated database reads.
