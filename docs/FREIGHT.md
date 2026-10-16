# Freight train display mode

In **Line settings**, select **Freight train** in a line's Type menu and apply the change. The existing physical railway filter still selects it. The directory adds a separate Freight train section, and static maps, first-person maps, transfers and merged branches use the same display type.

- A front-train pictogram with **bare bold digits**: no colored number tile, outline or background. Numbers use the existing HUD ink for contrast.
- Independent automatic sequence: **72001, 72002, 72003, …**. Passenger Train letters, RER letters, tram and bus numbering are unchanged.
- No automatic prefix or suffix. Existing manual prefixes, numbers and suffixes take precedence; leaving the number blank uses the automatic preview.
- Saved assignments stay stable when another line is discovered or added. Concurrent saves reserve separate indices. Save your game to retain them across reloads.
- One number identifies the persistent game line. Turning around does not change it. No Paris-relative direction or vehicle-specific train-run number is inferred.
- Freight maps initialize connections only for relevant station groups and explicitly linked nearby stops, selecting services with current non-passenger capacity. Passenger maps keep their passenger connections. No additional recurring fleet/map query is introduced; the existing current-vehicle progress check is unchanged.

Rail continues to default to **Train**. Freight train is a manual display choice; the mod does not scan every line's vehicles to infer cargo, train composition or logistics role. An unconfigured cargo railway is therefore still displayed as Train until you change its type. Freight can use the existing same-type/full-badge endpoint-connected merge rules; it does not merge with passenger Train just because their labels match.

City presets have no freight-train palette. Freight tracks retain game line colors; the unframed number remains legible HUD text. The train pictogram is the existing shared asset, and this feature adds no fonts, textures, timers, scripting events or stylesheet rules.

## French reference

The starting value is a **fictional game-line sequence inspired by a historical French freight number band**, not a claim to implement SNCF's current train-run allocation. [EspaceRails, “La numérotation des trains” (4 November 2012)](https://www.espacerails.com/reel/article-25-la-numerotation-des-trains.html) lists 70000–99999 for domestic block freight, with exclusions. The mod does not model those reservations, international/domestic classifications, composition indices or regional ranges, and does not infer them from cargo type.

The user selected 72001 as the starting point and manual overrides for other desired ranges. Consecutive line identifiers are not parity-based movement identifiers; [SNCF's direction-numbering reference](https://www.groupe-sncf.com/fr/groupe/patrimoine-archives/numeros-pairs-impairs-trains) concerns actual train numbering, not a game's persistent service label.

## 中文使用

在线路设置的「显示类型」中选择「货运火车」，点击应用。编号默认是 `72001、72002、72003…`，与客运 Train 的字母编号独立；火车图标旁直接显示粗体数字，没有编号底框。前缀和后缀默认为空，也可手动输入其他编号，例如 `52001` 或 `F-55001`。

铁路默认仍是 Train，货运火车为手动选择；不新增全线路车辆扫描来识别客货或猜测物流类别。货运图在初始化时只读取相关货运接驳，行驶中仍只检查当前车辆。保存游戏后保留配置，折返或新增其他线路不改变已保存标号。

这是一套借鉴法国历史号段的游戏线路编号，不是真实车次分配，也不按远离／朝向巴黎自动切换奇偶号。
