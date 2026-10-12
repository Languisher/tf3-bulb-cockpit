# In-Game Route Display · mod.io release materials · 0.1.68dev

This directory documents the prepared development release. A staged folder or GitHub upload does not establish that a public mod.io listing exists.

## Contents

- `mod/_metadata/modinfo.json`: English profile and Chinese localization, with the supported `Script Mod` tag and repository URL.
- `mod/_metadata/0.png`: 1920×1080 AI promotional cover.
- `mod/_metadata/1.png`: 1920×1080 gameplay gallery image, RER branches.
- `mod/_metadata/2.png`: 1920×1080 gameplay gallery image, bus route and transfers.
- `docs/images/`: unchanged full-resolution screenshots used in both READMEs.
- `cover-prompt.txt`: final prompt used with the built-in imagegen tool.
- `changelog.txt`: upload changelog text.

The upload folder must contain `mod.json`, `_metadata/` and `content/` directly. Stage only `mod/`, not this repository, its backups, or a containing ZIP. Keep `modId` as `linnan_bulb_cockpit` for save compatibility; the prepared upload uses revision `68` and the human-facing version `0.1.68dev`. Its English title is **In-Game Route Display** and its Chinese title is **游戏线路显示**.

## Publish through the game

1. Place the folder in the profile's `local/staging_area/linnan_bulb_cockpit/` and restart the game so it is discovered.
2. Main menu → Mod Hub → My Mods → select In-Game Route Display / 游戏线路显示. Log in to mod.io if prompted.
3. Check the cover, both gallery screenshots, profile and platform validation. Use the development-build description as supplied; Windows/Linux/console compatibility is not claimed.
4. Set visibility to Public and upload. Resolve any reported validation errors; a locally verified archive is not a substitute for the game's publisher validation.
5. Verify the resulting mod.io page and platform file status, then add that exact page URL to the READMEs.

On macOS the profile is usually `~/Library/Application Support/Steam/userdata/<Steam user ID>/3493540/local/`. When a staged copy and installed copy share a modId, the game prefers staging; their runtime content should match while preparing an upload. Do not use stale staging copies for later testing.

## Future updates

Preserve `_metadata/mod.io_fileid.txt` in the local staging folder after the first successful upload. It identifies the existing listing. Increase `revision` for later file releases and verify that the upload panel says it will update the existing mod. The packaging tool excludes this publishing reference from installable archives, and Git ignores it. Changes made only to the website profile can be overwritten by metadata from a later game upload.

## Sources

- [Official publishing workflow](https://wiki.transportfever3.com/doku.php?id=modding:general:publishing)
- [Mod metadata, translations and gallery image conventions](https://wiki.transportfever3.com/doku.php?id=modding:general:moddefinition)
- [Supported tags](https://wiki.transportfever3.com/doku.php?id=modding:general:modtags)
