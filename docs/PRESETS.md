# City line presets

Open **Line settings → Line presets**. Choose Default, Paris, Shanghai or Munich for all types, or choose independently for Train, RER, Metro, Tramway, Bus, Ferry, Air, Truck and Freight train. “Per type” indicates mixed choices. Changes apply after the save command succeeds; save the game to retain them across reloads. Existing saves start with Default without a migration write.

Presets change **badge colors/shapes and diagram track colors**, including merged branches, static maps, first-person maps and transfers. They never change a real game's line name, transport type or stored line color. Default uses game colors and the existing mode shapes. Unsupported numbers keep game colors but retain the selected city shape/symbol for supported transport types. Unsupported types retain their existing style.

The complete displayed badge is matched first, ignoring case and spaces and recognizing mode prefixes such as `T`, `U` and `S`. If it does not match, the configured number/letter field is tried. Recognized standard prefixes and leading zeros normalize to the city badge (M01 → Paris 1; 1 → Munich U1/S1). Other custom prefixes and suffixes remain visible. Number search also matches this rendered badge. Example: Metro number `1` can use Shanghai red while RER `S1` uses Munich light blue and Tramway `T3b` uses Paris green.

| Preset | Matched identifiers | Badge treatment |
| --- | --- | --- |
| Paris Metro | 1–18, 3bis, 7bis | Circular, contrasting number |
| Paris RER | A–E | Existing rounded-square rail badges |
| Paris Train | H, J, K, L, N, P, R, U | Existing train/rail badges |
| Paris Tramway | T1, T2, T3a, T3b, T4–T14 | Colored double bars, dark lettering |
| Paris Bus | 183, 393, TVM, Tzen1–Tzen6 | Existing flat bus badges |
| Shanghai Metro | 1–18 | Square, white numbering; red mode mark |
| Munich Metro | U1–U8 (also 1–8) | Full U1–U8 labels in 2:1 rectangles, white numbering; U7/U8 use two colors |
| Munich RER | S1–S8 (also 1–8) | Full S1–S8 labels in 2:1 capsules; white numbering except black for S8; S mode mark |
| Munich Tramway | 12, 14, 16–21, 23, 25, 27, 28 | Rectangular; 28 outlined; Tram mode mark |

Paris Metro 1 is yellow (#ffcd02). Munich **U1 is green (#52822f), U3 is orange (#ee732a)**; S1 is light blue. Shanghai Train/RER/Tramway and all unlisted city/type/number combinations fall back to the game color. Choosing a city does not change Train into Metro or RER: select the appropriate display type first. For Munich S-Bahn, manually select **RER** as the display type; the physical game's railway filter is unchanged. U7/U8 badge overlays show both colors; their track uses the primary line color. Track thickness and tram center stripes still follow the mod's existing transport-mode design.

These are compact native-GUI approximations, using the game's fonts and shared geometric masks, not bundled official fonts or full operator artwork. No commercial Parisine font is included. Digital map colors can differ from print specifications. Future routes not included in the offline tables fall back instead of guessing.

## Sources

Checked 2026-10-17 (MVG and RATP maps rechecked for this fix). Sources are references and are not bundled in the installable mod.

- Paris palette assignments and existing badge proportions: [BULB editor](https://bulb.slama.io/editor), its Paris presets. Operator references: [Île-de-France Mobilités signage guidance](https://prim.iledefrance-mobilites.fr/fr/chartes-et-prescriptions/prescriptions-signaletiques), [RATP Metro 1](https://www.ratp.fr/plans-lignes/metro/1) and [network maps](https://www.iledefrance-mobilites.fr/le-reseau/plans).
- Shanghai Metro line colors and square badges: [Shanghai government, operator network map](https://english.shanghai.gov.cn/en-Latest-WhatsNew/20240924/b625d488216241f78f743cd87a40df0c.html), cross-checked against the [2026 operating timetable](https://www.shanghai.gov.cn/nw17239/20260413/d8e14c16213246eba8fac7c23b2b04af.html). Coverage is 1–18, not a claim to include every current or future Shanghai service.
- Munich U/S colors and shapes: [MVG network and tariff map, January 2026](https://www.mvg.de/dam/mvg/plaene/netz-tarifplan.pdf). Tram colors and limited-service outlined badges: [MVG tram network, March 2026](https://www.mvg.de/dam/jcr:d01df598-a358-44ad-9c35-3984488c036c/A4-Tramnetz-2026-Web.pdf). Both are available through [MVG's map page](https://www.mvg.de/verbindungen/fahrplaene-netzplaene.html).

## Runtime and maintenance

`presets.lua` contains only static tables and pure lookups. Applying a palette decorates newly created diagram data; collected game snapshots are never mutated. It does not scan the map, fetch network data, add a timer or poll settings. Changing a dropdown sends one explicit command; repeated unchanged selections send none. The simulation merges the nested per-type patch and skips unchanged saves. Other preferences and line edits are retained.

One new 64×64 white-alpha diagonal mask is shared by Munich U7/U8. It is generated offline by `python3 tools/make_badge_diagonal.py`; no image generation or per-line texture creation runs in the game. Square and capsule badges reuse native rectangles and the existing circle mask. This feature adds no stylesheet rules or global selectors.

## 中文使用说明

进入「线路设置 → 线路预设」，可统一选择默认／巴黎／上海／慕尼黑，也可按 Train、RER、地铁、电车、公交、货运火车等类型分别选择。各类型不同时，统一选择框显示「分别设置」。保存命令成功后生效，保存游戏后可在下次载入时保留。

预设同时影响编号图标、线路图线条和对应换乘标识；主线、合并分支、静态图和第一人称使用同一规则。默认或未匹配的编号继续沿用游戏颜色；支持的类型即使编号未匹配，也保留城市图标样式，不修改游戏里的真实线路名或颜色。先匹配最终标号，再尝试编号字段；识别到的常用交通前缀和前导零按城市样式归一，其他自定义前后缀保留。巴黎地铁 1 号为黄色；慕尼黑 U1 为绿色、U3 为橙色、S1 为浅蓝色。预设不改变显示类型，慕尼黑 U 线须选择地铁类型。上海未配置 RER 配色；慕尼黑 S 线请使用 RER 显示类型。

样式通过游戏原生字体与共用几何图形近似，不包含商业字体。配色范围见上表；未列出的类型和编号会回退到游戏颜色。慕尼黑 U7／U8 的编号标识为双色，线路图线条使用其主色。预设不新增联网、计时器、地图扫描或配置轮询。

As of 0.1.83dev, wide city badge geometry is resolved **before** station spacing and row wrapping. The same geometry drives directory buttons, identity marks, transfers and click targets, rather than squeezing a 2:1 badge into half of a square slot.
