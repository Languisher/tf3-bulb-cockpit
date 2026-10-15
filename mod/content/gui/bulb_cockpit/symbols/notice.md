# Paris rail graphical marks

`rer-a.tga` through `rer-e.tga` and `rer-frame.tga` are white-alpha
raster layers converted from the Paris RER A–E SVG marks publicly rendered
in BULB's “Use a preset” dialog (v1.5.2-alpha, inspected 2026-10-10):
https://bulb.slama.io/editor

The letter outlines and rounded frame preserve those graphical marks' proportions.
By default, the mod tints the frame with each live game line's color and selects
black or white letter ink for contrast. Optional city presets override the display
color; the real game line color is unchanged. See docs/PRESETS.md in the repository.

BULB credits its pictograms and fonts to RATP, Île-de-France Mobilités and the
respective rights holders. These marks remain their property. This mod is not
affiliated with or endorsed by BULB, RATP or Île-de-France Mobilités.
No Parisine font file is included. The other primitive shape masks and tram
side-view symbol in this folder were drawn for this mod.

`transilien-mode.tga` is the white-alpha front-train pictogram inside a rounded
square used for BULB's Transilien (`TRAIN`) mode. It was converted offline from
the SVG mask displayed by the editor's `.picto .layer1[data-v-45c2d838]` style
(v1.5.2-alpha, inspected 2026-10-13). The source outline is preserved in
`tools/assets/transilien-mode.svg`; the website's duplicate identical path is
included only once. This pictogram has the same third-party rights attribution
above and is not covered by this repository's MIT license.

The mod uses this pictogram for its Train mode identity and transfers; line-letter
badges still use the Paris RER A–E outlines described above. A single shared
128×128 mask is loaded by the game; no SVG processing runs during gameplay.

`rer-mode-ring.tga` is a simple transparent rounded-square outline drawn for this mod. Its RER text is rendered with the game font. The outline is generated offline by `tools/make_rer_mode_ring.py`; it does not embed a font or reuse the Transilien pictogram.

`badge-diagonal.tga` is an original 64×64 geometric alpha overlay for Munich U7/U8 two-color badges, generated offline by `tools/make_badge_diagonal.py`. It contains no third-party artwork or font.
