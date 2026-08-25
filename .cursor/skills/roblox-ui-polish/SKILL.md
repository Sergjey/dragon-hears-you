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
1. Read `refs/README.md` and any images under `refs/ui/`, `refs/mood/`.
2. Reuse existing ScreenGui / components if present.
3. If no refs yet: still follow **Tokens** below; do not invent a second style mid-feature.

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
