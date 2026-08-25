---
name: roblox-ui-polish
description: >-
  Design polished Roblox UI, HUD, and presentation that feel modern and playable.
  Use when building ScreenGui, menus, HUD, buttons, shops, dialogs, or when the
  user mentions UI, UX, visuals, animations polish, or that something looks ugly
  or default Roblox.
---

# Roblox UI polish

## Goal
Ship UI people would actually play: clear hierarchy, readable on phone, intentional motion, on-theme with **dragon-hears-you** — not stock Studio defaults.

## Before drawing pixels
1. Check `refs/ui|mood|chars` for images; if empty, use **Tokens** + **Component recipes** below (and `refs/LINKS.md` for human inspiration).
2. Reuse existing ScreenGui / components if present.
3. Do not invent a second style mid-feature — stick to ember tokens.

## Tokens (v1 — ember dragon)
| Role | Value |
|------|--------|
| Bg deep | RGB ~18, 14, 12 |
| Panel | RGB ~32, 24, 20 @ 0.92 transparency ok with blur |
| Accent | warm ember RGB ~232, 120, 48 |
| Accent 2 | soft gold RGB ~232, 196, 120 |
| Danger | RGB ~200, 64, 56 |
| Text primary | near-white RGB ~245, 240, 230 |
| Text muted | RGB ~170, 155, 140 |
| Corner | `UICorner` 8–12px (consistent per tier) |
| Pad | 8px grid (8 / 16 / 24) |

Typography: one display-ish font for titles (e.g. `Enum.Font.GothamBold` or a licensed custom) + one body (`Gotham` / `GothamMedium`). Max 2 fonts. Title > body > caption sizes with clear contrast.

## Hard bans
- Default blue `TextButton` with no restyle
- Offset-only layouts that break on mobile
- Walls of text; unlabeled icon buttons with no affordance
- Rainbow gradients, heavy drop shadows stacked 3+ deep, emoji as primary UI
- Instant show/hide with no tween for major panels (use 0.15–0.25s Quad/Out or springs)
- Blocking the whole screen without a clear close/back control

## Interaction states (required)
Every primary control needs **default / hover / pressed / disabled** (color, transparency, or scale 0.96–1.0). Sound optional but one click SFX > silence for core actions.

## Layout checklist
- [ ] `IgnoreGuiInset` decided deliberately (HUD vs full-screen menu)
- [ ] Safe area: top bar / notch not covering HP or currency
- [ ] Thumb-reachable primary CTA on phones
- [ ] Contrast readable on light and dark world backdrops (add panel scrim if needed)
- [ ] `AutoLocalize` / text size: long English strings don’t clip

## Component recipes (no screenshots required)

### Primary button
- Height ~36–44px (scale on Y for mobile), `UICorner` 10, ember fill, gold text or inverse on hover
- `UIStroke` 1px gold @ 0.35 transparency; hover → brighter fill; press → scale 0.97

### Panel / modal
- Dark panel + slight transparency; full-screen dimmer behind (`BackgroundTransparency` 0.4 black)
- Title (bold) + short subtitle; content; footer with primary + ghost secondary
- Open: transparency + scale 0.96→1 in ~0.2s; close reverse

### HUD chip (HP / resource)
- Left or top-left cluster; bar with ember fill on deep track; icon 24px + number
- Don’t crowd center crosshair / dragon focus area

### Text
- Title 24–32, body 16–18, caption 12–14; muted for secondary
- Prefer short labels (“Listen”, “Bond”, “Flee”) over paragraphs

## Motion
- Panels: fade + slight Y or scale (0.96→1)
- Feedback: tiny scale punch on click
- Idle: at most one subtle loop (ember glow); don’t animate everything
- Use `TweenService` or a single shared spring util — don’t copy-paste tween code everywhere

## Characters & anims
- Prefer marketplace / custom Animation IDs for walk/idle/emote over rewriting Motor6D by hand
- Wire through `Animator` on Humanoid; stop conflicting anims when starting a new one
- Placeholder mesh OK only behind a TODO + ticket; don’t call it final art

## Assets
- Prefer `rbxassetid://…` you own or that’s licensed for the experience
- Studio MCP mesh/material gen = prototype only unless art-directed
- Put mood screenshots and target UI in `refs/` so future agents match them

## Deliverable bar
When finishing a UI task, state: which tokens used, mobile considered Y/N, states implemented, and leftover placeholders.
