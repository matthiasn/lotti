/// Settings key recording that this device has stamped its clockless
/// definitions and entry links since the last clockless one arrived
/// (ADR 0130). The startup repair sets it; receiving a clockless row from an
/// older peer clears it.
const clocklessRepairSettingsKey = 'maintenance_clocklessRepairV1';
