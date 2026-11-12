# CleanBuild V3 Design System

## Direction

Native, restrained, information-first macOS utility. The design uses SwiftUI semantic colors, San Francisco, SF Symbols, native tables, split views, toolbars, lists, and sheets. It avoids decorative gradients, oversized cards, custom fonts, and arbitrary accent colors.

The local UI design search suggested a minimal/Swiss direction but returned web-oriented colors and typography. Those details were rejected because the product brief and macOS conventions require system blue, semantic colors, and San Francisco.

## Tokens

### Spacing

| Token | Value | Use |
|---|---:|---|
| `xSmall` | 4 | tight label/value relationship |
| `small` | 8 | icon-to-label, compact controls |
| `medium` | 12 | row internals |
| `large` | 16 | section internals |
| `xLarge` | 20 | related section separation |
| `xxLarge` | 24 | major section separation |
| `xxxLarge` | 32 | page-level separation |

### Layout

- Page inset: 28 pt.
- Sidebar: native compact sidebar, 190–230 pt, collapsible.
- Explorer sources: 190–220 pt.
- Explorer inspector: 260–300 pt.
- Default window: 1280×800 pt.
- Minimum window: 1000×680 pt.
- Compact surface radius: 8 pt; use surfaces only for cohesive grouped information.

### Typography

- Page heading: system 28 pt semibold.
- Section heading: system 18 pt semibold.
- Body: system 13–14 pt regular.
- Secondary/caption: system 11–12 pt.
- Primary storage value: system 38 pt semibold with monospaced digits.
- Table values: native table typography; storage numbers use monospaced digits.

### Color

- Primary action and selection: system accent blue.
- Text/background/separators: semantic system colors.
- Success/Safe: system green, always paired with text or symbol.
- Warning/Review: system orange, only for caution.
- Error/destructive: system red, only for failures or destructive actions.
- Protected: secondary/lock treatment; red is reserved for an actual destructive or error context.

### Icons

- One registry of SF Symbols defines navigation, sources, safety, scan, inspector, and actions.
- Outline symbols are used for navigation and neutral actions.
- Filled symbols are reserved for selected or strong status states.
- Decorative symbols adjacent to equivalent text are hidden from accessibility where appropriate.

## Interaction rules

- One primary action per state.
- Hide controls that have no useful effect in the current state.
- Row focus controls inspection; checkboxes control cleanup inclusion.
- Double-clicking a result reveals it in Finder.
- Context menus provide Reveal, Copy Path, and cleanup inclusion/removal.
- Protected items remain visibly ineligible.
- The inspector can be collapsed from the toolbar.
- No invented scan or cleanup percentages.

