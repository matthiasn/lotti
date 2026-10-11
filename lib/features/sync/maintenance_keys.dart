/// Settings key recording whether this device has stamped every clockless
/// definition and entry link it holds (ADR 0130): [clocklessRepairDone]
/// once the startup repair finished, or a fresh token written whenever a
/// clockless row from an older peer is stored. The repair records
/// completion only if the token it read before sweeping is still there, so
/// a row stored during a sweep leaves the next start to sweep again.
const clocklessRepairSettingsKey = 'maintenance_clocklessRepairV1';

/// The value of [clocklessRepairSettingsKey] once nothing is left to stamp.
const clocklessRepairDone = 'true';
