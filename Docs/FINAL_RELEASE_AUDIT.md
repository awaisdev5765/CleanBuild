# CleanBuild Final Release Audit

Date: 2026-11-02  
Environment: macOS 15.7.2, Xcode 26.0.1, Swift 6.2, Apple Silicon host  
Application target: macOS 14+, SwiftUI, arm64/x86_64 universal Release binary

## 1. Features implemented

- Native SwiftUI application with onboarding, Overview, three-pane Storage Explorer, History, and Settings.
- Real allocated-size scans for Xcode DerivedData, Xcode Archives, Gradle caches, npm/Yarn caches, and Flutter build output inside explicitly approved workspaces.
- Deterministic Safe, Review, and Protected classifications with reasons and consequences.
- Search, source filtering, safety filtering, sortable native table columns, exact paths, item inspector, Finder reveal, path copying, selection totals, and explicit cleanup review.
- Dry run by default; real cleanup uses `FileManager.trashItem` only after revalidation.
- Atomic local scan/job history, audit outcomes, preferences, workspace paths, and exclusions.
- Original CleanBuild app icon with complete 16–1024 px macOS asset variants and true alpha-transparent outer corners (no baked white canvas).
- Keyboard scan/rescan commands, native searchable fields, semantic colors, SF Symbols, VoiceOver labels, and a persistent System/Light/Dark appearance preference.
- Dedicated cleanup review, in-progress overlay, cancellation affordance, and itemized completion summary.

## 2. Features verified

- Debug and Release app builds complete successfully.
- Release bundle metadata is `com.cleanbuild.app`, version `1.0.0`, build `1`, category Developer Tools.
- Release executable is universal arm64/x86_64.
- Asset compilation emits `AppIcon.icns`; the icon was visually checked at 16/64/1024 px, compiled without asset warnings, and extracted representations retain alpha transparency.
- Live UI inspection covered onboarding state, empty Overview, scan progress, populated Overview, full-height Storage Explorer, source list, item list, empty inspector, History, and Settings navigation.
- A live read-only scan returned measured results without deleting or changing developer storage.
- Finder/Spotlight/Dock use the compiled `AppIcon.icns`; final verification on a separate installed/notarized build remains a distribution acceptance step.

## 3. Tests executed

### Core unit and integration suite

Command:

```sh
CLANG_MODULE_CACHE_PATH=/private/tmp/cleanbuild-clang \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/cleanbuild-swiftpm \
swift test --disable-sandbox
```

Result: **27 tests discovered; 26 passed; 1 opt-in performance test skipped; 0 failures.**

Coverage includes path protection, traversal normalization, directory measurement, known-directory scanning, Flutter workspace scoping, classification metadata, nested plans, duplicate filesystem identities, dry run, fixture-only Trash execution, symlink rejection, forged allowlist paths, replacement races, size mutation, external deletion, exclusions, Protected/report-only sources, active-use rejection, partial Trash failure, concurrent cleanup, cancellation, interruption journal lifecycle, history corruption/retention, and settings persistence.

### Xcode unit and UI suite

Command:

```sh
xcodebuild -project CleanBuild.xcodeproj -scheme CleanBuild \
  -configuration Debug -derivedDataPath work/TestDerivedDataOutside \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

Final result (2026-11-02): **TEST SUCCEEDED**. Core: 27 executed, 26 passed, 1 opt-in benchmark skipped, 0 failures. UI: 2 executed, 2 passed, 0 failures. UI journeys cover primary navigation, empty states, Settings, and Command-R rescan/cancel availability.

### Performance benchmark

Command:

```sh
CLEANBUILD_RUN_PERFORMANCE=1 swift test --disable-sandbox \
  --filter CoreTests/testPerformanceLargeTree100kFiles
```

Measured result on this host:

- Fixture creation: 59.009 seconds for 100,000 one-byte files.
- Allocated-size scan: 10.972 seconds.
- Measured allocation: 409,600,000 bytes.
- End-to-end test including cleanup of the temporary fixture: 85.685 seconds.

The scan runs off the main actor through `ScanCoordinator`; cancellation is checked during enumeration. Memory was not profiled with Instruments in this environment, so no memory-use claim is made.

## 4. Safety audit findings

Confirmed defects found and fixed:

1. Cleanup previously lacked an independent source-specific root allowlist. It now requires a direct child of a narrow production root.
2. Cleanup previously trusted path/size only. It now binds a scan target to volume ID, filesystem ID, modification date, canonical path, and measured allocation.
3. Symlinks and symlink-resolved path changes now fail closed.
4. Nested, duplicate-path, and duplicate-filesystem-identity plans are rejected before mutation.
5. Flutter cleanup now independently checks the currently approved workspace list rather than trusting target metadata.
6. Docker, simulator, and Android sources remain report-only and cannot reach generic deletion.
7. Tool activity is checked conservatively with a fixed `/usr/bin/pgrep` invocation; matching Xcode, Gradle, Node, Flutter, or Dart activity blocks cleanup.
8. Concurrent work on one executor is rejected, and the app model prevents a second cleanup launch.
9. A pending-plan journal is written atomically before work. An interrupted journal is detected at next launch; the app does not resume deletion and instructs the user to rescan.
10. Permission, missing-item, size-change, identity-change, and Trash failures produce itemized failed outcomes rather than retries.
11. Scanner enumeration errors now propagate instead of becoming invented zero sizes.
12. Metadata files such as `CACHEDIR.TAG` are no longer surfaced as cleanup directory targets.
13. Package descendants are measured, fixing zero-byte `.xcarchive` reporting caused by package skipping.
14. History and settings write failures now surface to the user; corrupt history is reported.

No destructive test touched a real developer directory. Real cleanup was not executed during this audit. Trash behavior was exercised through an isolated fixture filesystem implementation.

## 5. UI/UX audit findings

- Replaced the flat single-list Explorer with a native source sidebar, focused item list, and detail inspector.
- Reworked Overview into measured storage, Safe/Review summaries, a classification bar, native source rows, and clear scan freshness.
- Corrected a split-view intrinsic-height regression discovered during screenshot inspection.
- Uses system typography, semantic backgrounds, semantic accent/success/caution/destructive colors, SF Symbols, native lists, sheets, toggles, buttons, toolbar, search, and splitters.
- Safety meaning is communicated by icon plus text, not color alone.
- Interactive selection controls have explicit accessibility labels; the classification graphic has an accessibility value.
- The window now defaults to 1280×800, enforces a 1000×680 minimum, and keeps the Explorer usable at narrower widths with adjustable source and inspector panes.
- Overview, populated scan results, Explorer, and Settings were screenshot-audited in both light and dark semantic appearances.
- Cleanup has an explicit review sheet, in-progress overlay, cancellation affordance, and completion sheet with succeeded, failed, skipped, and simulated outcomes.
- The approved icon is also used inside the app identity treatment; the compiled icon has transparent outer corners instead of a baked white square.

## 6. Known limitations

- Simulators, Docker, and Android are report-only/not scanned in this release; no cleanup claim is made.
- Archives and package caches are Review items and require explicit acknowledgement.
- Active-use detection is intentionally conservative and may block a cleanup while an owning tool is open even if that exact target is idle.
- Persistence is an atomic Codable store rather than SQLite. Integrity failures surface, but there are no relational migrations.
- Security-scoped bookmarks are not implemented. This direct-download build is unsandboxed; an App Store build requires sandboxing and bookmark-backed workspace access.
- APFS clone/snapshot effects mean measured allocation is not a guarantee of physically reclaimed bytes.
- No Instruments memory profile, external-drive matrix, separate Intel Mac run, or notarized clean-machine installation was available.

## 7. Remaining blockers

- Apple Developer ID identity and Team ID were not provided.
- The Release app is ad-hoc/linker signed, not Developer ID signed.
- Notarization and stapling have not been performed.
- A final installed-build check is required for Finder, Dock, Spotlight, application switcher, Gatekeeper, external/read-only volumes, VoiceOver, high contrast, and reduced motion.

## 8. Release readiness assessment

**Safety status:** no known critical cleanup-safety defect remains in the implemented cleanup scope.  
**Engineering status:** release-candidate quality; Debug/Release builds and automated suites pass.  
**Distribution status:** **not production-distributable yet** because Developer ID signing, notarization, stapling, and clean-machine acceptance have not occurred.

## 9. Exact distribution steps

1. Set a production bundle identifier and Apple Development Team in Xcode.
2. Decide distribution channel:
   - Direct distribution: keep the documented unsandboxed filesystem model, sign with Developer ID Application, and disclose scope clearly.
   - Mac App Store: enable App Sandbox and implement security-scoped bookmarks before submission.
3. Build an Archive in Release configuration with hardened runtime enabled.
4. Export with Developer ID signing and verify:
   `codesign --verify --deep --strict --verbose=2 CleanBuild.app`.
5. Create a ZIP or DMG without modifying the signed bundle.
6. Submit with `xcrun notarytool submit <artifact> --keychain-profile <profile> --wait`.
7. Require an `Accepted` result, then run `xcrun stapler staple CleanBuild.app` and `xcrun stapler validate CleanBuild.app`.
8. Verify with `spctl --assess --type execute --verbose=4 CleanBuild.app`.
9. Install on a separate clean macOS 14+ machine and complete the manual matrix in `Docs/TEST_PLAN.md`.
10. Only after those checks, publish the signed artifact and checksum with the privacy notice and release notes.

