-- Static display palettes; no game reads, network access or mutable cache.
-- Sources and native-shape approximations: docs/PRESETS.md.
local V={names={'default','paris','shanghai','munich'},modes={'TRAIN','RER','METRO','TRAM','BUS','BOAT','AIR','TRUCK','FREIGHT_TRAIN'}}
local allowedModes,allowedNames={},{}
for _,m in ipairs(V.modes)do allowedModes[m]=true end
for _,n in ipairs(V.names)do allowedNames[n]=true end
local function indexed(colors)
  local result={};for i,c in ipairs(colors)do result[tostring(i)]=c end;return result
end
local paris={
  METRO=indexed{'#ffcd02','#006db8','#9b993b','#bb4a9b','#f78f4b','#77c696','#f59fb3','#c5a3cd','#cec92a',
    '#e0b03b','#8d6539','#008c5a','#87d3df','#662c91','#b80b4b','#f59fb3','#cec92a','#00b397'},
  RER={a='#ed1c2a',b='#4c90cd',c='#ffcd02',d='#008c5a',e='#bb4a9b'},
  TRAIN={h='#8d6539',j='#cec92a',k='#9b993b',l='#c5a3cd',n='#00b397',p='#f78f4b',r='#f59fb3',u='#b80b4b'},
  TRAM=indexed{'#006db8','#bb4a9b','#f78f4b','#e0b03b','#662c91','#ed1c2a','#8d6539','#9b993b','#4c90cd',
    '#9b993b','#f78f4b','#b80b4b','#8d6539','#00b397'},
  BUS={['393']='#87d3df',['183']='#ed1c2a',tvm='#006db8'},
}
paris.METRO['3bis']='#87d3df';paris.METRO['7bis']='#77c696'
paris.TRAM['3a']='#f78f4b';paris.TRAM['3b']='#008c5a';paris.TRAM['3']=nil
for i=1,6 do paris.BUS['tzen'..i]='#cec92a'end
local palettes={paris=paris,
  shanghai={METRO=indexed{'#e3002b','#8cc220','#fcd600','#461d84','#944d9a','#d40068','#ed6f00','#0094d8',
    '#87caed','#c6afd4','#871c2b','#007b66','#e999c0','#616020','#bca886','#98d1c0','#b6766c','#c09453'}},
  munich={METRO=indexed{'#52822f','#c10831','#ee732a','#07a984','#bc7a00','#0065ae','#52822f','#ec6725'},
    RER=indexed{'#1fbae7','#76b82a','#951b81','#e30613','#00527f','#00975f','#a24901','#ffcc00'},
    TRAM={['12']='#96368b',['14']='#e5007d',['16']='#0065ae',['17']='#8b563e',['18']='#13a538',
      ['19']='#e30613',['20']='#16bae7',['21']='#bc7a00',['23']='#bccf00',['25']='#f1919c',['27']='#f7a600',['28']='#f7a600'}},
}
function V.valid(patch)
  if type(patch)~='table' or not next(patch)then return false end
  for mode,preset in pairs(patch)do if not allowedModes[mode] or not allowedNames[preset]then return false end end
  return true
end
function V.selection(aliases,mode)
  local options=aliases and aliases.__options
  local selections=options and options.linePresets
  local value=type(selections)=='table' and selections[mode]
  return allowedNames[value] and value or 'default'
end
local function key(mode,value)
  local text=tostring(value or ''):lower():gsub('%s+','')
  if mode=='METRO'then text=text:gsub('^metro',''):gsub('^m',''):gsub('^u',''):gsub('号线$','')
  elseif mode=='RER'then text=text:gsub('^rer',''):gsub('^s','')
  elseif mode=='TRAIN'then text=text:gsub('^train','')
  elseif mode=='TRAM'then text=text:gsub('^tramway',''):gsub('^tram',''):gsub('^t','')end
  return text
end
function V.resolve(mode,badge,gameColor,aliases,identifier)
  local preset=V.selection(aliases,mode)
  local palette=palettes[preset] and palettes[preset][mode]
  -- Default/unsupported types do no badge-string normalization.
  if not palette then return {color=gameColor,preset=preset,matched=false}end
  local index=key(mode,badge)
  local chosen=palette and palette[index]
  if not chosen and identifier~=nil then index=key(mode,identifier);chosen=palette and palette[index]end
  local result={color=chosen or gameColor,preset=preset,matched=chosen~=nil}
  if not chosen then return result end
  if preset=='paris' and mode=='TRAM'then result.ink='#231f20'
  elseif preset=='shanghai' and mode=='METRO'then result.shape='rectangle';result.ink='#ffffff'
  elseif preset=='munich' and (mode=='METRO' or mode=='RER' or mode=='TRAM')then
    result.shape=mode=='RER' and 'capsule' or 'rectangle';result.aspect=2
    result.ink=(mode=='RER' and index=='8') and '#000000' or '#ffffff'
    if mode=='METRO' and (index=='7' or index=='8')then result.secondary='#c10831'
    elseif mode=='TRAM' and index=='28'then result.outline=true;result.ink=chosen end
  end
  return result
end
function V.decorate(plan,aliases,gameColor)
  plan.presentation=V.resolve(plan.mode,plan.badge,gameColor,aliases,plan.identifier)
  plan.color=plan.presentation.color
  if plan.presentation.matched then
    for _,stop in ipairs(plan.stops)do stop.color=plan.color end
    for _,segment in ipairs(plan.rails or {})do segment.color=plan.color end
  end
  for _,stop in ipairs(plan.stops)do
    for _,transfer in ipairs(stop.transfers)do
      transfer.presentation=V.resolve(transfer.mode,transfer.text,transfer.color,aliases,transfer.identifier)
      transfer.color=transfer.presentation.color
    end
  end
  return plan
end
return V
