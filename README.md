<div align="center">

# 🧹 CleanBuild

**A native macOS developer-storage recovery utility.**

Measure what your tools are actually storing, understand what is safe to remove,
and clean up only after explicit review — offline, with no background daemons.

[![Swift](https://img.shields.io/badge/Swift-6.2-orange?logo=swift&logoColor=white)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)](#requirements)
[![License](https://img.shields.io/badge/license-MIT-green)](#license)
[![Tests](https://img.shields.io/badge/tests-4%20passing-brightgreen)](#test)

</div>

---

## What it does

CleanBuild is a native SwiftUI macOS app that scans the cache and build folders
Xcode, Gradle, npm, Yarn, and Flutter quietly accumulate, then explains the
consequences of cleaning each one **before** anything changes.

**Built for developers who have lost 100+ GB to DerivedData and didn't know where.**

## ✨ Highlights

- **Real scans** — allocated-size scans of Xcode DerivedData & Archives, Gradle
  caches, npm/Yarn caches, and explicitly approved Flutter workspaces
- **Safety-first classification** — every target is *Safe*, *Review*, or *Protected*:
  - **Safe** = positively identified generated output, still requires selection + confirmation
  - **Review** = regenerable/archival data with meaningful consequences (rebuild, download, symbolication). Never preselected, requires acknowledgement
  - **Protected** = user data or forbidden roots. **Cannot be selected at all**
- **Dry-run by default** — cleanup defaults to dry-run; when enabled, targets are
  revalidated and moved to the macOS Trash one at a time
- **Fails closed** — if a target changed since the scan, cleanup refuses and requires a new scan
- **Canonical-path protections** — checks against `/`, `/System`, `/Library`, `/Applications`,
  and the home root; symlinked entries are skipped while scanning
- **Nested-target deduplication** — never double-counts folders inside folders
- **Complete audit trail** — atomic local scan/job history and outcome records
- **Native SwiftUI** — onboarding, Overview, Explorer, History, Settings, toolbar,
  commands, search, filters, and a full 16–1024 px asset catalog

## 📦 What it scans

| Source | Scan | Classification |
|---|---|---|
| Xcode DerivedData | ✅ Real scan | Safe — eligible after review |
| Xcode Archives | ✅ Real scan | Review |
| Gradle cache | ✅ Real scan | Review |
| npm / Yarn caches | ✅ Real scan | Review |
| Flutter build output | ✅ Real scan | Safe only inside explicitly added workspaces |
| Simulators, Docker, Android | Report-only | Not scanned — the UI says so honestly |

## 🚀 Requirements

- macOS 14 or later
- Xcode 16 or later (verified with Xcode 26.0.1, Swift 6.2)

## 🔨 Build

```sh
xcodebuild -project CleanBuild.xcodeproj -scheme CleanBuild \
  -configuration Debug -derivedDataPath work/DerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

Run the app at `work/DerivedData/Build/Products/Debug/CleanBuild.app`.

## 🧪 Test

```sh
CLANG_MODULE_CACHE_PATH=/private/tmp/cleanbuild-clang \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/cleanbuild-swiftpm \
swift test --disable-sandbox
```

Verified: `swift test --disable-sandbox` — 4 tests, 0 failures ·
`xcodebuild` — **BUILD SUCCEEDED** on Xcode 26.0.1, Swift 6.2, arm64, macOS 15.7.2.

## 🏗 Architecture

- `CleanBuild/App` — app entry, scene, toolbar, commands
- `CleanBuild/Features` — Overview, Explorer, History, Settings flows
- `CleanBuild/DesignSystem` — shared design system
- `CleanBuildCore` — the SwiftPM library target: scanning, classification, cleanup
- `Tests/Core` — core safety tests

## 🔒 Privacy

CleanBuild works **offline**. It stores only local scan metadata and job outcomes
under Application Support. It has no account, analytics, advertising, or cloud backend.

## 📄 Distribution

The included build is unsigned. See [Docs/RELEASE.md](Docs/RELEASE.md) for
signing and notarization steps, and [Docs/SAFETY_MODEL.md](Docs/SAFETY_MODEL.md)
for the full safety model.

## License

MIT

---

<div align="center">

**If CleanBuild freed up space on your Mac, consider supporting the project:**

<a href="https://www.buymeacoffee.com/awaisdev5765">
  <img src="https://img.shields.io/badge/Buy%20Me%20a%20Coffee-awaisdev5765-yellow?logo=buymeacoffee&logoColor=white" alt="Buy Me A Coffee">
</a>

</div>
