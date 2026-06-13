// Shared (planned, recorded, expected) table — the same `inMinutes /
// inMinutes` formula backs both TimeBudgetProgress.progressFraction and
// DayBudgetStats.progressFraction, including the sub-minute truncation
// edge case (30s planned → 0 inMinutes → fraction 0).
const progressFractionCases = <(Duration, Duration, double, String)>[
  (Duration(hours: 2), Duration(hours: 1), 0.5, 'normal values'),
  (Duration.zero, Duration(hours: 1), 0.0, 'planned is zero'),
  (Duration.zero, Duration.zero, 0.0, 'both zero'),
  (Duration(hours: 2), Duration.zero, 0.0, 'recorded is zero'),
  (Duration(hours: 2), Duration(hours: 2), 1.0, 'recorded == planned'),
  (Duration(hours: 2), Duration(hours: 3), 1.5, 'over budget'),
  (Duration(minutes: 90), Duration(minutes: 45), 0.5, 'integer minutes'),
  (
    Duration(seconds: 30),
    Duration(seconds: 15),
    0.0,
    'sub-minute planned truncates to zero',
  ),
];
