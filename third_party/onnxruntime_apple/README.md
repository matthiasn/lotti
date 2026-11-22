# ONNX Runtime pods for iOS and macOS

`flutter_onnxruntime` depends on the CocoaPods `onnxruntime-objc` and
`onnxruntime-c` 1.24.2. Their trunk specs download from
`download.onnxruntime.ai`, which stopped working in November 2026: the host
now serves a generic `*.azureedge.net` certificate and the archives are gone,
and Microsoft's `microsoft/onnxruntime` and
`microsoft/onnxruntime-swift-package-manager` GitHub repositories return 404.
Every iOS and macOS build without a warm CocoaPods cache failed in
`pod install`, which is why 1.1.107 never reached TestFlight.

`ios/Podfile` and `macos/Podfile` therefore pin both pods to the specs in this
directory with `:podspec`. Each is the trunk spec byte for byte except its
`source`:

| Pod | Source | Pinned by |
|-----|--------|-----------|
| `onnxruntime-c` | `pod-archive-onnxruntime-c-1.24.2.zip` re-hosted on the [FutureWorkshops/onnxruntime-swift-package-manager](https://github.com/FutureWorkshops/onnxruntime-swift-package-manager/releases/tag/1.24.3) release `1.24.3` | `sha256` `f7100a99…6e600b54`, which CocoaPods verifies |
| `onnxruntime-objc` | the `objectivec/` sources at commit `b7fb7f7d…` of the same repository | the commit hash |

Neither pin trusts the mirror:

- The `sha256` is the checksum Microsoft's own `Package.swift` declared for
  this archive at tag `1.24.2`, long before the outage. It reads the same in
  every surviving copy of that repository's history, so a downloaded archive is
  the exact binary earlier releases shipped.
- `b7fb7f7d…` is Microsoft's `1.24.2` release commit of the Swift package
  repository, which carries the Objective-C wrapper that the pod archive
  packaged. The FutureWorkshops, move37-com and sackheads copies resolve the tag
  to the same commit and the same `objectivec` tree. A git commit hash covers
  its whole content.

The mirror decides only availability. If it disappears, re-host the same two
artifacts anywhere and change the URLs. The pins stay valid.

## Upgrading ONNX Runtime

Bump the version together with the `onnxruntime-objc` dependency in
`third_party/flutter_onnxruntime/{ios,macos}/flutter_onnxruntime.podspec`. Take
the new trunk specs and replace only their `source` here. Take the archive's
`sha256` from Microsoft's own release metadata, not from the mirror that hosts
it. Then update both `Podfile.lock` files with a real `pod install`, or by hand:
their `SPEC CHECKSUMS` entries are the SHA-1 of each spec file, and
`PODFILE CHECKSUM` is the SHA-1 of the Podfile.
