# Freight train display mode

Cargo-only rail fleets automatically use **Freight train**. In **Line settings**, you can override the Type and apply the change. The existing physical railway filter still selects it. The directory adds a separate Freight train section, and static maps, first-person maps, transfers and merged branches use the same display type.

- A front-train pictogram with **bare bold digits**: no colored number tile, outline or background. Numbers use the existing HUD ink for contrast.
- Independent automatic sequence: **72001, 72002, 72003, …**. Passenger Train letters, RER letters, tram and bus numbering are unchanged.
- No automatic prefix or suffix. Existing manual prefixes, numbers and suffixes take precedence; leaving the number blank uses the automatic preview.
- Saved assignments stay stable when another line is discovered or added. Concurrent saves reserve separate indices. Save your game to retain them across reloads.
- One number identifies the persistent game line. Turning around does not change it. No Paris-relative direction or vehicle-specific train-run number is inferred.
- Freight maps initialize connections only for relevant station groups and explicitly linked nearby stops, selecting services with non-passenger load capability. Passenger maps keep their passenger connections. No additional recurring fleet/map query is introduced; the existing current-vehicle progress check is unchanged.

**Train**, **Freight train** and **Truck** are distinct passenger railway, freight railway and road freight categories; there is no duplicate “Freight” category. Internal saved IDs remain compatible.

On initialization, rail fleets with non-passenger capability and no passenger capability automatically use Freight train. This uses the same `TRANSPORT_VEHICLE.config.allCaps` and passenger cargo ID as Build 40420's native `vehicle_util.isAbleToLoadCargo` / `isAbleToLoadPassenger`, falling back to current capacities when allCaps is absent. Passenger/mixed fleets and empty or unknown fleets remain Train. Explicit user display types and numbers still win; old automatic Train letters migrate to the independent numeric sequence.

Opening the directory classifies its rail metadata once. First-person/static initialization checks only the current route, explicit same-badge candidates and its relevant connections. Capacity results and component reads are memoized for that initialization and then discarded. No fleet checks run during idle/arrival progress updates. Changing a fleet becomes visible next time you reopen the directory/map or reenter first person. Freight and passenger Train do not merge merely because their labels match.

City presets have no freight-train palette. Freight tracks retain game line colors; the unframed number remains legible HUD text. The train pictogram is the existing shared asset, and this feature adds no fonts, textures, timers, scripting events or stylesheet rules.

## French reference

The starting value is a **fictional game-line sequence inspired by a historical French freight number band**, not a claim to implement SNCF's current train-run allocation. [EspaceRails, “La numérotation des trains” (4 November 2012)](https://www.espacerails.com/reel/article-25-la-numerotation-des-trains.html) lists 70000–99999 for domestic block freight, with exclusions. The mod does not model those reservations, international/domestic classifications, composition indices or regional ranges, and does not infer them from cargo type.

The user selected 72001 as the starting point and manual overrides for other desired ranges. Consecutive line identifiers are not parity-based movement identifiers; [SNCF's direction-numbering reference](https://www.groupe-sncf.com/fr/groupe/patrimoine-archives/numeros-pairs-impairs-trains) concerns actual train numbering, not a game's persistent service label.

## 中文使用

在线路设置的「显示类型」中选择「货运火车」，点击应用。编号默认是 `72001、72002、72003…`，与客运 Train 的字母编号独立；火车图标旁直接显示粗体数字，没有编号底框。前缀和后缀默认为空，也可手动输入其他编号，例如 `52001` 或 `F-55001`。

纯货运铁路车队自动使用货运火车；客运、客货混合、空线路或能力不明时使用 Train。读取游戏原生 allCaps／capacities 装载能力，兼容自动换货车厢；手动类型和编号优先。旧自动字母编号转入独立数字序列。打开目录时识别目录中的铁路，第一人称／静态图初始化只识别当前及相关线路；缓存限本次初始化，行驶与到站检查不再读取车队。修改车辆后重新打开目录／线路图或重新进入第一人称即可更新。货车（Truck）是公路货运，不与货运火车混为一类。保存游戏后保留编号，折返或新增线路不重排旧编号。

这是一套借鉴法国历史号段的游戏线路编号，不是真实车次分配，也不按远离／朝向巴黎自动切换奇偶号。
