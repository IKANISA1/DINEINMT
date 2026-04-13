# DineIn Guest PWA Design System

## Goal

Refine the existing production guest app into a calmer, cleaner, more premium PWA without rebuilding the product model, routing, or business logic.

This system is explicitly additive:

- preserve existing guest journeys
- preserve core information architecture
- preserve route names and business logic
- replace noise with reusable structure
- make the app feel lighter, faster, and more trustworthy

## Scope

This document covers the guest-facing PWA surface:

- discover
- venues browse
- venue detail
- menu and item detail
- cart and checkout
- order history
- order status
- order success
- guest settings
- global loading, empty, error, and offline states

## Audit

### Primary UI issues found

- Headers were often too loud for routine screens: large display copy, uppercase labels, and decorative letter spacing reduced scan speed.
- The same information was expressed with too many patterns: glass cards, clay cards, custom rows, custom pills, and ad hoc CTAs.
- Too much supporting text sat next to information that should have been visualized as status chips, metadata pills, cards, or compact tiles.
- Important actions were sometimes buried inside long vertical stacks instead of being pinned or grouped.
- Empty, loading, and error states did not consistently use the same visual language as the main happy-path screens.
- Desktop width was sometimes used to make screens feel denser instead of calmer.

### Where text was overused

- Discover hero copy and repeated section framing.
- Venue browse filters and helper text around search.
- Venue detail metadata blocks that relied on sentences instead of compact status surfaces.
- Order history and order success screens, which leaned on uppercase headings and verbose framing.
- Menu and cart areas where labels can become badges, pills, and grouped action blocks.
- Settings rows that explain too much before the user has asked for more detail.

### Where widgets should replace text

- Search prompts should be search fields, not explanatory copy.
- Venue and order metadata should be pills, badges, and stat tiles.
- Section intros should be one short subtitle at most.
- Reorder, support, and location actions should be quick action tiles instead of stacked rows of text.
- Live order state should be a status banner plus progress system, not heading-heavy prose.
- Checkout actions should live in sticky action areas, not repeated container stacks.

## Core Principles

1. Show less at once.
2. Make the next action obvious.
3. Use spacing before copy.
4. Standardize surfaces, not just colors.
5. Prefer icon-plus-structure over explanatory text.
6. Keep one primary action per screen when possible.
7. Push secondary details into progressive disclosure.
8. Treat empty, loading, error, and offline states as first-class product surfaces.

## Design Tokens

### Color

Source of truth: `packages/ui/lib/theme/app_colors.dart`

- Primary: bronze `#75663A`
- Primary container: warm sand `#F0E6CF`
- Secondary: muted green `#496654`
- Tertiary: slate `#62707B`
- Error: muted red `#B44940`
- App background and base surface: warm off-white `#F7F4EE`
- Lowest surface: pure white for premium cards
- Outline: soft neutral, low contrast

Rules:

- Use primary only for focus, key actions, and highlighted state.
- Use secondary for success, calm confirmation, and fulfilled progress.
- Use tertiary for neutral metadata and pre-active states.
- Avoid saturated accent colors unless tied to state.
- Do not add extra gradients, glow, or tinted panels unless they reinforce hierarchy.

### Typography

Source of truth: `packages/ui/lib/theme/app_typography.dart`

- Typeface: Manrope with broad fallback coverage
- Display sizes reserved for rare hero moments only
- Most routine screens should rely on:
  - `headlineSmall`
  - `titleLarge`
  - `titleMedium`
  - `bodyMedium`
  - `bodySmall`
- Eliminate aggressive uppercase and tracking except for tiny utility signals where it improves recognition

Rules:

- Keep titles short, preferably 2-5 words.
- Use one subtitle at most per section.
- Avoid stacked title plus intro paragraph plus helper copy.
- Default body copy should clarify action or state, not narrate the UI.

### Radius

Source of truth: `packages/ui/lib/theme/app_theme.dart`

- `radiusSm` 10
- `radiusMd` 14
- `radiusLg` 18
- `radiusXl` 22
- `radiusXxl` 30
- `radiusFull` 999

Rules:

- Use pill radius only for chips, badges, and compact metadata.
- Use 18-24 radius for most premium cards.
- Avoid mixing very sharp and very soft radii on the same screen.

### Spacing

Source of truth: `packages/ui/lib/theme/app_theme.dart`

Base rhythm:

- 4
- 8
- 12
- 16
- 20
- 24
- 32
- 40

Rules:

- Card padding should usually be 16-20.
- Screen section gaps should usually be 24-32.
- Prefer fewer but more intentional groups.
- Do not use spacing to compensate for weak hierarchy or repeated labels.

### Depth

- Use borders first.
- Use subtle ambient shadow second.
- Use elevated shadow only for highlighted hero cards or critical confirmation surfaces.
- Avoid stacked border plus glass plus shadow plus tint.

## Responsive Rules

### Breakpoints

- Compact mobile: under 600 px
- Expanded mobile / small tablet: 600-839 px
- Tablet / desktop: 840 px and above

### Layout behavior

- Mobile is the default composition model.
- Desktop should widen content and add breathing room, not add dashboard density.
- Keep readable content width constrained for heroes, forms, and status flows.
- Preserve the same components across breakpoints; only adapt grouping and column count.

### Interaction behavior

- Primary actions stay reachable with one thumb on mobile.
- Sticky action bars should be used for checkout, order confirmation, and other high-intent steps.
- Horizontal chip rails should remain scrollable on mobile and wrap on wider layouts when helpful.
- Search, filters, and quick actions should remain above-the-fold on mobile without pushing content too far down.

## Navigation Rules

- Preserve the existing route architecture and essential guest navigation.
- Keep the guest shell visually quieter than the page content.
- Use bottom navigation for top-level movement on mobile.
- On wider layouts, promote the same destinations into calmer desktop framing instead of inventing new paths.
- Limit app bar actions to genuinely high-value utilities.
- Prefer sheets and contextual menus for overflow actions.

## Component Library

### Shared system primitives

Existing shared foundation:

- `AppSurfaceCard`
- `AppIconButton`
- `AppPill`
- `PremiumButton`
- `SkeletonLoader`
- `EmptyState`
- `ErrorState`

Guest PWA additions:

- `GuestSurfaceCard`
- `GuestHeroCard`
- `GuestSectionHeader`
- `GuestSearchField`
- `GuestQuickActionTile`
- `GuestMetricTile`
- `GuestFilterPill`
- `GuestMetaPill`
- `GuestStickyActionBar`
- `GuestStatePanel`

### Usage rules

- `GuestHeroCard`: only one per screen, only for the primary context.
- `GuestSurfaceCard`: default reusable surface for guest screens.
- `GuestQuickActionTile`: use for short, high-frequency actions, never for long settings copy.
- `GuestMetricTile`: use for compact operational facts, not marketing stats.
- `GuestFilterPill`: use for toggles, filters, and segmented choices with low cognitive load.
- `GuestMetaPill`: use for metadata, status hints, and compact secondary info.
- `GuestStickyActionBar`: use when the screen has a clear conversion or confirmation action.
- `GuestStatePanel`: use for empty and error states before creating one-off illustrations and copy.

## Icon Rules

- Icons must clarify action, category, or state.
- The same concept should map to the same icon across the app.
- Do not place icons only for decoration or symmetry.
- Pair icons with short labels for quick actions, pills, and bottom actions.
- Keep icons legible at small sizes and use one consistent visual language.

Recommended mappings:

- search: `Icons.search_rounded`
- venue: `LucideIcons.store`
- order: `Icons.receipt_long_rounded`
- time/history: `LucideIcons.clock3`
- menu/food: `LucideIcons.utensilsCrossed`
- payment: `LucideIcons.wallet` or `LucideIcons.smartphone`
- home/discover: `LucideIcons.home`
- support/help: `LucideIcons.hand`

## Widget-First Patterns

### Hero summary card

Use for:

- discover
- order history
- order success
- venue landing summary

Structure:

- eyebrow
- short title
- short subtitle
- optional trailing status or success icon
- optional footer pills

### Search + filter rail

Use for:

- venue browse
- menu browse
- order history filtering if added later

Structure:

- always-visible search field
- horizontal chip row on mobile
- wrap chips on wider layouts if needed

### Quick action row

Use for:

- discover
- venue detail
- settings shortcuts

Structure:

- 2-4 action tiles
- icon-led
- one-line label
- optional tiny value

### Metadata pill group

Use for:

- venue capabilities
- order facts
- price level
- service mode
- Wi-Fi, delivery, dine-in, table, timing

### Sticky action area

Use for:

- cart checkout
- order success
- status-related follow-up actions

Structure:

- one primary action full width
- optional secondary row
- safe-area aware

### State panel

Use for:

- empty results
- empty history
- recoverable load errors
- unavailable or missing content

Structure:

- compact icon block
- short title
- one short subtitle
- optional single action

## Screen-Level Redesign Guidance

### Discover

Current problems:

- repeated framing text
- uneven card hierarchy
- reorder and browse utilities compete with featured content

Direction:

- keep the screen search-first
- use one hero card
- use quick action tiles for immediate paths
- show featured venues as image-led surfaces
- collapse repeated explanatory text into short section subtitles

Implementation status:

- updated in this pass

### Venues Browse

Current problems:

- filtering and search previously required too much interpretation
- venue cards competed with surrounding chrome

Direction:

- keep search permanently visible
- keep filters in pill form
- emphasize venue surface, not helper copy
- maintain route-driven search intent but resolve it into inline search focus

Implementation status:

- updated in this pass

### Venue Detail

Current problems:

- metadata and utility information used too much text
- promo context and practical details were visually fragmented

Direction:

- compress capabilities and context into pill rows
- use one clean hero summary, then card-based sections
- make menu access the obvious primary action
- move secondary venue detail into expandable or lower-priority cards

Implementation status:

- updated in this pass

### Menu

Current problems:

- category and badge language can still feel louder than needed
- item density can grow too text-heavy on long menus

Direction:

- keep categories as a controlled segmented rail
- reduce repeated category framing
- make item cards prioritize image, name, price, and add action
- push long descriptions into item detail sheets
- standardize dietary and availability badges

Implementation status:

- updated in this pass

### Cart

Current problems:

- empty state and checkout sections still need a fuller unification pass
- direct-input areas can feel heavier than the final action

Direction:

- group summary, table, notes, and payment into fewer stronger cards
- keep line items compact and editable
- keep total and checkout sticky on mobile
- preserve exact checkout logic while reducing visual density

Implementation status:

- updated in this pass

### Item Detail / Quick Add

Current problems:

- decorative hero treatment was heavier than the actual product task
- special request input existed without being connected to cart line data
- quick add sheet exposed too much text for a compact action

Direction:

- keep the product image strong but simplify the chrome around it
- make quantity and add-to-order sticky and obvious
- keep notes optional and route them into the cart line item
- use the sheet for quick add and the page for fuller item context

Implementation status:

- updated in this pass

### Order History

Current problems:

- oversized header treatment
- too much uppercase and decorative emphasis
- order cards carried too many visual styles

Direction:

- one calm hero card
- compact order cards with image, status, metadata pills, and total
- reduce text to order essentials only

Implementation status:

- updated in this pass

### Order Status

Current problems:

- progress content is strong, but surrounding labels and footer action can be quieter

Direction:

- keep the progress banner and steps
- reduce shouted section labels
- keep one clear sticky exit action
- keep support/help as a single top-level affordance

Implementation status:

- refined in this pass

### Order Success

Current problems:

- confirmation screen was too loud and typography-heavy
- actions were oversized relative to information value

Direction:

- turn the page into a clean confirmation hero
- show order reference as compact metadata
- keep track order as the primary sticky action
- keep home and optional payment as compact secondary actions

Implementation status:

- updated in this pass

### Order Details / Receipt

Current problems:

- receipt layout used a separate, louder design language from the rest of guest flow
- item notes and compact metadata were not surfaced cleanly

Direction:

- treat the receipt as a calm read-only summary
- use one receipt hero, one items block, and one total block
- surface line-item notes without adding visual clutter

Implementation status:

- updated in this pass

### Guest Settings

Current problems:

- too many row variants
- helper copy competes with labels

Direction:

- standardize to one tile pattern
- keep labels short
- reveal detail only where needed

Implementation status:

- updated in this pass

### Splash / entry / permissions

Direction:

- keep these ultra-light
- one brand anchor
- one message
- one clear next action if needed
- avoid decorative loading theater

Implementation status:

- updated in this pass

## Loading, Empty, Error, and Offline States

### Loading

- Prefer skeletons over spinners for screen-level loads.
- Use the same card rhythm as the final content.
- Avoid more than 3-4 placeholder blocks before the real content shape becomes clear.

### Empty

- Use `GuestStatePanel` or equivalent shared empty state.
- One sentence maximum for explanation.
- One action maximum unless the screen truly has two strong recovery paths.

### Error

- Use a calm error panel, not a full-screen alarm.
- Message should state what failed in plain language.
- Include a retry only when retry is meaningful.

### Offline

- Offline indication should remain global, subtle, and persistent.
- Do not block browse-only paths because of temporary network loss.
- Show reconnect feedback as a lightweight toast or banner transition, not a modal.

## Incremental Rollout Guidance

### Implementation rules

- Replace one-off guest cards with shared guest primitives.
- Do not change route names or navigation logic unless usability truly requires it.
- Keep business logic in providers, repositories, and services untouched.
- UI refactors should be staged screen by screen, not by large speculative rewrites.
- Preserve copy where tests rely on it unless there is a paired test update.

### Recommended rollout order

1. Shared tokens and core guest primitives
2. Discover and venue browse
3. Venue detail and guest shell
4. Order flow
5. Cart and checkout consolidation
6. Menu and item detail unification
7. Settings, permissions, and edge states

### Completed in this pass

- minimalist light token system aligned in `packages/ui/lib/theme/*`
- new guest PWA primitives in `packages/ui/lib/widgets/guest_pwa.dart`
- shared empty and error state refinement
- guest discover redesign
- venue browse redesign
- guest shell cleanup
- venue detail metadata and section cleanup
- menu badges, item detail page, and quick add sheet redesign
- cart sticky checkout consolidation and note-aware cart lines
- order history redesign
- order receipt redesign
- order success redesign
- order status footer and section simplification
- guest settings redesign
- splash redesign
- offline banner refinement

### Next migration targets

- wider desktop guest shell refinement
- broader guest widget and integration test coverage for the redesigned flows

## Acceptance Criteria

- Every guest screen should communicate its primary action within one second.
- Headers should be short and structurally useful, not theatrical.
- Cards, pills, search, and sticky actions should follow a consistent system.
- Text should only remain where it adds necessary meaning.
- State screens should feel like part of the product, not fallback leftovers.
- The app should feel calmer, lighter, and more premium without changing what the user can do.
