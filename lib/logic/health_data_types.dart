import 'package:health/health.dart';

/// The health data types Lotti reads, grouped the way the platforms authorize
/// them.
///
/// These lists are the unit of *permission*, not merely of presentation. Apple
/// Health and Health Connect grant read access per data type, but a user thinks
/// in families — "blood pressure", not "systolic" and "diastolic" — and every
/// system authorization sheet Lotti raises should correspond to one such
/// family. See [permissionFamilyFor].

/// Sleep, including the per-stage types Apple writes from iOS 16 onward.
const sleepTypes = <HealthDataType>[
  HealthDataType.SLEEP_IN_BED,
  HealthDataType.SLEEP_ASLEEP,
  HealthDataType.SLEEP_LIGHT,
  HealthDataType.SLEEP_DEEP,
  HealthDataType.SLEEP_REM,
  HealthDataType.SLEEP_AWAKE,
];

/// Blood pressure. **Always authorized as a pair**: one reading is two samples,
/// and asking for them separately raises two system sheets for what the user
/// turned on or off as a single switch.
const bpTypes = <HealthDataType>[
  HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
  HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
];

const heartRateTypes = <HealthDataType>[
  HealthDataType.RESTING_HEART_RATE,
  HealthDataType.WALKING_HEART_RATE,
  HealthDataType.HEART_RATE_VARIABILITY_SDNN,
];

const bodyMeasurementTypes = <HealthDataType>[
  HealthDataType.WEIGHT,
  HealthDataType.BODY_FAT_PERCENTAGE,
  HealthDataType.BODY_MASS_INDEX,
  HealthDataType.HEIGHT,
];

const activityTypes = <HealthDataType>[
  HealthDataType.STEPS,
  HealthDataType.FLIGHTS_CLIMBED,
  HealthDataType.DISTANCE_WALKING_RUNNING,
];

const workoutTypes = <HealthDataType>[HealthDataType.WORKOUT];

/// Every family, in the order the Health Import page lists them.
///
/// A type absent from all of these is its own family — [permissionFamilyFor]
/// falls back to a single-element list rather than dropping it, so a type added
/// to a fetcher without being added here still gets authorized.
const healthPermissionFamilies = <List<HealthDataType>>[
  activityTypes,
  sleepTypes,
  heartRateTypes,
  bpTypes,
  bodyMeasurementTypes,
  workoutTypes,
];

/// The family [type] must be authorized with, or `[type]` if it belongs to none.
List<HealthDataType> permissionFamilyFor(HealthDataType type) {
  for (final family in healthPermissionFamilies) {
    if (family.contains(type)) {
      return family;
    }
  }
  return <HealthDataType>[type];
}

/// Expands [types] to the union of the families they belong to,
/// de-duplicating.
///
/// Families appear in the order their first member is encountered in [types];
/// within a family, [healthPermissionFamilies] order is preserved. There is no
/// global ordering guarantee, and nothing needs one — the result is handed to
/// `requestAuthorization` as a set of types to authorize together.
///
/// This is what turns a dashboard's per-series request — the blood-pressure
/// card asks for systolic and diastolic independently, one background import
/// each — into a single authorization covering both.
List<HealthDataType> expandToPermissionFamilies(
  Iterable<HealthDataType> types,
) {
  final expanded = <HealthDataType>{};
  for (final type in types) {
    expanded.addAll(permissionFamilyFor(type));
  }
  return expanded.toList();
}

/// Sleep stages that are additionally stored under the generic
/// `HealthDataType.SLEEP_ASLEEP` type.
///
/// Apple splits sleep into core, deep and REM from iOS 16 / watchOS 9 onward
/// (`SLEEP_LIGHT`, `SLEEP_DEEP`, `SLEEP_REM` in plugin terms) and reserves the
/// generic category for `asleepUnspecified` — which is all an older phone, or a
/// sleep entry added by hand in the Health app, ever writes. The "Asleep"
/// dashboard charts the generic type, so each staged sample is stored a second
/// time under it to keep one comparable series across both eras.
///
/// This set previously named `SLEEP_ASLEEP_CORE` and `SLEEP_ASLEEP_UNSPECIFIED`,
/// which are not values of the plugin's enum and so matched nothing. Deep and
/// REM matched by luck; core — the *largest* stage of a typical night — did not,
/// and the "Asleep" chart lost roughly half of every staged night.
const sleepStagesDuplicatedAsAsleep = <String>{
  'HealthDataType.SLEEP_LIGHT',
  'HealthDataType.SLEEP_DEEP',
  'HealthDataType.SLEEP_REM',
};
