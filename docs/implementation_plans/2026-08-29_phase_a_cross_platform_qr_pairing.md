# Phase A — cross-platform QR pairing

**Status:** implemented; macOS and Linux webcam scanning confirmed, remaining
packaging and edge-case acceptance pending
**Date:** 2026-08-29

## Codebase findings

The current branch already implements the mobile-generation half of the brief:

- `SyncDevicesList` exposes **Add device** without a desktop gate.
- `ProvisionedSyncPage` renders the configured device roster on mobile, so an
  Android phone or tablet can reach that action directly.
- `AddDeviceModal` calls `ProvisioningController.regenerateHandover()` and
  renders the v2 handover bundle with `QrImageView`; its QR size is constrained
  by both width and viewport height.
- The joining flow already scans on Android/iOS with `mobile_scanner`, verifies
  the independently-derived pairing code, and retains paste/manual entry as a
  fallback.

The remaining limitation is in `bundle_import_page.dart`: `_manualEntry` starts
true for every desktop and the camera action is exposed only when `isMobile`.

## Implementation

### 1. Preserve mobile QR generation

No second QR generator is needed. Keep the existing flow in:

- `lib/features/sync/ui/widgets/matrix/sync_devices_list.dart`
- `lib/features/sync/ui/provisioned/add_device_page.dart`
- `lib/features/sync/ui/provisioned_sync_page.dart`

Add/retain platform-focused widget coverage proving that a configured Android
surface exposes Add device and that the resulting sheet contains
`addDeviceQrImage`. This protects the already-shipped architecture while the
desktop import path changes.

### 2. macOS scanner

Reuse `mobile_scanner` 7.x. It officially supports macOS and is already the
production Android/iOS scanner, so it preserves identical barcode handling,
deduplication, bundle validation, and pairing-code confirmation.

The macOS runner already has `com.apple.security.device.camera` in debug and
release entitlements and `NSCameraUsageDescription` in `Info.plist`. Update the
usage description so it names QR pairing as well as journal photos.

### 3. Linux scanner

`mobile_scanner` has no Linux implementation. Add:

- `camera` for the standard `CameraController` API;
- `camera_desktop` for Linux capture (Camera portal/PipeWire in Flatpak, V4L2
  outside Flatpak); and
- `zxing2` for pure-Dart QR decoding from RGBA/BGRA camera frames.

Create `lib/features/sync/ui/provisioned/desktop_qr_scanner.dart`. It will:

1. enumerate webcams and initialize the first available camera without audio;
2. render the live preview inside the existing tokenized scanner frame;
3. sample frames with deterministic backpressure (never decode two frames at
   once);
4. convert padded RGBA/BGRA rows to the ARGB pixels ZXing expects;
5. decode off the UI isolate and emit each distinct payload at most once; and
6. dispose the stream/controller on every exit path.

Lotti already installs the GStreamer development/runtime packages this plugin
requires in Linux CI, and its runner already links GStreamer. The Flatpak path
uses the desktop camera portal, so the manifest should not gain broad
`--device=all` access.

### 4. Import-flow integration and UX

Refactor `bundle_import_page.dart` around a platform capability:

- Android/iOS/macOS/Linux start on the scanner.
- Windows remains on manual entry for now.
- **Enter manually** remains available under every scanner.
- Manual entry shows **Scan the QR instead** only on supported platforms.
- Permission denial, missing camera, initialization failure, and decode failure
  stay inline in the existing scanner surface with Retry and manual fallback.
- Successful desktop scans enter the existing handover review screen; no
  security checks or credential serialization change.

No new visual constants are required: the current scanner frame, design-system
tokens, and localized labels are reused.

## Files

- `pubspec.yaml`, `pubspec.lock`
- `lib/features/sync/ui/provisioned/bundle_import_page.dart`
- `lib/features/sync/ui/provisioned/desktop_qr_scanner.dart` (new)
- `macos/Runner/Info.plist`
- `test/features/sync/ui/provisioned/bundle_import_page_scanner_test.dart`
- `test/features/sync/ui/provisioned/desktop_qr_scanner_test.dart` (new)
- `test/features/sync/ui/provisioned_sync_page_test.dart` or the existing
  add-device mirror test, only if the mobile-generation assertion is missing
- `test/features/sync/ui/sync_manual_screenshots_test.dart`
- `lib/features/sync/README.md`
- `knowledge/features/sync/overview.md`
- one `changelog.d/` fragment

## Verification

Automated:

- Pure frame-decoder tests for BGRA, RGBA, row padding, malformed frames, no QR,
  and a valid QR payload.
- Widget tests for macOS/Linux scanner-first behavior, Windows manual fallback,
  scanner-to-manual switching, retry, distinct-payload delivery, and disposal.
- Existing bundle import/controller tests to prove scanned and pasted payloads
  still share the same validation and pairing confirmation.
- Targeted analyzer and Flutter tests only for touched source mirrors.
- Linux debug build to compile/link the new native plugin.
- Before/after desktop screenshots from the existing sync manual harness.

Hardware acceptance before calling Phase A complete:

- macOS: webcam scanning confirmed on 2026-08-29; grant denial, retry, and both
  phone/tablet source coverage remain to be recorded.
- Linux: webcam scanning confirmed on 2026-08-29; native no-camera fallback and
  the exact packaging path remain to be recorded.
- Linux Flatpak: portal grant/deny, PipeWire preview, scan, and relaunch after a
  remembered permission decision.
- Android phone and tablet: generate a code, keep the whole QR visible without
  horizontal clipping, and complete a desktop join.

Phase B must not start until those Phase A acceptance paths are green.
