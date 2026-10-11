-- Mode-specific primitives; RER A–E use BULB's Paris preset outline masks.
-- See symbols/NOTICE.md for the graphical marks' source and attribution.
-- All shapes are white alpha masks; the live game line color supplies tint.
local B={}
local DARK={0.137,0.122,0.125,1}
local BLUE={0.137,0.247,0.569,1}
local ROOT='linnan_bulb_cockpit::/gui/bulb_cockpit/symbols/'
local shapes={METRO='circle',RER='rounded-square',TRAIN='rounded-square',TRAM='tram-bars',BUS='bus-frame',
  BOAT='tram-bars',AIR='rounded-square',TRUCK='bus-frame'}
function B.geometry(mode,small)
  local size=small and 24 or 38
  local bus=mode=='BUS' or mode=='TRUCK'
  return {shape=shapes[mode] or shapes.TRAIN,width=bus and (small and (mode=='BUS' and 34 or 38) or 50) or size,
    height=bus and (small and (mode=='BUS' and 15.3 or 17.1) or 22.5) or size,
    icon=small and 18 or 26,gap=small and 5 or 6,
    font=small and (bus and (mode=='BUS' and 11 or 9) or (mode=='TRAM' and 16 or 18))
      or (bus and 14 or (mode=='TRAM' and 20 or 28)),
    minFont=small and 9 or 10}
end
-- Advance widths from the game's OFL Noto Sans CJK SC Bold face, rounded upward.
local advance={[" "]=0.26,["!"]=0.282,["\""]=0.479,["#"]=0.646,["$"]=0.572,["%"]=0.902,["&"]=0.75,["'"]=0.266,["("]=0.339,[")"]=0.339,["*"]=0.542,["+"]=0.572,[","]=0.285,["-"]=0.32,["."]=0.281,["/"]=0.415,["0"]=0.572,["1"]=0.572,["2"]=0.572,["3"]=0.572,["4"]=0.572,["5"]=0.572,["6"]=0.572,["7"]=0.572,["8"]=0.572,["9"]=0.572,[":"]=0.281,[";"]=0.285,["<"]=0.572,["="]=0.572,[">"]=0.572,["?"]=0.477,["@"]=0.898,["A"]=0.692,["B"]=0.665,["C"]=0.642,["D"]=0.732,["E"]=0.56,["F"]=0.549,["G"]=0.724,["H"]=0.765,["I"]=0.389,["J"]=0.331,["K"]=0.664,["L"]=0.559,["M"]=0.943,["N"]=0.813,["O"]=0.791,["P"]=0.621,["Q"]=0.791,["R"]=0.656,["S"]=0.551,["T"]=0.577,["U"]=0.756,["V"]=0.65,["W"]=0.967,["X"]=0.67,["Y"]=0.626,["Z"]=0.579,["["]=0.331,["\\"]=0.415,["]"]=0.331,["^"]=0.572,["_"]=0.411,["`"]=0.365,["a"]=0.599,["b"]=0.632,["c"]=0.516,["d"]=0.632,["e"]=0.597,["f"]=0.387,["g"]=0.632,["h"]=0.65,["i"]=0.299,["j"]=0.298,["k"]=0.62,["l"]=0.298,["m"]=0.975,["n"]=0.65,["o"]=0.625,["p"]=0.632,["q"]=0.632,["r"]=0.447,["s"]=0.502,["t"]=0.434,["u"]=0.65,["v"]=0.571,["w"]=0.856,["x"]=0.578,["y"]=0.571,["z"]=0.493,["{"]=0.394,["|"]=0.551,["}"]=0.394,["~"]=0.572}
local function units(value)
  local width=0
  for c in tostring(value):gmatch('[%z\1-\127\194-\244][\128-\191]*') do
    width=width+(advance[c] or 1)
  end
  return width
end
function B.textWidth(value,size)
  local widest=0
  for line in tostring(value):gmatch('[^\n]+')do widest=math.max(widest,units(line)*size)end
  return widest
end
function B.fit(value,width,base,minFont)
  value=tostring(value):gsub('[\r\n]',' ')
  local size=math.floor(math.max(minFont,math.min(base,width/math.max(1,units(value)))))
  if units(value)*size<=width then return value,size end
  local result=''
  for c in value:gmatch('[%z\1-\127\194-\244][\128-\191]*') do
    if units(result..c..'…')*size>width then break end
    result=result..c
  end
  return result..'…',size
end
function B.ink(mode,fill)
  if mode=='TRAM' or mode=='BOAT' then return DARK end
  if fill[1]*0.299+fill[2]*0.587+fill[3]*0.114>0.6 then
    return (mode=='RER' or mode=='TRAIN') and {0,0,0,1} or DARK
  end
  return {1,1,1,1}
end
-- Dependencies are injected so this module owns no React lifecycle hooks.
function B.create(builtin,style,text,gameIcon,theme)
  theme=theme or {}
  local symbolInk=theme.symbolInk or BLUE
  local function badgeInk(mode,fill)
    return ((mode=='TRAM' or mode=='BOAT') and theme.openBadgeInk) or B.ink(mode,fill)
  end
  local function mask(name,width,height,ink,class,tooltip)
    local meta=style{size={width,height},color=ink,anchorPoint={0,0},padding={0,0,0,0},margin={0,0,0,0}}
    meta.class=class;meta.tooltip=tooltip
    return builtin.ImageView{path=ROOT..name..'.tga',scaling=builtin.type.ImageViewScaling.Stretch,meta=meta}
  end
  local function component(width,height,children,class,tooltip,anchor)
    local meta=style{size={width,height},anchorPoint=anchor or {0,0},backgroundColor={0,0,0,0},
      padding={0,0,0,0},margin={0,0,0,0}}
    meta.class=class;meta.tooltip=tooltip
    -- A floating layout measures individual children, not their h/v offsets.
    -- Composite marks need a measured extent, otherwise a BoxLayout parent
    -- can shrink their coordinate space to the largest single badge. Keep
    -- size metadata on a Component, never on the native Layout itself.
    if class=='bulb-mode-mark' or class=='bulb-transfer-group'then
      local extent=style{size={width,height},anchorPoint={0,0},backgroundColor={0,0,0,0}}
      extent.class='bulb-layout-extent'
      table.insert(children,1,builtin.FloatingLayoutChild{h=0,v=0,
        item=builtin.Component{meta=extent,mouseTransparent=true}})
    end
    return builtin.Component{meta=meta,layout=builtin.FloatingLayout{meta={class='bulb-fixed-layout'},children=children}}
  end
  local function add(children,item,x,y,w,h)
    children[#children+1]=builtin.FloatingLayoutChild{h=x/w,v=y/h,item=item}
  end
  local function icon(mode,size)
    local children={}
    if mode=='RER' or mode=='TRAIN' then
      add(children,mask('metro-ring',size,size,symbolInk),0,0,size,size)
      local value,font=B.fit('RER',size*0.80,math.floor(size*0.5),6)
      add(children,text(value,font,size,size,symbolInk,nil,'bulb-mode-letter'),0,0,size,size)
    elseif mode=='METRO' then
      add(children,mask('metro-ring',size,size,symbolInk),0,0,size,size)
      add(children,text('M',math.floor(size*0.75),size,size,symbolInk,nil,'bulb-mode-letter'),0,0,size,size)
    elseif mode=='BUS' then
      add(children,mask('tram-bars',size,size,symbolInk),0,0,size,size)
      add(children,text('BUS',math.floor(size*0.50),size,size,symbolInk,nil,'bulb-mode-letter'),0,0,size,size)
    elseif mode=='TRAM' then
      add(children,mask('tram-bars',size,size,symbolInk),0,0,size,size)
      add(children,mask('tram-glyph',size*0.84,size*0.84,symbolInk),size*0.08,size*0.08,size,size)
    else
      add(children,gameIcon(mode,size),0,0,size,size)
    end
    return component(size,size,children,'bulb-mode-icon')
  end
  local function appendBadge(children,mode,label,fill,small,tooltip,x,y,width,height)
    local g=B.geometry(mode,small)
    local preset=(mode=='RER' or mode=='TRAIN') and tostring(label):match('^%s*([A-Ea-e])%s*$')
    if preset then
      -- Both layers retain the original full SVG bounds, including the letter's
      -- internal padding. Do not fit or recenter these glyphs as ordinary text.
      add(children,mask('rer-frame',g.width,g.height,fill,'bulb-shape-'..g.shape,tooltip),x,y,width,height)
      add(children,mask('rer-'..preset:lower(),g.width,g.height,badgeInk(mode,fill),
        small and 'bulb-rer-transfer-preset' or 'bulb-rer-line-preset',tooltip),x,y,width,height)
    else
      add(children,mask(g.shape,g.width,g.height,fill,'bulb-shape-'..g.shape,tooltip),x,y,width,height)
      local inset=(mode=='METRO' or mode=='RER' or mode=='TRAIN') and g.width*0.16
        or (mode=='TRAM' and small and g.width*0.05 or g.width*0.10)
      local labelWidth=g.width-2*inset
      local value,font=B.fit(label,labelWidth,g.font,g.minFont)
      local lineHeight=math.min(g.height,font+4)
      add(children,text(value,font,labelWidth,lineHeight,badgeInk(mode,fill),nil,
        small and 'bulb-transfer-label' or 'bulb-line-badge',nil,tooltip),
        x+inset,y+(g.height-lineHeight)/2,width,height)
    end
  end
  local function single(mode,label,fill,small,tooltip)
    local g=B.geometry(mode,small)
    local width,height=g.icon+g.gap+g.width,math.max(g.icon,g.height)
    local children={}
    add(children,icon(mode,g.icon),0,(height-g.icon)/2,width,height)
    appendBadge(children,mode,label,fill,small,tooltip,g.icon+g.gap,(height-g.height)/2,width,height)
    return component(width,height,children,'bulb-mode-mark',tooltip),width,height
  end
  local function badge(mode,label,fill,small,tooltip,anchor)
    local g=B.geometry(mode,small)
    local children={}
    appendBadge(children,mode,label,fill,small,tooltip,0,0,g.width,g.height)
    -- Buttons center their content; inline table cells supply a top-left
    -- anchor. The masks inside always keep local top-left coordinates.
    return component(g.width,g.height,children,'bulb-line-tile',tooltip,anchor or {.5,.5}),g.width,g.height
  end
  local function group(mode,rows)
    local g=B.geometry(mode,true)
    local width,height=g.icon,24
    for _,row in ipairs(rows)do
      width=math.max(width,g.icon+#row.lines*(g.gap+g.width))
      height=math.max(height,row.y+24)
    end
    local children,names={},{}
    -- One mode icon belongs to the first row. Continuations keep the same
    -- badge columns in a transparent group, without another icon.
    add(children,icon(mode,g.icon),0,(24-g.icon)/2,width,height)
    for _,row in ipairs(rows)do
      for index,line in ipairs(row.lines)do
        local x=g.icon+g.gap+(index-1)*(g.width+g.gap)
        local y=row.y+(24-g.height)/2
        if line.onClick then
          local content=badge(mode,line.text,line.fill,true,line.fullName)
          local meta=style{size={g.width,g.height},anchorPoint={0,0},padding={0,0,0,0},margin={0,0,0,0}}
          meta.class='bulb-transfer-link';meta.tooltip=line.fullName
          add(children,builtin.Button{meta=meta,content=content,onClick=line.onClick},x,y,width,height)
        else
          appendBadge(children,mode,line.text,line.fill,true,line.fullName,x,y,width,height)
        end
        names[#names+1]=line.fullName
      end
    end
    return component(width,height,children,'bulb-transfer-group',table.concat(names,'\n')),width,height
  end
  return single,group,badge
end
return B
