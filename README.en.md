# In-Game Route Display · 0.1.83dev

English · [中文说明](README.md)

![In-Game Route Display AI-generated promotional cover](mod/_metadata/0.png)

AI-generated promotional artwork. See the screenshots below for actual gameplay.

Shows vehicle routes, stop progress and transfers directly in Transport Fever 3, with dynamic first-person maps and a clickable line directory. No browser, image export or external renderer is needed while playing.

This is a development build targeting macOS Build 40420. Windows and Linux have not been tested. Long-session FPS degradation remains under investigation; passing Lua tests does not establish that the game’s native resources are fully released.

## In-game screenshots

Rail branches, captured before the Train/RER split, with the line identity at the upper left and the route, branches and transfers at the bottom.

![RER branch map during gameplay](docs/images/rer-branch-gameplay.png)

A bus route with a longer stop sequence and bus / tram transfer badges.

![Bus route and transfer badges during gameplay](docs/images/bus-transfers-gameplay.png)

These are the user's original 5120×2880 gameplay captures, without AI alterations. Click either image to view the original.

## Install

Published packages are available under [Releases](https://github.com/Languisher/tf3-bulb-cockpit/releases). To install this development version from source, copy `mod/` into the game’s user directory as `local/mods/linnan_bulb_cockpit`, or run `python3 install.py` on macOS. The installer backs up the previous mod and leaves game saves untouched.

1. Fully quit the game before installing or upgrading.
2. Load your save with **In-Game Route Display** (Chinese title: **游戏线路显示**) enabled.
3. Open the route-map button in the upper-right corner of the normal map view. Hold its small top grip to drag it.
4. The interface defaults to English. Use the language picker on the directory homepage to choose your interface language.
5. Save your game to retain the language preference when reloading.

Saves without a language preference default to English; existing English or Chinese preferences are preserved. The picker now supports English, Simplified Chinese, Traditional Chinese, French, German, Spanish, Italian, Brazilian Portuguese, Russian, Polish, Turkish, Ukrainian, Japanese and Korean. Only the mod interface is translated: line names, station names, city names and custom badges retain their original text. The existing window title, button hints and page content switch immediately. Language and blinking preferences are saved independently.

Typical macOS Steam installation location:

```text
~/Library/Application Support/Steam/userdata/<Steam user ID>/3493540/local/mods/linnan_bulb_cockpit/
```

## Use

- The settings entry starts at the upper right, on the same row and at the same size as the native layers button. Hold its small top grip to drag it; click the button body to open settings. Enter a vehicle’s first-person view to show its identity at the upper left and its route map at the bottom center. The settings button is hidden in first-person view and in the pause menu.
- The directory lists Train, RER, Metro, Tramway and Freight train badges. Bus lines appear only after a search. Click a badge to view the full static map; click a transfer badge to navigate to that line. Returning releases the current map’s data.
- The pin beside **Back to routes** locates the selected real line on the game map and closes the window.
- **Line settings** edits each badge as prefix + number/letters + suffix. Search by name or complete badge, such as `T1` or `T3b`. **Apply all** includes edits hidden by a search filter. These edits never rename real game lines.
- Rail defaults to Train, using BULB’s Transilien front-train pictogram and A/B/C letters. RER is a separate opt-in category between Train and Metro with an RER wordmark. Tram defaults to Tramway. Rail and tram can be displayed as Train, RER, Metro or Tramway. Legacy automatic rail letters and explicit RER choices are retained. Colors come from the game by default.
- **Line settings → Line presets** offers Default, Paris, Shanghai and Munich globally or per type. Presets change badges and diagram tracks, including branches and transfers; unknown numbers fall back to game colors. See [coverage and sources](docs/PRESETS.md).
- **Automatic freight-train recognition** uses rail fleet load capability, including auto-load wagons. Passenger/mixed and empty fleets remain Train; explicit user types take precedence. Freight trains use the train icon and borderless `72001`, `72002`, … labels with stable saved numbering and manual overrides. Classification runs when opening the directory or initializing relevant routes, with no recurring fleet scan. The former road “Freight” type is now clearly named **Truck**. See [freight numbering](docs/FREIGHT.md).
- Lines of the same display type and complete badge merge only when their actual endpoints form one connected group. Manually linked nearby stops count as transfers, not shared merge endpoints.
- Unreached stops served by the current vehicle stay yellow. **Blinking: On** makes only the next stop flash; later stops remain steady. Passed, skipped and other-branch stops have no yellow lamp. Blinking is off by default and may reduce performance when enabled. Stops on branches the vehicle does not serve remain white inside.
- **Bus numbering** configures numeric city / Express prefixes and is disabled by default. Prefix `10` produces `1001`, `1002`, …; prefix `51` produces `5101`, `5102`, ….
- **Link stops** lets you select two separate stops directly on the map to share their transfer information.

**Line settings** includes the game's native road / tram / rail / ship / air multi-select filters. No selection shows all lines. Filters follow actual transport, so a rail line displayed as Metro remains in the rail category. Search and carrier filters work together; Apply all retains hidden edits.

English and other Latin-script station names wrap between words using the existing font metrics. CJK labels can still break between characters. Labels stay within two rows; extra words or an oversized single word use an ellipsis, and hovering shows the full name. The same layout is used in the HUD and static branch maps.

**Route-map scale**, above the transport filters, defaults to **100%**, ranges from **10% to 400%** in **1% steps**, and has a Reset button. It changes only the bottom first-person diagram. Mouse dragging submits one save on release; save the game to retain the preference. Branch diagrams still fit the available screen height. Zoom changes native rail, station and transfer dimensions together and renders text at its final font size, avoiding magnified glyphs and inconsistent branch lengths. Long translated back captions size their button to fit; narrow layouts provide the full tooltip.

GUI dimensions are calibrated once per loaded game and shared by both entries. Startup retries are bounded and their component is removed afterward; rides, re-entry and opening settings perform no further size queries. Reload the save after changing resolution, window size or UI scale. Duplicate notifications for the same camera vehicle do not reset the route session. Opening settings coalesces queued requests and reuses unchanged configuration revisions. Measurement probes never paint; the whole launcher is hidden in first-person view.

Route metadata is initialized for the selected line and its relevant connections. While riding, the mod checks the current vehicle every half-second and updates the diagram when progress changes. Leaving first-person view unloads the HUD and releases session data. After changing stops or colors outside the mod, leave and re-enter first-person view to refresh.

## Development and validation

Requires Python 3 and Lua 5.4:

```sh
python3 tools/run_tests.py
python3 tools/package.py
```

Five integration tests require GUI sources extracted from your own Build 40420 installation:

```sh
python3 tools/run_tests.py --game-gui /path/to/extracted/gui/main
```

The directory must contain `react.lua`, `stylesheetutil.lua` and the relative `../../scripts/mat4.tl`. Game sources are not redistributed. Without this argument, those tests are explicitly skipped.

Version 0.1.83dev passed 63 Lua tests and 97 syntax checks locally, including floating-entry placement parameters, a competing camera-replacement scenario, bilingual persistence, failure rollback, native React wrappers, layout bounds and resource-lifetime budgets. These checks mock the game’s C++ GUI and cannot replace in-game visual, dragging and performance checks.

## Missing route-map button

The button appears after loading a save in normal map view. It is hidden in first-person view, the pause menu and the game's main menu. Enable the mod for that save and fully restart the game after updating.

Version 0.1.83dev mounts an independent native floating window through the official `ModEntryPointExtension`. It starts at the upper right and can be dragged, without occupying the layers/clock toolbar. Earlier versions attached the entry to `FreeCamOptions`; another UI mod replacing that component could remove it. The first-person HUD still adapts the camera component, so this does not establish compatibility with every UI mod.

If it remains missing, report your OS, game Build, mod version, other UI mods and startup errors mentioning `linnan_bulb_cockpit`. When verbose logging is retained, `[Route Display 0.1.83dev] floating entry mounted` confirms that the entry was submitted to the native window manager; an installed message alone does not.

The mod includes no commercial Parisine font or game fonts. It uses the game’s native fonts and approximates BULB’s visual style. Asset attribution is in [notice.md](mod/content/gui/bulb_cockpit/symbols/notice.md). This project is not affiliated with BULB, RATP, Île-de-France Mobilités or the game developer.

Translation catalogs load only when selected, with English fallback and no extra polling. See [i18n maintenance](docs/I18N.md). Native font appearance still requires in-game checks across languages.
