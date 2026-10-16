-- UI-only translations. Never translate game names or user-entered badges.
-- Bound translators are immutable snapshots; no global language or polling.
local I={}
I.english={
  ["货运火车"]="Freight train",
  ["线路预设"]="Line presets",
  ["默认"]="Default",
  ["巴黎"]="Paris",
  ["上海"]="Shanghai",
  ["慕尼黑"]="Munich",
  ["分别设置"]="Per type",
  ["全部类型"]="All types",
  ["返回线路设置"]="Back to line settings",
  ["预设保存失败，请重试。"]="Could not save the preset. Please retry.",

  ["线路图缩放"]="Route-map scale",
  ["恢复默认"]="Reset",
  ["缩放保存失败，请重试。"]="Could not save the scale. Please retry.",
  ["显示公路线路"]="Show road lines",
  ["显示电车线路"]="Show tram lines",
  ["显示铁路线路"]="Show rail lines",
  ["显示船舶线路"]="Show ship lines",
  ["显示航空线路"]="Show air lines",
  ["地铁"]="Metro",
  ["电车"]="Tramway",
  ["公交"]="Bus",
  ["轮渡"]="Ferry",
  ["航空"]="Air",
  ["货运"]="Freight",
  ["线路图设置"]="Route maps",
  ["关闭线路图设置"]="Close route maps",
  ["拖动此处移动线路图按钮"]="Drag here to move the route map button",
  ["线路目录"]="Route directory",
  ["线路设置"]="Line settings",
  ["返回线路目录"]="Back to routes",
  ["标识"]="Badge",
  ["前缀"]="Prefix",
  ["编号"]="Number",
  ["后缀"]="Suffix",
  ["线路"]="Line",
  ["显示类型"]="Type",
  ["操作"]="Action",
  ["应用"]="Apply",
  ["全部应用"]="Apply all",
  ["关联车站"]="Link stops",
  ["公交线路编号一键配置"]="Bus numbering",
  ["编号前的文字，例如 T、快、RER；可留空"]="Text before the number, e.g. T or RER; optional.",
  ["数字或英文字母，例如 3、A、AA、12A；留空使用预览编号"]="Digits or Latin letters, e.g. 3, A, AA or 12A; leave blank to use the preview.",
  ["编号后的文字，例如 b、支线；可留空"]="Text after the number, e.g. b; optional.",
  ["选择线路图中的交通标识样式"]="Choose the transport symbol used on route maps.",
  ["编号仅支持数字或英文字母；其他文字请放在前缀或后缀。"]="Use digits or Latin letters for the number; put other text in the prefix or suffix.",
  ["「%s」的编号仅支持数字或英文字母。"]="The number for “%s” must contain only digits or Latin letters.",
  ["未能校验同号线路，请稍后重试。"]="Could not check matching lines. Please retry.",
  ["已合并 %d 条同号线路。"]="Merged %d lines with the same badge. ",
  ["正在应用线路配置…"]="Applying line settings…",
  ["已应用。"]="Applied. ",
  ["请保存游戏。"]="Please save your game.",
  ["配置未写入，请稍后重试。"]="Settings were not saved. Please retry.",
  ["应用失败，请稍后重试。"]="Could not apply settings. Please retry.",
  ["同类型、同完整标号且起终点连通的线路合并显示；请保存游戏。"]="Lines with the same type and full badge merge when their endpoints connect. Save your game to keep changes.",
  ["当前存档没有线路。"]="No lines in this save.",
  ["没有找到匹配的线路。"]="No matching lines.",
  ["%d 条线路"]="%d lines",
  ["%d 条 · "]="%d lines · ",
  ["让独立站组在线路图中共享换乘，例如火车站与站前公交站"]="Share transfers between separate stops, such as a railway station and its nearby bus stop.",
  ["未能读取车站，请稍后重试。"]="Could not load stops. Please retry.",
  ["没有待应用的修改。"]="No pending changes.",
  ["正在应用全部修改…"]="Applying all changes…",
  ["已应用 %d 条修改，请保存游戏。"]="Applied %d changes. Please save your game.",
  ["全部应用失败，修改已保留，请重试。"]="Could not apply all changes. Your edits are kept; please retry.",
  ["维护城市与 Express 的数字前缀对照表，默认关闭"]="Set numeric prefixes for each city and Express routes. Disabled by default.",
  ["未能读取公交线路，请稍后重试。"]="Could not load bus lines. Please retry.",
  ["未能读取城市，请稍后重试。"]="Could not load cities. Please retry.",
  ["黄灯闪烁：开启"]="Blinking: On",
  ["黄灯闪烁：关闭"]="Blinking: Off",
  ["正在应用…"]="Applying…",
  ["已应用，请保存游戏。"]="Applied. Please save your game.",
  ["应用所有已编辑线路，包含被搜索筛选隐藏的修改"]="Apply all edited lines, including edits hidden by the search filter.",
  ["搜索编号"]="Search badge",
  ["搜索名称"]="Search name",
  ["名称"]="Name",
  ["全部"]="All",
  ["按名称或完整线路标号搜索，例如 T1、T3b"]="Search by line name or full badge, e.g. T1 or T3b.",
  ["编号 ↑"]="Number ↑",
  ["编号 ↓"]="Number ↓",
  ["名称 ↑"]="Name ↑",
  ["编号自然排序：2 在 10 前，字母按 A…Z、AA…；相同编号再按实际名称排列"]="Natural order: 2 before 10; letters A…Z, AA…; ties sorted by line name.",
  ["线路已删除，无法定位。请返回目录刷新。"]="This line was deleted. Return to the directory to refresh.",
  ["定位失败，请稍后重试。"]="Could not locate this line. Please retry.",
  ["在地图上定位此线路"]="Locate this line on the map",
  ["线路图暂时无法绘制。请返回目录重试。"]="Could not draw this map. Return to the directory and retry.",
  ["线路已删除、没有站点或暂时无法读取。请返回目录重试。"]="This line is deleted, empty or unavailable. Return to the directory and retry.",
  ["正在读取线路…"]="Loading line…",
  ["搜索公交标号或线路名称"]="Search bus badge or line name",
  ["输入标号或名称搜索公交线路。"]="Enter a badge or name to find bus lines.",
  ["没有匹配的公交线路。"]="No matching bus lines.",
  ["当前没有此类线路。"]="No lines of this type.",
  ["前缀＋两位流水号：10 → 1001；51 → 5101。"]="Prefix + two-digit sequence: 10 → 1001; 51 → 5101.",
  ["跳过"]="Skip",
  ["数字前缀，例如 10 → 1001、1002…；留空跳过这一类线路"]="Numeric prefix, e.g. 10 → 1001, 1002…; leave blank to skip this category.",
  ["默认关闭；选择后点击“应用到全部公交”保存。"]="Disabled by default. Select, then click “Apply to all buses” to save.",
  ["已开启"]="On",
  ["已关闭"]="Off",
  ["公交批量编号"]="Batch bus numbering",
  ["市内 %d · 跨城 %d · 城市不明跳过 %d"]="Local %d · Express %d · Unknown city: %d skipped",
  ["城市／类别"]="City / category",
  ["预览"]="Preview",
  ["启用时对全部可识别公交使用此规则；之后逐线应用可覆盖，关闭则恢复未被手动修改的旧标号。"]="Applies to all identifiable bus lines. Individual edits can override it. Disabling restores previous badges unless manually edited.",
  ["应用到全部公交"]="Apply to all buses",
  ["未能写入，请重试。"]="Could not save. Please retry.",
  ["%s的前缀只能填写数字；留空跳过。"]="The prefix for %s must contain only digits; leave blank to skip.",
  ["%s与%s的前缀重复。"]="%s and %s have the same prefix.",
  ["关联换乘车站"]="Link transfer stops",
  ["请点击车站或车站图标。"]="Click a stop or its map icon.",
  ["这里包含多个独立车站，请点击目标车站的图标。"]="There are several separate stops here. Click the intended stop’s icon.",
  ["点击开始关联，再依次点击地图上的两个车站。"]="Click “Link stops”, then select two stops on the map.",
  ["已删除："]="Deleted: ",
  ["地图选择器暂时不可用，请稍后重试。"]="Map selection is unavailable. Please retry.",
  ["已取消点选。"]="Selection cancelled.",
  ["请选择另一个车站，不能关联同一站组。"]="Choose a different stop; a stop group cannot link to itself.",
  ["已选齐两个车站，请确认关联。"]="Two stops selected. Confirm the link.",
  ["已选第一个站，请点击第二个站。"]="First stop selected. Click the second stop.",
  ["请点击地图上的第一个车站；右键可取消。"]="Click the first stop on the map; right-click to cancel.",
  ["请点选两个仍然存在的车站。"]="Select two stops that still exist.",
  ["请选择两个不同的车站。"]="Select two different stops.",
  ["这两个车站已关联。"]="These stops are already linked.",
  ["正在解除关联…"]="Unlinking…",
  ["正在关联…"]="Linking…",
  ["已应用到线路图，请保存游戏。"]="Route maps updated. Please save your game.",
  ["未能写入，请稍后重试。"]="Could not save. Please retry.",
  ["已有关联 · %d 对"]="Existing links · %d pairs",
  ["关联可传递：A↔B、B↔C 会共享三个站的换乘。"]="Links are transitive: A↔B and B↔C share transfers across all three stops.",
  ["删除这一条关联；其他关联仍然保留"]="Remove this link; keep all other links.",
  ["解除"]="Unlink",
  ["尚未设置手动关联。"]="No manual links yet.",
  ["尚未点选"]="Not selected",
  ["重新开始点选"]="Restart selection",
  ["重新点选"]="Select again",
  ["开始关联"]="Link stops",
  ["取消点选"]="Cancel",
  ["确认关联"]="Confirm link",
  ["环线没有可确认的起终点，未合并。"]="Circular lines have no confirmed endpoints and cannot be merged.",
  ["同号线路的实际起终点不连通，未合并；请检查整组线路。"]="Lines with this badge have disconnected endpoints and were not merged. Check the whole group.",
  ["省略 %d 站（第 %d–%d 站）"]="%d stops omitted (stops %d–%d)",
  ["该支线省略 %d 站"]="%d stops omitted on this branch",
  ["同号线路未合并 · 端点不连通或为环线"]="Matching lines not merged · disconnected endpoints or circular route",
  ["线路图暂时无法读取车辆数据，请查看游戏日志。"]="Could not read vehicle data. Please check the game log.",
  ["… %d站"]="… %d stops",
  ["切换界面语言"]="Switch interface language",
  ["语言"]="Language",
  ["语言保存失败，请重试。"]="Could not save the language. Please retry.",
}
-- This ordered registry also supplies native names for the language picker.
I.locales={
  {code='en',name='English'}, {code='zh',name='简体中文'}, {code='zh-tw',name='繁體中文'},
  {code='fr',name='Français'}, {code='de',name='Deutsch'}, {code='es',name='Español'},
  {code='it',name='Italiano'}, {code='pt-br',name='Português (Brasil)'}, {code='ru',name='Русский'},
  {code='pl',name='Polski'}, {code='tr',name='Türkçe'}, {code='uk',name='Українська'},
  {code='ja',name='日本語'}, {code='ko',name='한국어'},
}
local indices,catalogs={},{en=I.english}
for index,locale in ipairs(I.locales)do indices[locale.code]=index end
local function normalize(value)
  if type(value)~='string'then return 'en'end
  value=value:lower():gsub('_','-')
  if value=='zh-cn' or value=='zh-hans' or value=='zh-sg'then return 'zh'end
  if value=='zh-hant' or value=='zh-hk'then return 'zh-tw'end
  if indices[value]then return value end
  local base=value:match('^([a-z]+)%-')
  return indices[base] and base or 'en'
end
function I.index(code)return indices[normalize(code)]end
function I.language(aliases)
  local options=aliases and aliases.__options
  return normalize(options and options.language)
end
function I.catalog(code)
  code=normalize(code)
  if code=='zh'then return nil end
  if not catalogs[code]then
    -- Load only languages actually selected; the game loader and this bounded
    -- registry reuse each small dictionary. No filesystem reads or polling.
    catalogs[code]=ug_require('linnan_bulb_cockpit::/gui/bulb_cockpit/locales/'..code..'.lua')
  end
  return catalogs[code]
end
function I.bind(aliases)
  local language=I.language(aliases)
  local messages=I.catalog(language)
  return function(source,...)
    local value=language=='zh' and source or (messages[source] or I.english[source] or source)
    if select('#',...)>0 then return string.format(value,...)end
    return value
  end
end
return I
