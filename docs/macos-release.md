# macOS Release

This document covers the **GitHub Release** distribution path for Lotti macOS — a Developer ID signed and notarized `.dmg` produced automatically by `.github/workflows/flutter-macos-release.yml` whenever a tag is pushed.

This is **separate** from the Mac App Store / TestFlight path, which is driven by `macos/fastlane/Fastfile` (`do_build` / `do_upload`) and uses an App Store distribution certificate via `match`. Do not mix the two — they use different certificates, different provisioning profiles, and different `exportOptions.plist` settings.

| Path | Cert type | Profile type | Driver |
|---|---|---|---|
| GitHub Release `.dmg` | Developer ID Application | Developer ID | `flutter-macos-release.yml` |
| TestFlight / MAS | Mac App Distribution | Mac App Store | `fastlane do_upload` |

## Prerequisites

- Apple Developer Program membership for team `7DN35ABWYL`.
- Access to the developer portal at <https://developer.apple.com/account>.
- A Mac with Xcode and Keychain Access for exporting credentials.

## One-time setup

### 1. Developer ID Application certificate

If you don't already have a Developer ID Application certificate in the **login** keychain:

1. In **Keychain Access**, choose `Certificate Assistant → Request a Certificate from a Certificate Authority`. Save the CSR to disk.
2. In the developer portal, create a new certificate of type **Developer ID Application**. Upload the CSR. Download the resulting `.cer` and double-click to install.

Export as `.p12`:

1. Open **Keychain Access**, search for `Developer ID Application: Matthias Nehlsen (7DN35ABWYL)`.
2. Expand the entry so the **private key** is visible.
3. Select **both** the certificate and its private key (⌘-click).
4. Right-click → **Export 2 items…** → save as `lotti-developerid.p12`.
5. Set a strong password. This becomes `MACOS_CERTIFICATE_PASSWORD`.

### 2. Developer ID provisioning profile

In the developer portal:

1. Navigate to **Profiles** → **+** → **Developer ID** (under Distribution, macOS).
2. App ID: `com.matthiasn.lotti`.
3. Include the application group `SS586VG7L7.lottiobx` (matches `macos/Runner/Release.entitlements`).
4. Select the Developer ID Application certificate from step 1.
5. Download as `lotti_developerid.provisionprofile`.

### 3. App-specific password for notarytool

1. Open <https://appleid.apple.com/account/manage>.
2. Under **App-Specific Passwords**, generate a new password labelled e.g. `lotti-notary-ci`.
3. Copy the value. This becomes `APPLE_APP_PASSWORD`.

### 4. Base64 encode for GitHub Secrets

Encode each file as a single unwrapped line. macOS BSD `base64` does not wrap by default; `-b 0` makes that intent explicit (and is harmless on systems whose `base64` does wrap):

```bash
base64 -b 0 -i lotti-developerid.p12              -o lotti-developerid.p12.b64
base64 -b 0 -i lotti_developerid.provisionprofile -o lotti_developerid.provisionprofile.b64
```

To copy a value to the clipboard for pasting into the GitHub secret editor:

```bash
pbcopy < lotti-developerid.p12.b64
```

### 5. GitHub Secrets

In the repository: **Settings → Secrets and variables → Actions → New repository secret**.

| Secret name | Value |
|---|---|
| `MACOS_CERTIFICATE_BASE64` | contents of `lotti-developerid.p12.b64` |
| `MACOS_CERTIFICATE_PASSWORD` | password used when exporting the `.p12` |
| `MACOS_PROVISIONING_PROFILE_BASE64` | contents of `lotti_developerid.provisionprofile.b64` |
| `MACOS_KEYCHAIN_PASSWORD` | any random string — only locks the temp keychain on the runner. Generate with `openssl rand -hex 24` |
| `APPLE_ID` | Apple ID email used for notarization |
| `APPLE_APP_PASSWORD` | app-specific password from step 3 |
| `APPLE_TEAM_ID` | `7DN35ABWYL` |

### 6. Local verification before pushing a tag

```bash
# Confirm the exported cert really is Developer ID Application:
security find-certificate -c "Developer ID Application" -p login.keychain-db \
  | openssl x509 -noout -subject -issuer

# Inspect the provisioning profile:
security cms -D -i lotti_developerid.provisionprofile | plutil -p - | head -40
```

Both should reference team `7DN35ABWYL` and bundle id `com.matthiasn.lotti`.

After verification, **delete the unencoded `.p12` and `.provisionprofile` files from disk** — the encoded copies in GitHub Secrets are now the source of truth for CI.

## Triggering a release

Push a tag (any tag matches the workflow trigger):

```bash
git tag v0.X.Y
git push origin v0.X.Y
```

The workflow will:

1. Import the certificate into a temp keychain on the runner.
2. Drop the provisioning profile into `~/Library/MobileDevice/Provisioning Profiles/`.
3. Run `flutter build macos --release --no-codesign`, then `xcodebuild archive`, then `xcodebuild -exportArchive` with a generated `developer-id` `exportOptions.plist`.
4. Notarize the `.app` with `notarytool submit --wait` and staple the ticket.
5. Build `Lotti.dmg` via `hdiutil`.
6. Notarize and staple the `.dmg`.
7. Create a prerelease GitHub Release (`gh release create -p`) and upload the `.dmg`.
8. Print the total build duration to logs and the job summary.

The release is created as a **prerelease**. After all platform workflows (Android, Linux, macOS, …) finish, manually mark it as **latest** in the GitHub UI.

## Rotating credentials

- **Certificate expires** (every ~5 years for Developer ID): redo step 1, re-encode, update `MACOS_CERTIFICATE_BASE64` and `MACOS_CERTIFICATE_PASSWORD`.
- **Provisioning profile expires**: redo step 2, re-encode, update `MACOS_PROVISIONING_PROFILE_BASE64`.
- **App-specific password lost or revoked**: redo step 3, update `APPLE_APP_PASSWORD`.

## Troubleshooting

- **`errSecInternalComponent` during `xcodebuild archive`** — the imported key wasn't authorized for `codesign`. The workflow handles this via `security set-key-partition-list`; check that step's logs.
- **`No matching profiles found`** — bundle id, team, or entitlements (notably `application-groups`) on the profile don't match `macos/Runner/Release.entitlements`. Recreate the profile.
- **Notarization status `Invalid`** — fetch the log with `xcrun notarytool log <submission-id> --apple-id … --team-id … --password …`. Common causes: hardened runtime not enabled, unsigned helper binaries inside the app bundle, or use of disallowed entitlements for Developer ID.
- **Gatekeeper still warns after install** — confirm the staple succeeded: `xcrun stapler validate Lotti.dmg` and `spctl -a -vv -t install Lotti.dmg`.
