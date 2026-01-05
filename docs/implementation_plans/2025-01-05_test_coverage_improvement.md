# Test Coverage Improvement Plan: lib/utils, lib/logic, lib/services

**Goal:** Achieve 90%+ test coverage for all three directories

**Current State:**
- `lib/utils/`: 4.3% (13/303 lines)
- `lib/logic/`: 0.0% (0/667 lines)
- `lib/services/`: 0.7% (5/723 lines)

**Target:** 90%+ for each directory (~1,523 lines to cover)

---

## Executive Summary

The extremely low coverage numbers are misleading - many test files exist but aren't being counted in coverage. The primary gaps are:

| Priority | File | Current | Lines | Effort |
|----------|------|---------|-------|--------|
| CRITICAL | persistence_logic.dart | 0% | 248 | High |
| CRITICAL | image_import.dart | 0% | 197 | High |
| HIGH | health_import.dart | 0% | 166 | Medium |
| HIGH | vector_clock_service.dart | 0% | 41 | Low |
| HIGH | notification_service.dart | 0% | 78 | Medium |
| HIGH | logging_service.dart | 0% | 73 | Medium |
| MEDIUM | nav_service.dart | 0% | 83 | Medium |
| MEDIUM | entities_cache_service.dart | 0% | 87 | Medium |
| MEDIUM | editor_state_service.dart | 0% | 45 | Low |
| MEDIUM | location.dart | 0% | 61 | Medium |
| MEDIUM | file_utils.dart | 0% | 81 | Medium |
| LOW | All others | Various | ~363 | Low-Medium |

---

## Phase 1: lib/utils Tests (Target: 90%+)

### 1.1 Files Needing New Tests

#### timezone.dart (0% → 90%) - HIGH PRIORITY
**File:** `lib/utils/timezone.dart` (8 lines)
**New test file:** `test/utils/timezone_test.dart`

```dart
// Tests needed:
- getLocalTimezone() returns valid timezone on non-Linux
- getLocalTimezone() reads /etc/timezone on Linux
- getLocalTimezone() handles missing timezone file
- getLocalTimezone() handles test environment flag
```

**Mocking needed:**
- File I/O (use IOOverrides or abstraction)
- Platform detection

#### platform.dart (17% → 90%) - LOW PRIORITY
**File:** `lib/utils/platform.dart` (6 lines)
**Note:** Platform detection variables are compile-time constants. Testing requires conditional compilation or acceptance that these are integration-level.

**Approach:** Document that platform.dart is excluded from unit test coverage due to compile-time nature. Integration tests cover indirectly.

### 1.2 Files Needing Test Improvements

#### audio_utils.dart (0% → 90%)
**Existing tests:** `test/utils/audio_utils_test.dart` ✓
**Issue:** Tests exist but not counted in coverage
**Action:** Verify tests run correctly, add missing edge cases:
- Empty audioDirectory/audioFile
- Unicode paths
- Special characters

#### color.dart (41% → 90%)
**Existing tests:** `test/utils/color_test.dart` ✓
**Missing tests:**
- `colorHexChannel()` direct tests
- Invalid hex strings (wrong length, invalid chars)
- Alpha channel edge cases (00, FF)
- `leadingHashSign: false` parameter

#### date_utils_extension.dart (0% → 90%)
**Existing tests:** `test/utils/date_utils_extension_test.dart` ✓
**Missing tests:**
- `md` format method
- `ymwd` format method
- Leap year dates
- DST transition dates

#### file_utils.dart (0% → 90%)
**Existing tests:** `test/utils/file_utils_test.dart` ✓
**Missing tests:**
- `folderForJournalEntity()` for all entity types
- `typeSuffix()` for all entity types
- Concurrent file writes
- Permission error handling

#### image_utils.dart (0% → 90%)
**Existing tests:** `test/utils/image_utils_test.dart` ✓
**Missing tests:**
- `compressAndSave()` - requires mocking FlutterImageCompress
- Android vs iOS path format differences
- Null/empty path handling

#### location.dart (0% → 90%)
**Existing tests:** `test/utils/location_test.dart`, `test/utils/location_fallback_test.dart` ✓
**Missing tests:**
- Windows platform behavior (returns null)
- Concurrent location requests
- Location initialization failures
- Network errors in IP geolocation

#### measurable_utils.dart (0% → 90%)
**Existing tests:** `test/utils/measurable_utils_test.dart` ✓
**Missing tests:**
- Tied popularity values (order stability)
- n > available unique values
- Float precision edge cases

#### screenshots.dart (0% → 90%)
**Existing tests:** Multiple test files exist ✓
**Missing tests:**
- Process timeout handling
- Tool failure scenarios

#### segmented_button.dart (0% → 90%)
**Existing tests:** `test/utils/segmented_button_test.dart` ✓
**Missing tests:**
- Custom semanticsLabel behavior
- Very long labels
- Unicode in labels

#### sort.dart (0% → 90%)
**Existing tests:** `test/utils/sort_test.dart` ✓
**Missing tests:**
- Empty filter string behavior
- Special characters in dashboard names
- Duplicate dashboard names

#### string_utils.dart (0% → 90%)
**Existing tests:** `test/utils/string_utils_test.dart` ✓ (comprehensive)
**Action:** Verify tests run and are counted

#### uuid.dart (0% → 90%)
**Existing tests:** `test/utils/uuid_test.dart` ✓ (comprehensive)
**Action:** Verify tests run and are counted

#### entry_utils.dart (0% → 90%)
**Existing tests:** `test/utils/entry_utils_test.dart` ✓
**Missing tests:**
- Very long strings
- Unicode content
- Empty string (non-null)

#### form_utils.dart (0% → 90%)
**Existing tests:** `test/utils/form_utils_test.dart` ✓
**Missing tests:**
- Scientific notation
- Very large numbers
- Leading/trailing spaces

#### geohash.dart (0% → 90%)
**Existing tests:** Via location_test.dart
**Known issue:** Library bug with negative coordinates
**Missing tests:**
- Boundary coordinates (poles, date line)
- Very close coordinates (precision)

#### cache_extension.dart (100%) ✓
No action needed.

#### screenshot_consts.dart (100%) ✓
No action needed.

---

## Phase 2: lib/logic Tests (Target: 90%+)

### 2.1 persistence_logic.dart - CRITICAL (0% → 90%)

**File:** `lib/logic/persistence_logic.dart` (248 lines)
**Existing tests:** `test/logic/persistence_logic_test.dart`, `test/logic/persistence_logic_update_test.dart`

**Major untested methods:**

#### Metadata Methods
```dart
createMetadata() - Core metadata creation with vector clock
updateMetadata() - Metadata updates with clearing flags
```

**Tests needed:**
- UUID v5 generation for deduplication
- Timezone handling
- Vector clock integration
- Clearing categoryId/labelIds flags

#### Entry Creation Methods
```dart
createSurveyEntry()
createHabitCompletionEntry()
createAiResponseEntry()
```

**Tests needed:**
- Survey data handling and linking
- Habit completion with notification scheduling
- AI response linking and notifications

#### Link Management
```dart
createLink() - Creates entity links
```

**Tests needed:**
- Link creation between entities
- Sync message enqueueing
- Update notifications

#### Geolocation Methods
```dart
addGeolocationAsync() - Race condition prevention
addGeolocation() - Fire-and-forget wrapper
```

**Tests needed:**
- Concurrent call prevention
- Null geolocation handling
- Existing geolocation preservation

#### Update Methods
```dart
updateJournalEntityText() - Type-specific text updates
updateTask() - Task priority denormalization
updateEvent() - Event data updates
updateJournalEntity() - Label preservation
```

**Tests needed:**
- Type checking for each entity type
- Priority/rank column updates
- Label ID preservation
- Exception handling

#### Definition Methods
```dart
upsertEntityDefinition()
upsertDashboardDefinition()
deleteDashboardDefinition()
```

**Tests needed:**
- Soft delete behavior
- Notification cancellation
- Sync message handling

**Mocking required:**
- JournalDb (multiple methods)
- VectorClockService
- UpdateNotifications
- OutboxService
- TagsService
- NotificationService
- Fts5Db
- LoggingService
- DeviceLocation

### 2.2 image_import.dart - CRITICAL (0% → 90%)

**File:** `lib/logic/image_import.dart` (197 lines)
**Existing tests:** Several partial test files exist

**Untested functions (marked @visibleForTesting):**

```dart
parseRational(String value) → double?
parseGpsCoordinate(dynamic coordData, String ref) → double?
extractGpsCoordinates(Uint8List data, DateTime createdAt) → Future<Geolocation?>
parseAudioFileTimestamp(String filename) → DateTime?
selectAudioMetadataReader() → AudioMetadataReader
extractDurationWithMediaKit(String filePath) → Future<Duration>
computeAudioRelativePath(DateTime timestamp) → String
computeAudioTargetFileName(DateTime timestamp, String extension) → String
```

**Tests needed:**

#### Rational Number Parsing
- Fraction format (123/456)
- Decimal format
- Divide by zero
- Invalid input

#### GPS Coordinate Parsing
- Valid coordinates (N/S/E/W)
- Degrees/minutes/seconds conversion
- Null/invalid coordData
- Directional signs

#### EXIF Extraction
- Missing EXIF data
- Invalid GPS keys
- Geohash generation

#### Audio Import
- Lotti filename format parsing
- Duration extraction with timeout
- Path/filename computation
- Test environment detection

**Private functions needing indirect testing:**
```dart
_createAnalysisCallback()
_extractImageTimestamp()
_parseExifDateTime()
```

**Import workflows:**
```dart
importPastedImages() - Clipboard image import
importGeneratedImageBytes() - AI-generated image import
importDroppedAudio() - Audio file drag-drop
handleDroppedMedia() - Media type routing
```

**Mocking required:**
- PhotoManager, AssetPicker
- JournalRepository, SpeechRepository
- File operations
- exif.readExifFromBytes
- Player (media_kit)
- LoggingService

### 2.3 health_import.dart - HIGH (0% → 90%)

**File:** `lib/logic/health_import.dart` (166 lines)
**Existing tests:** `test/logic/health_import_test.dart`

**Missing coverage:**

#### Platform Detection
```dart
getPlatform() - iOS/Android/desktop detection
```

#### Queue Management
```dart
_fetchHealthDataDelta() - Queue handling
_start() - Queue processing
```

#### Mobile Platform Behavior
- All current tests run on desktop
- Need tests for iOS/Android health data fetching
- Authorization failure paths

#### Type Mapping
- BLOOD_PRESSURE type handling
- BODY_MASS_INDEX type handling
- Sleep type duplication logic

**Mocking required:**
- DeviceInfoPlugin
- HealthService
- PersistenceLogic
- JournalDb

### 2.4 Already Well-Tested (Verify Coverage Counting)

- `autocomplete_update.dart` - 29 tests, 100% logic coverage
- `entry_creation_service.dart` - 5 tests, good coverage
- `create_entry.dart` - 11 tests, good coverage

---

## Phase 3: lib/services Tests (Target: 90%+)

### 3.1 Services Needing New Test Files

#### vector_clock_service.dart - HIGH (0% → 90%)
**File:** `lib/services/vector_clock_service.dart` (41 lines)
**New test file:** `test/services/vector_clock_service_test.dart`

**Tests needed:**
```dart
init() - Initialization and state loading
increment() - Counter increment
setNewHost() - Host UUID generation
getHost() - Host retrieval
setNextAvailableCounter() - Counter persistence
getNextAvailableCounter() - Counter retrieval
getHostHash() - SHA1 hash generation
getNextVectorClock() - Vector clock creation with merge
```

**Mocking required:**
- SettingsDb

#### dev_logger.dart - HIGH (0% → 90%)
**File:** `lib/services/dev_logger.dart` (15 lines)
**New test file:** `test/services/dev_logger_test.dart`

**Tests needed:**
```dart
log() - Basic logging
warning() - Warning level
error() - Error with stacktrace
clear() - Log clearing
capturedLogs - Log capture
suppressOutput - Output suppression
```

#### dev_log.dart - LOW (0% → 90%)
**File:** `lib/services/dev_log.dart` (4 lines)
**New test file:** `test/services/dev_log_test.dart`

**Tests needed:**
- `lottiDevLog()` delegates to DevLogger
- Assert behavior in debug mode

#### link_service.dart - HIGH (0% → 90%)
**File:** `lib/services/link_service.dart` (21 lines)
**New test file:** `test/services/link_service_test.dart`

**Tests needed:**
```dart
createLink() - Link creation flow
linkTo() - Setting target
linkFrom() - Setting source
```

**Edge cases:**
- Both IDs null
- Only one ID set
- Timer clearing after 2 minutes
- Tag filtering

**Mocking required:**
- PersistenceLogic
- TagsService
- JournalDb
- HapticFeedback

#### share_service.dart - LOW (0% → 90%)
**File:** `lib/services/share_service.dart` (3 lines)
**New test file:** `test/services/share_service_test.dart`

**Tests needed:**
- `shareText()` with text and subject
- Empty text handling

**Note:** Platform integration limits testability

#### portal_service.dart - MEDIUM (0% → 90%)
**File:** `lib/services/portals/portal_service.dart` (53 lines)
**New test file:** `test/services/portals/portal_service_test.dart`

**Tests needed:**
```dart
isRunningInFlatpak - Environment detection
shouldUsePortal - Portal availability check
createHandleToken() - Token generation
isInterfaceAvailable() - DBus interface check
```

**Mocking required:**
- Platform.environment
- DBusClient

### 3.2 Services Needing Test Improvements

#### notification_service.dart (0% → 90%)
**Existing tests:** `test/services/notification_service_test.dart` (minimal)

**Missing tests:**
```dart
updateBadge() - Badge count logic
scheduleHabitNotification() - Habit scheduling
scheduleNotification() - Generic scheduling
cancelNotification() - Notification removal
showNotification() - Immediate notification
```

**Platform-specific tests needed:**
- iOS initialization
- macOS badge handling
- Linux notification plugin
- Permission handling

**Mocking required:**
- FlutterLocalNotificationsPlugin
- JournalDb
- Timezone utilities

#### logging_service.dart (0% → 90%)
**Existing tests:** `test/services/logging_service_test.dart`

**Missing tests:**
- `captureEvent()` with all parameters
- `captureException()` with stacktrace
- Database failure with file fallback
- Config flag listening
- Logging disabled state

**Mocking required:**
- LoggingDb
- File I/O
- JournalDb

#### nav_service.dart (0% → 90%)
**Existing tests:** `test/services/nav_service_test.dart`

**Missing tests:**
- `restoreRoute()` - Route restoration
- Feature flag dynamic index calculation
- Tab switching with configuration changes
- Route persistence round-trip

**Mocking required:**
- JournalDb
- SettingsDb
- BeamerDelegate instances

#### editor_state_service.dart (0% → 90%)
**Existing tests:** `test/services/editor_state_service_test.dart`

**Missing tests:**
- `getUnsavedStream()` - Stream emissions
- Draft synchronization
- Debounce timing (2s normal, 0 in test)
- Selection tracking

**Mocking required:**
- EditorDb
- JournalDb
- QuillController

#### entities_cache_service.dart (0% → 90%)
**Existing tests:** `test/services/entities_cache_service_test.dart` (43+ tests)

**Verify coverage is counting correctly**

Additional edge cases if needed:
- Stream coordination timing
- Cache invalidation
- Orphan pruning edge cases

#### health_service.dart (0% → 90%)
**Existing tests:** `test/services/health_service_test.dart`

**Missing tests:**
- Authorization denied scenario
- Invalid date ranges
- Empty health data results

#### time_service.dart (0% → 90%)
**Existing tests:** `test/services/time_service_test.dart`

**Missing tests:**
- Starting while already started
- Stream emission timing
- Null entity handling

#### db_notification.dart (0% → 90%)
**Existing tests:** `test/services/db_notification_test.dart`

**Missing tests:**
- Batching timing (100ms normal, 1s sync)
- Dispose safety
- Multiple notifier coordination

#### app_prefs_service.dart (25% → 90%)
**Existing tests:** `test/services/app_prefs_service_test.dart`

**Missing tests:**
- `clearPrefsByPrefix()` batch operation
- Test environment default returns

#### ip_geolocation_service.dart (0% → 90%)
**Existing tests:** `test/services/ip_geolocation_service_test.dart` (13+ tests)

**Verify coverage is counting correctly**

#### tags_service.dart (0% → 90%)
**Existing tests:** `test/services/tags_service_test.dart` (16 tests)

**Verify coverage is counting correctly**

### 3.3 Portal Services

#### screenshot_portal_service.dart (0% → 90%)
**Existing tests:** `test/services/portals/screenshot_portal_service_test.dart`

**Missing tests:**
- User cancellation (response code 1)
- Portal error (response code 2)
- Cross-device rename fallback
- Timeout handling

---

## Implementation Order

### Week 1: Critical Files
1. **persistence_logic.dart** - Core business logic
2. **vector_clock_service.dart** - Foundation for sync
3. **image_import.dart** - @visibleForTesting functions

### Week 2: High Priority Services
4. **logging_service.dart** - Error tracking
5. **notification_service.dart** - User notifications
6. **link_service.dart** - Entity relationships
7. **health_import.dart** - Mobile platform tests

### Week 3: Medium Priority
8. **nav_service.dart** - Navigation logic
9. **editor_state_service.dart** - Draft management
10. **file_utils.dart** - File operations
11. **location.dart** - Geolocation

### Week 4: Lower Priority & Verification
12. **dev_logger.dart** / **dev_log.dart**
13. **share_service.dart**
14. **portal_service.dart**
15. Verify existing tests count in coverage
16. Add edge cases to well-tested files

---

## Test Infrastructure Notes

### Mocking Patterns Used in Codebase
- `setUpTestGetIt()` for dependency injection
- `MockJournalDb`, `MockSettingsDb` for database
- `fakeAsync` for time-dependent tests
- `ProviderContainer` overrides for Riverpod

### Test File Naming Convention
- `test/{module}/{file}_test.dart`
- Integration tests: `*_integration_test.dart`

### Running Coverage
```bash
fvm flutter test --coverage
# Analyze specific directories
lcov --summary coverage/lcov.info --include "lib/utils/*" "lib/logic/*" "lib/services/*"
```

---

## Success Criteria

- [ ] lib/utils/ coverage ≥ 90%
- [ ] lib/logic/ coverage ≥ 90%
- [ ] lib/services/ coverage ≥ 90%
- [ ] All tests pass
- [ ] No regressions in existing functionality
- [ ] Test README updated with new patterns

---

## Files Summary

### New Test Files to Create (7)
1. `test/utils/timezone_test.dart`
2. `test/services/vector_clock_service_test.dart`
3. `test/services/dev_logger_test.dart`
4. `test/services/dev_log_test.dart`
5. `test/services/link_service_test.dart`
6. `test/services/share_service_test.dart`
7. `test/services/portals/portal_service_test.dart`

### Existing Test Files to Enhance (25+)
- All files listed in Phases 1-3 with "Missing tests" sections

### Source Files (Total: 44)
- lib/utils/: 20 files
- lib/logic/: 6 files
- lib/services/: 18 files (including portals/)
