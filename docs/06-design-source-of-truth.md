# 06 — Design Source of Truth

This document is the visual design source of truth for Billed. Use it when
adding or reviewing UI work. The older UI spec describes product behavior; this
document describes the intended look, hierarchy, and interaction feel.

Reference concept:

![Liquid Glass dashboard concept](assets/liquid-glass-dashboard-concept.png)

## Product Feel

Billed should feel like a native macOS menu bar instrument: compact, calm,
premium, and glanceable. It is not a marketing surface and not a full analytics
app. The panel should answer three questions quickly:

1. Which provider am I viewing?
2. How much usage happened in this range?
3. What changed across time, activity, and models?

The target aesthetic is Apple-inspired Liquid Glass: translucent layered
surfaces, restrained depth, crisp typography, and subtle system accent color.
Avoid decorative gradients, noisy backgrounds, and oversized promotional copy.

## Layout

The primary surface is a floating menu bar panel.

- Target width: 380-430 pt.
- Minimum practical height: 620 pt.
- Corner radius: 10-14 pt for the outer panel, 8 pt for internal surfaces.
- Padding: 16 pt horizontal page padding, 10-14 pt vertical section spacing.
- Scrolling: content scrolls under a fixed-feeling header and footer.

Top-to-bottom structure:

1. Header
2. Provider tabs
3. Range selector
4. Hero usage summary
5. Supporting metric cards
6. Token split
7. Daily trend
8. Activity
9. Time of day
10. Models
11. Footer actions

## Header

The header establishes context and should be visible at first glance.

- Show an icon badge for the selected provider.
- Show selected provider name as the title.
- Show last updated or cached state below the title.
- Put refresh at the right as an icon button.
- Use `Color(nsColor: .controlBackgroundColor)` or a macOS material-like
  surface. Keep the header visually distinct from scroll content.

Provider badge:

- Size: 34 x 34 pt.
- Shape: rounded rectangle, radius 8 pt.
- Fill: accent color at low opacity.
- Icon: SF Symbol from `ServiceProvider.iconName`, semibold, accent color.

## Provider Tabs

Provider tabs are compact pills, not large navigation tabs.

- Include provider icon and display name.
- Active tab uses accent color at low opacity.
- Inactive available tabs use a subtle secondary fill.
- Disabled providers are dimmed, but still understandable.
- Missing providers are tertiary and disabled.
- Keep tab labels one line.

Supported providers:

- Cursor
- Claude
- Codex
- Antigravity
- Opencode

## Range Selector

The range selector remains a native segmented control.

- Options come from `UsageRange.allCases`.
- It sits below provider tabs.
- It should span the panel width.
- Changing range updates the menu bar metric and all dashboard sections.

## Hero Usage Summary

The hero summary is the first data object in the panel.

Content:

- Eyebrow: `Current usage`
- Primary number: compact total tokens, e.g. `12.8M`
- Unit label: `tokens`
- Summary chips: cost and request count

Style:

- Use large rounded/tabular numerals.
- Background uses accent color at low opacity.
- Keep it calm; no saturated gradients.
- If tokens are unavailable for a provider, show `0` and let request/activity
  sections carry the provider-specific signal.

## Metric Cards

Supporting metrics sit below the hero.

Default cards:

- Cache read
- Average cost per request

Rules:

- Two cards per row.
- Each card has an icon, muted label, strong value, and muted detail.
- Cards use a subtle control-background fill and radius 8 pt.
- Values use monospaced digits and a one-line limit.

## Section Surfaces

Secondary analytics sections should use consistent surfaces.

Section header:

- SF Symbol icon.
- Semibold subheadline title.
- No large explanatory copy.

Section body:

- Token split: stacked bar plus compact legend.
- Daily trend: chart plus metric picker.
- Activity: compact two-column stat grid.
- Time of day: 24-hour heatmap.
- Models: sortable list with bars.

Surface style:

- Fill: `Color(nsColor: .controlBackgroundColor)`.
- Radius: 8 pt.
- Padding: 12 pt.
- Spacing: 10 pt inside each section.

## Typography

Use system fonts throughout.

- Provider title: headline semibold.
- Hero number: 34 pt, bold, rounded design, monospaced digits.
- Section title: subheadline semibold.
- Card value: title2 semibold, monospaced digits.
- Labels/details: caption or caption2, secondary foreground.

Do not use negative letter spacing. Avoid hero-scale text outside the hero
usage number.

## Color And Material

Primary palette:

- Background: native macOS window background.
- Header/footer and section cards: native control background.
- Accent: system accent color, low opacity for fills.
- Text: primary/secondary/tertiary system foreground styles.

Avoid:

- Purple gradient themes.
- Beige/tan or brown/orange palettes.
- Dark blue/slate-heavy dashboard styling.
- Decorative orbs, bokeh, or abstract blobs.

Liquid Glass direction:

- Use translucent, layered surfaces where native macOS material is available.
- Use subtle highlights and separation rather than heavy borders.
- Keep contrast strong enough for small menu bar panel text.

## Charts And Data Density

Charts are supporting evidence, not the primary hero.

- Daily trend height: about 130 pt.
- Time-of-day heatmap height: about 18 pt plus labels.
- Model rows use compact bars and one-line names.
- Empty states should be short and specific: `No usage in this range`.

## Footer

Footer actions stay compact and utility-oriented.

Actions:

- Settings
- Launch at login
- Quit

Style:

- Use a subtle footer surface matching the header.
- Use icon + text for Settings and Quit.
- Keep font at caption size.

## Interaction Rules

- Refresh is always available for configured providers.
- Switching providers clears stale metrics before loading the next provider.
- Async refreshes must only update the UI if their provider is still selected.
- Disabled providers may be visible, but they should not silently affect
  aggregate menu bar totals.
- Settings toggles are the source of truth for provider enablement.

## Accessibility

- Metrics and rows should combine child labels into a clear VoiceOver sentence.
- Icon-only controls require accessibility labels and help text.
- Do not encode state by color alone.
- Text must remain readable in light and dark mode.
- Keep target sizes comfortable for pointer use in a menu bar popover.

## Implementation Checklist

Before accepting UI changes:

- The first viewport shows provider identity and primary usage.
- Provider switching cannot display another provider's stale tokens.
- The panel builds in light and dark mode using system colors.
- No text overlaps or clips at the target width.
- Charts and lists show useful empty states.
- `swift build` passes.

## Non-Goals

- No full-screen dashboard.
- No marketing landing page.
- No decorative hero illustration.
- No custom image-heavy branding system.
- No animated or playful visual effects unless they improve clarity.
