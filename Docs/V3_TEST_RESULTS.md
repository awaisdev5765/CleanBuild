# CleanBuild V3 Checkpoint Test Results

Date: 3 November 2026

## Build

- Universal macOS Release build: **Passed**
- Release application: `work/V3PackageDerivedData/Build/Products/Release/CleanBuild.app`

## Core test suite

- Executed: 27
- Passed: 26
- Skipped: 1 opt-in performance test
- Failed: 0

## UI test suite

- Executed: 3
- Passed: 3
- Failed: 0
- Result bundle: `work/V3TestDerivedData/Logs/Test/Test-CleanBuild-2026.11.03_13-39-45-+0500.xcresult`

Covered checkpoint behavior includes:

- new first-scan Overview copy
- populated scan navigation
- empty Explorer hiding search, filtering, and cleanup controls

## Manual visual verification

- Empty Overview: light and dark
- Scan progress: light and dark
- Populated Overview: light and dark
- Empty Explorer: light
- Populated Explorer: light and dark
- Inspector content: dark
- Cleanup selection footer: light and dark
- Source table column visibility at 1180 × 760
- Semantic colors and native material adaptation

## Notes

Only a real scan was used for visual verification. No real cleanup was executed. History, Settings, cleanup flow, onboarding, and remaining states are outside this approval checkpoint and require the next V3 implementation phase.

