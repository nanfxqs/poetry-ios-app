> 历史规范：R1，已被 [DESIGN.md](DESIGN.md) 替代，不用于当前设计。

# Design System: 诗词 · 页边入景

## 1. Visual Theme & Atmosphere
An intimate, quiet Chinese classical poetry reader for iPhone. The accepted direction is D: a small landscape vignette at a page-header corner, fading into the page. Poetry remains the primary surface. The atmosphere is romantic but restrained, with no standalone oversized illustration panel and no imagery under the poem. A small top illustration is a fallback direction only.

## 2. Color Palette & Roles
- Warm ivory #F8F8EE: continuous reading canvas and navigation surface.
- Deep ink #253D31: poem text and prominent headings, always clearly readable.
- Moss green #3D6754: active navigation and actions.
- Muted forest #5D7062: secondary readable labels; avoid faint gray fine print.
- Pale leaf #DCE2D5: separators and control outlines.
- Mist green #C6D1C4: decorative landscape detail, outside text areas.

## 3. Typography Rules
Use Noto Serif CJK SC or a Chinese Songti-style serif for Chinese poems and literary headings; use Noto Sans CJK SC/system sans for controls and metadata. The Chinese glyphs must be supported. Poem text approximately 22px with generous 1.9–2.3 line-height; titles 22–26px; control text 14–16px. Keep long titles wrapping naturally. Avoid excessive character spacing and preserve larger accessibility text.

## 4. Component Stylings
- Buttons: quiet outlined controls, gently curved 8px corners; compact pill-shaped tag filters are acceptable. Touch targets at least 44px.
- Containers: mostly flat, continuous canvas. Thin separators rather than stacked floating cards. Compact result sheets may have softly curved 12px top corners.
- Inputs: simple readable search field, restrained outline, clear placeholder and filter action.
- Bottom navigation: three equal icon-and-label items 今日 / 探索 / 诗集 with a clearly indicated active item. Respect iPhone safe areas.
- Illustrations: a small static corner vignette fading at its edges. Keep all actual poem glyphs on an unobstructed solid canvas. Never a historical-location claim.
- Graphs: restrained nodes with readable names and sparse labeled relationships. No glowing particles, orbiting stars, or continuously moving layout.

## 5. Layout Principles
Mobile-first portrait at approximately 390px width. Horizontal margins around 24px, consistent 8px spacing rhythm. Header branding and a small vignette share the same band. Title and author precede the poem without a large hero. Text, one short emotional cue, save/sound actions and expandable interpretation follow. Keep natural content density; no artificial giant empty areas. Long poems scroll. Images stay static and sound defaults off; only short necessary interaction transitions, honoring reduced motion.
