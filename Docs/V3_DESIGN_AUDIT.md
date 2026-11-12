# CleanBuild V3 Design Audit

Date: 2026-11-03  
Scope: baseline inspection before the V3 checkpoint redesign

## Evidence inspected

- Running CleanBuild Release build at 1180×760.
- `outputs/v3-baseline/overview.png`
- `outputs/v3-baseline/explorer.png`
- `outputs/v3-baseline/history.png`
- `outputs/v3-baseline/settings.png`
- Current SwiftUI hierarchy and accessibility tree.

## Main window

- The persistent CleanBuild identity block duplicates application identity already supplied by the window, Dock, and menu bar.
- The block adds a divider and vertical weight without helping navigation.
- Page titles appear in both the navigation destination and content, weakening hierarchy.
- The unified toolbar and collapsible sidebar are correct native foundations and should be retained.

## Overview

- The pre-scan state places `ContentUnavailableView` inside another rounded surface, producing a very large empty white rectangle.
- The large blank area makes the primary action feel small and detached.
- The generic external-drive symbol does not communicate the product’s identity or safety promise.
- The populated summary is directionally correct, but its type scale is smaller than the V3 storage hierarchy and the source list lacks real column semantics.
- Source status, classification, and size require more predictable alignment.

## Storage Explorer

- Search, safety filtering, sorting, and inspector controls appear before results exist.
- A zero-selection cleanup footer is always present, suggesting an action that cannot be performed.
- The empty state is surrounded by controls unrelated to the current state.
- The table places Size last instead of near the item name, reducing scanability.
- Selection is implemented through row checkboxes while row focus drives the inspector; that distinction is valid but needs clearer context and keyboard behavior.
- The three-pane structure is useful, but pane widths and compact metadata need tighter defaults.

## History

- Repeated disclosure rows have limited visual distinction between scans, dry runs, and real cleanup jobs.
- Outcome, item count, and size are compressed into similar two-line summaries.
- The screen uses width reasonably but lacks contextual copy or inspect actions.
- History redesign is intentionally deferred until the user approves the V3 Overview and Explorer checkpoint.

## Settings

- Each small preference group is placed in a large rounded card, producing a web-dashboard appearance.
- Repeated icon/title/divider/card patterns add vertical space and visual noise.
- Controls do not follow a compact label/control alignment grid.
- Settings redesign is intentionally deferred until checkpoint approval.

## Accessibility observations

- Sidebar navigation and primary scan controls expose native roles and labels.
- Icon-only toolbar buttons have labels and help text.
- Classification uses icon plus text, not color alone.
- Empty Explorer currently exposes irrelevant disabled controls, increasing VoiceOver traversal cost.
- The cleanup checkbox label announces selection intent; protected state remains disabled.

## Checkpoint priorities

1. Remove the sidebar identity header.
2. Replace the Overview’s oversized empty card with a compact, balanced welcome group.
3. Turn populated source results into a real aligned table.
4. Hide Explorer controls and cleanup actions until they are relevant.
5. Refine Explorer pane widths, column order, no-match state, context menu, double-click behavior, and inspector density.

