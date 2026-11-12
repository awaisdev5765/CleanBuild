# CleanBuild UI/UX V2 — Baseline Audit

Date: 2026-11-02

## Scope and method

This audit was completed before V2 UI implementation. It covers every SwiftUI view, the shared app model, scan and cleanup flows, persistence-backed settings/history, automated tests, and the running Release build. The baseline app was inspected at its current default window size in dark appearance. No destructive cleanup was performed.

## Existing information architecture

- A native `NavigationSplitView` exposes four stable destinations: Overview, Storage Explorer, History, and Settings.
- Scan and cleanup state are centralized in the main-actor `AppModel`; scanning and cleanup engines remain outside the views.
- Onboarding and cleanup review are sheets, while cleanup results are redirected to History.
- The Explorer is a three-pane `HSplitView`: source filter, item list, and inspector.

The overall structure is appropriate for a macOS utility and should be refined rather than replaced.

## Existing actions and real data

- Scan/Rescan, scan cancellation, search, safety filtering, source filtering, item selection, reveal in Finder, cleanup review, dry run, move to Trash, history clearing, workspace management, and exclusions are backed by real application behavior.
- Source status is available from each `ScanSession`, including Available, Not Installed, Permission Required, and Unavailable states.
- Cleanup outcomes include succeeded, failed, skipped, and simulated states with measured bytes and messages.
- There is no API that can provide deterministic per-file scan progress, cleanup cancellation, notifications, launch-at-login, or appearance persistence. V2 must not invent those controls or values.

## Findings

### Critical usability and safety findings

1. The cleanup sheet proceeds from review acknowledgment directly to the destructive action. The final action label is only “Move to Trash”; it should explicitly state that selected items will be moved and maintain a clearly separated destructive treatment.
2. Cleanup has no dedicated progress or completion experience. The toolbar shows only a spinner and successful/failed outcomes are discoverable only after automatic navigation to History. This weakens feedback for a high-consequence operation.
3. Unsupported sources appear in the Explorer as ordinary zero-count sources. This can imply that they were scanned and found empty; source availability must be stated explicitly.
4. The overview classification bar represents only Safe and Review storage. Protected storage is not represented, so the visualization can be inaccurate when protected results exist.

### Navigation and layout findings

1. The default window is 1180×760 with a 980×650 minimum, below the V2 target of 1280×800 and 1000-point minimum width.
2. Sidebar navigation is native and understandable, but lacks a compact brand identity/header and consistent V2 icon semantics.
3. The Explorer’s fixed three-pane layout does not adapt when the window narrows. The inspector has no collapse control and can consume too much space.
4. The baseline empty Overview leaves a very large unstructured region. The empty state needs a stronger primary action and a short privacy/safety explanation.

### Overview findings

1. Summary cards communicate total, Safe, and Review values, but Protected is missing.
2. Source rows are visually clear, but use `onTapGesture` rather than native `Button` semantics, reducing keyboard and VoiceOver quality.
3. Source rows show technical status detail but not a concise availability badge.
4. The source section is not sortable and does not expose its dominant classification.
5. “Scan Now” and the toolbar Scan action duplicate each other without a clear primary-action hierarchy.

### Storage Explorer findings

1. The main results region is a `List`, not a macOS `Table`. Size, source, date, and classification cannot be independently sorted.
2. Multiple cleanup selection is visually separated from the row selection used by the inspector, but the distinction is not explained.
3. The inspector supports text selection and Reveal in Finder, but lacks Copy Path and an item-scoped Review for Cleanup action.
4. Long paths are readable only in the inspector and there is no tooltip on truncated row content.
5. The source list does not expose availability or scan errors.

### Cleanup review, progress, and completion findings

1. Review displays paths, sizes, classifications, and consequences and correctly requires acknowledgment for Review items.
2. There is no classification summary, final safety explanation, or explicit distinction between dry-run validation and a real Trash operation beyond the toggle/button text.
3. No cleanup progress sheet exists.
4. No completion summary exists; partial failures are only visible in History.

### History findings

1. History is real and locally persisted.
2. Cleanup jobs lack an at-a-glance result, reclaimed/estimated total, and source summary.
3. Scan rows lack completion duration/status detail and cannot be inspected beyond one dense line.
4. Outcome icons incorrectly render skipped/simulated outcomes using a success-colored checkmark.

### Settings findings

1. Settings expose only implemented preferences: workspaces, exclusions, dry-run default, history clearing, and app information. This is honest and should be preserved.
2. The current Form is compressed into one source line and creates weak visual grouping at runtime.
3. Removal actions are text-heavy and repeated; paths need better truncation, tooltips, and consistent destructive semantics.
4. Clear History has no confirmation dialog.

### Design-system and visual findings

1. There is no centralized token layer for spacing, radii, pane widths, semantic surfaces, or icon sizes.
2. Repeated cards use ad-hoc spacing and corner radii.
3. SF Symbols are used consistently, but a few source glyphs (notably Flutter) are weak semantic matches.
4. The in-app `BrandMark` is visually unrelated to the installed app icon.
5. Native system colors generally support dark mode, but light mode and high-contrast behavior have not been verified.

### Accessibility findings

1. Native controls provide a strong baseline and important icon-only selection controls have explicit labels.
2. Clickable overview source rows lack button semantics.
3. Classification relies on both text and color, which is correct, but progress/outcome states require clearer non-color labels.
4. Truncated paths do not consistently expose their full value via Help/tooltip text.
5. Keyboard shortcuts exist for scan/rescan and modal default/cancel actions; Explorer actions need equivalent keyboard discoverability.

## V2 implementation direction

- Keep the current navigation and engine boundaries.
- Introduce centralized native design tokens and reusable surfaces, section headers, status badges, and path rows.
- Make Overview a clear command-and-summary screen with accurate Safe/Review/Protected data and explicit source availability.
- Convert Explorer results to a sortable macOS Table, retain the three-pane workflow, add inspector actions, and make the inspector collapsible.
- Add real cleanup progress and completion states based only on actual job outcomes.
- Improve History and Settings without introducing unimplemented preferences.
- Verify Release builds, automated tests, VoiceOver labels, keyboard operation, window resizing, and both system appearances with screenshots.

## Baseline assessment

The existing UI is functional and recognizably native, but it is not yet at the requested production-level V2 standard. The principal blockers are incomplete cleanup feedback, misleading source availability, inaccurate classification visualization, weak Explorer data interaction, missing responsive pane behavior, and the absence of a shared visual system.
