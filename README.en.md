# In-Game Route Display · 0.1.74dev

English · [中文说明](README.md)

![In-Game Route Display AI-generated promotional cover](mod/_metadata/0.png)

AI-generated promotional artwork. See the screenshots below for actual gameplay.

Shows vehicle routes, stop progress and transfers directly in Transport Fever 3, with dynamic first-person maps and a clickable line directory. No browser, image export or external renderer is needed while playing.

This is a development build targeting macOS Build 40420. Windows and Linux have not been tested. Long-session FPS degradation remains under investigation; passing Lua tests does not establish that the game’s native resources are fully released.

## In-game screenshots

RER branches with the line identity at the upper left and the route, branches and transfers at the bottom.

![RER branch map during gameplay](docs/images/rer-branch-gameplay.png)

A bus route with a longer stop sequence and bus / tram transfer badges.

![Bus route and transfer badges during gameplay](docs/images/bus-transfers-gameplay.png)

These are the user's original 5120×2880 gameplay captures, without AI alterations. Click either image to view the original.

## Install

Published packages are available under [Releases](https://github.com/Languisher/tf3-bulb-cockpit/releases). To install this development version from source, copy `mod/` into the game’s user directory as `local/mods/linnan_bulb_cockpit`, or run `python3 install.py` on macOS. The installer backs up the previous mod and leaves game saves untouched.

1. Fully quit the game before installing or upgrading.
2. Load your save with **In-Game Route Display** (Chinese title: **游戏线路显示**) enabled.
3. Open the route-map button in the upper-right corner of the normal map view. Hold its small top grip to drag it.
4. The interface defaults to English. Click **中文** on the directory homepage to use Chinese; click **English** to switch back.
5. Save your game to retain the language preference when reloading.

Saves without a language preference default to English; explicitly saved English or Chinese preferences are preserved. Only the mod interface is translated: line names, station names, city names and custom badges retain their original text. The existing window title, button hints and page content switch immediately. Language and blinking preferences are saved independently.

Typical macOS Steam installation location:

```text
~/Library/Application Support/Steam/userdata/<Steam user ID>/3493540/local/mods/linnan_bulb_cockpit/
```

## Use

- The settings entry starts at the upper right, on the same row and at the same size as the native layers button. Hold its small top grip to drag it; click the button body to open settings. Enter a vehicle’s first-person view to show its identity at the upper left and its route map at the bottom center. The settings button is hidden in first-person view and in the pause menu.
- The directory lists RER, Metro and Tramway badges. Bus lines appear only after a search. Click a badge to view the full static map; click a transfer badge to navigate to that line. Returning releases the current map’s data.
- The pin beside **Back to routes** locates the selected real line on the game map and closes the window.
- **Line settings** edits each badge as prefix + number/letters + suffix. Search by name or complete badge, such as `T1` or `T3b`. **Apply all** includes edits hidden by a search filter. These edits never rename real game lines.
- Rail defaults to RER, using BULB’s Transilien front-train mode pictogram alongside its A/B/C letter badge; tram defaults to Tramway. Both can be configured as RER, Metro or Tramway. Colors come from the game.
- Lines of the same display type and complete badge merge only when their actual endpoints form one connected group. Manually linked nearby stops count as transfers, not shared merge endpoints.
- Unreached stops served by the current vehicle stay yellow. **Blinking: On** makes only the next stop flash; later stops remain steady. Passed, skipped and other-branch stops have no yellow lamp. Blinking is off by default and may reduce performance when enabled. Stops on branches the vehicle does not serve remain white inside.
- **Bus numbering** configures numeric city / Express prefixes and is disabled by default. Prefix `10` produces `1001`, `1002`, …; prefix `51` produces `5101`, `5102`, ….
- **Link stops** lets you select two separate stops directly on the map to share their transfer information.

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

Version 0.1.74dev passed 50 Lua tests and 69 syntax checks locally, including floating-entry placement parameters, a competing camera-replacement scenario, bilingual persistence, failure rollback, native React wrappers, layout bounds and resource-lifetime budgets. These checks mock the game’s C++ GUI and cannot replace in-game visual, dragging and performance checks.

## Missing route-map button

The button appears after loading a save in normal map view. It is hidden in first-person view, the pause menu and the game's main menu. Enable the mod for that save and fully restart the game after updating.

Version 0.1.74dev mounts an independent native floating window through the official `ModEntryPointExtension`. It starts at the upper right and can be dragged, without occupying the layers/clock toolbar. Earlier versions attached the entry to `FreeCamOptions`; another UI mod replacing that component could remove it. The first-person HUD still adapts the camera component, so this does not establish compatibility with every UI mod.

If it remains missing, report your OS, game Build, mod version, other UI mods and startup errors mentioning `linnan_bulb_cockpit`. When verbose logging is retained, `[Route Display 0.1.74dev] floating entry mounted` confirms that the entry was submitted to the native window manager; an installed message alone does not.

The mod includes no commercial Parisine font or game fonts. It uses the game’s native fonts and approximates BULB’s visual style. Asset attribution is in [notice.md](mod/content/gui/bulb_cockpit/symbols/notice.md). This project is not affiliated with BULB, RATP, Île-de-France Mobilités or the game developer.
