# BOOT MENU THEME

The Ventoy boot menu is a **GRUB2 gfxmenu** theme. Understanding one thing makes
everything else here obvious:

> **GRUB draws almost nothing.** The menu card, the sidebar, the `Select` pill,
> the `✕`, the `[enter] [s]ettings [c]onsole` bar at the bottom — all of it is
> painted into the background JPEG. GRUB only draws the entry text, the icons,
> the selection pill and the countdown label, positioned by percentage on top of
> that picture.

That is why the layout numbers in the theme files and the artwork have to be
designed together: move the menu and the text lands off the card.

---

## 1. WHAT GRUB ACTUALLY DRAWS

| Element | Comes from | Controlled by |
| :--- | :--- | :--- |
| Background, card, sidebar, key hints | `background_*.jpg` | your image editor |
| Entry text | GRUB | `item_color`, `selected_item_color`, `item_font` |
| Entry icons | `icons/<class>.png` | `menu_class` in `ventoy.json` |
| Selection pill | `select_*.png` | `selected_item_pixmap_style` |
| Countdown text | GRUB | the `+ label` block |
| Console window | GRUB | the `terminal-*` properties |

`select_*.png` is a **3-slice** pixmap: `_w` (left cap), `_c` (tiled centre),
`_e` (right cap). GRUB stretches `_c` to the row width, so the caps must be the
full row height and the centre can be one pixel wide.

---

## 2. FILE LAYOUT

```
ventoy/theme/
├── template/
│   └── theme.template.txt      <- edit this, not the generated files
├── build-theme.ps1             <- regenerates the 18 theme files
├── autoinstaller/
│   ├── theme_<style><ratio>_<art>.txt    18 generated files
│   ├── background_<style><ratio>_<art>.jpg   18 images
│   ├── icons/*.png             79 distro/OS icons
│   ├── select_c|e|w.png        selection pill slices
│   └── cascadia-code_16|28.pf2
└── preview_<style><ratio>.png  6 preview renders
```

`style` is `dark` or `light`, `ratio` is `169`, `43` or `1610`, `art` is `fb`,
`gh` or `htc`. 2 x 3 x 3 = 18.

**The eighteen `.txt` files are generated.** Only the geometry actually differs
between them, and it depends on the aspect ratio alone; style and artwork change
nothing but which image is named. Edit the template and run:

``` powershell
.\build-theme.ps1
```

`.\build-theme.ps1 -Check` fails if the committed files have drifted, which is
what CI runs.

---

## 3. GEOMETRY PER ASPECT RATIO

All values are percentages of screen size, so one design covers every resolution
of the same shape.

| | 16:9 | 4:3 | 16:10 |
| :--- | ---: | ---: | ---: |
| menu `left` | 18% | 8% | 16% |
| menu `width` | 50% | 65% | 52% |
| menu `top` / `height` | 18% / 64% | 18% / 64% | 18% / 64% |
| icon and row height | 76 px | 84 px | 84 px |
| countdown `left` / `width` | 30% / 36% | 24% / 43% | 28% / 32% |
| console `left` / `top` / `width` | 15% / 16% / 55% | 6% / 18% / 60% | 15% / 16% / 55% |

Row pitch is `item_height + item_spacing` = 92 px (16:9) or 100 px, with a 24 px
gap between icon and text.

---

## 4. REDRAWING THE ARTWORK

Current canvases are 4K at each ratio: **3840x2160** (16:9), **3840x2880** (4:3),
**3840x2400** (16:10). GRUB scales to the actual `gfxmode`, so keep the ratio and
stay at or above these sizes.

For a 16:9 canvas, the menu occupies **x 18%-68%, y 18%-82%** — at 3840x2160 that
is x 691-2611, y 389-1771. Draw the card so it covers that box with padding, and
leave the first row's centre at y ≈ 18% + half a row.

Text colours live in the template: `item_color` `#6C6E70`, selected `#CDCDCD`,
both light, because the card is dark in **both** styles — "light" only lightens
the area around the card. If you redraw the card light, change those two values
(and the countdown colour follows the selected colour).

`desktop-color` `#3B3B39` is the fill GRUB uses before the image loads and where
the image does not reach; set it to your background's dominant colour.

### Branding to remove

The current backgrounds carry the **previous owner's branding baked in**: a logo
and the name `1172005thinh`, a handwritten signature, a `HungThinhCloud` mark and
a QR code, all in the right-hand sidebar. This cannot be stripped with a script —
those pixels are the image. Redrawing the 18 backgrounds (and the 6 previews,
which are just renders) is the only way to clear it.

The 79 files in `icons/` are third-party distribution logos and carry no personal
branding; they can stay.

---

## 5. WIRING IT UP

`ventoy.json` picks which of the 18 files to use and preloads the fonts:

``` json
"theme": {
    "file": [ "/ventoy/theme/autoinstaller/theme_dark169_gh.txt" ],
    "gfxmode": "1920x1080",
    "fonts": [ "/ventoy/font/cascadia-code/cascadia-code_28.pf2" ]
}
```

Listing several files makes Ventoy pick one at random each boot, which is how the
three artwork variants are used. `gfxmode` must match the ratio of the theme you
point at, and every font size named in the theme must appear in `fonts` or GRUB
falls back to its built-in face.
