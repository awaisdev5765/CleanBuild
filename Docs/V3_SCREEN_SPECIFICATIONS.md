# CleanBuild V3 Screen Specifications — Checkpoint

## Main window

- Native `NavigationSplitView` with unified toolbar and collapsible compact sidebar.
- Sidebar contains only Overview, Storage Explorer, History, and Settings.
- No oversized brand header or divider.
- Default 1280×800; minimum 1000×680.

## Overview — first scan

- No page-sized surface.
- A centered content group occupies a maximum width of 480 pt.
- Existing app icon at 72 pt, 28 pt headline, concise 14 pt support text.
- Prominent but compact `Scan Mac` button.
- Privacy/safety reassurance with `lock.shield` symbol below the action.

## Overview — scanning

- Compact bordered status group beneath the page header.
- Current source, indeterminate progress, explanation, and Cancel action.
- No invented percentage.

## Overview — populated

- Header: Developer Storage, last-scanned time, `Scan Again` action.
- One cohesive summary group with a 38 pt total, eligibility note, proportional Safe/Review/Protected bar, and aligned legend.
- Sources displayed in a native Table sorted by measured size descending.
- Columns: Source, Size, Classification, Status.
- Selecting a source opens Storage Explorer with that filter.
- Footer information reports scan duration, available source count, unavailable source count, and warnings only when present.

## Storage Explorer — empty

- Compact centered state with scan action.
- Search, sorting, filters, inspector toggle, and cleanup footer are absent.
- No blank bottom action strip.

## Storage Explorer — populated

- Resizable three-pane split: sources 190–220 pt, flexible table, inspector 260–300 pt.
- Toolbar exposes search, safety filter, sorting, direction, and inspector only after results exist.
- Table columns: Name/selection, Size, Safety, Modified, Source.
- Native row focus drives inspector; checkboxes support multiple cleanup targets.
- Double-click reveals in Finder. Context menu offers Reveal, Copy Path, and cleanup inclusion/removal.
- Empty filtered results display a no-match state with a Clear Filters action.
- Selection footer appears only when one or more eligible items are selected and reads “N items selected · size”.
- Inspector uses compact labeled groups for identity, size, source, modified date, classification, reason, consequence, path, and actions.

## Deferred pending checkpoint approval

- History V3.
- Settings V3.
- Cleanup sheets and completion V3.
- Onboarding and remaining error-state polish.
